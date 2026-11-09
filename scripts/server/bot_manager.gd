# scripts/server/bot_manager.gd
# Bot AI pemain (server-side): pseudo-peer tanpa koneksi jaringan sungguhan.
# Bot ikut state match & results: bergerak mengikuti path checkpoint Rush Island
# (MapData), klaim checkpoint/finish via mekanisme server yang sama seperti
# pemain biasa (MatchManager.process_checkpoint / process_finish).
# Owner: fitur bot. Kontrak RPC eksisting TIDAK diubah; hanya RPC baru request_add_bot.
class_name BotManager
extends RefCounted

const BOT_SPEED_MIN: float = 5.5   # m/s, variasi per bot agar tidak robotik
const BOT_SPEED_MAX: float = 8.5
const REACH_EPSILON: float = 0.4   # jarak "sampai" target waypoint (m)

var match_manager: MatchManager


func _init(p_match_manager: MatchManager) -> void:
	match_manager = p_match_manager


## Tambahkan satu bot ke room (hanya dipanggil dari ServerMain, host & lobi saja).
## Nama berurutan: Bot 1, Bot 2, ... peer_id negatif agar tidak tabrakan dengan peer asli.
func add_bot(room: Room) -> PlayerEntry:
	var bot_index: int = 1
	while true:
		var taken: bool = false
		for pid: int in room.players:
			if (room.players[pid] as PlayerEntry).nickname == "Bot %d" % bot_index:
				taken = true
				break
		if not taken:
			break
		bot_index += 1
	var entry := PlayerEntry.from_values(
		room.next_bot_peer_id, "Bot %d" % bot_index, randi() % 4, room.next_join_order, "")
	entry.is_bot = true
	entry.is_ready = true
	entry.bot_speed_mps = randf_range(BOT_SPEED_MIN, BOT_SPEED_MAX)
	room.players[entry.peer_id] = entry
	room.next_join_order += 1
	room.next_bot_peer_id -= 1
	room.empty_since_ms = -1
	Log.info("room %s: bot ditambahkan (nickname='%s' peer_id=%d speed=%.1f m/s)" % [
		room.code, entry.nickname, entry.peer_id, entry.bot_speed_mps])
	return entry


## Update semua bot tiap frame server. Hanya aktif saat room RUNNING.
func update_bots(room: Room, delta_sec: float, now_ms: int) -> void:
	if room.state != Protocol.RoomState.RUNNING:
		return
	for pid: int in room.players:
		var e: PlayerEntry = room.players[pid]
		if not e.is_bot or e.finish_time_ms >= 0:
			continue
		_advance_bot(room, e, delta_sec, now_ms)


## Gerakkan satu bot ke arah target berikutnya (checkpoint atau finish).
func _advance_bot(room: Room, e: PlayerEntry, delta_sec: float, now_ms: int) -> void:
	var target: Vector3
	var is_finish: bool = e.next_checkpoint >= MapData.CHECKPOINT_POSITIONS.size()
	if is_finish:
		target = MapData.FINISH_POSITION
	else:
		target = MapData.CHECKPOINT_POSITIONS[e.next_checkpoint]
	var remaining: float = e.last_pos.distance_to(target)
	var step: float = maxf(e.bot_speed_mps * delta_sec, REACH_EPSILON)
	if remaining <= step:
		# Sampai waypoint: klaim via mekanisme server yang sama seperti pemain.
		e.last_pos = target
		e.has_state = true
		e.last_state_ms = now_ms
		if is_finish:
			match_manager.process_finish(room, e, now_ms)
		else:
			match_manager.process_checkpoint(room, e, e.next_checkpoint)
		return
	e.last_pos = e.last_pos.move_toward(target, step)
	# Bot ikut broadcast state agar client melihat bot bergerak.
	e.has_state = true
	e.last_state_ms = now_ms
