# A3 smoke test: touch controls + camera rig runtime check.
extends SceneTree

var _failed: int = 0
var _passed: int = 0

func check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  [OK] " + label)
	else:
		_failed += 1
		printerr("  [FAIL] " + label)


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	# Headless windows default to 64x64; use a realistic landscape viewport.
	root.size = Vector2i(1280, 720)
	await process_frame
	var controls: CanvasLayer = (load(
		"res://scenes/ui/touch_controls.tscn") as PackedScene).instantiate()
	root.add_child(controls)
	await process_frame
	check(controls.input_provider != null, "provider exists")

	var provider: Node = controls.input_provider
	# Deadzone test via virtual move.
	provider.set_virtual_move(Vector2(0.10, 0.0))
	check(provider.get_move_vector() == Vector2.ZERO, "deadzone 0.10 -> zero")
	provider.set_virtual_move(Vector2(0.0, -0.5))
	var mv: Vector2 = provider.get_move_vector()
	check(mv.length() > 0.3 and mv.length() <= 1.0,
		"move vector rescaled: %s" % [mv])
	provider.set_virtual_move(Vector2(2.0, 2.0))
	check(provider.get_move_vector().length() <= 1.0, "clamped to 1.0")
	provider.set_virtual_move(Vector2.ZERO)

	# Simulate touch on joystick base center.
	var joy: Control = controls.get_node("VirtualJoystick")
	var center: Vector2 = joy._base_center
	_send_touch(0, center, true)
	await process_frame
	_send_drag(0, center + Vector2(30.0, -30.0))
	await process_frame
	mv = provider.get_move_vector()
	check(mv.length() > 0.1, "joystick drag produces move: %s" % [mv])
	_send_touch(0, center, false)
	await process_frame
	check(provider.get_move_vector() == Vector2.ZERO,
		"joystick released -> zero")

	# Multi-touch: a second touch far from the joystick does not move it.
	_send_touch(1, center + Vector2(600.0, 0.0), true)
	await process_frame
	_send_drag(1, center + Vector2(600.0, 100.0))
	await process_frame
	check(provider.get_move_vector() == Vector2.ZERO,
		"unrelated touch index 1 ignored by joystick")
	_send_touch(1, center + Vector2(600.0, 0.0), false)
	await process_frame

	# Jump button touch (right half).
	var buttons: Control = controls.get_node("TouchButtons")
	var jc: Vector2 = buttons._jump_button.position \
		+ buttons._jump_button.size * 0.5
	_send_touch(2, jc, true)
	await process_frame
	check(provider.is_jump_just_pressed(), "jump button just pressed")
	check(not provider.is_jump_just_pressed(), "jump flag consumed")
	_send_touch(2, jc, false)
	await process_frame

	# Pause button touch.
	var pc: Vector2 = buttons._pause_button.position \
		+ buttons._pause_button.size * 0.5
	_send_touch(3, pc, true)
	await process_frame
	check(provider.is_pause_just_pressed(), "pause button just pressed")
	_send_touch(3, pc, false)
	await process_frame

	# Camera drag (right half, above the jump button).
	var jcenter: Vector2 = buttons._jump_button.position \
		+ buttons._jump_button.size * 0.5
	var drag_pos: Vector2 = Vector2(
		root.size.x * 0.75, maxf(jcenter.y - buttons._jump_button.size.y * 2.0, 10.0))
	print("DEBUG drag_pos=", drag_pos, " half=", root.size.x * 0.5)
	print("DEBUG jump_rect=", buttons._jump_button.get_global_rect())
	print("DEBUG pause_rect=", buttons._pause_button.get_global_rect())
	_send_touch(4, drag_pos, true)
	await process_frame
	_send_drag(4, drag_pos + Vector2(60.0, 30.0))
	await process_frame
	var cam_delta: Vector2 = provider.get_camera_delta()
	check(cam_delta.x == 60.0 and cam_delta.y > 0.0,
		"camera drag delta accumulated: %s" % [cam_delta])

	# Camera rig.
	var rig: Node3D = load("res://scripts/camera/camera_rig.gd").new()
	root.add_child(rig)
	controls.attach_camera_rig(rig)
	check(rig._spring_arm.spring_length == 5.5, "arm default 5.5")
	check(rig._spring_arm.collision_mask == 1, "arm mask layer 1")
	check(rig.get_camera() != null, "camera exists")
	rig.set_arm_length(20.0)
	check(rig._spring_arm.spring_length == 9.0, "arm clamped to max 9")
	rig.set_arm_length(1.0)
	check(rig._spring_arm.spring_length == 2.0, "arm clamped to min 2")

	# Pitch clamp via _rotate.
	rig._rotate(Vector2(0.0, 1000.0))
	check(absf(rig._pitch - 60.0) < 0.001, "pitch clamped to +60")
	rig._rotate(Vector2(0.0, -5000.0))
	check(absf(rig._pitch - (-20.0)) < 0.001, "pitch clamped to -20")

	# Follow target.
	var target: Node3D = Node3D.new()
	root.add_child(target)
	target.position = Vector3(10, 5, -3)
	rig.set_target(target)
	rig._physics_process(1.0)
	check(rig.global_position.distance_to(target.position) < 1.0,
		"rig follows target")

	print("PASSED: %d  FAILED: %d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _send_touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev: InputEventScreenTouch = InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _send_drag(index: int, pos: Vector2) -> void:
	var ev: InputEventScreenDrag = InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	Input.parse_input_event(ev)
