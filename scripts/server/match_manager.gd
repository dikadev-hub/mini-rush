# scripts/server/match_manager.gd
# Alur match: countdown, start, broadcast state 20 Hz, checkpoint, finish, ranking.
# Owner: A7. Kontrak: README 5.6.
class_name MatchManager
extends RefCounted

var room_manager: RoomManager
var match_timeout_sec: float = GameConfig.DEFAULT_MATCH_TIMEOUT_SEC
var _broadcast_accum: float = 0.0


func _init(p_room_manager: RoomManager, p_timeout_sec: float) -> void:
	room_manager = p_room_manager
	match_timeout_sec = p_timeout_sec


## Mulai countdown. Return {ok, error}.
func request_start(room: Room, requester_peer: int) -> Dictionary:
	if room == null:
		return {"ok": false, "error": Protocol.ErrorCode.ROOM_NOT_FOUND}
	if requester_peer != room.host_peer:
		return {"ok": false, "error": Protocol.ErrorCode.NOT_HOST}
	var ready_count: int = 0
	for pid: int in room.players:
		var e: PlayerEntry = room.players[pid]
		if e.is_ready:
			ready_count += 1
	if room.player_count() < GameConfig.MIN_PLAYERS_TO_START or ready_count < GameConfig.MIN_PLAYERS_TO_START \
			or ready_count < room.player_count():
		return {"ok": false, "error": Protocol.ErrorCode.INVALID_STATE}
	room.state = Protocol.RoomState.COUNTDOWN
	room.countdown_start_server_ms = Time.get_ticks_msec()
	var now: int = Time.get_unix_time_from_system() * 1000
	return {
		"ok": true,
		"error": Protocol.ErrorCode.OK,
		"start_server_ms": now + int(GameConfig.COUNTDOWN_SECONDS * 1000.0),
		"countdown_sec": GameConfig.COUNTDOWN_SECONDS,
	}


## Countdown selesai: race dimulai.
func begin_race(room: Room) -> void:
	room.state = Protocol.RoomState.RUNNING
	room.race_start_server_ms = Time.get_ticks_msec()
	for pid: int in room.players:
		(room.players[pid] as PlayerEntry).reset_for_race()
	Log.info("room %s: race dimulai (timeout %ds)" % [room.code, int(match_timeout_sec)])


## Proses satu state update dari client. Return {ok, kick, error, reason}.
func process_state(room: Room, entry: PlayerEntry, state: Dictionary, sender_id: int, now_ms: int) -> Dictionary:
	var payload_check: Dictionary = Validator.check_state_payload(state, sender_id)
	if not bool(payload_check["ok"]):
		Log.warn("room %s: state peer %d ditolak (%s)" % [room.code, sender_id, payload_check["reason"]])
		return {"ok": false, "kick": false, "error": Protocol.ErrorCode.INVALID_STATE, "reason": payload_check["reason"]}
	var pos: Vector3 = state["p"] as Vector3
	var delta_sec: float = 0.0
	var last_ms: int = entry.last_state_ms
	if entry.has_state and now_ms > last_ms:
		delta_sec = float(now_ms - last_ms) / 1000.0
	if entry.has_state and delta_sec > 0.0:
		var speed: float = Validator.compute_speed(entry.last_pos, pos, delta_sec)
		if not Validator.is_speed_valid(speed):
			var kicked: bool = Validator.register_speed_violation(entry, now_ms)
			Log.warn("room %s: peer %d speed %.1f m/s > batas (%s)" % [
				room.code, sender_id, speed,
				("kick" if kicked else "ditolak")])
			if kicked:
				return {"ok": false, "kick": true, "error": Protocol.ErrorCode.INVALID_STATE,
					"reason": RoomManager.KICK_SPEED_HACK}
			return {"ok": false, "kick": false, "error": Protocol.ErrorCode.INVALID_STATE, "reason": "speed"}
	# Update valid.
	entry.last_pos = pos
	entry.last_state_ms = now_ms
	entry.has_state = true
	return {"ok": true, "kick": false, "error": Protocol.ErrorCode.OK, "reason": ""}


## Klaim checkpoint. Return {accepted}.
func process_checkpoint(room: Room, entry: PlayerEntry, index: int) -> bool:
	var accepted: bool = Validator.check_checkpoint(entry, index)
	if accepted:
		entry.next_checkpoint = index + 1
		Log.info("room %s: peer %d checkpoint %d diterima" % [room.code, entry.peer_id, index])
	else:
		Log.warn("room %s: peer %d checkpoint %d ditolak (next=%d, pos=%s)" % [
			room.code, entry.peer_id, index, entry.next_checkpoint, entry.last_pos])
	return accepted


## Klaim finish. Return {accepted, time_ms, is_winner}.
func process_finish(room: Room, entry: PlayerEntry, now_ms: int) -> Dictionary:
	if not Validator.check_finish(entry):
		Log.warn("room %s: finish peer %d ditolak (checkpoints=%d/%d)" % [
			room.code, entry.peer_id, entry.next_checkpoint, MapData.CHECKPOINT_POSITIONS.size()])
		return {"accepted": false, "time_ms": -1, "is_winner": false}
	entry.finish_time_ms = now_ms - room.race_start_server_ms
	entry.status = Protocol.PlayerStatus.FINISHED
	var is_winner: bool = true
	for pid: int in room.players:
		var e: PlayerEntry = room.players[pid]
		if e.peer_id != entry.peer_id and e.finish_time_ms >= 0 and e.finish_time_ms < entry.finish_time_ms:
			is_winner = false
	Log.info("room %s: peer %d finish dalam %d ms (winner=%s)" % [
		room.code, entry.peer_id, entry.finish_time_ms, str(is_winner)])
	return {"accepted": true, "time_ms": entry.finish_time_ms, "is_winner": is_winner}


## Ranking akhir: urutan waktu finish, lalu DNF/DISCONNECTED di akhir.
func build_results(room: Room, now_ms: int) -> Array:
	var finished: Array[PlayerEntry] = []
	var dnf: Array[PlayerEntry] = []
	for pid: int in room.players:
		var e: PlayerEntry = room.players[pid]
		if e.finish_time_ms >= 0:
			finished.append(e)
		else:
			e.status = Protocol.PlayerStatus.DNF
			dnf.append(e)
	finished.sort_custom(func(a: PlayerEntry, b: PlayerEntry) -> bool:
		if a.finish_time_ms != b.finish_time_ms:
			return a.finish_time_ms < b.finish_time_ms
		return a.join_order < b.join_order)
	dnf.sort_custom(func(a: PlayerEntry, b: PlayerEntry) -> bool:
		return a.join_order < b.join_order)
	var results: Array = []
	var rank: int = 1
	for e: PlayerEntry in finished:
		results.append({
			"rank": rank,
			"peer_id": e.peer_id,
			"nickname": e.nickname,
			"time_ms": e.finish_time_ms,
			"status": int(Protocol.PlayerStatus.FINISHED),
		})
		rank += 1
	for e: PlayerEntry in dnf:
		results.append({
			"rank": rank,
			"peer_id": e.peer_id,
			"nickname": e.nickname,
			"time_ms": -1,
			"status": int(e.status),
		})
		rank += 1
	return results


## Cek akhir match: semua FINISHED/DNF atau timeout. Return true jika match harus diakhiri.
func should_finish(room: Room, now_ms: int) -> bool:
	if room.state != Protocol.RoomState.RUNNING:
		return false
	var all_done: bool = true
	for pid: int in room.players:
		var e: PlayerEntry = room.players[pid]
		if e.finish_time_ms < 0:
			all_done = false
	if all_done and room.player_count() > 0:
		return true
	return now_ms - room.race_start_server_ms >= int(match_timeout_sec * 1000.0)


## Kirim broadcast state 20 Hz. states_fn mengembalikan Array snapshot tiap pemain.
func tick_broadcast(delta: float, room: Room, states_fn: Callable) -> Array:
	if room == null or room.state != Protocol.RoomState.RUNNING:
		return []
	_broadcast_accum += delta
	var interval: float = 1.0 / GameConfig.SERVER_STATE_RATE_HZ
	if _broadcast_accum < interval:
		return []
	_broadcast_accum -= interval
	return states_fn.call(room)
