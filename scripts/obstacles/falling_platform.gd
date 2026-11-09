# scripts/obstacles/falling_platform.gd
# Platform jatuh: platform statis yang setelah diinjak pemain menunggu fall_delay
# detik, jatuh (gradasi / langsung), lalu respawn di posisi awal setelah
# respawn_delay detik. Owner: A4.
class_name FallingPlatform
extends Node3D

@export var size: Vector3 = Vector3(3.0, 0.6, 3.0)
@export var fall_delay: float = 0.8
@export var respawn_delay: float = 3.0
@export var fall_speed: float = 8.0

var _body: StaticBody3D
var _origin: Vector3 = Vector3.ZERO
var _triggered: bool = false
var _falling: bool = false
var _timer: float = 0.0

func _ready() -> void:
	_origin = position
	_body = ObstacleMaterials.box_body(size, Vector3.ZERO, ObstacleMaterials.get_material(ObstacleMaterials.COLOR_FALLING))
	add_child(_body)

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if _triggered and not _falling:
		_timer -= delta
		if _timer <= 0.0:
			_falling = true
			_timer = respawn_delay
			# Matikan kolisi saat jatuh.
			for child: Node in _body.get_children():
				if child is CollisionShape3D:
					(child as CollisionShape3D).disabled = true
	elif _falling:
		position.y -= fall_speed * delta
		_timer -= delta
		if _timer <= 0.0:
			_reset()

func _reset() -> void:
	position = _origin
	_triggered = false
	_falling = false
	for child: Node in _body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = false

# Dipanggil Area3D pendeteksi injakan (dibangun oleh builder).
func _on_body_entered(_body_in: Node3D) -> void:
	if not _triggered and not _falling:
		_triggered = true
		_timer = fall_delay
