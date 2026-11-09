# scripts/main/main.gd — Entry point. Routing gelombang 3:
# server -> ServerMain (autoload) menangani sendiri; client -> menu,
# atau mode --auto-test (test multiplayer lokal, gelombang 3).
extends Node

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--auto-test"):
			var tester: Node = load("res://scripts/gameplay/auto_test.gd").new()
			tester.name = "AutoTest"
			add_child(tester)
			return
	SceneRouter.goto_scene("res://scenes/ui/main_menu.tscn")
