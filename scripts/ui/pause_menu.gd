# scripts/ui/pause_menu.gd
# Scene UI: Pause menu. Owner: A8. Kontrak README 5.7.
# Resume / Settings / Leave Match. Overlay semi-transparan.
extends Control

const SETTINGS_SCENE: String = "res://scenes/ui/settings_menu.tscn"

signal resume_requested()
signal leave_requested()

var _root: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	add_child(layer)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := UITheme.big_label(tr("PAUSED"), 48)
	vbox.add_child(title)

	var btn_resume := UITheme.accent_button(tr("RESUME"))
	btn_resume.custom_minimum_size = Vector2(320, 60)
	btn_resume.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		resume_requested.emit())
	vbox.add_child(btn_resume)

	var btn_settings := Button.new()
	btn_settings.text = tr("SETTINGS")
	btn_settings.custom_minimum_size = Vector2(320, 56)
	btn_settings.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		SceneRouter.goto_scene(SETTINGS_SCENE))
	vbox.add_child(btn_settings)

	var btn_leave := Button.new()
	btn_leave.text = tr("LEAVE_MATCH")
	btn_leave.custom_minimum_size = Vector2(320, 56)
	btn_leave.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		leave_requested.emit())
	vbox.add_child(btn_leave)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		resume_requested.emit()
