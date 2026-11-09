# scripts/server/room_manager.gd
# Manajemen room: create/join/leave, host migration, TTL room kosong, reconnect.
# Owner: A7. Kontrak: README 5.6.
class_name RoomManager
extends RefCounted

const KICK_SPEED_HACK: String = "speed_violation_limit"

var rooms: Dictionary = {}       # kode -> Room
var peer_to_room: Dictionary = {}  # peer_id -> kode


static func new_token() -> String:
	return "%08x%08x" % [randi(), randi()]


func generate_unique_code() -> String:
	for attempt: int in 100:
		var code := RoomCode.generate()
		if not rooms.has(code):
			return code
	return RoomCode.generate() + str(randi() % 10)  # fallback praktis; tetap 6 karakter dijalannya generator


func get_room_by_peer(peer_id: int) -> Room:
	if not peer_to_room.has(peer_id):
		return null
	return rooms.get(peer_to_room[peer_id], null)


func get_entry(peer_id: int) -> PlayerEntry:
	var room := get_room_by_peer(peer_id)
	if room == null:
		return null
	return room.players.get(peer_id, null)


## Buat room. Return {ok, error, room, entry}.
func create_room(peer_id: int, nickname: String, character_id: int) -> Dictionary:
	if not Validator.check_nickname(nickname):
		return {"ok": false, "error": Protocol.ErrorCode.INVALID_NICKNAME, "room": null, "entry": null}
	var code := generate_unique_code()
	var token := new_token()
	var entry := PlayerEntry.from_values(peer_id, nickname, character_id, 0, token)
	var room := Room.create(code, entry, _now_ms())
	rooms[code] = room
	peer_to_room[peer_id] = code
	Log.info("room %s dibuat oleh peer %d (nickname='%s')" % [code, peer_id, nickname])
	return {"ok": true, "error": Protocol.ErrorCode.OK, "room": room, "entry": entry}


## Join room. Return {ok, error, room, entry}.
func join_room(peer_id: int, room_code: String, nickname: String, character_id: int) -> Dictionary:
	if not Validator.check_nickname(nickname):
		return {"ok": false, "error": Protocol.ErrorCode.INVALID_NICKNAME, "room": null, "entry": null}
	var room: Room = rooms.get(room_code, null)
	if room == null:
		return {"ok": false, "error": Protocol.ErrorCode.ROOM_NOT_FOUND, "room": null, "entry": null}
	if peer_to_room.has(peer_id):
		return {"ok": false, "error": Protocol.ErrorCode.INVALID_STATE, "room": null, "entry": null}
	if room.player_count() >= GameConfig.MAX_PLAYERS_PER_ROOM:
		return {"ok": false, "error": Protocol.ErrorCode.ROOM_FULL, "room": null, "entry": null}
	if room.state != Protocol.RoomState.LOBBY:
		return {"ok": false, "error": Protocol.ErrorCode.ROOM_ALREADY_STARTED, "room": null, "entry": null}
	# Reconnect: slot lama dengan token yang sama masih ada.
	var token := ""
	var entry := PlayerEntry.from_values(peer_id, nickname, character_id, room.next_join_order, token)
	entry.player_token = new_token()
	room.players[peer_id] = entry
	room.next_join_order += 1
	peer_to_room[peer_id] = room_code
	room.empty_since_ms = -1
	Log.info("peer %d join room %s (nickname='%s')" % [peer_id, room_code, nickname])
	return {"ok": true, "error": Protocol.ErrorCode.OK, "room": room, "entry": entry}


## Reconnect dengan token lama: kembalikan ke slot yang sama (README 5.6).
func try_reconnect(peer_id: int, room_code: String, token: String) -> Dictionary:
	var room: Room = rooms.get(room_code, null)
	if room == null:
		return {"ok": false, "room": null, "entry": null}
	for pid: int in room.players:
		var e: PlayerEntry = room.players[pid]
		if e.peer_id != peer_id and e.player_token == token and e.status == Protocol.PlayerStatus.DISCONNECTED:
			# Pindahkan slot lama ke peer baru.
			room.players.erase(pid)
			e.peer_id = peer_id
			e.status = Protocol.PlayerStatus.ALIVE
			e.disconnected_at_ms = -1
			room.players[peer_id] = e
			peer_to_room[peer_id] = room_code
			Log.info("peer %d reconnect ke room %s (slot lama dipulihkan)" % [peer_id, room_code])
			return {"ok": true, "room": room, "entry": e}
	return {"ok": false, "room": null, "entry": null}


## Keluar room. Return true jika ada room yang terdampak.
func leave_room(peer_id: int) -> bool:
	var room := get_room_by_peer(peer_id)
	if room == null:
		return false
	var was_host: bool = room.host_peer == peer_id
	room.players.erase(peer_id)
	peer_to_room.erase(peer_id)
	Log.info("peer %d leave room %s" % [peer_id, room.code])
	if room.is_empty():
		room.empty_since_ms = _now_ms()
		return true
	if was_host:
		var new_host: int = room.oldest_active_peer()
		room.host_peer = new_host
		Log.info("host migration room %s: peer %d -> %d" % [room.code, peer_id, new_host])
	return true


## Peer disconnect. Saat RUNNING: tandai DISCONNECTED (bukan remove) agar reconnect mungkin.
func handle_disconnect(peer_id: int) -> void:
	var room := get_room_by_peer(peer_id)
	if room == null:
		return
	var entry := get_entry(peer_id)
	if room.state == Protocol.RoomState.RUNNING and entry != null:
		entry.status = Protocol.PlayerStatus.DISCONNECTED
		entry.disconnected_at_ms = _now_ms()
		Log.info("peer %d disconnect saat RUNNING di room %s (DISCONNECTED, reconnect window %ds)" % [
			peer_id, room.code, int(GameConfig.RECONNECT_WINDOW_SEC)])
		peer_to_room.erase(peer_id)
		return
	leave_room(peer_id)


## Buang slot DISCONNECTED yang melewati reconnect window.
func expire_reconnects(now_ms: int) -> void:
	var window_ms: int = int(GameConfig.RECONNECT_WINDOW_SEC * 1000.0)
	for code: String in rooms:
		var room: Room = rooms[code]
		if room.state != Protocol.RoomState.RUNNING:
			continue
		var to_remove: Array[int] = []
		for pid: int in room.players:
			var e: PlayerEntry = room.players[pid]
			if e.status == Protocol.PlayerStatus.DISCONNECTED and e.disconnected_at_ms >= 0:
				if now_ms - e.disconnected_at_ms > window_ms:
					to_remove.append(pid)
		for pid: int in to_remove:
			var e: PlayerEntry = room.players[pid]
			e.status = Protocol.PlayerStatus.DNF
			room.players.erase(pid)
			Log.info("slot peer %d di room %s melewati reconnect window (DNF, dihapus)" % [pid, code])
			if room.is_empty():
				room.empty_since_ms = now_ms


## Hapus room kosong setelah ROOM_EMPTY_TTL_SEC. Return daftar kode yang dihapus.
func expire_empty_rooms(now_ms: int) -> Array[String]:
	var removed: Array[String] = []
	var ttl_ms: int = int(GameConfig.ROOM_EMPTY_TTL_SEC * 1000.0)
	var to_remove: Array[String] = []
	for code: String in rooms:
		var room: Room = rooms[code]
		if room.is_empty() and room.empty_since_ms >= 0:
			if now_ms - room.empty_since_ms >= ttl_ms:
				to_remove.append(code)
	for code: String in to_remove:
		rooms.erase(code)
		removed.append(code)
		Log.info("room %s kosong > TTL, dihapus" % code)
	return removed


func kick_peer(peer_id: int, reason: String) -> void:
	var room := get_room_by_peer(peer_id)
	var code := room.code if room != null else "?"
	leave_room(peer_id)
	Log.warn("kick peer %d dari room %s: %s" % [peer_id, code, reason])
	# Disconnect diterapkan NetManager entry point (ServerMain) di sisi multiplayer_peer.


func match_finished(room: Room, now_ms: int) -> void:
	room.state = Protocol.RoomState.FINISHED
	Log.info("match room %s selesai pada %d" % [room.code, now_ms])


static func _now_ms() -> int:
	return Time.get_ticks_msec()
