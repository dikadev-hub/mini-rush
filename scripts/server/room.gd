# scripts/server/room.gd
# Struktur data room. Owner: A7.
class_name Room
extends RefCounted

var code: String = ""
var state: Protocol.RoomState = Protocol.RoomState.LOBBY
var host_peer: int = 0
var players: Dictionary = {}  # peer_id -> PlayerEntry
var created_at_ms: int = 0
var empty_since_ms: int = -1
var race_start_server_ms: int = 0
var countdown_start_server_ms: int = 0
var next_join_order: int = 0


static func create(p_code: String, host: PlayerEntry, now_ms: int) -> Room:
	var r := Room.new()
	r.code = p_code
	r.created_at_ms = now_ms
	r.empty_since_ms = -1
	r.host_peer = host.peer_id
	r.players[host.peer_id] = host
	host.join_order = r.next_join_order
	r.next_join_order += 1
	return r


func player_count() -> int:
	return players.size()


func is_empty() -> bool:
	return players.is_empty()


func active_count() -> int:
	var n: int = 0
	for pid: int in players:
		var e: PlayerEntry = players[pid]
		if e.status != Protocol.PlayerStatus.DISCONNECTED:
			n += 1
	return n


func all_finished_or_dnf() -> bool:
	for pid: int in players:
		var e: PlayerEntry = players[pid]
		if e.status == Protocol.PlayerStatus.ALIVE or e.status == Protocol.PlayerStatus.DISCONNECTED:
			# DISCONNECTED belum dijadikan DNF sampai timeout match (diputuskan RoomManager).
			if e.status == Protocol.PlayerStatus.ALIVE:
				return false
	return true


func oldest_active_peer() -> int:
	var best_peer: int = 0
	var best_order: int = 2147483647
	for pid: int in players:
		var e: PlayerEntry = players[pid]
		if e.join_order < best_order:
			best_order = e.join_order
			best_peer = pid
	return best_peer


func snapshot() -> Dictionary:
	var list: Array = []
	for pid: int in players:
		list.append((players[pid] as PlayerEntry).to_dict())
	return {
		"room_code": code,
		"state": int(state),
		"host_peer": host_peer,
		"players": list,
	}
