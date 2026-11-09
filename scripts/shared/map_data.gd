# scripts/shared/map_data.gd
# Kontrak data map. Owner: A1. Server & client memakai nilai yang sama.
class_name MapData
extends RefCounted

const MAP_ID: String = "rush_island"
const CHECKPOINT_POSITIONS: Array[Vector3] = [
	Vector3(0, 1, -12),
	Vector3(0, 4, -32),
	Vector3(-6, 6, -52),
	Vector3(6, 8, -70),
]
const CHECKPOINT_RADIUS: float = 2.5
const FINISH_POSITION: Vector3 = Vector3(0, 9, -90)
const FINISH_RADIUS: float = 3.0
const SPAWN_POSITION: Vector3 = Vector3(0, 1.5, 4)
const WORLD_BOUNDS_MIN: Vector3 = Vector3(-60, -30, -100)
const WORLD_BOUNDS_MAX: Vector3 = Vector3(60, 60, 20)
const KILL_Y: float = -20.0
const SPAWN_OFFSET_STEP: Vector3 = Vector3(1.2, 0, 0)  # pemain tidak bertumpuk saat spawn
