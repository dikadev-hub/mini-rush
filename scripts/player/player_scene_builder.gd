# A2: Builds the player scene in code (rule 0.7: no hand-written .tscn for
# non-main scenes). Produces a CharacterBody3D with PlayerController,
# PlayerVisual, collision shape, and CameraRig placeholder hooks.
class_name PlayerSceneBuilder
extends RefCounted

const PLAYER_RADIUS: float = 0.4
const PLAYER_HEIGHT: float = 1.6


static func build(peer_id: int = 0) -> CharacterBody3D:
	var body: CharacterBody3D = CharacterBody3D.new()
	body.name = str(peer_id) if peer_id > 0 else "Player"
	body.set_script(load("res://scripts/player/player_controller.gd"))

	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = PLAYER_HEIGHT
	shape.shape = capsule
	body.add_child(shape)

	var visual_script: Script = load("res://scripts/player/player_visual.gd")
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	visual.set_script(visual_script)
	body.add_child(visual)

	body.set_meta("peer_id", peer_id)
	return body
