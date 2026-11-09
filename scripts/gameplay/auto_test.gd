# scripts/gameplay/auto_test.gd — Gelombang 3 (A9): skenario --auto-test.
# Alur: connect -> create/join room -> ready -> host start -> countdown ->
# race (state exchange 20 Hz, autodrive) -> rpc_match_results -> quit(0).
# Client 1: create room & print "AUTOTEST ROOM_CODE=<kode>".
# Client 2+: join via --room-code=<kode>.
extends Node

const RACE_SCENE: String = "res://scripts/gameplay/race_scene.gd"
const WATCHDOG_SEC: float = 90.0

var _index: int = 1
var _scenario: String = "join_room"
var _bot_seen: bool = false
var _room_code: String = ""
var _countdown_received: bool = false
var _states_exchanged: bool = false
var _results_received: bool = false
var _started_requested: bool = false
var _elapsed: float = 0.0
var _poll_accum: float = 0.0

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--auto-test="):
			_scenario = arg.get_slice("=", 1)
		elif arg.begins_with("--auto-test-index="):
			_index = int(arg.get_slice("=", 1))
		elif arg.begins_with("--room-code="):
			_room_code = arg.get_slice("=", 1)
	print("[AUTOTEST] client %d mulai (room_code='%s')" % [_index, _room_code])
	NetManager.connection_succeeded.connect(_on_connected)
	NetManager.connection_failed.connect(_on_connection_failed)
	NetManager.room_response_received.connect(_on_room_response)
	NetManager.match_countdown_started.connect(_on_countdown)
	NetManager.match_started.connect(_on_match_started)
	NetManager.remote_states_updated.connect(_on_remote_states)
	NetManager.match_results_received.connect(_on_results)
	NetManager.room_snapshot_updated.connect(_on_snapshot)
	print("[AUTOTEST] skenario: %s" % _scenario)
	if GameConfig.transport == "ws":
		NetManager.connect_to_server_ws(GameConfig.server_address, GameConfig.server_port)
	else:
		NetManager.connect_to_server(GameConfig.server_address, GameConfig.server_port)

func _on_connection_failed(_reason: String) -> void:
	printerr("[AUTOTEST] FAIL koneksi: " + _reason)
	get_tree().quit(1)

func _on_connected() -> void:
	var nick: String = "Tester%d" % _index
	if _index == 1:
		NetManager.request_create_room(nick, 0)
	else:
		NetManager.request_join_room(_room_code, nick, 0)

func _on_room_response(error_code: int, snap: Dictionary) -> void:
	if error_code != Protocol.ErrorCode.OK:
		printerr("[AUTOTEST] FAIL room response error %d" % error_code)
		get_tree().quit(1)
		return
	var code: String = str(snap.get("room_code", ""))
	if _index == 1:
		print("[AUTOTEST] ROOM_CODE=%s" % code)
	print("[AUTOTEST] client %d di room %s" % [_index, code])
	if _scenario == "add_bot" and _index == 1:
		# Skenario bot: host menambahkan bot via RPC baru request_add_bot.
		NetManager.request_add_bot()
	NetManager.set_ready(true)


## Verifikasi bot muncul di daftar pemain (skenario add_bot).
func _on_snapshot(snap: Dictionary) -> void:
	if _scenario != "add_bot" or _bot_seen:
		return
	for p: Variant in snap.get("players", []):
		var e: Dictionary = p as Dictionary
		if bool(e.get("is_bot", false)):
			_bot_seen = true
			print("[AUTOTEST] BOT_IN_SNAPSHOT name=%s pid=%d" % [e.get("nickname", "?"), e.get("peer_id", 0)])
			return

func _on_countdown(start_server_ms: int, countdown_sec: int) -> void:
	_countdown_received = true
	print("[AUTOTEST] COUNTDOWN start_ms=%d sec=%d" % [start_server_ms, countdown_sec])
	SceneRouter.goto_scene(RACE_SCENE)

func _on_match_started(_race_start_server_ms: int) -> void:
	print("[AUTOTEST] MATCH_STARTED")
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("set_autodrive"):
		scene.call("set_autodrive", true)

func _on_remote_states(_states: Array) -> void:
	if not _states_exchanged:
		_states_exchanged = true
		print("[AUTOTEST] STATES_EXCHANGED (%d state)" % _states.size())

func _on_results(results: Array) -> void:
	if _results_received:
		return
	_results_received = true
	var normalized: Array = []
	for r: Variant in results:
		var e: Dictionary = r as Dictionary
		normalized.append({
			"rank": int(e.get("rank", 0)),
			"peer_id": int(e.get("peer_id", 0)),
			"nickname": str(e.get("nickname", "")),
			"time_ms": int(e.get("time_ms", -1)),
			"status": int(e.get("status", -1)),
		})
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("peer_id")) < int(b.get("peer_id")))
	print("[AUTOTEST] RESULTS: " + JSON.stringify(normalized))
	if _scenario == "add_bot" and not _bot_seen:
		printerr("[AUTOTEST] FAIL bot tidak pernah muncul di snapshot room")
		get_tree().quit(1)
		return
	if _scenario == "add_bot":
		var bot_in_results: bool = false
		for r: Variant in normalized:
			if str((r as Dictionary).get("nickname", "")).begins_with("Bot "):
				bot_in_results = true
				print("[AUTOTEST] BOT_FINISHED name=%s rank=%s time_ms=%s status=%s" % [
					(r as Dictionary).get("nickname"), (r as Dictionary).get("rank"),
					(r as Dictionary).get("time_ms"), (r as Dictionary).get("status")])
		if not bot_in_results:
			printerr("[AUTOTEST] FAIL bot tidak ada di hasil match")
			get_tree().quit(1)
			return
	print("[AUTOTEST] client %d selesai OK" % _index)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > WATCHDOG_SEC and not _results_received:
		printerr("[AUTOTEST] FAIL watchdog timeout (countdown=%s states=%s results=%s)" % [
			_countdown_received, _states_exchanged, _results_received])
		get_tree().quit(1)
		return
	if _index == 1 and not _started_requested:
		_poll_accum += delta
		if _poll_accum < 0.5:
			return
		_poll_accum = 0.0
		var snap: Dictionary = NetManager.last_room_snapshot
		var list: Array = snap.get("players", [])
		if list.size() < 2:
			return
		var all_ready: bool = true
		for p: Variant in list:
			if not bool((p as Dictionary).get("is_ready", false)):
				all_ready = false
				break
		if all_ready:
			_started_requested = true
			print("[AUTOTEST] host meminta start match")
			NetManager.request_start_match()
