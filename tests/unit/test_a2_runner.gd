# A2 smoke test runner: standalone SceneTree script that exercises the
# PlayerController against a real static floor and reports pass/fail.
# Uses member state + bound methods (GDScript lambdas capture locals by value).
extends SceneTree

var _failed: int = 0
var _passed: int = 0

var _player: CharacterBody3D = null
var _landed_count: int = 0
var _jump_count: int = 0
var _anims: Array[StringName] = []


func _init() -> void:
	_run()


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [OK] " + label)
	else:
		_failed += 1
		printerr("  [FAIL] " + label)


func _on_landed() -> void:
	_landed_count += 1


func _on_jumped() -> void:
	_jump_count += 1


func _on_anim_changed(anim_name: StringName) -> void:
	_anims.append(anim_name)


func _wait(frames: int) -> void:
	for i in range(frames):
		await physics_frame


func _run() -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)

	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)

	_player = PlayerSceneBuilder.build(1)
	var provider: Node = Node.new()
	provider.set_script(load("res://scripts/input/input_provider.gd"))
	_player.add_child(provider)
	world.add_child(_player)
	_player.global_position = Vector3(0, 2.0, 0)
	var controller: PlayerController = _player as PlayerController
	check(controller != null, "scene builder yields PlayerController")
	check(is_equal_approx(controller.max_speed, 8.5), "max_speed default 8.5")
	check(is_equal_approx(controller.acceleration, 28.0), "acceleration default 28")
	check(is_equal_approx(controller.deceleration, 34.0), "deceleration default 34")
	check(is_equal_approx(controller.air_acceleration, 9.0), "air_acceleration default 9")
	check(is_equal_approx(controller.jump_velocity, 8.0), "jump_velocity default 8")
	check(is_equal_approx(controller.gravity_scale, 1.0), "gravity_scale default 1")
	check(is_equal_approx(controller.rotation_speed, 12.0), "rotation_speed default 12")
	check(is_equal_approx(controller.coyote_time, 0.12), "coyote_time default 0.12")
	check(is_equal_approx(controller.jump_buffer_time, 0.12), "jump_buffer_time default 0.12")
	check(is_equal_approx(controller.respawn_invuln_time, 1.0), "respawn_invuln default 1.0")
	check(controller.up_direction == Vector3.UP, "up_direction is UP")
	check(absf(controller.floor_max_angle - deg_to_rad(45.0)) < 0.001, "floor_max_angle 45deg")

	_player.landed.connect(_on_landed)
	_player.jumped.connect(_on_jumped)
	_player.animation_changed.connect(_on_anim_changed)

	# --- fall + land ---
	await _wait(40)
	check(_player.is_on_floor(), "player lands on floor")
	check(absf(_player.global_position.y - 0.8) < 0.15,
		"rest height near capsule half-height (got %.2f)" % _player.global_position.y)
	check(_landed_count >= 1, "landed signal emitted")
	check(_anims.has(&"idle"), "idle animation reported")

	# --- gravity ---
	_player.global_position = Vector3(0, 5.0, 0)
	_player.velocity = Vector3.ZERO
	await _wait(80)
	check(_player.is_on_floor(), "falls back to floor under gravity")

	# --- jump via InputProvider (real device action; controller reads provider) ---
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	var peak: float = _player.global_position.y
	for i in range(25):
		await physics_frame
		peak = maxf(peak, _player.global_position.y)
	check(_jump_count >= 1, "jumped signal emitted")
	check(peak > 1.4, "jump raises player (peak %.2f)" % peak)
	await _wait(90)
	check(_player.is_on_floor(), "lands after jump")

	# --- acceleration toward max speed on ground ---
	var start_z: float = _player.global_position.z
	Input.action_press("move_up")
	await _wait(20)
	var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	check(speed > 5.0, "accelerates under sustained input (%.2f m/s)" % speed)
	check(speed <= controller.max_speed + 0.01, "speed capped at max_speed")
	check(absf(_player.global_position.z - start_z) > 1.0, "moves along -Z forward")

	# --- deceleration ---
	Input.action_release("move_up")
	await _wait(20)
	check(Vector2(_player.velocity.x, _player.velocity.z).length() < 0.5,
		"decelerates to rest when input released")

	# --- no double jump in air: jump first, then press jump mid-air ---
	var jumps_before: int = _jump_count
	Input.action_press("jump")
	await _wait(3)
	Input.action_release("jump")
	check(_jump_count == jumps_before + 1, "ground jump accepted")
	var jumps_in_air_before: int = _jump_count
	Input.action_press("jump")
	await _wait(3)
	Input.action_release("jump")
	check(_jump_count == jumps_in_air_before, "no double jump in air")
	await _wait(120)

	# --- coyote time: step off an edge, then jump within 0.12s ---
	var edge: StaticBody3D = StaticBody3D.new()
	var edge_shape: CollisionShape3D = CollisionShape3D.new()
	var edge_box: BoxShape3D = BoxShape3D.new()
	edge_box.size = Vector3(4, 1, 4)
	edge_shape.shape = edge_box
	edge.add_child(edge_shape)
	edge.position = Vector3(40, -0.5, 40)
	world.add_child(edge)
	_player.respawn_to(Vector3(40, 1.2, 40))
	await _wait(30)
	check(_player.is_on_floor(), "player standing on ledge")
	var jumps_before_coyote: int = _jump_count
	Input.action_press("move_up")
	await _wait(30)  # leaves the ledge after ~0.5s: crosses 2m half-width from standstill
	Input.action_release("move_up")
	check(not _player.is_on_floor(), "walked off the ledge")
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	check(_jump_count > jumps_before_coyote, "coyote-time jump accepted")
	await _wait(120)

	# --- respawn resets state ---
	_player.velocity = Vector3(3, -5, 2)
	_player.respawn_to(Vector3(6, 3.0, 6))
	check(_player.velocity == Vector3.ZERO, "respawn resets velocity")
	check(_player.is_invulnerable(), "respawn grants invulnerability")
	check(_player.get_current_animation() == &"idle", "respawn resets animation")
	await _wait(120)
	check(not _player.is_invulnerable(), "invulnerability expires after ~1s")
	check(_player.is_on_floor(), "respawned player settles on floor")

	# --- signal contract ---
	check(_player.has_signal("jumped"), "signal jumped exists")
	check(_player.has_signal("landed"), "signal landed exists")
	check(_player.has_signal("respawned"), "signal respawned exists")
	check(_player.has_signal("animation_changed"), "signal animation_changed exists")

	print("PASSED: %d  FAILED: %d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
