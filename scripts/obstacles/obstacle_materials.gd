# scripts/obstacles/obstacle_materials.gd
# Material bersama untuk semua obstacle. Owner: A4.
# Satu instance material dipakai ulang untuk ratusan mesh (hemat draw call/memory).
class_name ObstacleMaterials
extends RefCounted

const COLOR_PLATFORM: Color = Color(0.42, 0.48, 0.38)
const COLOR_PLATFORM_TOP: Color = Color(0.55, 0.62, 0.45)
const COLOR_BRIDGE: Color = Color(0.55, 0.42, 0.28)
const COLOR_MOVING: Color = Color(0.35, 0.55, 0.72)
const COLOR_HAZARD: Color = Color(0.85, 0.38, 0.25)
const COLOR_FALLING: Color = Color(0.78, 0.55, 0.30)
const COLOR_POLE_INACTIVE: Color = Color(0.65, 0.65, 0.65)
const COLOR_POLE_ACTIVE: Color = Color(0.30, 0.85, 0.35)
const COLOR_FINISH: Color = Color(0.90, 0.80, 0.15)
const COLOR_DECOR_TREE: Color = Color(0.22, 0.45, 0.25)
const COLOR_DECOR_ROCK: Color = Color(0.45, 0.45, 0.42)

static var _cache: Dictionary = {}

static func get_material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if not _cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.9
		_cache[key] = mat
	var cached: StandardMaterial3D = _cache[key]
	return cached

static func box_body(
	size: Vector3,
	local_pos: Vector3,
	material: StandardMaterial3D,
	collision_layer: int = 1
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = collision_layer
	body.collision_mask = 0
	body.position = local_pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh.mesh = box_mesh
	body.add_child(mesh)
	return body

static func box_animatable_body(
	size: Vector3,
	material: StandardMaterial3D,
	collision_layer: int = 1
) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = true
	body.collision_layer = collision_layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh.mesh = box_mesh
	body.add_child(mesh)
	return body

static func make_pole(active_color: Color) -> MeshInstance3D:
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.15
	cyl.height = 3.0
	cyl.material = ObstacleMaterials.get_material(active_color)
	pole.mesh = cyl
	pole.position = Vector3(0.0, 1.5, 0.0)
	return pole
