# Autoload: ServerMain. Owner: A7. Kontrak: README 4.1, 4.5, 5.6, 9.
# Entry point dedicated server. Hanya aktif jika GameConfig.is_dedicated_server.
extends Node

const GameConfigScript := preload("res://scripts/autoload/game_config.gd")

const DEFAULT_MAX_ROOMS: int = 50
const DEFAULT_MAX_PLAYERS: int = 8
const MAX_CLIENTS_CAP: int = 400
const HEALTH_LOG_INTERVAL_SEC: float = 10.0

var room_manager: RoomManager = null
var match_manager: MatchManager = null
var max_rooms: int = DEFAULT_MAX_ROOMS
var max_players: int = DEFAULT_MAX_PLAYERS
var log_level: String = "info"
var match_timeout_sec: float = GameConfigScript.DEFAULT_MATCH_TIMEOUT_SEC
var _health_accum: float = 0.0
var _uptime_start_msec: int = 0
var _shutdown_requested: bool = false
var _countdown_done: Dictionary = {}  # kode room -> bool
var _match_started: Dictionary = {}   # kode room -> bool
var _results_sent: Dictionary = {}    # kode room -> bool


func _ready() -> void:
	var gc: Node = get_node("/root/GameConfig")
	if not bool(gc.is_dedicated_server):
		set_process(false)
		return
	_parse_args()
	Log.init_logger(log_level)
	_uptime_start_msec = Time.get_ticks_msec()
	randomize()
	room_manager = RoomManager.new()
	match_manager = MatchManager.new(room_manager, match_timeout_sec)
	get_tree().auto_accept_quit = false
	get_tree().set_auto_accept_quit(false)
	_wire_net_events()
	_start_transport_server()
	Log.info("ServerMain siap: transport=%s port=%d max_rooms=%d max_players=%d max_clients=%d timeout=%.0fs" % [
		str(_gc().get("transport")), _gc().get("server_port"), max_rooms, max_players, _max_clients(), match_timeout_sec])


## Wire NetManager event ke handler (kontrak 4.5). Dipanggil di _ready.
func _wire_net_events() -> void:
	var nm: Node = get_node_or_null("/root/NetManager")
	if nm == null:
		Log.error("NetManager tidak ditemukan — RPC client tidak akan diproses")
		return
	nm.set("server_event_handler", _on_net_event)
	nm.connect("server_state_submitted", _on_server_state_submitted)


func _on_server_state_submitted(_peer_id: int, _state: Dictionary) -> void:
	pass  # Validasi penuh ditangani lewat event "submit_state".


func _on_net_event(event_name: String, sender_id: int, args: Array) -> void:
	match event_name:
		"create_room":
			handle_request_create_room(sender_id, args[0], args[1], args[2])
		"join_room":
			handle_request_join_room(sender_id, args[0], args[1], args[2], args[3])
		"leave_room":
			handle_request_leave_room(sender_id)
		"set_ready":
			handle_set_ready(sender_id, args[0])
		"start_match":
			handle_request_start_match(sender_id)
		"submit_state":
			handle_submit_state(sender_id, args[0])
		"report_checkpoint":
			handle_report_checkpoint(sender_id, args[0])
		"report_finish":
			handle_report_finish(sender_id)
		"health_request":
			handle_server_health(sender_id)
		_:
			Log.warn("event NetManager tidak dikenal: %s" % event_name)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			_gc().set("server_port", int(arg.get_slice("=", 1)))
		elif arg.begins_with("--max-rooms="):
			max_rooms = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--max-players="):
			# Maksimal tetap 8 (kontrak MAX_PLAYERS_PER_ROOM).
			max_players = clampi(int(arg.get_slice("=", 1)), 1, GameConfigScript.MAX_PLAYERS_PER_ROOM)
		elif arg.begins_with("--log-level="):
			log_level = arg.get_slice("=", 1)
		elif arg.begins_with("--match-timeout="):
			match_timeout_sec = maxf(1.0, float(arg.get_slice("=", 1)))
	Log.info("argumen CLI: port=%d max_rooms=%d max_players=%d log_level=%s match_timeout=%.0f" % [
		_gc().get("server_port"), max_rooms, max_players, log_level, match_timeout_sec])


func _gc() -> Node:
	return get_node("/root/GameConfig")


func _max_clients() -> int:
	return mini(max_rooms * max_players, MAX_CLIENTS_CAP)


func _start_enet_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(_gc().get("server_port"), _max_clients())
	if err != OK:
		Log.error("gagal membuat server ENet di port %d (error %d)" % [_gc().get("server_port"), err])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Log.info("server ENet aktif di UDP %d (max_clients=%d)" % [_gc().get("server_port"), _max_clients()])


## Memulai server dengan transport sesuai GameConfig.transport ("enet" | "ws").
func _start_transport_server() -> void:
	if str(_gc().get("transport")) == "ws":
		_start_ws_server()
	else:
		_start_enet_server()


## WebSocket server: TCP, untuk VPS/publik yang memblokir UDP inbound.
## Client connect via NetManager.connect_to_server_ws().
func _start_ws_server() -> void:
	var peer := WebSocketMultiplayerPeer.new()
	var err: Error = peer.create_server(_gc().get("server_port"))
	if err != OK:
		Log.error("gagal membuat server WebSocket di port %d (error %d)" % [_gc().get("server_port"), err])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Log.info("transport: websocket — server WS aktif di TCP %d (max_clients=%d)" % [
		_gc().get("server_port"), _max_clients()])


func _process(delta: float) -> void:
	if _shutdown_requested or room_manager == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	# 1. Countdown -> race start.
	for code: String in room_manager.rooms:
		var room: Room = room_manager.rooms[code]
		if room.state == Protocol.RoomState.COUNTDOWN and not _match_started.get(code, false):
			if now_ms - room.countdown_start_server_ms >= int(GameConfigScript.COUNTDOWN_SECONDS * 1000.0):
				match_manager.begin_race(room)
				_match_started[code] = true
				_countdown_done[code] = true
				_send_match_started(room)
		# 2. Akhir match (semua selesai atau timeout).
		elif room.state == Protocol.RoomState.RUNNING and _match_started.get(code, false):
			if match_manager.should_finish(room, now_ms):
				var results: Array = match_manager.build_results(room, now_ms)
				_send_match_results(room, results)
				room_manager.match_finished(room, now_ms)
				_results_sent[code] = true
				_send_return_to_lobby(room)
	# 3. Broadcast states 20 Hz per room RUNNING.
	for code: String in room_manager.rooms:
		var room2: Room = room_manager.rooms[code]
		if room2.state == Protocol.RoomState.RUNNING and _match_started.get(code, false):
			var states: Array = _collect_states(room2)
			if states.size() > 0:
				_net_call("rpc_broadcast_states", [states])
	# 4. TTL room kosong & reconnect window.
	room_manager.expire_reconnects(now_ms)
	room_manager.expire_empty_rooms(now_ms)
	# 5. Health log tiap 10 detik.
	_health_accum += delta
	if _health_accum >= HEALTH_LOG_INTERVAL_SEC:
		_health_accum = 0.0
		var player_total: int = 0
		for code: String in room_manager.rooms:
			player_total += room_manager.rooms[code].player_count()
		var uptime: int = (now_ms - _uptime_start_msec) / 1000
		Log.info("health: rooms=%d players=%d uptime=%ds" % [room_manager.rooms.size(), player_total, uptime])


func _collect_states(room: Room) -> Array:
	var states: Array = []
	var now_ms: int = Time.get_ticks_msec()
	for pid: int in room.players:
		var e: PlayerEntry = room.players[pid]
		if not e.has_state:
			continue
		if now_ms - e.last_state_ms > 5000:
			continue  # state terlalu tua, jangan disiarkan
		states.append({
			"pid": e.peer_id,
			"p": e.last_pos,
			"r": 0.0,
			"a": "idle",
			"g": true,
			"t": e.last_state_ms,
		})
	return states


# ---------- Bridges ke NetManager (RPC milik A6) ----------

## Kirim RPC ke satu peer via NetManager jika RPC sudah ada (A6).
func _net_call_to(peer_id: int, rpc_name: String, args: Array) -> void:
	var nm: Node = get_node_or_null("/root/NetManager")
	if nm == null or not nm.has_method(rpc_name):
		return  # NetManager (A6) belum menyediakan RPC; dicatat di laporan.
	var callable: Callable = Callable(nm, rpc_name)
	match args.size():
		0: nm.rpc_id(peer_id, rpc_name)
		1: nm.rpc_id(peer_id, rpc_name, args[0])
		2: nm.rpc_id(peer_id, rpc_name, args[0], args[1])


func _net_call(rpc_name: String, args: Array) -> void:
	_net_call_to(0, rpc_name, args)


func _send_room_snapshot(room: Room) -> void:
	_net_call("rpc_room_snapshot", [room.snapshot()])


func _send_match_started(room: Room) -> void:
	var start_unix_ms: int = (Time.get_unix_time_from_system() - GameConfigScript.COUNTDOWN_SECONDS) * 1000
	for pid: int in room.players:
		_net_call_to(pid, "rpc_match_started", [start_unix_ms])
	Log.info("room %s: rpc_match_started dikirim ke %d peer" % [room.code, room.player_count()])


func _send_match_results(room: Room, results: Array) -> void:
	_net_call("rpc_match_results", [results])


func _send_return_to_lobby(room: Room) -> void:
	room.state = Protocol.RoomState.LOBBY
	_match_started[room.code] = false
	_countdown_done[room.code] = false
	_results_sent[room.code] = false
	_net_call("rpc_return_to_lobby", [room.snapshot()])


# ---------- Signal peer disconnect ----------

func _on_peer_disconnected(peer_id: int) -> void:
	Log.info("peer %d terputus dari server" % peer_id)
	room_manager.handle_disconnect(peer_id)


# ---------- Handler RPC client->server (dipanggil NetManager A6, kontrak 4.5) ----------
# NetManager menerima RPC lalu mendelegasikan ke ServerMain via method publik ini.

func handle_request_create_room(sender: int, nickname: String, character_id: int, protocol_version: int) -> void:
	if not Validator.check_protocol_version(protocol_version):
		_net_call_to(sender, "rpc_room_response", [Protocol.ErrorCode.VERSION_MISMATCH, {}])
		return
	var res := room_manager.create_room(sender, nickname, character_id)
	if not res["ok"]:
		_net_call_to(sender, "rpc_room_response", [res["error"], {}])
		return
	var room: Room = res["room"]
	_net_call_to(sender, "rpc_room_response", [Protocol.ErrorCode.OK, room.snapshot()])
	_net_call_to(sender, "rpc_room_snapshot", [room.snapshot()])


func handle_request_join_room(sender: int, room_code: String, nickname: String, character_id: int, protocol_version: int) -> void:
	if not Validator.check_protocol_version(protocol_version):
		_net_call_to(sender, "rpc_room_response", [Protocol.ErrorCode.VERSION_MISMATCH, {}])
		return
	var res := room_manager.join_room(sender, room_code, nickname, character_id)
	if not res["ok"]:
		_net_call_to(sender, "rpc_room_response", [res["error"], {}])
		return
	var room: Room = res["room"]
	_net_call_to(sender, "rpc_room_response", [Protocol.ErrorCode.OK, room.snapshot()])
	_send_room_snapshot(room)


func handle_request_leave_room(sender: int) -> void:
	room_manager.leave_room(sender)


func handle_set_ready(sender: int, is_ready: bool) -> void:
	var entry := room_manager.get_entry(sender)
	if entry == null:
		return
	entry.is_ready = is_ready
	var room := room_manager.get_room_by_peer(sender)
	if room != null:
		_send_room_snapshot(room)


func handle_request_start_match(sender: int) -> void:
	var room := room_manager.get_room_by_peer(sender)
	var res := match_manager.request_start(room, sender)
	if not res["ok"]:
		_net_call_to(sender, "rpc_room_response", [res["error"], {} if room == null else room.snapshot()])
		return
	room_manager.get_entry(sender).is_ready = false
	_send_room_snapshot(room)
	_net_call("rpc_match_countdown", [res["start_server_ms"], res["countdown_sec"]])


func handle_submit_state(sender: int, state: Dictionary) -> void:
	var room := room_manager.get_room_by_peer(sender)
	if room == null or room.state != Protocol.RoomState.RUNNING:
		print("[SERVERDBG] state ditolak: room=", room, " state_running=", (room != null and room.state == Protocol.RoomState.RUNNING))
		return
	var entry := room_manager.get_entry(sender)
	if entry == null:
		print("[SERVERDBG] entry null untuk ", sender)
		return
	var res := match_manager.process_state(room, entry, state, sender, Time.get_ticks_msec())
	if res["kick"]:
		room_manager.kick_peer(sender, res["reason"])
		# Ditolak keras: tutup koneksi peer.
		multiplayer.multiplayer_peer.disconnect_peer(sender)


func handle_report_checkpoint(sender: int, index: int) -> void:
	var room := room_manager.get_room_by_peer(sender)
	if room == null or room.state != Protocol.RoomState.RUNNING:
		return
	var entry := room_manager.get_entry(sender)
	if entry == null:
		return
	var accepted: bool = match_manager.process_checkpoint(room, entry, index)
	_net_call_to(sender, "rpc_checkpoint_ack", [index, accepted])


func handle_report_finish(sender: int) -> void:
	var room := room_manager.get_room_by_peer(sender)
	if room == null or room.state != Protocol.RoomState.RUNNING:
		return
	var entry := room_manager.get_entry(sender)
	if entry == null:
		return
	var res := match_manager.process_finish(room, entry, Time.get_ticks_msec())
	if res["accepted"] and match_manager.should_finish(room, Time.get_ticks_msec()):
		var results: Array = match_manager.build_results(room, Time.get_ticks_msec())
		_send_match_results(room, results)
		room_manager.match_finished(room, Time.get_ticks_msec())
		_results_sent[room.code] = true
		_send_return_to_lobby(room)


func handle_server_health(sender: int) -> void:
	# Respons health: log ringkas (tanpa endpoint HTTP, kontrak 5.6).
	Log.info("health probe dari peer %d: rooms=%d uptime=%ds" % [
		sender, room_manager.rooms.size(), (Time.get_ticks_msec() - _uptime_start_msec) / 1000])


# ---------- Graceful shutdown (SIGTERM / WM_CLOSE_REQUEST) ----------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_graceful_shutdown()


func _graceful_shutdown() -> void:
	if _shutdown_requested:
		return
	_shutdown_requested = true
	Log.info("graceful shutdown dimulai: memberi tahu semua room (%d)" % room_manager.rooms.size())
	for code: String in room_manager.rooms:
		var room: Room = room_manager.rooms[code]
		# Client melihat server_disconnected; snapshot terakhir dikirim sebagai best-effort.
		_send_room_snapshot(room)
	await get_tree().create_timer(0.5).timeout
	Log.info("server keluar")
	multiplayer.multiplayer_peer = null
	get_tree().quit(0)
