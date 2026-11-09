# scenes/multiplayer/multiplayer_room.tscn equivalent (dibangun di kode).
# Root scene multiplayer: menampilkan LobbyUI di CanvasLayer dan menyediakan
# entry point untuk spawn scene race nantinya (A2/A5). Owner: A6.
extends Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var lobby_scene: PackedScene = null
	if ResourceLoader.exists("res://scenes/lobby/lobby_ui.tscn"):
		lobby_scene = load("res://scenes/lobby/lobby_ui.tscn")
	if lobby_scene != null:
		var inst: Control = lobby_scene.instantiate()
		add_child(inst)
	else:
		var script: Script = load("res://scenes/lobby/lobby_ui.gd")
		var ui := Control.new()
		ui.name = "LobbyUI"
		ui.set_script(script)
		add_child(ui)
