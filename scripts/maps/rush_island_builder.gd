# scripts/maps/rush_island_builder.gd
# Membangun Rush Island dari MapData saat _ready(): platform awal, 3 lompatan
# (gap 2.5 m), 2 platform bergerak, 1 rotating bar, jembatan sempit 12 m x 1.6 m,
# sliding barrier + falling platform, garis finish, 4 checkpoint. Owner: A4.
# MapData hanya dibaca, tidak diubah.
class_name RushIslandBuilder
extends Node3D

const JUMP_PLATFORM_SIZE: Vector3 = Vector3(3.0, 1.0, 3.0)
const JUMP_GAP: float = 2.5
const CP_PLATFORM_SIZE: Vector3 = Vector3(6.0, 1.0, 6.0)

func _ready() -> void:
	_build_light()
	_build_environment()
	_build_start_platform()
	_build_jump_section()
	_build_moving_platforms()
	_build_rotating_bar_section()
	_build_narrow_bridge()
	_build_final_obstacles()
	_build_finish()
	_build_checkpoints()

# --- Pencahayaan: tepat 1 DirectionalLight3D dengan shadow ---
func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	light.shadow_enabled = true
	light.light_energy = 1.2
	add_child(light)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.6
	env.environment = environment
	add_child(env)

# --- Dekorasi berulang via MultiMeshInstance3D (pohon + batu, tanpa kolisi) ---
func _build_environment() -> void:
	var tree_multimesh := MultiMeshInstance3D.new()
	var tree_mm := MultiMesh.new()
	tree_mm.transform_format = MultiMesh.TRANSFORM_3D
	var tree_mesh := BoxMesh.new()
	tree_mesh.size = Vector3(0.8, 2.5, 0.8)
	tree_mesh.material = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_DECOR_TREE)
	tree_mm.mesh = tree_mesh
	var tree_positions: Array[Vector3] = [
		Vector3(-8, 1.0, 2), Vector3(8, 1.0, 1), Vector3(-10, 1.0, -6),
		Vector3(11, 1.0, -10), Vector3(-9, 1.0, -20), Vector3(10, 3.0, -30),
		Vector3(-11, 5.0, -48), Vector3(12, 7.0, -64), Vector3(-10, 9.0, -86),
		Vector3(9, 9.0, -94),
	]
	tree_mm.instance_count = tree_positions.size()
	for i: int in tree_positions.size():
		var t := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE), tree_positions[i])
		tree_mm.set_instance_transform(i, t)
	tree_multimesh.multimesh = tree_mm
	add_child(tree_multimesh)

	var rock_multimesh := MultiMeshInstance3D.new()
	var rock_mm := MultiMesh.new()
	rock_mm.transform_format = MultiMesh.TRANSFORM_3D
	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(1.2, 0.9, 1.2)
	rock_mesh.material = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_DECOR_ROCK)
	rock_mm.mesh = rock_mesh
	var rock_positions: Array[Vector3] = [
		Vector3(5, 0.6, 6), Vector3(-5, 0.6, 5), Vector3(6, 0.6, -2),
		Vector3(-4, 1.6, -26), Vector3(5, 3.6, -34), Vector3(0, 5.6, -50),
		Vector3(-6, 7.6, -58), Vector3(0, 8.6, -78),
	]
	rock_mm.instance_count = rock_positions.size()
	for i: int in rock_positions.size():
		var t2 := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE), rock_positions[i])
		rock_mm.set_instance_transform(i, t2)
	rock_multimesh.multimesh = rock_mm
	add_child(rock_multimesh)

# --- 1. Platform awal (spawn) — permukaan atas y=1.0, spawn di (0, 1.5, 4) ---
func _build_start_platform() -> void:
	add_child(ObstacleMaterials.box_body(Vector3(10.0, 1.0, 8.0), Vector3(0, 0.5, 4), ObstacleMaterials.get_material(ObstacleMaterials.COLOR_PLATFORM_TOP)))

# --- 2. Tiga platform lompatan dengan celah 2.5 m ---
func _build_jump_section() -> void:
	# Platform 3x3, celah tepi 2.5 → jarak antar pusat = 3 + 2.5 = 5.5.
	var base_z: float = -4.0
	var platform_mat: StandardMaterial3D = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_PLATFORM)
	for i: int in 3:
		var z: float = base_z - float(i) * (JUMP_PLATFORM_SIZE.z + JUMP_GAP)
		var y: float = 0.75 + float(i) * 0.25
		add_child(ObstacleMaterials.box_body(JUMP_PLATFORM_SIZE, Vector3(0, y, z), platform_mat))
	# Platform checkpoint 0 di (0,1,-12): permukaan atas y=1.0, ukuran CP_PLATFORM_SIZE.
	add_child(_cp_platform(Vector3(0, 0.5, -12)))

# --- 3. Dua platform bergerak + platform checkpoint 1 di (0,4,-32) ---
func _build_moving_platforms() -> void:
	var mp1: MovingPlatform = MovingPlatform.new()
	mp1.size = Vector3(3.0, 0.8, 3.0)
	mp1.axis = Vector3(1.0, 0.0, 0.0)
	mp1.distance = 5.0
	mp1.speed = 2.0
	mp1.pause_time = 0.5
	mp1.position = Vector3(-2.0, 1.6, -20.0)
	add_child(mp1)

	var mp2: MovingPlatform = MovingPlatform.new()
	mp2.size = Vector3(3.0, 0.8, 3.0)
	mp2.axis = Vector3(0.0, 1.0, 0.0)
	mp2.distance = 3.0
	mp2.speed = 1.5
	mp2.pause_time = 0.4
	mp2.start_phase = 1.0
	mp2.position = Vector3(2.0, 2.2, -26.0)
	add_child(mp2)

	# Platform pendaratan checkpoint 1: permukaan atas y=4.0.
	add_child(_cp_platform(Vector3(0, 3.5, -32)))

# --- 4. Rotating bar di atas jalur + platform checkpoint 2 di (-6,6,-52) ---
func _build_rotating_bar_section() -> void:
	# Jalur naik dari y=4 ke y=6: dua platform statis.
	var mat: StandardMaterial3D = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_PLATFORM)
	add_child(ObstacleMaterials.box_body(Vector3(5.0, 1.0, 5.0), Vector3(0, 4.5, -40), mat))
	add_child(ObstacleMaterials.box_body(Vector3(5.0, 1.0, 5.0), Vector3(-3, 5.5, -46), mat))

	var bar: RotatingBar = RotatingBar.new()
	bar.rpm = 14.0
	bar.length = 8.0
	bar.axis = Vector3.UP
	bar.position = Vector3(0, 5.6, -40.5)
	add_child(bar)

	add_child(_cp_platform(Vector3(-6, 5.5, -52)))

# --- 5. Jembatan sempit 12 m x 1.6 m menuju checkpoint 3 di (6,8,-70) ---
func _build_narrow_bridge() -> void:
	var bridge: NarrowBridge = NarrowBridge.new()
	bridge.length = 12.0
	bridge.width = 1.6
	bridge.position = Vector3(0, 7.3, -62.0)
	add_child(bridge)
	# Perancah naik dari cp2 (y=6) ke jembatan (atas y=7.5).
	var mat: StandardMaterial3D = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_PLATFORM)
	add_child(ObstacleMaterials.box_body(Vector3(4.0, 1.0, 4.0), Vector3(-3, 6.5, -57), mat))
	add_child(ObstacleMaterials.box_body(Vector3(4.0, 1.0, 4.0), Vector3(0, 7.0, -60), mat))
	add_child(_cp_platform(Vector3(6, 7.5, -70)))

# --- 6. Penghalang geser + platform jatuh sebelum garis finish ---
func _build_final_obstacles() -> void:
	var mat: StandardMaterial3D = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_PLATFORM)
	add_child(ObstacleMaterials.box_body(Vector3(6.0, 1.0, 6.0), Vector3(6, 7.5, -76), mat))

	var barrier: SlidingBarrier = SlidingBarrier.new()
	barrier.size = Vector3(0.8, 2.0, 4.0)
	barrier.slide_axis = Vector3(1.0, 0.0, 0.0)
	barrier.range = 6.0
	barrier.period = 3.0
	barrier.position = Vector3(6, 8.5, -79.0)
	add_child(barrier)

	# Dua platform jatuh berurutan di jalur akhir.
	_add_falling_platform(Vector3(2.0, 8.0, -82.0))
	_add_falling_platform(Vector3(-2.0, 8.0, -85.0))

	# Jalur pendek menuju platform finish (atas y=9).
	add_child(ObstacleMaterials.box_body(Vector3(5.0, 1.0, 4.0), Vector3(0, 8.5, -86.0), mat))

# Platform jatuh: papan + Area3D pemantau injakan di permukaan atas.
func _add_falling_platform(pos: Vector3) -> void:
	var fp: FallingPlatform = FallingPlatform.new()
	fp.size = Vector3(3.0, 0.6, 3.0)
	fp.fall_delay = 0.8
	fp.respawn_delay = 3.0
	fp.position = pos
	add_child(fp)
	var sensor := Area3D.new()
	sensor.collision_layer = 4
	sensor.collision_mask = 2
	var sensor_shape := CollisionShape3D.new()
	var sensor_box := BoxShape3D.new()
	sensor_box.size = Vector3(3.4, 1.2, 3.4)
	sensor_shape.shape = sensor_box
	sensor.add_child(sensor_shape)
	sensor.position = Vector3(0.0, 0.6, 0.0)
	sensor.body_entered.connect(fp._on_body_entered)
	fp.add_child(sensor)

# --- 7. Garis finish di MapData.FINISH_POSITION ---
func _build_finish() -> void:
	# Platform finish: permukaan atas y=9.0 di (0, -, -90).
	add_child(ObstacleMaterials.box_body(Vector3(8.0, 1.0, 8.0), Vector3(0, 8.5, -90), ObstacleMaterials.get_material(ObstacleMaterials.COLOR_PLATFORM_TOP)))
	var finish := FinishLine.new()
	finish.radius = MapData.FINISH_RADIUS
	finish.position = MapData.FINISH_POSITION
	add_child(finish)

# --- Empat checkpoint dari MapData.CHECKPOINT_POSITIONS ---
func _build_checkpoints() -> void:
	for i: int in MapData.CHECKPOINT_POSITIONS.size():
		var cp := Checkpoint.new()
		cp.index = i
		cp.radius = MapData.CHECKPOINT_RADIUS
		cp.position = MapData.CHECKPOINT_POSITIONS[i]
		add_child(cp)

# Platform checkpoint: ukuran tetap, permukaan atas pada position.y + 0.5.
func _cp_platform(center: Vector3) -> StaticBody3D:
	return ObstacleMaterials.box_body(CP_PLATFORM_SIZE, center, ObstacleMaterials.get_material(ObstacleMaterials.COLOR_PLATFORM_TOP))
