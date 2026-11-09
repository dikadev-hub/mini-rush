# scripts/server/validator.gd
# Validasi semua input client di sisi server. Owner: A7. Kontrak: README 5.6.
class_name Validator
extends RefCounted

const VIOLATION_WINDOW_MS: int = 5000
const MAX_VIOLATIONS: int = 20

const NICKNAME_ALLOWED: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -"


static func check_nickname(nickname: String) -> bool:
	if nickname.length() < Protocol.NICKNAME_MIN_LEN or nickname.length() > Protocol.NICKNAME_MAX_LEN:
		return false
	for i in nickname.length():
		if not NICKNAME_ALLOWED.contains(nickname[i]):
			return false
	return true


static func check_protocol_version(version: int) -> bool:
	return version == Protocol.PROTOCOL_VERSION


static func check_position_in_bounds(pos: Vector3) -> bool:
	return pos.x >= MapData.WORLD_BOUNDS_MIN.x and pos.x <= MapData.WORLD_BOUNDS_MAX.x \
		and pos.y >= MapData.WORLD_BOUNDS_MIN.y and pos.y <= MapData.WORLD_BOUNDS_MAX.y \
		and pos.z >= MapData.WORLD_BOUNDS_MIN.z and pos.z <= MapData.WORLD_BOUNDS_MAX.z


## Kecepatan aktual antara dua posisi. delta_sec harus > 0.
static func compute_speed(from_pos: Vector3, to_pos: Vector3, delta_sec: float) -> float:
	if delta_sec <= 0.0:
		return 0.0
	return from_pos.distance_to(to_pos) / delta_sec


static func is_speed_valid(speed: float) -> bool:
	return speed <= Protocol.MAX_SPEED * Protocol.MAX_POSITION_DELTA_FACTOR


## Menambah pelanggaran kecepatan dan membersihkan yang sudah lewat window.
## Return true jika pemain harus di-kick.
static func register_speed_violation(entry: PlayerEntry, now_ms: int) -> bool:
	entry.speed_violations.append(now_ms)
	var cutoff: int = now_ms - VIOLATION_WINDOW_MS
	while entry.speed_violations.size() > 0 and entry.speed_violations[0] < cutoff:
		entry.speed_violations.remove_at(0)
	return entry.speed_violations.size() >= MAX_VIOLATIONS


## Checkpoint valid hanya jika index == next_checkpoint dan last_pos dekat posisi checkpoint.
static func check_checkpoint(entry: PlayerEntry, index: int) -> bool:
	if index != entry.next_checkpoint:
		return false
	if index < 0 or index >= MapData.CHECKPOINT_POSITIONS.size():
		return false
	var target: Vector3 = MapData.CHECKPOINT_POSITIONS[index]
	var max_dist: float = MapData.CHECKPOINT_RADIUS + Protocol.MAX_ALLOWED_TELEPORT_DIST
	return entry.last_pos.distance_to(target) <= max_dist


## Finish valid hanya jika semua checkpoint terkumpul dan posisi dekat finish.
static func check_finish(entry: PlayerEntry) -> bool:
	if entry.next_checkpoint != MapData.CHECKPOINT_POSITIONS.size():
		return false
	var max_dist: float = MapData.FINISH_RADIUS + Protocol.MAX_ALLOWED_TELEPORT_DIST
	return entry.last_pos.distance_to(MapData.FINISH_POSITION) <= max_dist


## Validasi payload state dari client. Return (ok, reason).
static func check_state_payload(state: Dictionary, sender_id: int) -> Dictionary:
	if not state.has("pid"):
		return {"ok": false, "reason": "missing pid"}
	var pid: int = int(state["pid"])
	if pid != sender_id:
		return {"ok": false, "reason": "pid mismatch"}
	if not state.has("p"):
		return {"ok": false, "reason": "missing position"}
	var pos_v: Variant = state["p"]
	if not (pos_v is Vector3):
		return {"ok": false, "reason": "position not Vector3"}
	if not check_position_in_bounds(pos_v as Vector3):
		return {"ok": false, "reason": "out of world bounds"}
	return {"ok": true, "reason": ""}
