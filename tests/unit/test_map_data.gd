# tests/unit/test_map_data.gd — A9. Test konstanta kontrak map (owner A1/A4).
extends RefCounted

func run(t) -> void:
	t.check(MapData.MAP_ID == "rush_island", "MAP_ID == rush_island")
	t.check(MapData.CHECKPOINT_POSITIONS.size() == 4, "4 checkpoint")
	t.check(MapData.CHECKPOINT_RADIUS == 2.5, "CHECKPOINT_RADIUS == 2.5")
	t.check(MapData.FINISH_POSITION == Vector3(0, 9, -90), "FINISH_POSITION sesuai kontrak")
	t.check(MapData.FINISH_RADIUS == 3.0, "FINISH_RADIUS == 3.0")
	t.check(MapData.SPAWN_POSITION == Vector3(0, 1.5, 4), "SPAWN_POSITION sesuai kontrak")
	t.check(MapData.KILL_Y == -20.0, "KILL_Y == -20.0")
	t.check(MapData.CHECKPOINT_POSITIONS[0] == Vector3(0, 1, -12)
		and MapData.CHECKPOINT_POSITIONS[3] == Vector3(6, 8, -70),
		"posisi checkpoint pertama & terakhir sesuai kontrak")
	# Checkpoint berurutan mendekati finish (progress z menurun)
	var monotonic := true
	for i in range(1, MapData.CHECKPOINT_POSITIONS.size()):
		if MapData.CHECKPOINT_POSITIONS[i].z >= MapData.CHECKPOINT_POSITIONS[i - 1].z:
			monotonic = false
	t.check(monotonic, "checkpoint berurutan progres menuju finish")
	t.check(MapData.WORLD_BOUNDS_MIN.x < MapData.SPAWN_POSITION.x
		and MapData.WORLD_BOUNDS_MAX.x > MapData.SPAWN_POSITION.x
		and MapData.WORLD_BOUNDS_MAX.z > MapData.SPAWN_POSITION.z
		and MapData.WORLD_BOUNDS_MIN.z < MapData.FINISH_POSITION.z,
		"spawn & finish di dalam WORLD_BOUNDS")
