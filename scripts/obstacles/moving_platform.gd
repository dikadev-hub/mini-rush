# scripts/obstacles/moving_platform.gd
# Platform bergerak: AnimatableBody3D sync_to_physics=true, bergerak bolak-balik
# pada axis sejauh distance dengan speed (m/s) dan pause_time di tiap ujung. Owner: A4.
class_name MovingPlatform
extends AnimatableBody3D

@export var size: Vector3 = Vector3(3.0, 0.8, 3.0)
@export var axis: Vector3 = Vector3(1.0, 0.0, 0.0)
@export var distance: float = 5.0
@export var speed: float = 2.0
@export var pause_time: float = 0.5
@export var start_phase: float = 0.0

var _origin: Vector3 = Vector3.ZERO
var _dir: int = 1
var _pause_left: float = 0.0

func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	_origin = position
	axis = axis.normalized() if axis.length() > 0.0001 else Vector3.RIGHT
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_MOVING)
	mesh.mesh = box_mesh
	add_child(mesh)
	if start_phase > 0.0:
		_pause_left = start_phase

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		return
	var step: Vector3 = axis * speed * float(_dir) * delta
	var next: Vector3 = position + step
	var offset: Vector3 = next - _origin
	var along: float = offset.dot(axis)
	if along >= distance:
		next = _origin + axis * distance
		_dir = -1
		_pause_left = pause_time
	elif along <= 0.0:
		next = _origin
		_dir = 1
		_pause_left = pause_time
	position = next
