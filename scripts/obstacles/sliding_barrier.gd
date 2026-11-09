# scripts/obstacles/sliding_barrier.gd
# Penghalang geser: AnimatableBody3D sync_to_physics=true, dinding geser bolak-balik
# melintasi jalur dengan range (meter) dan period (detik per siklus penuh). Owner: A4.
class_name SlidingBarrier
extends AnimatableBody3D

@export var size: Vector3 = Vector3(0.8, 2.0, 4.0)
@export var slide_axis: Vector3 = Vector3(1.0, 0.0, 0.0)
@export var range: float = 6.0
@export var period: float = 3.0
@export var start_phase: float = 0.0

var _origin: Vector3 = Vector3.ZERO
var _phase: float = 0.0

func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	_origin = position
	slide_axis = slide_axis.normalized() if slide_axis.length() > 0.0001 else Vector3.RIGHT
	if period <= 0.0:
		period = 1.0
	_phase = start_phase * TAU
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_HAZARD)
	mesh.mesh = box_mesh
	add_child(mesh)

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	_phase += delta * TAU / period
	var offset: float = sin(_phase) * range * 0.5
	position = _origin + slide_axis * offset
