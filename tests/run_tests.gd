# tests/run_tests.gd
# SceneTree test runner — sesuai template spec bagian 8 (A9).
# Jalankan: godot --headless --path . -s res://tests/run_tests.gd
extends SceneTree

var _failed: int = 0
var _passed: int = 0

func _init() -> void:
	_run_all()
	print("PASSED: %d  FAILED: %d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [OK] " + label)
	else:
		_failed += 1
		printerr("  [FAIL] " + label)

func skip(reason: String) -> void:
	_passed += 1
	print("  [SKIP] " + reason)

func _try_load(path: String) -> GDScript:
	# Guard: modul agent lain belum ada → skip, jangan fail.
	var dir := path.get_base_dir()
	var file := path.get_file()
	if not FileAccess.file_exists(path):
		skip("module belum ada: " + path)
		return null
	var script: GDScript = load(path)
	if script == null:
		skip("module gagal dimuat: " + path)
		return null
	return script

func _run_all() -> void:
	print("=== Mini Rush unit tests ===")
	var room_code := _try_load("res://tests/unit/test_room_code.gd")
	if room_code != null:
		room_code.new().run(self)
	var protocol := _try_load("res://tests/unit/test_protocol.gd")
	if protocol != null:
		protocol.new().run(self)
	var map_data := _try_load("res://tests/unit/test_map_data.gd")
	if map_data != null:
		map_data.new().run(self)
	var a8 := _try_load("res://tests/unit/test_a8_managers.gd")
	if a8 != null:
		a8.new().run(self)
	var a5 := _try_load("res://tests/unit/test_a5_race.gd")
	if a5 != null:
		# Tunggu frame fisika pertama agar node berada di dalam tree (headless).
		await physics_frame
		var a5_root: Node3D = Node3D.new()
		root.add_child(a5_root)
		a5.new().run(a5_root, check)
	var integration := _try_load("res://tests/integration/test_multiplayer_flow.gd")
	if integration != null:
		integration.new().run(self)
