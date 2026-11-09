# scripts/autoload/net_manager.gd
# Autoload: NetManager (client & server). Owner: A6. Contract: README bagian 4.4-4.6, 5.5.
extends Node

## Signal publik untuk UI dan modul lain.
signal connection_started(address: String, port: int)
signal connection_succeeded()
signal connection_failed(reason: String)
signal server_lost()
signal room_response_received(error_code: int, room_snapshot: Dictionary)
signal room_snapshot_updated(room_snapshot: Dictionary)
signal match_countdown_started(start_server_ms: int, countdown_sec: int)
signal match_started(race_start_server_ms: int)
signal remote_states_updated(states: Array)
signal checkpoint_ack_received(index: int, accepted: bool)
signal match_results_received(results: Array)
signal returned_to_lobby(room_snapshot: Dictionary)

const CONNECT_TIMEOUT_SEC: float = 8.0
const CLIENT_SEND_HZ: float = 20.0
const INTERP_DELAY_MS: int = 100
const SNAPSHOT_MAX_AGE_MS: int = 500
const SNAPSHOT_HISTORY_SIZE: int = 2

## Peer client aktif (null saat offline / di server dedicated).
var _peer: ENetMultiplayerPeer = null

## Status koneksi client: "idle", "connecting", "connected".
var connection_state: String = "idle"
var _connecting: bool = false
var _connect_address: String = ""
var _connect_port: int = 0
var _connect_deadline_ms: int = 0

## Snapshot terakhir room (untuk lobi).
var last_room_snapshot: Dictionary = {}

## Posisi/rotasi lokal terakhir yang dipublish oleh player_controller (A2).
## Di-set oleh scene race via set_local_state().
var _local_state: Dictionary = {}

## Interpolasi remote: peer_id -> Array[Dictionary] (2 snapshot terakhir).
var _remote_snapshots: Dictionary = {}
## Posisi terakhir yang sudah dirender per peer (untuk hold saat snapshot tua).
var _remote_render_state: Dictionary = {}

var _send_accumulator: float = 0.0


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ------------------------------------------------------------------
# Koneksi client
# ------------------------------------------------------------------

## Membuat ENetMultiplayerPeer client dan mulai koneksi ke server.
## Timeout 8 detik; hasil lewat sinyal connection_succeeded / connection_failed.
func connect_to_server(address: String, port: int) -> void:
	if _connecting or (connection_state == "connected"):
		return
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_client(address, port)
	if err != OK:
		_peer = null
		connection_failed.emit("Gagal membuat client (kode %d): %s" % [err, error_string(err)])
		return
	multiplayer.multiplayer_peer = _peer
	_connecting = true
	connection_state = "connecting"
	_connect_address = address
	_connect_port = port
	_connect_deadline_ms = Time.get_ticks_msec() + int(CONNECT_TIMEOUT_SEC * 1000.0)
	connection_started.emit(address, port)
	print("[NetManager] Menghubungi %s:%d ..." % [address, port])


## Memutus koneksi saat ini dan kembali offline.
func disconnect_from_server() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_peer = null
	_connecting = false
	connection_state = "idle"
	_local_state.clear()
	_remote_snapshots.clear()
	_remote_render_state.clear()
	last_room_snapshot.clear()


func _process(_delta: float) -> void:
	if _connecting and Time.get_ticks_msec() >= _connect_deadline_ms:
		var addr: String = "%s:%d" % [_connect_address, _connect_port]
		_cleanup_peer_after_failure()
		connection_failed.emit(
			"Timeout: server tidak dapat dihubungi di %s dalam %d detik." % [addr, int(CONNECT_TIMEOUT_SEC)]
		)


func _cleanup_peer_after_failure() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_peer = null
	_connecting = false
	connection_state = "idle"


func _on_connected_to_server() -> void:
	_connecting = false
	connection_state = "connected"
	print("[NetManager] Terhubung ke server (peer id %d)." % multiplayer.get_unique_id())
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	_cleanup_peer_after_failure()
	var addr: String = "%s:%d" % [_connect_address, _connect_port]
	print("[NetManager] Koneksi gagal ke %s." % addr)
	connection_failed.emit("Server tidak dapat dihubungi di %s." % addr)


func _on_server_disconnected() -> void:
	disconnect_from_server()
	print("[NetManager] Koneksi ke server terputus.")
	server_lost.emit("Koneksi ke server terputus.")


func is_connected_to_server() -> bool:
	return connection_state == "connected" and multiplayer.multiplayer_peer != null


# ------------------------------------------------------------------
# RPC client -> server (dipanggil client, dikirim ke peer 1)
# ------------------------------------------------------------------

func request_create_room(nickname: String, character_id: int) -> void:
	rpc_id(1, "rpc_request_create_room", nickname, character_id, Protocol.PROTOCOL_VERSION)


func request_join_room(room_code: String, nickname: String, character_id: int) -> void:
	rpc_id(1, "rpc_request_join_room", room_code, nickname, character_id, Protocol.PROTOCOL_VERSION)


func request_leave_room() -> void:
	rpc_id(1, "rpc_request_leave_room")


func set_ready(is_ready: bool) -> void:
	rpc_id(1, "rpc_set_ready", is_ready)


func request_start_match() -> void:
	rpc_id(1, "rpc_request_start_match")


func report_checkpoint(index: int) -> void:
	rpc_id(1, "rpc_report_checkpoint", index)


func report_finish() -> void:
	rpc_id(1, "rpc_report_finish")


func request_server_health() -> void:
	rpc_id(1, "rpc_server_health")


# ------------------------------------------------------------------
# RPC deklarasi (kontrak 4.5, tidak boleh diubah)
# ------------------------------------------------------------------

@rpc("any_peer", "reliable")
func rpc_request_create_room(nickname: String, character_id: int, protocol_version: int) -> void:
	# Dieksekusi di server; implementasi milik A7 (ServerMain/RoomManager).
	if not multiplayer.is_server():
		return
	_server_handle_create_room(nickname, character_id, protocol_version)


@rpc("any_peer", "reliable")
func rpc_request_join_room(room_code: String, nickname: String, character_id: int, protocol_version: int) -> void:
	if not multiplayer.is_server():
		return
	_server_handle_join_room(room_code, nickname, character_id, protocol_version)


@rpc("any_peer", "reliable")
func rpc_request_leave_room() -> void:
	if not multiplayer.is_server():
		return
	_server_handle_leave_room()


@rpc("any_peer", "reliable")
func rpc_set_ready(is_ready: bool) -> void:
	if not multiplayer.is_server():
		return
	_server_handle_set_ready(is_ready)


@rpc("any_peer", "reliable")
func rpc_request_start_match() -> void:
	if not multiplayer.is_server():
		return
	_server_handle_start_match()


@rpc("authority", "reliable")
func rpc_room_response(error_code: int, room_snapshot: Dictionary) -> void:
	last_room_snapshot = room_snapshot
	room_response_received.emit(error_code, room_snapshot)


@rpc("authority", "reliable")
func rpc_room_snapshot(room_snapshot: Dictionary) -> void:
	last_room_snapshot = room_snapshot
	room_snapshot_updated.emit(room_snapshot)


@rpc("authority", "reliable")
func rpc_match_countdown(start_server_ms: int, countdown_sec: int) -> void:
	match_countdown_started.emit(start_server_ms, countdown_sec)


@rpc("authority", "reliable")
func rpc_match_started(race_start_server_ms: int) -> void:
	match_started.emit(race_start_server_ms)


@rpc("any_peer", "unreliable_ordered")
func rpc_submit_state(state: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	# Validasi minim: pid harus sama dengan pengirim. Penerusan ke broadcast
	# dilakukan server (A7). Di sini hanya diteruskan lewat sinyal internal.
	_server_handle_state(state)


@rpc("authority", "unreliable_ordered")
func rpc_broadcast_states(states: Array) -> void:
	_ingest_remote_states(states)


@rpc("any_peer", "reliable")
func rpc_report_checkpoint(index: int) -> void:
	if not multiplayer.is_server():
		return
	_server_handle_checkpoint(index)


@rpc("authority", "reliable")
func rpc_checkpoint_ack(index: int, accepted: bool) -> void:
	checkpoint_ack_received.emit(index, accepted)


@rpc("any_peer", "reliable")
func rpc_report_finish() -> void:
	if not multiplayer.is_server():
		return
	_server_handle_finish()


@rpc("authority", "reliable")
func rpc_match_results(results: Array) -> void:
	match_results_received.emit(results)


@rpc("authority", "reliable")
func rpc_return_to_lobby(room_snapshot: Dictionary) -> void:
	last_room_snapshot = room_snapshot
	returned_to_lobby.emit(room_snapshot)


@rpc("any_peer", "reliable")
func rpc_server_health() -> void:
	if not multiplayer.is_server():
		return
	_server_handle_health()


# ------------------------------------------------------------------
# Pengiriman state lokal (akumulator 20 Hz di _physics_process)
# ------------------------------------------------------------------

## Dipanggil scene race / player controller lokal untuk mempublish state.
func set_local_state(pos: Vector3, rot_y: float, anim: StringName, on_floor: bool) -> void:
	_local_state = {
		"p": pos,
		"r": rot_y,
		"a": anim,
		"g": on_floor,
	}


func _physics_process(delta: float) -> void:
	if not is_connected_to_server():
		return
	_send_accumulator += delta
	var interval: float = 1.0 / CLIENT_SEND_HZ
	if _send_accumulator < interval:
		return
	_send_accumulator = fmod(_send_accumulator, interval)
	if _local_state.is_empty():
		return
	var state: Dictionary = {
		"pid": multiplayer.get_unique_id(),
		"p": _local_state.get("p", Vector3.ZERO),
		"r": _local_state.get("r", 0.0),
		"a": _local_state.get("a", &"idle"),
		"g": _local_state.get("g", false),
		"t": Time.get_ticks_msec(),
	}
	rpc_id(1, "rpc_submit_state", state)


# ------------------------------------------------------------------
# Interpolasi remote (2 snapshot, delay 100 ms, hold > 500 ms)
# ------------------------------------------------------------------

func _ingest_remote_states(states: Array) -> void:
	var now_ms: int = Time.get_ticks_msec()
	for s in states:
		var state: Dictionary = s
		var pid: int = int(state.get("pid", 0))
		if pid == 0 or pid == multiplayer.get_unique_id():
			continue
		var snap: Dictionary = {
			"p": state.get("p", Vector3.ZERO),
			"r": state.get("r", 0.0),
			"a": state.get("a", &"idle"),
			"g": state.get("g", false),
			"t": int(state.get("t", now_ms)),
			"recv_ms": now_ms,
		}
		var hist: Array = _remote_snapshots.get(pid, [])
		hist.append(snap)
		while hist.size() > SNAPSHOT_HISTORY_SIZE:
			hist.pop_front()
		_remote_snapshots[pid] = hist
	remote_states_updated.emit(states)


## Dipanggil tiap frame oleh scene race untuk posisi/rotasi render remote player.
## Return {} jika belum ada data.
func get_remote_interp(pid: int) -> Dictionary:
	var hist: Array = _remote_snapshots.get(pid, [])
	if hist.is_empty():
		return {}
	var now_ms: int = Time.get_ticks_msec()
	var target_ms: int = now_ms - INTERP_DELAY_MS
	var prev: Dictionary = hist[0]
	var next: Dictionary = hist[hist.size() - 1]
	if hist.size() < 2 or int(next.get("recv_ms", 0)) <= target_ms:
		# Belum cukup snapshot atau snapshot terbaru masih lebih tua dari target:
		# tahan posisi terakhir (jangan ekstrapolasi).
		prev = next
		next = next
	elif int(prev.get("recv_ms", 0)) > target_ms:
		# Kedua snapshot lebih baru dari target: tahan.
		next = prev
	else:
		var span: int = int(next.get("recv_ms", 0)) - int(prev.get("recv_ms", 0))
		var frac: float = 0.0
		if span > 0:
			frac = clampf(float(target_ms - int(prev.get("recv_ms", 0))) / float(span), 0.0, 1.0)
		var pos_prev: Vector3 = prev.get("p", Vector3.ZERO)
		var pos_next: Vector3 = next.get("p", Vector3.ZERO)
		var pos: Vector3 = pos_prev.lerp(pos_next, frac)
		var rot_prev: float = float(prev.get("r", 0.0))
		var rot_next: float = float(next.get("r", 0.0))
		# Slerp pada sudut Y: interpolasi melingkar via Quaternion.
		var q: Quaternion = Quaternion(Vector3.UP, rot_prev).slerp(
			Quaternion(Vector3.UP, rot_next), frac
		)
		var rot_y: float = q.get_euler().y
		var out: Dictionary = {
			"p": pos,
			"r": rot_y,
			"a": next.get("a", &"idle"),
			"g": next.get("g", false),
		}
		_remote_render_state[pid] = out
		return out
	# Hold: gunakan posisi terakhir, tapi jika snapshot > 500 ms tetap tahan (bukan ekstrapolasi).
	var held: Dictionary = {
		"p": next.get("p", Vector3.ZERO),
		"r": float(next.get("r", 0.0)),
		"a": next.get("a", &"idle"),
		"g": next.get("g", false),
	}
	_remote_render_state[pid] = held
	return held


func is_remote_stale(pid: int) -> bool:
	var hist: Array = _remote_snapshots.get(pid, [])
	if hist.is_empty():
		return true
	var last_recv_ms: int = int(hist[hist.size() - 1].get("recv_ms", 0))
	return (Time.get_ticks_msec() - last_recv_ms) > SNAPSHOT_MAX_AGE_MS


func remove_remote_player(pid: int) -> void:
	_remote_snapshots.erase(pid)
	_remote_render_state.erase(pid)


# ------------------------------------------------------------------
# Hook server (dipanggil A7 melalui sinyal internal / override)
# ------------------------------------------------------------------
# NetManager juga berjalan di server. Handler server meneruskan event ke
# ServerMain (A7) via sinyal agar kepemilikan file tetap bersih.

signal server_state_submitted(peer_id: int, state: Dictionary)
signal server_state_validated(peer_id: int, state: Dictionary)

## Konektor A7: server menyetel handler ini untuk memproses event room.
## Format: handler(nama_event: String, sender_id: int, args: Array)
var server_event_handler: Callable = Callable()


func _server_emit(event_name: String, args: Array) -> void:
	if server_event_handler.is_valid():
		server_event_handler.call(event_name, multiplayer.get_remote_sender_id(), args)


func _server_handle_create_room(nickname: String, character_id: int, protocol_version: int) -> void:
	_server_emit("create_room", [nickname, character_id, protocol_version])


func _server_handle_join_room(room_code: String, nickname: String, character_id: int, protocol_version: int) -> void:
	_server_emit("join_room", [room_code, nickname, character_id, protocol_version])


func _server_handle_leave_room() -> void:
	_server_emit("leave_room", [])


func _server_handle_set_ready(is_ready: bool) -> void:
	_server_emit("set_ready", [is_ready])


func _server_handle_start_match() -> void:
	_server_emit("start_match", [])


func _server_handle_state(state: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	server_state_submitted.emit(sender, state)
	_server_emit("submit_state", [state])


func _server_handle_checkpoint(index: int) -> void:
	_server_emit("report_checkpoint", [index])


func _server_handle_finish() -> void:
	_server_emit("report_finish", [])


func _server_handle_health() -> void:
	_server_emit("health_request", [])


# ------------------------------------------------------------------
# Helper server -> client (dipakai A7)
# ------------------------------------------------------------------

func server_send_room_response(peer_id: int, error_code: int, room_snapshot: Dictionary) -> void:
	if multiplayer.is_server():
		rpc_id(peer_id, "rpc_room_response", error_code, room_snapshot)


func server_send_room_snapshot(peer_id: int, room_snapshot: Dictionary) -> void:
	if multiplayer.is_server():
		rpc_id(peer_id, "rpc_room_snapshot", room_snapshot)


func server_broadcast_room_snapshot(room_snapshot: Dictionary) -> void:
	if multiplayer.is_server():
		rpc("rpc_room_snapshot", room_snapshot)


func server_send_countdown(peer_id: int, start_server_ms: int, countdown_sec: int) -> void:
	if multiplayer.is_server():
		rpc_id(peer_id, "rpc_match_countdown", start_server_ms, countdown_sec)


func server_broadcast_countdown(start_server_ms: int, countdown_sec: int) -> void:
	if multiplayer.is_server():
		rpc("rpc_match_countdown", start_server_ms, countdown_sec)


func server_broadcast_match_started(race_start_server_ms: int) -> void:
	if multiplayer.is_server():
		rpc("rpc_match_started", race_start_server_ms)


func server_broadcast_states(states: Array) -> void:
	if multiplayer.is_server():
		rpc("rpc_broadcast_states", states)


func server_send_checkpoint_ack(peer_id: int, index: int, accepted: bool) -> void:
	if multiplayer.is_server():
		rpc_id(peer_id, "rpc_checkpoint_ack", index, accepted)


func server_broadcast_results(results: Array) -> void:
	if multiplayer.is_server():
		rpc("rpc_match_results", results)


func server_send_return_to_lobby(peer_id: int, room_snapshot: Dictionary) -> void:
	if multiplayer.is_server():
		rpc_id(peer_id, "rpc_return_to_lobby", room_snapshot)


func server_broadcast_return_to_lobby(room_snapshot: Dictionary) -> void:
	if multiplayer.is_server():
		rpc("rpc_return_to_lobby", room_snapshot)
