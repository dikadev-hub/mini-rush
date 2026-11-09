# scripts/obstacles/narrow_bridge.gd
# Jembatan sempit: StaticBody3D papan sempit + dua rel visual. Lebar minimum 1.2 m. Owner: A4.
class_name NarrowBridge
extends StaticBody3D

@export var length: float = 12.0
@export var width: float = 1.6
@export var thickness: float = 0.4

const MIN_WIDTH: float = 1.2

func _ready() -> void:
	if width < MIN_WIDTH:
		width = MIN_WIDTH
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, thickness, length)
	shape.shape = box
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(width, thickness, length)
	box_mesh.material = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_BRIDGE)
	mesh.mesh = box_mesh
	add_child(mesh)
	# Rel visual di kedua sisi (tanpa kolisi, dekorasi).
	var rail_mat: StandardMaterial3D = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_PLATFORM_TOP)
	for side: int in [-1, 1]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.15, 0.5, length)
		rail_mesh.material = rail_mat
		rail.mesh = rail_mesh
		rail.position = Vector3(side * (width * 0.5 + 0.1), thickness * 0.5 + 0.25, 0.0)
		add_child(rail)
