# scripts/ui/settings_menu.gd
# Scene UI: Settings. Owner: A8. Kontrak README 5.7.
# Slider music/sfx/sensitivitas kamera+kontrol, dropdown kualitas,
# toggle FPS 30/60, dropdown bahasa id/en. Perubahan langsung ke SettingsManager.
extends Control

const MENU_RETURN_PATH: String = "res://scenes/ui/main_menu.tscn"
const QUALITY_NAMES: Array[String] = ["Low", "Medium", "High"]

var _return_path: String = MENU_RETURN_PATH


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := CenterContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	root.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	vbox.add_child(UITheme.big_label(tr("SETTINGS"), 48))

	_add_slider(vbox, tr("MUSIC_VOLUME"), SettingsManager.music_volume,
		func(v: float) -> void: SettingsManager.set_music_volume(v))
	_add_slider(vbox, tr("SFX_VOLUME"), SettingsManager.sfx_volume,
		func(v: float) -> void: SettingsManager.set_sfx_volume(v))
	_add_slider(vbox, tr("CAMERA_SENSITIVITY"), SettingsManager.camera_sensitivity,
		func(v: float) -> void: SettingsManager.set_camera_sensitivity(v))
	_add_slider(vbox, tr("CONTROLS_SENSITIVITY"), SettingsManager.controls_sensitivity,
		func(v: float) -> void: SettingsManager.set_controls_sensitivity(v))

	_add_option_row(vbox, tr("GRAPHICS_QUALITY"), QUALITY_NAMES,
		SettingsManager.graphics_quality,
		func(idx: int) -> void: SettingsManager.set_graphics_quality(idx))
	_add_option_row(vbox, tr("FPS_LIMIT"), ["30", "60"],
		0 if SettingsManager.fps_limit <= 30 else 1,
		func(idx: int) -> void: SettingsManager.set_fps_limit(30 if idx == 0 else 60))
	_add_option_row(vbox, tr("LANGUAGE"), ["id", "en"],
		0 if SettingsManager.locale == "id" else 1,
		func(idx: int) -> void: SettingsManager.set_locale("id" if idx == 0 else "en"))

	var btn_back := UITheme.accent_button(tr("BACK"))
	btn_back.custom_minimum_size = Vector2(280, 56)
	btn_back.pressed.connect(func() -> void:
		SettingsManager.save_settings()
		AudioManager.play_sfx("button")
		SceneRouter.goto_scene(_return_path))
	vbox.add_child(btn_back)


func _add_slider(parent: Control, label_text: String, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(320, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.1
	s.max_value = 3.0 if label_text.begins_with("Sens") or label_text.begins_with(tr("CAMERA_SENSITIVITY").substr(0, 4)) else 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(280, 32)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float) -> void: setter.call(v))
	row.add_child(s)
	parent.add_child(row)


func _add_option_row(parent: Control, label_text: String, options: Array[String], selected: int, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(320, 0)
	row.add_child(l)
	var dd := OptionButton.new()
	for opt: String in options:
		dd.add_item(opt)
	dd.selected = selected
	dd.item_selected.connect(func(idx: int) -> void: setter.call(idx))
	row.add_child(dd)
	parent.add_child(row)


func set_return_path(path: String) -> void:
	_return_path = path
