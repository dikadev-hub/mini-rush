# A5: Logika balapan client. Owner: A5. Contract: README bagian 4.5, 5.4.
class_name RaceController
extends Node

## State race pemain lokal: checkpoint, respawn, timer display, finish.
## Waktu resmi HANYA dari server (rpc_match_results); timer lokal display only.
## Index checkpoint TIDAK dimajukan sebelum ack server (optimistic UI saja).

signal checkpoint_pending_changed(index: int, pending: bool)
signal checkpoint_confirmed(index: int)
signal checkpoint_rejected(index: int)
signal respawned_to(position: Vector3)
signal finish_reported()
signal local_elapsed_changed(elapsed_ms: int)
signal results_received(results: Array)

const _LOG_PREFIX: String = "[RaceController]"

## Node pemain lokal (PlayerController) — di-set scene race sebelum mulai.
var player: PlayerController = null

## Urutan spawn pemain lokal (0-based) untuk offset respawn anti-tumpuk.
var spawn_order: int = 0

## Contract state (5.4).
var next_checkpoint_index: int = 0
var last_checkpoint_position: Vector3 = MapData.SPAWN_POSITION
var finish_sent: bool = false
var match_finished: bool = false

## Optimistic UI: checkpoint yang sudah diklaim ke server tapi belum di-ack.
var _pending_checkpoint: int = -1

## Referensi NetManager (dapat dioverride di test; default singleton global).
var _net_override_obj: Object = null

## Timer lokal (display only, ms sejak race dimulai secara lokal).
var _local_running: bool = false
var _local_start_ms: int = 0
var _local_elapsed_ms: int = 0
var _reported_indexes: Dictionary = {}


func _ready() -> void:
	reset_race()
	var net: Object = _net()
	if net != null and net.has_signal("checkpoint_ack_received"):
		net.connect("checkpoint_ack_received", _on_checkpoint_ack)
	if net != null and net.has_signal("match_results_received"):
		net.connect("match_results_received", _on_match_results)


func _process(delta: float) -> void:
	if not _local_running or match_finished:
		return
	_local_elapsed_ms += int(round(delta * 1000.0))
	local_elapsed_changed.emit(_local_elapsed_ms)
	_check_kill_y()


## Pasang listener ke Area3D checkpoint (Checkpoint) dan finish (FinishLine).
func bind_world(checkpoints: Array, finish_line: FinishLine) -> void:
	for cp: Area3D in checkpoints:
		if cp.has_signal("checkpoint_entered"):
			cp.checkpoint_entered.connect(_on_checkpoint_entered)
	if finish_line != null and finish_line.has_signal("finish_entered"):
		finish_line.finish_entered.connect(_on_finish_entered)


## Mulai timer lokal saat race dimulai (dipanggil scene race saat
## NetManager.match_started).
func start_local_timer() -> void:
	_local_running = true
	_local_start_ms = Time.get_ticks_msec()
	_local_elapsed_ms = 0


func stop_local_timer() -> void:
	_local_running = false


## Reset penuh state race (match baru / kembali ke lobi).
func reset_race() -> void:
	next_checkpoint_index = 0
	last_checkpoint_position = MapData.SPAWN_POSITION
	finish_sent = false
	match_finished = false
	_pending_checkpoint = -1
	_local_running = false
	_local_start_ms = 0
	_local_elapsed_ms = 0
	_reported_indexes.clear()


func get_local_elapsed_ms() -> int:
	return _local_elapsed_ms


func is_checkpoint_pending(index: int) -> bool:
	return _pending_checkpoint == index


## Mengembalikan singleton NetManager (lookup runtime agar kompilasi lolos
## di mode --check-only --script tanpa autoload), atau stub test.
func _net() -> Object:
	if _net_override_obj != null:
		return _net_override_obj
	var tree: SceneTree = get_tree() as SceneTree
	if tree != null and tree.root.has_node("NetManager"):
		return tree.root.get_node("NetManager")
	return null


# ------------------------------------------------------------------
# Checkpoint (5.4)
# ------------------------------------------------------------------

## Dipanggil Checkpoint.checkpoint_entered(index) oleh pemain lokal.
func _on_checkpoint_entered(index: int) -> void:
	if match_finished:
		return
	if index != next_checkpoint_index:
		# Bukan checkpoint yang ditunggu: abaikan (out-of-order / sudah lewat).
		print("%s Checkpoint %d diabaikan (menunggu %d)." % [_LOG_PREFIX, index, next_checkpoint_index])
		return
	if _pending_checkpoint == index:
		return  # sudah dikirim, menunggu ack
	_reported_indexes[index] = true
	_pending_checkpoint = index
	checkpoint_pending_changed.emit(index, true)
	print("%s Klaim checkpoint %d -> server." % [_LOG_PREFIX, index])
	var net: Object = _net()
	if net != null:
		net.call("report_checkpoint", index)


## Dipanggil NetManager.checkpoint_ack_received(index, accepted).
func _on_checkpoint_ack(index: int, accepted: bool) -> void:
	if index != _pending_checkpoint:
		return  # ack untuk klaim lama/stale
	_pending_checkpoint = -1
	checkpoint_pending_changed.emit(index, false)
	if accepted:
		next_checkpoint_index = index + 1
		last_checkpoint_position = MapData.CHECKPOINT_POSITIONS[index]
		checkpoint_confirmed.emit(index)
		print("%s Checkpoint %d diterima (next=%d)." % [_LOG_PREFIX, index, next_checkpoint_index])
	else:
		checkpoint_rejected.emit(index)
		printerr("%s Checkpoint %d DITOLAK server." % [_LOG_PREFIX, index])


# ------------------------------------------------------------------
# Finish (5.4)
# ------------------------------------------------------------------

func _on_finish_entered() -> void:
	if match_finished or finish_sent:
		return
	finish_sent = true
	stop_local_timer()
	finish_reported.emit()
	print("%s Finish dilaporkan ke server." % _LOG_PREFIX)
	var net: Object = _net()
	if net != null:
		net.call("report_finish")


func _on_match_results(results: Array) -> void:
	match_finished = true
	stop_local_timer()
	results_received.emit(results)


# ------------------------------------------------------------------
# Respawn (5.4)
# ------------------------------------------------------------------

func _check_kill_y() -> void:
	if player == null or match_finished:
		return
	if player.global_position.y < MapData.KILL_Y:
		respawn_local()


## Respawn pemain lokal ke checkpoint terakhir + offset urutan spawn.
func respawn_local() -> void:
	if player == null:
		return
	var target: Vector3 = last_checkpoint_position \
		+ MapData.SPAWN_OFFSET_STEP * float(spawn_order)
	player.respawn_to(target)
	respawned_to.emit(target)
	print("%s Respawn ke %s (order %d)." % [_LOG_PREFIX, target, spawn_order])
