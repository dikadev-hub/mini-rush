# tests/integration/test_map_builder.gd
# Test runtime map builder (A4). Dijalankan: godot --headless --path . -s res://tests/integration/test_map_builder.gd
extends SceneTree

var _frames: int = 0
var _reported: bool = false

func _init() -> void:
	var builder_script: GDScript = load("res://scripts/maps/rush_island_builder.gd")
	var map: Node3D = builder_script.new()
	map.name = "RushIslandMap"
	root.add_child(map)

func _process(_delta: float) -> bool:
	# _ready() builder berjalan setelah frame pertama; tunggu 3 frame lalu evaluasi.
	_frames += 1
	if _frames >= 3 and not _reported:
		_reported = true
		_evaluate()
		quit(0)
	return false

func _evaluate() -> void:
	var failed: int = 0
	var map: Node = null
	for child: Node in root.get_children():
		if child.name == "RushIslandMap":
			map = child
	var all: Array[Node] = []
	if map != null:
		_collect(map, all)

	var static_bodies: int = 0
	var animatables: int = 0
	var checkpoints: int = 0
	var finish: int = 0
	var lights: int = 0
	var multimeshes: int = 0
	var falling: int = 0
	var sync_ok: bool = true
	for n: Node in all:
		if n is AnimatableBody3D:
			animatables += 1
			if not (n as AnimatableBody3D).sync_to_physics:
				sync_ok = false
		elif n is StaticBody3D:
			static_bodies += 1
		elif n is Area3D:
			if n is Checkpoint:
				checkpoints += 1
			elif n is FinishLine:
				finish += 1
		elif n is DirectionalLight3D:
			lights += 1
		elif n is MultiMeshInstance3D:
			multimeshes += 1
		elif n is FallingPlatform:
			falling += 1

	var checks: Array = [
		[static_bodies >= 10, "platform statis >= 10 (%d)" % static_bodies],
		[animatables == 5, "AnimatableBody3D = 5 (2 moving + 2 bar + 1 barrier) -> %d" % animatables],
		[sync_ok, "semua AnimatableBody3D sync_to_physics=true"],
		[falling == 2, "2 falling platform"],
		[checkpoints == 4, "4 checkpoint dari MapData"],
		[finish == 1, "1 garis finish"],
		[lights == 1, "tepat 1 DirectionalLight3D"],
		[multimeshes == 2, "2 MultiMeshInstance3D dekorasi"],
	]
	var cp_ok: bool = true
	for n2: Node in all:
		if n2 is Checkpoint:
			var c: Checkpoint = n2 as Checkpoint
			if c.collision_mask != 2 or c.radius != MapData.CHECKPOINT_RADIUS:
				cp_ok = false
	checks.append([cp_ok, "checkpoint mask layer 2 + radius MapData"])
	checks.append([abs(MapData.CHECKPOINT_RADIUS - 2.5) < 0.001, "MapData tidak diubah (radius 2.5)"])

	for c: Array in checks:
		if c[0]:
			print("  [OK] " + str(c[1]))
		else:
			printerr("  [FAIL] " + str(c[1]))
			failed += 1
	print("PASSED: %d  FAILED: %d" % [checks.size() - failed, failed])

func _collect(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for child: Node in node.get_children():
		_collect(child, out)
