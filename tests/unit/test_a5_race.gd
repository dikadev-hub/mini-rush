# A5 unit tests: RaceController (README 5.4).
# Checkpoint urut, ack flow (accepted/rejected), respawn trigger, finish once.
# NetManager di-stub via RaceController._net_override_obj karena autoload
# tidak aktif saat dijalankan lewat test runner SceneTree.
extends RefCounted

const RaceControllerScript := preload("res://scripts/gameplay/race_controller.gd")


var _respawns: Array[Vector3] = []
var _pending_seen: Array = []
var _confirmed: Array[int] = []
var _rejected: Array[int] = []
var _finish_count: Array[int] = []
var _got_results: Array = []


## Stub NetManager minimal: mencatat panggilan report_checkpoint/report_finish.
class NetStub extends RefCounted:
	var checkpoint_calls: Array[int] = []
	var finish_calls: Array[int] = []

	func report_checkpoint(index: int) -> void:
		checkpoint_calls.append(index)

	func report_finish() -> void:
		finish_calls.append(1)


func run(scene_root: Node, check: Callable) -> void:
	var stub: NetStub = NetStub.new()

	# --- initial state ---
	var rc: Node = RaceControllerScript.new()
	scene_root.add_child(rc)
	rc._net_override_obj = stub
	# Hubungkan semua sinyal SEBELUM ada emit (lambda menangkap lokal by-value).
	rc.checkpoint_pending_changed.connect(_on_pending_changed)
	rc.checkpoint_confirmed.connect(_on_confirmed)
	rc.checkpoint_rejected.connect(_on_rejected)
	rc.finish_reported.connect(_on_finish_reported)
	rc.results_received.connect(_on_results)
	rc.respawned_to.connect(_on_respawned)
	rc.reset_race()
	check.call(rc.next_checkpoint_index == 0, "next_checkpoint_index starts at 0")
	check.call(rc.last_checkpoint_position == MapData.SPAWN_POSITION,
		"last_checkpoint_position defaults to SPAWN_POSITION")
	check.call(not rc.finish_sent, "finish_sent starts false")
	check.call(not rc.is_checkpoint_pending(0), "no pending checkpoint initially")
	check.call(stub.checkpoint_calls.is_empty() and stub.finish_calls.is_empty(),
		"no RPC sent on reset")

	# --- checkpoint urut: hanya index == next yang dikirim ---
	rc._on_checkpoint_entered(0)
	check.call(arr_eq(stub.checkpoint_calls, [0]), "checkpoint 0 reported to server")
	check.call(rc.is_checkpoint_pending(0), "checkpoint 0 optimistic pending")
	check.call(rc.next_checkpoint_index == 0, "index NOT advanced before ack")

	# checkpoint melompat (index 2 saat menunggu 0) diabaikan
	rc._on_checkpoint_entered(2)
	check.call(arr_eq(stub.checkpoint_calls, [0]), "out-of-order checkpoint NOT reported")
	check.call(rc.next_checkpoint_index == 0, "index stays 0 on skipped checkpoint")

	# klaim duplikat saat pending tidak dikirim ulang
	rc._on_checkpoint_entered(0)
	check.call(arr_eq(stub.checkpoint_calls, [0]), "duplicate pending claim not re-sent")

	# --- ack accepted=true ---
	rc._on_checkpoint_ack(0, true)
	check.call(rc.next_checkpoint_index == 1, "ack accepted advances index to 1")
	check.call(rc.last_checkpoint_position == MapData.CHECKPOINT_POSITIONS[0],
		"ack sets last_checkpoint_position")
	check.call(not rc.is_checkpoint_pending(0), "pending cleared after ack")
	check.call(arr_eq(_confirmed, [0]), "checkpoint_confirmed emitted")
	check.call(_pending_seen.has([0, true]) and _pending_seen.has([0, false]),
		"pending indicator toggled on then off %s" % str(_pending_seen))

	# ack untuk klaim stale (tidak pending) diabaikan
	var before: int = rc.next_checkpoint_index
	rc._on_checkpoint_ack(0, true)
	check.call(rc.next_checkpoint_index == before, "stale ack ignored")

	# --- ack accepted=false: batalkan indikator, index tidak maju ---
	rc._on_checkpoint_entered(1)
	check.call(arr_eq(stub.checkpoint_calls, [0, 1]), "checkpoint 1 reported")
	rc._on_checkpoint_ack(1, false)
	check.call(arr_eq(_rejected, [1]), "checkpoint_rejected emitted")
	check.call(rc.next_checkpoint_index == 1, "index unchanged after rejection")
	check.call(not rc.is_checkpoint_pending(1), "pending indicator cancelled on rejection")
	check.call(rc.last_checkpoint_position == MapData.CHECKPOINT_POSITIONS[0],
		"last_checkpoint_position unchanged after rejection")

	# --- sequence lengkap 4 checkpoint ---
	for i in range(1, MapData.CHECKPOINT_POSITIONS.size()):
		rc._on_checkpoint_entered(i)
		rc._on_checkpoint_ack(i, true)
	check.call(rc.next_checkpoint_index == MapData.CHECKPOINT_POSITIONS.size(),
		"all checkpoints consumed sequentially")
	check.call(rc.last_checkpoint_position
		== MapData.CHECKPOINT_POSITIONS[MapData.CHECKPOINT_POSITIONS.size() - 1],
		"last checkpoint position after full sequence")

	# --- finish sekali ---
	rc._on_finish_entered()
	rc._on_finish_entered()
	rc._on_finish_entered()
	check.call(stub.finish_calls.size() == 1, "rpc_report_finish sent exactly once")
	check.call(_finish_count.size() == 1, "finish_reported emitted once")
	check.call(rc.finish_sent, "finish_sent flag set")

	# --- match results menghentikan race ---
	rc._on_match_results([{"pid": 1, "time_ms": 1234}])
	check.call(_got_results.size() == 1, "results_received emitted")
	check.call(rc.match_finished, "match_finished set on results")

	# --- respawn trigger: y < KILL_Y (reset state hasil dari blok sebelumnya) ---
	rc.match_finished = false
	rc.player = null
	rc._check_kill_y()
	check.call(_respawns.is_empty(), "no respawn without player")
	var player: PlayerController = PlayerSceneBuilder.build(1)
	var holder: Node3D = Node3D.new()
	scene_root.add_child(holder)
	holder.add_child(player)
	check.call(player.is_inside_tree(), "player added to scene tree (root=%s inside=%s)" % [scene_root, scene_root.is_inside_tree() if scene_root != null else false])
	rc.player = player
	player.global_position = Vector3(0, MapData.KILL_Y - 5.0, 0)
	rc._check_kill_y()
	check.call(_respawns.size() == 1, "respawn triggered below KILL_Y (got %d)" % _respawns.size())
	check.call(player.global_position == rc.last_checkpoint_position,
		"respawned to last_checkpoint_position (spawn_order 0)")
	player.global_position = Vector3(0, MapData.KILL_Y + 5.0, 0)
	rc._check_kill_y()
	check.call(_respawns.size() == 1, "no respawn above KILL_Y")

	# --- respawn offset urutan spawn ---
	rc.spawn_order = 3
	player.global_position = Vector3(0, MapData.KILL_Y - 1.0, 0)
	rc._check_kill_y()
	var expected: Vector3 = rc.last_checkpoint_position + MapData.SPAWN_OFFSET_STEP * 3.0
	check.call(player.global_position == expected, "respawn offset by spawn_order")
	check.call(player.velocity == Vector3.ZERO, "respawn resets velocity")
	check.call(player.is_invulnerable(), "respawn grants invulnerability")

	# --- timer lokal display only ---
	rc.reset_race()
	rc.start_local_timer()
	check.call(rc.get_local_elapsed_ms() == 0, "local timer starts at 0")
	rc._process(0.5)
	check.call(rc.get_local_elapsed_ms() == 500, "local timer accumulates delta")
	rc._process(0.25)
	check.call(rc.get_local_elapsed_ms() == 750, "local timer keeps accumulating")
	rc.stop_local_timer()
	var t_stopped: int = rc.get_local_elapsed_ms()
	rc._process(1.0)
	check.call(rc.get_local_elapsed_ms() == t_stopped,
		"local timer stops on stop_local_timer")
	check.call(not rc.match_finished,
		"local timer never declares official result (server-only)")
	check.call(stub.finish_calls.size() == 1, "timer run sends no extra RPCs")

	player.queue_free()
	holder.queue_free()


## Handler sinyal (method, bukan lambda: lambda menangkap lokal by-value).
func _on_pending_changed(i: int, pending: bool) -> void:
	_pending_seen.append([i, pending])

func _on_confirmed(i: int) -> void:
	_confirmed.append(i)

func _on_rejected(i: int) -> void:
	_rejected.append(i)

func _on_finish_reported() -> void:
	_finish_count.append(1)

func _on_results(results: Array) -> void:
	_got_results.append(results)

func _on_respawned(pos: Vector3) -> void:
	_respawns.append(pos)


## Helper perbandingan array (menghindari ambiguasi parse 'as Array').
func arr_eq(a: Array, b: Array) -> bool:
	return a == b
