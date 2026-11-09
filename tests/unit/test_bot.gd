# tests/unit/test_bot.gd — Unit test fitur bot AI (server-side).
# Skenario: add bot join room, progress checkpoint via update_bots, finish masuk results.
extends RefCounted


func run(t) -> void:
	print("  -- bot AI server-side")
	_test_add_bot(t)
	_test_add_bot_names_and_capacity(t)
	_test_bot_not_host_candidate(t)
	_test_bot_progress_and_finish(t)
	_test_bot_in_results(t)
	_test_bot_reset_for_race(t)


func _make_room(bot_count: int = 0) -> Room:
	var rm := RoomManager.new()
	var res := rm.create_room(100, "Host", 0)
	var room: Room = res["room"]
	var mm: MatchManager = MatchManager.new(rm, 600.0)
	var bm: BotManager = BotManager.new(mm)
	for i in bot_count:
		bm.add_bot(room)
	return room


func _make_managers():
	var rm := RoomManager.new()
	var res := rm.create_room(100, "Host", 0)
	var room: Room = res["room"]
	var mm: MatchManager = MatchManager.new(rm, 600.0)
	var bm: BotManager = BotManager.new(mm)
	return [rm, room, mm, bm]


func _test_add_bot(t) -> void:
	var room := _make_room(1)
	t.check(room.player_count() == 2, "bot: host + 1 bot di room")
	var found: PlayerEntry = null
	for pid: int in room.players:
		var e: PlayerEntry = room.players[pid]
		if e.is_bot:
			found = e
	t.check(found != null, "bot: entri bot ada di players")
	if found != null:
		t.check(found.nickname == "Bot 1", "bot: nama 'Bot 1'")
		t.check(found.peer_id < 0, "bot: peer_id negatif (tidak tabrakan peer asli)")
		t.check(found.is_ready, "bot: otomatis ready")
		t.check(found.bot_speed_mps > 0.0, "bot: kecepatan terisi")
		t.check(bool(found.to_dict().get("is_bot", false)), "bot: snapshot memuat is_bot=true")


func _test_add_bot_names_and_capacity(t) -> void:
	var room := _make_room(3)
	var names: Array = []
	for pid: int in room.players:
		var e: PlayerEntry = room.players[pid]
		if e.is_bot:
			names.append(e.nickname)
	t.check(names.size() == 3, "bot: 3 bot ditambahkan")
	t.check("Bot 2" in names and "Bot 3" in names, "bot: nama berurutan tanpa duplikat")
	# Room penuh: 8 pemain -> bot ke-9 ditolak di level ServerMain; di sini cek jumlah.
	t.check(room.player_count() <= 8, "bot: batas maksimum pemain dihormati")


func _test_bot_not_host_candidate(t) -> void:
	var room := _make_room(2)
	# Host keluar -> host baru harus manusia, bukan bot.
	room.host_peer = 0  # paksa migrasi manual: cari kandidat non-bot
	var cand := room.oldest_active_peer()
	var e: PlayerEntry = room.players[cand]
	t.check(e != null and not e.is_bot, "bot: oldest_active_peer tidak memilih bot")


func _test_bot_progress_and_finish(t) -> void:
	var parts: Array = _make_managers()
	var room: Room = parts[1]
	var mm: MatchManager = parts[2]
	var bm: BotManager = parts[3]
	var bot: PlayerEntry = bm.add_bot(room)
	room.state = Protocol.RoomState.RUNNING
	room.race_start_server_ms = 1000
	var now: int = 2000
	# Simulasi update sampai bot finish (maks 5 menit virtual, step 0.5 s).
	var finished: bool = false
	for i in 3600:
		bm.update_bots(room, 0.5, now)
		if bot.finish_time_ms >= 0:
			finished = true
			break
		now += 500
	t.check(finished, "bot: mencapai finish via checkpoint mekanisme server")
	t.check(bot.status == Protocol.PlayerStatus.FINISHED, "bot: status FINISHED")
	t.check(bot.next_checkpoint == MapData.CHECKPOINT_POSITIONS.size(), "bot: semua checkpoint terkumpul")
	t.check(bot.finish_time_ms > 0, "bot: finish_time_ms positif")
	# Semua selesai -> should_finish true (bot ikut logika match). Host dibuat finish juga.
	var host: PlayerEntry = room.players[100]
	for cp in MapData.CHECKPOINT_POSITIONS.size():
		host.last_pos = MapData.CHECKPOINT_POSITIONS[cp]
		mm.process_checkpoint(room, host, cp)
	host.last_pos = MapData.FINISH_POSITION
	mm.process_finish(room, host, now)
	t.check(mm.should_finish(room, now), "bot: should_finish true saat bot & host finish")


func _test_bot_in_results(t) -> void:
	var parts: Array = _make_managers()
	var room: Room = parts[1]
	var mm: MatchManager = parts[2]
	var bm: BotManager = parts[3]
	var bot: PlayerEntry = bm.add_bot(room)
	room.state = Protocol.RoomState.RUNNING
	room.race_start_server_ms = 1000
	var now: int = 2000
	for i in 3600:
		bm.update_bots(room, 0.5, now)
		if bot.finish_time_ms >= 0:
			break
		now += 500
	var results: Array = mm.build_results(room, now)
	t.check(results.size() == 2, "bot: results memuat host + bot")
	var bot_result: Dictionary = {}
	for r: Variant in results:
		var e: Dictionary = r as Dictionary
		if str(e.get("nickname", "")) == bot.nickname:
			bot_result = e
	t.check(not bot_result.is_empty(), "bot: hasil bot ada di rpc_match_results payload")
	if not bot_result.is_empty():
		t.check(int(bot_result.get("time_ms", -1)) > 0, "bot: waktu finish tercatat di hasil")
		t.check(int(bot_result.get("status", -1)) == int(Protocol.PlayerStatus.FINISHED), "bot: status FINISHED di hasil")
		t.check(int(bot_result.get("rank", 0)) >= 1, "bot: rank valid")


func _test_bot_reset_for_race(t) -> void:
	var parts: Array = _make_managers()
	var room: Room = parts[1]
	var mm: MatchManager = parts[2]
	var bm: BotManager = parts[3]
	var bot: PlayerEntry = bm.add_bot(room)
	room.state = Protocol.RoomState.RUNNING
	room.race_start_server_ms = 1000
	var now: int = 2000
	for i in 3600:
		bm.update_bots(room, 0.5, now)
		if bot.finish_time_ms >= 0:
			break
		now += 500
	# Race baru: reset_for_race dipanggil begin_race.
	mm.begin_race(room)
	t.check(bot.finish_time_ms == -1, "bot: reset untuk race berikutnya")
	t.check(bot.next_checkpoint == 0, "bot: checkpoint di-reset")
	t.check(room.state == Protocol.RoomState.RUNNING, "bot: room RUNNING untuk race baru")
