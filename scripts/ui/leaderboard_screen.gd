# scripts/ui/leaderboard_screen.gd
# Scene UI: Leaderboard lokal. Owner: A8. Kontrak README 5.7.
# Data dari file lokal (ProfileManager.local_leaderboard), label "Lokal".
extends Control

const MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 64)
	root.add_theme_constant_override("margin_right", 64)
	root.add_theme_constant_override("margin_top", 40)
	root.add_theme_constant_override("margin_bottom", 40)
	layer.add_child(root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	root.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	title_row.add_child(UITheme.big_label(tr("LEADERBOARD"), 48))
	var tag := Label.new()
	tag.text = "(" + tr("LOCAL") + ")"
	tag.modulate = UITheme.COLOR_TEXT_DIM
	vbox.add_child(title_row)
	title_row.add_child(tag)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var entries: Array[Dictionary] = ProfileManager.get_sorted_leaderboard()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = tr("NO_ENTRIES")
		empty.modulate = UITheme.COLOR_TEXT_DIM
		list.add_child(empty)
	for i: int in range(mini(entries.size(), 50)):
		var e: Dictionary = entries[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var rank := Label.new()
		rank.text = "%d." % (i + 1)
		rank.custom_minimum_size = Vector2(60, 0)
		row.add_child(rank)
		var nick := Label.new()
		nick.text = str(e.get("nickname", "?"))
		nick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nick)
		var time_l := Label.new()
		time_l.text = UITheme.format_time_ms(int(e.get("time_ms", -1)))
		time_l.custom_minimum_size = Vector2(160, 0)
		row.add_child(time_l)
		list.add_child(row)

	var btn_back := UITheme.accent_button(tr("BACK"))
	btn_back.custom_minimum_size = Vector2(280, 56)
	btn_back.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		SceneRouter.goto_scene(MENU_SCENE))
	vbox.add_child(btn_back)
