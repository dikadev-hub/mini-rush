# A3: Third-person camera rig. Smooth-follows a target, SpringArm3D collision
# on environment layer 1, pitch clamped -20..60 deg. Camera look comes from
# right-screen touch drag and mouse motion; sensitivity from SettingsManager.
class_name CameraRig
extends Node3D

const ARM_DEFAULT_LENGTH: float = 5.5
const ARM_MIN_LENGTH: float = 2.0
const ARM_MAX_LENGTH: float = 9.0
const PITCH_MIN_DEG: float = -20.0
const PITCH_MAX_DEG: float = 60.0
const FOLLOW_RATE: float = 10.0
const MOUSE_SENSITIVITY: float = 0.15
const TOUCH_DEG_PER_PX: float = 1.0 / 6.0

@export var follow_rate: float = FOLLOW_RATE
@export var pitch_min_deg: float = PITCH_MIN_DEG
@export var pitch_max_deg: float = PITCH_MAX_DEG

var _spring_arm: SpringArm3D = null
var _camera: Camera3D = null
var _target: Node3D = null
var _yaw: float = 0.0
var _pitch: float = 15.0
var _provider: Node = null


func _ready() -> void:
	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = ARM_DEFAULT_LENGTH
	_spring_arm.collision_mask = 1  # environment layer 1
	_spring_arm.margin = 0.25
	add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.fov = 70.0
	_spring_arm.add_child(_camera)

	_apply_pitch_rotation()


func set_target(target: Node3D) -> void:
	_target = target
	if _target != null:
		global_position = _target.global_position


func set_provider(provider: Node) -> void:
	_provider = provider


func get_camera() -> Camera3D:
	return _camera


func set_arm_length(length: float) -> void:
	_spring_arm.spring_length = clampf(length, ARM_MIN_LENGTH, ARM_MAX_LENGTH)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_rotate(motion.relative * MOUSE_SENSITIVITY)


func _rotate(delta_deg: Vector2) -> void:
	var sens: float = _get_sensitivity()
	_yaw -= delta_deg.x * sens
	_pitch = clampf(_pitch + delta_deg.y * sens, pitch_min_deg, pitch_max_deg)
	rotation.y = deg_to_rad(_yaw)
	_apply_pitch_rotation()


func _apply_pitch_rotation() -> void:
	_spring_arm.rotation_degrees.x = _pitch


func _get_sensitivity() -> float:
	if _provider != null and _provider.has_method("get_sensitivity"):
		return _provider.get_sensitivity()
	return 1.0


func _physics_process(delta: float) -> void:
	if _provider != null and _provider.has_method("get_camera_delta"):
		var touch_delta: Vector2 = _provider.get_camera_delta()
		if touch_delta != Vector2.ZERO:
			_rotate(touch_delta * TOUCH_DEG_PER_PX)
	if _target != null:
		var factor: float = 1.0 - exp(-follow_rate * delta)
		global_position = global_position.lerp(
			_target.global_position, factor)
