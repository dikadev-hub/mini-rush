# A2: Player visual builder + animation handling.
# Builds a placeholder capsule mesh with flat colors (real .glb assets to follow,
# see docs/reports/a2_player.md). Plays animations via AnimationPlayer when the
# model provides them; otherwise falls back to a scale-bounce tween on land.
class_name PlayerVisual
extends Node3D

const CAPSULE_HEIGHT: float = 1.6
const CAPSULE_RADIUS: float = 0.4
const PLACEHOLDER_COLOR: Color = Color(0.25, 0.55, 0.95)
const INVULN_COLOR: Color = Color(0.95, 0.95, 0.3, 0.6)
const BOUNCE_SCALE: Vector3 = Vector3(1.15, 0.85, 1.15)
const BOUNCE_TIME: float = 0.15
const REST_SCALE: Vector3 = Vector3.ONE

var _mesh_instance: MeshInstance3D = null
var _anim_player: AnimationPlayer = null
var _bounce_tween: Tween = null
var _material: StandardMaterial3D = null


func _ready() -> void:
	_build_placeholder()
	_find_animation_player()


func _build_placeholder() -> void:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = CAPSULE_RADIUS
	mesh.height = CAPSULE_HEIGHT
	_material = StandardMaterial3D.new()
	_material.albedo_color = PLACEHOLDER_COLOR
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "BodyMesh"
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = _material
	_mesh_instance.position = Vector3(0.0, CAPSULE_HEIGHT * 0.5, 0.0)
	add_child(_mesh_instance)


func _find_animation_player() -> void:
	_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player == null:
		for child in get_children():
			if child is AnimationPlayer:
				_anim_player = child
				break


func has_animation(anim_name: StringName) -> bool:
	return _anim_player != null and _anim_player.has_animation(anim_name)


func play_animation(anim_name: StringName) -> void:
	if has_animation(anim_name):
		_anim_player.play(anim_name)
		return
	if anim_name == &"land":
		_play_bounce()


func _play_bounce() -> void:
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()
	scale = BOUNCE_SCALE
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(self, "scale", REST_SCALE, BOUNCE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_invulnerable(active: bool) -> void:
	if _material == null:
		return
	_material.albedo_color = INVULN_COLOR if active else PLACEHOLDER_COLOR
