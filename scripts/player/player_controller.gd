# A2: Player movement controller. Reads input only from InputProvider (A3).
class_name PlayerController
extends CharacterBody3D

signal jumped
signal landed
signal respawned
signal animation_changed(anim_name: StringName)

const UP_DIRECTION: Vector3 = Vector3.UP
const FLOOR_MAX_ANGLE_RAD: float = 1.5707963267948966 * 0.5  # 45 deg

@export var max_speed: float = 8.5
@export var acceleration: float = 28.0
@export var deceleration: float = 34.0
@export var air_acceleration: float = 9.0
@export var jump_velocity: float = 8.0
@export var gravity_scale: float = 1.0
@export var rotation_speed: float = 12.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var respawn_invuln_time: float = 1.0
## Optional direct reference; otherwise a child InputProvider node is used.
@export var input_provider: Node = null

var _input_provider: Node = null
var _was_on_floor: bool = true
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _invuln_timer: float = 0.0
var _current_anim: StringName = &"idle"
var _visual: Node3D = null
## Set once a jump consumes the coyote window, until the next floor contact.
var _coyote_consumed: bool = false


func _ready() -> void:
	up_direction = UP_DIRECTION
	floor_max_angle = FLOOR_MAX_ANGLE_RAD
	_resolve_input_provider()
	_resolve_visual()


func _resolve_input_provider() -> void:
	if input_provider != null:
		_input_provider = input_provider
		return
	for child in get_children():
		if child.is_in_group("input_provider"):
			_input_provider = child
			return
		if child.get_script() != null and child.get_script().get_global_name() == "InputProvider":
			_input_provider = child
			return


func _resolve_visual() -> void:
	for child in get_children():
		if child is Node3D and child.get_script() != null \
				and child.get_script().get_global_name() == "PlayerVisual":
			_visual = child
			return


func _physics_process(delta: float) -> void:
	var move_input: Vector2 = Vector2.ZERO
	var jump_pressed: bool = false
	if _input_provider == null:
		_resolve_input_provider()
	if _input_provider != null:
		move_input = _input_provider.get_move_vector()
		jump_pressed = _input_provider.is_jump_just_pressed()

	_update_timers(delta, jump_pressed)
	_apply_gravity(delta)
	_apply_horizontal_motion(move_input, delta)
	_try_jump()
	move_and_slide()
	_update_rotation(move_input, delta)
	_check_landed()


func _update_timers(delta: float, jump_pressed: bool) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		_coyote_consumed = false
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
	if jump_pressed:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	if _invuln_timer > 0.0:
		_invuln_timer = maxf(0.0, _invuln_timer - delta)


func _coyoter_zero() -> float:
	return 0.0


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var gravity: float = float(ProjectSettings.get_setting(
			"physics/3d/default_gravity", 9.8))
		velocity.y -= gravity * gravity_scale * delta


func _apply_horizontal_motion(move_input: Vector2, delta: float) -> void:
	var planar: Vector3 = Vector3(move_input.x, 0.0, move_input.y)
	var target: Vector3 = planar * max_speed
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var rate: float
	if is_on_floor():
		rate = acceleration if target.length_squared() > 0.001 else deceleration
	else:
		rate = air_acceleration
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _try_jump() -> void:
	if _jump_buffer_timer <= 0.0:
		return
	var can_jump: bool = is_on_floor() \
		or (_coyote_timer > 0.0 and not _coyote_consumed)
	if can_jump:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_coyote_consumed = true
		_was_on_floor = false
		jumped.emit()
		_play_animation(&"jump")


func _update_rotation(move_input: Vector2, delta: float) -> void:
	if move_input.length_squared() < 0.001:
		return
	var planar_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if planar_velocity.length_squared() < 0.01:
		return
	var target_yaw: float = atan2(planar_velocity.x, planar_velocity.z)
	var target_basis: Basis = Basis(UP_DIRECTION, target_yaw)
	basis = basis.slerp(target_basis, clampf(rotation_speed * delta, 0.0, 1.0))


func _check_landed() -> void:
	var on_floor: bool = is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit()
		_play_animation(&"land")
	_was_on_floor = on_floor
	var next_anim: StringName = _pick_animation(on_floor)
	_play_animation(next_anim)


func _pick_animation(on_floor: bool) -> StringName:
	if not on_floor:
		return &"fall" if velocity.y < -0.1 else &"jump"
	if Vector3(velocity.x, 0.0, velocity.z).length() > 0.5:
		return &"run"
	return &"idle"


func respawn_to(position: Vector3) -> void:
	global_position = position
	velocity = Vector3.ZERO
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_coyote_consumed = false
	_invuln_timer = respawn_invuln_time
	_was_on_floor = false
	respawned.emit()
	_play_animation(&"idle")


func is_invulnerable() -> bool:
	return _invuln_timer > 0.0


func get_current_animation() -> StringName:
	return _current_anim


func _play_animation(anim_name: StringName) -> void:
	if anim_name != _current_anim:
		_current_anim = anim_name
		animation_changed.emit(anim_name)
	if _visual != null:
		_visual.play_animation(anim_name)
