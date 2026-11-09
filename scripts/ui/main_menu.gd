# scripts/ui/main_menu.gd
# Scene UI: Main Menu. Owner: A8. Kontrak README 5.7.
# Logo, Play/Settings/Profile/Leaderboard, status koneksi, preview karakter SubViewport.
extends Control

const SETTINGS_SCENE: String = "res://scenes/ui/settings_menu.tscn"
const PROFILE_SCENE: String = "res://scenes/ui/profile_screen.tscn"
const LEADERBOARD_SCENE: String = "res://scenes/ui/leaderboard_screen.tscn"
const LOBBY_SCENE: String = "res://scenes/lobby/lobby_ui.tscn"

var _status_label: Label
var _character_preview: SubViewportContainer


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MenuLayer"
	add_child(layer)

	var root := MarginContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 64)
	root.add_theme_constant_override("margin_right", 64)
	root.add_theme_constant_override("margin_top", 40)
	root.add_theme_constant_override("margin_bottom", 40)
	layer.add_child(root)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	root.add_child(columns)

	# Kolom kiri: logo + tombol + status koneksi.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 16)
	columns.add_child(left)

	var logo := UITheme.big_label("MINI RUSH", 88)
	logo.modulate = UITheme.COLOR_ACCENT
	left.add_child(logo)

	var subtitle := Label.new()
	subtitle.text = "Balapan platformer multiplayer 8 pemain"
	subtitle.modulate = UITheme.COLOR_TEXT_DIM
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(subtitle)

	left.add_child(_spacer(24))

	var btn_play := UITheme.accent_button(tr("PLAY"))
	btn_play.custom_minimum_size = Vector2(320, 64)
	btn_play.pressed.connect(_on_play)
	left.add_child(btn_play)

	left.add_child(_make_nav_button("SETTINGS", SETTINGS_SCENE))
	left.add_child(_make_nav_button("PROFILE", PROFILE_SCENE))
	left.add_child(_make_nav_button("LEADERBOARD", LEADERBOARD_SCENE))

	left.add_child(_spacer(16))
	_status_label = Label.new()
	_status_label.modulate = UITheme.COLOR_TEXT_DIM
	_status_label.text = _connection_status_text()
	left.add_child(_status_label)

	# Kolom kanan: preview karakter dalam SubViewport.
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_child(right)
	_character_preview = _build_character_preview()
	right.add_child(_character_preview)


func _process(_delta: float) -> void:
	var vp := _character_preview.get_child(0) as SubViewport if _character_preview.get_child_count() > 0 else null
	if vp != null:
		var cam: Camera3D = vp.get_camera_3d()
		if cam != null:
			cam.rotation.y += _delta * 0.8


func _build_character_preview() -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(360, 480)
	var vp := SubViewport.new()
	vp.size = Vector2(360, 480)
	vp.transparent_bg = true
	container.add_child(vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.4, 3.0)
	cam.rotation_degrees = Vector3(-8, 0, 0)
	vp.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	vp.add_child(light)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	mesh.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = UITheme.COLOR_PRIMARY
	mesh.material_override = mat
	vp.add_child(mesh)
	return container


func _make_nav_button(label_key: String, scene_path: String) -> Button:
	var b := Button.new()
	b.text = tr(label_key)
	b.custom_minimum_size = Vector2(320, 56)
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		SceneRouter.goto_scene(scene_path))
	return b


func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


func _connection_status_text() -> String:
	if NetManager.is_connected_to_server():
		return tr("STATUS_CONNECTED")
	return tr("STATUS_OFFLINE")


func _on_play() -> void:
	AudioManager.play_sfx("button")
	AudioManager.play_music("theme_loop")
	SceneRouter.goto_scene(LOBBY_SCENE)
