# scripts/obstacles/checkpoint.gd
# Checkpoint: Area3D SphereShape radius (default MapData.CHECKPOINT_RADIUS),
# mask layer 2 (player). Tiang visual berubah warna saat pemain masuk. Owner: A4.
# Sinyal `checkpoint_entered` dikonsumsi A5 (race_controller) untuk klaim checkpoint.
class_name Checkpoint
extends Area3D

signal checkpoint_entered(index: int)

@export var index: int = 0
@export var radius: float = 2.5

var _pole: MeshInstance3D
var _activated: bool = false

func _ready() -> void:
	collision_layer = 4  # layer 3 (trigger), bit ke-3
	collision_mask = 2   # mask layer 2 (player)
	monitoring = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	add_child(shape)
	_pole = ObstacleMaterials.make_pole(ObstacleMaterials.COLOR_POLE_INACTIVE)
	add_child(_pole)
	# Ring dasar sebagai penanda visual.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.75
	torus.outer_radius = radius * 0.9
	torus.material = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_POLE_INACTIVE)
	ring.mesh = torus
	ring.position = Vector3(0.0, 0.1, 0.0)
	add_child(ring)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _activated:
		return
	# Hanya pemain lokal (authority) yang memicu indikator visual.
	if not body.is_multiplayer_authority():
		return
	_activated = true
	if _pole != null:
		var cyl: CylinderMesh = _pole.mesh as CylinderMesh
		cyl.material = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_POLE_ACTIVE)
	checkpoint_entered.emit(index)

func reset_visual() -> void:
	_activated = false
	if _pole != null:
		var cyl: CylinderMesh = _pole.mesh as CylinderMesh
		cyl.material = ObstacleMaterials.get_material(ObstacleMaterials.COLOR_POLE_INACTIVE)
