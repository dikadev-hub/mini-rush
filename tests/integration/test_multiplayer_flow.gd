# tests/integration/test_multiplayer_flow.gd — A9.
# Test alur multiplayer penuh (create/join/countdown/results). Membutuhkan modul
# NetManager (A6) dan RoomManager (A7). Jika class belum ada, runner melewatkan
# file ini (guard di run_tests.gd) tanpa fail.
extends RefCounted

func run(t) -> void:
	# Guard: NetManager autoload contract harus ada.
	var nm := _find_class("res://scripts/autoload/net_manager.gd")
	if nm == null:
		t.skip("NetManager (A6) belum ada — integration test ditunda ke gelombang 3")
		return
	var rm := _find_class("res://scripts/server/room_manager.gd")
	if rm == null:
		t.skip("RoomManager (A7) belum ada — integration test ditunda ke gelombang 3")
		return
	# Verifikasi kontrak RPC ada di NetManager.
	var required_rpcs: Array[String] = [
		"rpc_request_create_room", "rpc_request_join_room", "rpc_request_leave_room",
		"rpc_set_ready", "rpc_request_start_match", "rpc_room_response",
		"rpc_room_snapshot", "rpc_match_countdown", "rpc_match_started",
		"rpc_submit_state", "rpc_broadcast_states", "rpc_report_checkpoint",
		"rpc_checkpoint_ack", "rpc_report_finish", "rpc_match_results",
		"rpc_return_to_lobby", "rpc_server_health",
	]
	var source: String = FileAccess.get_file_as_string("res://scripts/autoload/net_manager.gd")
	for rpc_name in required_rpcs:
		t.check(source.contains("func " + rpc_name), "NetManager punya " + rpc_name)
	# Full flow runtime test (spawn headless peers) ditangani oleh
	# scripts/run_local_multiplayer.sh di gelombang 3.

func _find_class(path: String) -> GDScript:
	if not FileAccess.file_exists(path):
		return null
	var script: GDScript = load(path)
	return script
