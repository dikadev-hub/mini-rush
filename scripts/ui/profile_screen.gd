# scripts/ui/profile_screen.gd
# Scene UI: Profil guest. Owner: A8. Kontrak README 5.7.
# Player ID, edit nickname, karakter, statistik (match/menang/waktu terbaik).
extends Control

const MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const NICKNAME_MAX_LEN: int = Protocol.NICKNAME_MAX_LEN

var _stats_labels: Dictionary = {}


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := CenterContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	root.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	vbox.add_child(UITheme.big_label(tr("PROFILE"), 48))

	var id_label := Label.new()
	id_label.text = "ID: " + ProfileManager.player_id
	id_label.modulate = UITheme.COLOR_TEXT_DIM
	vbox.add_child(id_label)

	# Edit nickname.
	var nick_row := HBoxContainer.new()
	nick_row.add_theme_constant_override("separation", 12)
	var nick_label := Label.new()
	nick_label.text = tr("NICKNAME")
	nick_label.custom_minimum_size = Vector2(200, 0)
	nick_row.add_child(nick_label)
	var nick_input := LineEdit.new()
	nick_input.text = ProfileManager.nickname
	nick_input.max_length = NICKNAME_MAX_LEN
	nick_input.custom_minimum_size = Vector2(280, 48)
	nick_input.text_submitted.connect(func(text: String) -> void:
		ProfileManager.set_nickname(text))
	nick_row.add_child(nick_input)
	vbox.add_child(nick_row)

	# Pilih karakter.
	var char_row := HBoxContainer.new()
	char_row.add_theme_constant_override("separation", 12)
	var char_label := Label.new()
	char_label.text = tr("CHARACTER")
	char_label.custom_minimum_size = Vector2(200, 0)
	char_row.add_child(char_label)
	var char_dd := OptionButton.new()
	for i: int in range(4):
		char_dd.add_item("Character %d" % (i + 1))
	char_dd.selected = ProfileManager.character_id
	char_dd.item_selected.connect(func(idx: int) -> void:
		ProfileManager.set_character_id(idx))
	char_row.add_child(char_dd)
	vbox.add_child(char_row)

	vbox.add_child(_stats_row(tr("TOTAL_MATCHES"), "total_matches"))
	vbox.add_child(_stats_row(tr("TOTAL_WINS"), "total_wins"))
	vbox.add_child(_stats_row(tr("BEST_TIME"), "best_time_ms"))

	var btn_back := UITheme.accent_button(tr("BACK"))
	btn_back.custom_minimum_size = Vector2(280, 56)
	btn_back.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		SceneRouter.goto_scene(MENU_SCENE))
	vbox.add_child(btn_back)

	ProfileManager.profile_updated.connect(_refresh_stats)
	_refresh_stats()


func _stats_row(label_text: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	var v := Label.new()
	v.name = key
	v.text = "-"
	row.add_child(v)
	_stats_labels[key] = v
	return row


func _refresh_stats() -> void:
	var m: Label = _stats_labels.get("total_matches")
	if m != null:
		m.text = str(ProfileManager.total_matches)
	var w: Label = _stats_labels.get("total_wins")
	if w != null:
		w.text = str(ProfileManager.total_wins)
	var b: Label = _stats_labels.get("best_time_ms")
	if b != null:
		b.text = UITheme.format_time_ms(ProfileManager.best_time_ms)
