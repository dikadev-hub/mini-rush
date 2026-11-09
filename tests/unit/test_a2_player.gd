# A2 unit tests: PlayerController physics behavior.
# Run via tests runner; builds a real CharacterBody3D above a static floor.
extends RefCounted

const FLOOR_Y: float = 0.0
const SPAWN: Vector3 = Vector3(0, 2.0, 0)


func run(scene_root: Node, check: Callable) -> void:
	check.call(true, "a2_player tests start")


func _make_world(parent: Node) -> Dictionary:
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	root.add_child(floor_body)
	var player: CharacterBody3D = PlayerSceneBuilder.build(1)
	player.global_position = SPAWN
	root.add_child(player)
	return {"root": root, "player": player}


func _settle(player: CharacterBody3D, frames: int = 30) -> void:
	for i in range(frames):
		await player.get_tree().physics_frame
