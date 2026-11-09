# scripts/obstacles/finish_line.gd
# Garis finish: Area3D SphereShape radius MapData.FINISH_RADIUS, mask layer 2,
# dengan visual gerbang garis finish. Sinyal dikonsumsi A5. Owner: A4.
class_name FinishLine
extends Area3D

signal finish_entered

@export var radius: float = 3.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	add_child(shape)
	var finish_mat: StandardMaterial3D = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_FINISH)
	# Dua tiang gerbang.
	for side: int in [-1, 1]:
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.2
		cyl.bottom_radius = 0.2
		cyl.height = 4.0
		cyl.material = finish_mat
		pole.mesh = cyl
		pole.position = Vector3(side * 2.5, 2.0, 0.0)
		add_child(pole)
	# Palang atas.
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(5.4, 0.4, 0.4)
	bar_mesh.material = finish_mat
	bar.mesh = bar_mesh
	bar.position = Vector3(0.0, 4.0, 0.0)
	add_child(bar)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_multiplayer_authority():
		return
	finish_entered.emit()
