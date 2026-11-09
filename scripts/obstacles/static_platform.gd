# scripts/obstacles/static_platform.gd
# Platform statis: StaticBody3D + BoxShape3D + BoxMesh dengan material bersama. Owner: A4.
class_name StaticPlatform
extends StaticBody3D

@export var size: Vector3 = Vector3(4.0, 1.0, 4.0)
@export var platform_color: Color = ObstacleMaterials.COLOR_PLATFORM

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = ObstacleMaterials.get_material(platform_color)
	mesh.mesh = box_mesh
	add_child(mesh)
