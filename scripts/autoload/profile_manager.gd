# scripts/autoload/profile_manager.gd
# Autoload: ProfileManager (client). Owner: A8. Kontrak README 5.7.
# Statistik HANYA dari rpc_match_results (bukan dihitung client).
extends Node

signal profile_updated()

const PROFILE_PATH: String = "user://profile.cfg"
const LEADERBOARD_PATH: String = "user://leaderboard.cfg"
const DEFAULT_NICKNAME: String = "Player"

var player_id: String = ""
var nickname: String = DEFAULT_NICKNAME
var character_id: int = 0
var player_token: String = ""
var total_matches: int = 0
var total_wins: int = 0
var best_time_ms: int = -1
var local_leaderboard: Array[Dictionary] = []


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(PROFILE_PATH)
	if err == OK:
		player_id = str(cfg.get_value("identity", "player_id", ""))
		nickname = str(cfg.get_value("identity", "nickname", DEFAULT_NICKNAME))
		character_id = int(cfg.get_value("identity", "character_id", 0))
		player_token = str(cfg.get_value("identity", "player_token", ""))
		total_matches = int(cfg.get_value("stats", "total_matches", 0))
		total_wins = int(cfg.get_value("stats", "total_wins", 0))
		best_time_ms = int(cfg.get_value("stats", "best_time_ms", -1))
	else:
		player_id = _generate_uuid_v4()
		player_token = _generate_uuid_v4()
		save_profile()
	if nickname.length() < Protocol.NICKNAME_MIN_LEN:
		nickname = DEFAULT_NICKNAME
	_load_leaderboard()


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("identity", "player_id", player_id)
	cfg.set_value("identity", "nickname", nickname)
	cfg.set_value("identity", "character_id", character_id)
	cfg.set_value("identity", "player_token", player_token)
	cfg.set_value("stats", "total_matches", total_matches)
	cfg.set_value("stats", "total_wins", total_wins)
	cfg.set_value("stats", "best_time_ms", best_time_ms)
	cfg.save(PROFILE_PATH)


func set_nickname(value: String) -> void:
	var v := value.strip_edges()
	if v.length() < Protocol.NICKNAME_MIN_LEN:
		return
	nickname = v.substr(0, Protocol.NICKNAME_MAX_LEN)
	save_profile()
	profile_updated.emit()


func set_character_id(value: int) -> void:
	character_id = clampi(value, 0, 3)
	save_profile()
	profile_updated.emit()


## Satu-satunya sumber update statistik: hasil resmi dari server.
func apply_match_results(results: Array, my_peer_id: int) -> void:
	total_matches += 1
	var my_best_new: bool = false
	for r: Variant in results:
		var entry: Dictionary = r as Dictionary
		var peer: int = int(entry.get("peer_id", -1))
		var time_ms: int = int(entry.get("time_ms", -1))
		var status: int = int(entry.get("status", int(Protocol.PlayerStatus.DNF)))
		if peer == my_peer_id and status == int(Protocol.PlayerStatus.FINISHED) and time_ms >= 0:
			if best_time_ms < 0 or time_ms < best_time_ms:
				best_time_ms = time_ms
				my_best_new = true
		_add_leaderboard_entry(str(entry.get("nickname", "?")), time_ms, status)
	save_profile()
	_save_leaderboard()
	profile_updated.emit()


func _add_leaderboard_entry(nick: String, time_ms: int, status: int) -> void:
	local_leaderboard.append({
		"nickname": nick,
		"time_ms": time_ms,
		"status": status,
		"at_ms": int(Time.get_unix_time_from_system() * 1000.0),
	})
	while local_leaderboard.size() > 50:
		local_leaderboard.pop_front()


func get_sorted_leaderboard() -> Array[Dictionary]:
	var finished: Array[Dictionary] = []
	var others: Array[Dictionary] = []
	for e: Dictionary in local_leaderboard:
		if int(e.get("status", 0)) == int(Protocol.PlayerStatus.FINISHED):
			finished.append(e)
		else:
			others.append(e)
	finished.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("time_ms", -1)) < int(b.get("time_ms", -1)))
	var out: Array[Dictionary] = []
	out.append_array(finished)
	out.append_array(others)
	return out


func _load_leaderboard() -> void:
	local_leaderboard.clear()
	var cfg := ConfigFile.new()
	var err := cfg.load(LEADERBOARD_PATH)
	if err != OK:
		return
	var raw: Variant = cfg.get_value("entries", "list", [])
	if raw is Array:
		for e: Variant in (raw as Array):
			if e is Dictionary:
				local_leaderboard.append(e as Dictionary)


func _save_leaderboard() -> void:
	var cfg := ConfigFile.new()
	var raw: Array = []
	for e: Dictionary in local_leaderboard:
		raw.append(e)
	cfg.set_value("entries", "list", raw)
	cfg.save(LEADERBOARD_PATH)


func _generate_uuid_v4() -> String:
	var bytes: Array[int] = []
	for i: int in range(16):
		bytes.append(randi() % 256)
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var hex: String = ""
	for b: int in bytes:
		hex += "%02x" % b
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
