# A3: Unified input provider. Merges keyboard/gamepad actions with
# virtual touch controls (joystick, camera drag, jump/pause buttons).
# Controller (A2) reads only from this node, never from Input.* directly.
class_name InputProvider
extends Node

const DEADZONE: float = 0.15
const DEFAULT_SENSITIVITY: float = 1.0

## Set by VirtualJoystick each frame it is active; zero when idle.
var _virtual_move: Vector2 = Vector2.ZERO
var _virtual_jump_pressed: bool = false
var _virtual_pause_pressed: bool = false
## Accumulated camera look delta (pixels) since last get_camera_delta().
var _camera_delta: Vector2 = Vector2.ZERO


func _process(_delta: float) -> void:
	# Consume one-frame flags at end of frame if nobody read them.
	pass


func set_virtual_move(value: Vector2) -> void:
	_virtual_move = value


func notify_virtual_jump() -> void:
	_virtual_jump_pressed = true


func notify_virtual_pause() -> void:
	_virtual_pause_pressed = true


func add_camera_delta(delta: Vector2) -> void:
	_camera_delta += delta


func get_move_vector() -> Vector2:
	var device: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down")
	var merged: Vector2 = device
	if _virtual_move.length() > device.length():
		merged = _virtual_move
	if merged.length() < DEADZONE:
		return Vector2.ZERO
	# Rescale so deadzone edge maps to 0 and full deflection maps to 1.0.
	var scaled: Vector2 = (merged - merged.normalized() * DEADZONE) \
		/ (1.0 - DEADZONE)
	return scaled.limit_length(1.0)


func is_jump_just_pressed() -> bool:
	var pressed: bool = Input.is_action_just_pressed("jump") \
		or _virtual_jump_pressed
	_virtual_jump_pressed = false
	return pressed


func is_pause_just_pressed() -> bool:
	var pressed: bool = Input.is_action_just_pressed("pause") \
		or _virtual_pause_pressed
	_virtual_pause_pressed = false
	return pressed


func get_camera_delta() -> Vector2:
	var delta: Vector2 = _camera_delta
	_camera_delta = Vector2.ZERO
	return delta


func get_sensitivity() -> float:
	var sm: Node = get_node_or_null("/root/SettingsManager")
	if sm != null and "camera_sensitivity" in sm:
		var value: Variant = sm.get("camera_sensitivity")
		if value is float and value > 0.0:
			return value
	return DEFAULT_SENSITIVITY
