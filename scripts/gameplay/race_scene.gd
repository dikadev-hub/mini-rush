# scripts/gameplay/race_scene.gd — Gelombang 3 (integrasi akhir).
# Scene race runtime: RushIslandBuilder + Players (spawn per peer sesuai kontrak
# 4.6: nama node str(peer_id), authority peer) + RaceController + HUD +
# touch_controls + CameraRig follow pemain lokal. Publish state lokal 20 Hz via
# NetManager.set_local_state; remote players dirender via RemotePlayerView.
extends Node3D

const RACE_SCENE_PATH: String = "res://scripts/gameplay/race_scene.gd"

var world: Node3D = null
var players_root: Node3D = null
var local_player: CharacterBody3D = null
var race_controller: RaceController = null
var camera_rig: CameraRig = null
var hud: Control = null
var touch_controls: TouchControls = null
var input_provider: InputProvider = null
var _spawn_orders: Dictionary = {}  # peer_id -> order (0-based)

func _ready() -> void:
	world = load("res://scripts/maps/rush_island_builder.gd").new()
	world.name = "World"
	add_child(world)
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	race_controller = RaceController.new()
	race_controller.name = "RaceController"
	add_child(race_controller)
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	hud = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	touch_controls = load("res://scenes/ui/touch_controls.tscn").instantiate()
	add_child(touch_controls)
	input_provider = touch_controls.input_provider
	touch_controls.attach_camera_rig(camera_rig)
	_spawn_players_from_snapshot()
	var checkpoints: Array = []
	var finish_line: FinishLine = null
	for child in world.get_children():
		if child is Checkpoint:
			checkpoints.append(child)
		elif child is FinishLine:
			finish_line = child
	race_controller.bind_world(checkpoints, finish_line)
	NetManager.match_started.connect(_on_match_started)
	var total: int = _spawn_orders.size()
	if hud != null and hud.has_method("set_player_count"):
		hud.set_player_count(total)

func _spawn_players_from_snapshot() -> void:
	var snap: Dictionary = NetManager.last_room_snapshot
	var my_id: int = multiplayer.get_unique_id()
	var list: Array = snap.get("players", [])
	var order: int = 0
	for entry_v: Variant in list:
		var entry: Dictionary = entry_v as Dictionary
		var pid: int = int(entry.get("peer_id", 0))
		if pid <= 0:
			continue
		_spawn_orders[pid] = order
		var body: CharacterBody3D = load("res://scripts/player/player_scene_builder.gd").build(pid)
		body.name = str(pid)
		body.set_multiplayer_authority(pid)
		var offset: Vector3 = MapData.SPAWN_OFFSET_STEP * float(order)
		body.position = MapData.SPAWN_POSITION + offset
		players_root.add_child(body)
		if pid == my_id:
			local_player = body
			if input_provider != null:
				local_player.input_provider = input_provider
			camera_rig.set_target(local_player)
			race_controller.player = local_player
			race_controller.spawn_order = order
		else:
			# Remote: matikan simulasi fisik lokal; posisi dari interpolasi.
			body.set_physics_process(false)
			var view_script: Script = load("res://scripts/networking/remote_player_view.gd")
			var view: Node3D = view_script.new()
			view.name = "RemoteSync"
			body.add_child(view)
			view.call("setup", pid)
		order += 1
	# Fallback: belum ada snapshot (mis. test langsung) — spawn pemain lokal saja.
	if local_player == null:
		var body2: CharacterBody3D = load("res://scripts/player/player_scene_builder.gd").build(my_id)
		body2.name = str(my_id)
		body2.set_multiplayer_authority(my_id)
		body2.position = MapData.SPAWN_POSITION
		players_root.add_child(body2)
		local_player = body2
		if input_provider != null:
			local_player.input_provider = input_provider
		camera_rig.set_target(local_player)
		race_controller.player = local_player

var _dbg_state_count: int = 0

func _physics_process(_delta: float) -> void:
	if local_player == null:
		if _dbg_state_count < 3:
			_dbg_state_count += 1
			print("[RACE] menunggu local_player ...")
		return
	_dbg_state_count += 1
	if _dbg_state_count <= 3:
		print("[RACE] publish state peer=%d connected=%s" % [multiplayer.get_unique_id(), NetManager.is_connected_to_server()])
	NetManager.set_local_state(
		local_player.global_position,
		local_player.rotation.y,
		local_player.get_current_animation(),
		local_player.is_on_floor())
	_update_hud_progress()

func _update_hud_progress() -> void:
	if hud == null:
		return
	var my_z: float = local_player.global_position.z
	var rank: int = 1
	for pid: int in _spawn_orders:
		if pid == multiplayer.get_unique_id():
			continue
		var other := players_root.get_node_or_null(str(pid)) as Node3D
		if other != null and other.global_position.z < my_z:
			rank += 1
	if hud.has_method("set_player_position"):
		hud.set_player_position(rank, _spawn_orders.size())

func _on_match_started(_race_start_server_ms: int) -> void:
	race_controller.start_local_timer()

func set_autodrive(enabled: bool) -> void:
	if input_provider != null:
		input_provider.set_virtual_move(Vector2(0.0, -1.0) if enabled else Vector2.ZERO)

func get_local_player() -> CharacterBody3D:
	return local_player
