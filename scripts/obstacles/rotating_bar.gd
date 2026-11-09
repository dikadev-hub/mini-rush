# scripts/obstacles/rotating_bar.gd
# Rintangan berputar: AnimatableBody3D sync_to_physics=true, bar memutar
# dengan rpm tertentu pada axis (default Y). Menjatuhkan pemain yang tertabrak. Owner: A4.
class_name RotatingBar
extends AnimatableBody3D

@export var rpm: float = 12.0
@export var length: float = 8.0
@export var axis: Vector3 = Vector3.UP
@export var bar_thickness: float = 0.6
@export var bar_height: float = 1.0

var _spin_axis: Vector3 = Vector3.UP

func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	_spin_axis = axis.normalized() if axis.length() > 0.0001 else Vector3.UP
	# Tiang pusat (visual saja, statis).
	var center := StaticBody3D.new()
	center.collision_layer = 1
	center.collision_mask = 0
	var center_shape := CollisionShape3D.new()
	var center_box := BoxShape3D.new()
	center_box.size = Vector3(0.8, bar_height + 1.0, 0.8)
	center_shape.shape = center_box
	center.add_child(center_shape)
	var center_mesh := MeshInstance3D.new()
	var center_box_mesh := BoxMesh.new()
	center_box_mesh.size = Vector3(0.8, bar_height + 1.0, 0.8)
	center_box_mesh.material = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_BRIDGE)
	center_mesh.mesh = center_box_mesh
	center.add_child(center_mesh)
	add_child(center)
	# Bar berputar (AnimatableBody3D di pusat, sync_to_physics).
	var bar := AnimatableBody3D.new()
	bar.sync_to_physics = true
	bar.collision_layer = 1
	bar.collision_mask = 0
	var bar_shape := CollisionShape3D.new()
	var bar_box := BoxShape3D.new()
	bar_box.size = Vector3(length, bar_height, bar_thickness)
	bar_shape.shape = bar_box
	bar.add_child(bar_shape)
	var bar_mesh := MeshInstance3D.new()
	var bar_box_mesh := BoxMesh.new()
	bar_box_mesh.size = Vector3(length, bar_height, bar_thickness)
	bar_box_mesh.material = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_HAZARD)
	bar_mesh.mesh = bar_box_mesh
	bar.add_child(bar_mesh)
	bar.name = "Bar"
	add_child(bar)

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	var bar: AnimatableBody3D = get_node_or_null("Bar") as AnimatableBody3D
	if bar == null:
		return
	var angle: float = rpm * TAU / 60.0 * delta
	bar.rotate(_spin_axis, angle)
