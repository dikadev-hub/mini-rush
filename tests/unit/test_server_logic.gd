# tests/unit/test_server_logic.gd — smoke test logika server (A7). Sementara, dipakai A9 untuk integrasi.
extends SceneTree

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	randomize()
	var rm := RoomManager.new()
	# nickname
	check(not Validator.check_nickname("a"), "nickname 1 char ditolak")
	check(not Validator.check_nickname("ab!"), "nickname invalid char ditolak")
	check(Validator.check_nickname("ab-cd Ef"), "nickname valid diterima")
	# protocol version
	check(not Validator.check_protocol_version(99), "versi mismatch ditolak")
	# create room
	var res := rm.create_room(100, "Host", 0)
	check(res["ok"], "create room ok")
	var room: Room = res["room"]
	check(room.host_peer == 100, "host = pemain pertama")
	# join hingga penuh (8)
	var joined: bool = true
	for i in range(2, 10):
		var r := rm.join_room(i, room.code, "P%d" % i, 0)
		if i <= 8 and not r["ok"]:
			joined = false
		if i == 9 and r["ok"]:
			check(false, "pemain ke-9 harus ROOM_FULL")
		if i == 9:
			check(r["error"] == Protocol.ErrorCode.ROOM_FULL, "pemain ke-9 ROOM_FULL")
	check(joined, "join pemain 2-8 ok")
	# join room lain (started check diabaikan, cek room tidak ada)
	var r2 := rm.join_room(99, "ZZZZZZ", "Px", 0)
	check(r2["error"] == Protocol.ErrorCode.ROOM_NOT_FOUND, "room tidak ada -> ROOM_NOT_FOUND")
	# host migration
	rm.leave_room(100)
	check(room.host_peer == 2, "host keluar -> pemain tertua jadi host")
	# state & speed validation
	var e := rm.get_entry(2)
	var now: int = Time.get_ticks_msec()
	e.last_state_ms = now - 1000
	e.has_state = true
	e.last_pos = Vector3.ZERO
	var m := MatchManager.new(rm, 600.0)
	check(m.process_state(room, e, {"pid": 3, "p": Vector3.ZERO}, 2, now)["ok"] == false, "pid mismatch ditolak")
	var fake_pos := Vector3(20, 0, 0)  # 20 m dalam 1 s > 21 batas? MAX_SPEED*FACTOR=21 -> valid; pakai 40
	fake_pos = Vector3(40, 0, 0)
	var res3 := m.process_state(room, e, {"pid": 2, "p": fake_pos}, 2, now)
	check(res3["ok"] == false, "speed hack ditolak")
	for i in 20:
		Validator.register_speed_violation(e, now)
	check(true, "20 pelanggaran tercatat")
	var res4 := m.process_state(room, e, {"pid": 2, "p": fake_pos}, 2, now)
	check(res4["kick"] == true, "20 pelanggaran -> kick")
	# out of bounds
	check(not Validator.check_position_in_bounds(Vector3(100, 0, 0)), "luar bounds ditolak")
	# checkpoint
	var e2 := rm.get_entry(3)
	e2.last_pos = MapData.CHECKPOINT_POSITIONS[0]
	check(m.process_checkpoint(room, e2, 1) == false, "checkpoint melompat ditolak")
	check(m.process_checkpoint(room, e2, 0) == true, "checkpoint urut diterima")
	# finish sebelum semua checkpoint ditolak
	check(m.process_finish(room, e2, now)["accepted"] == false, "finish tanpa semua checkpoint ditolak")
	# finish valid
	e2.next_checkpoint = MapData.CHECKPOINT_POSITIONS.size()
	e2.last_pos = MapData.FINISH_POSITION
	room.race_start_server_ms = now - 5000
	var fr := m.process_finish(room, e2, now)
	check(fr["accepted"] == true and fr["time_ms"] == 5000, "finish valid, waktu 5000 ms")
	# ranking: e2 FINISHED, lainnya DNF
	room.state = Protocol.RoomState.RUNNING
	var results := m.build_results(room, now)
	check(results.size() == room.player_count(), "results memuat semua pemain")
	check(int(results[0]["time_ms"]) == 5000, "ranking pertama = finisher")
	# room TTL
	rm.expire_reconnects(now)
	rm.expire_empty_rooms(now + int(GameConfigScriptRoomTTLProbe()))
	print("PASSED: %d  FAILED: %d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func GameConfigScriptRoomTTLProbe() -> int:
	return 0


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [OK] " + label)
	else:
		_failed += 1
		printerr("  [FAIL] " + label)
