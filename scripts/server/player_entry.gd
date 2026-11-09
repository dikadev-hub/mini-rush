# scripts/server/player_entry.gd
# Entri pemain dalam room. Owner: A7.
class_name PlayerEntry
extends RefCounted

var peer_id: int = 0
var nickname: String = ""
var character_id: int = 0
var is_ready: bool = false
var status: Protocol.PlayerStatus = Protocol.PlayerStatus.ALIVE
var next_checkpoint: int = 0
var last_pos: Vector3 = MapData.SPAWN_POSITION
var last_state_ms: int = 0
var has_state: bool = false
var finish_time_ms: int = -1
var join_order: int = 0
var player_token: String = ""
var speed_violations: Array[int] = []  # timestamp ms pelanggaran kecepatan
var disconnected_at_ms: int = -1


static func from_values(p_peer_id: int, p_nickname: String, p_character_id: int,
		p_join_order: int, p_token: String) -> PlayerEntry:
	var e := PlayerEntry.new()
	e.peer_id = p_peer_id
	e.nickname = p_nickname
	e.character_id = p_character_id
	e.join_order = p_join_order
	e.player_token = p_token
	return e


func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"nickname": nickname,
		"character_id": character_id,
		"is_ready": is_ready,
		"status": int(status),
		"next_checkpoint": next_checkpoint,
		"finish_time_ms": finish_time_ms,
		"join_order": join_order,
	}


func reset_for_race() -> void:
	is_ready = false
	status = Protocol.PlayerStatus.ALIVE
	next_checkpoint = 0
	last_pos = MapData.SPAWN_POSITION
	last_state_ms = 0
	has_state = false
	finish_time_ms = -1
	speed_violations.clear()
	disconnected_at_ms = -1
