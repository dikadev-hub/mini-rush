# scripts/ui/hud.gd
# Scene UI: HUD race. Owner: A8. Kontrak README 5.7 dan bagian 7.
# Countdown besar tengah, timer race, posisi 1-dari-N, indikator checkpoint,
# jumlah pemain, tombol pause. Semua di CanvasLayer, anchors responsif.
extends Control

signal pause_requested()

var _countdown_label: Label
var _timer_label: Label
var _position_label: Label
var _checkpoint_label: Label
var _players_label: Label
var _race_running: bool = false
var _race_start_ms: int = 0
var _total_checkpoints: int = MapData.CHECKPOINT_POSITIONS.size()
var _next_checkpoint: int = 0


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	add_child(layer)

	var root := MarginContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_bottom", 16)
	layer.add_child(root)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(top)

	# Baris atas: timer, posisi, checkpoint, pemain + tombol pause.
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 24)
	top.add_child(top_row)

	_timer_label = UITheme.big_label("0:00.000", 40)
	_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top_row.add_child(_timer_label)

	_position_label = UITheme.big_label("1/" + str(1), 40)
	top_row.add_child(_position_label)

	_checkpoint_label = UITheme.big_label("CP 0/%d" % _total_checkpoints, 40)
	top_row.add_child(_checkpoint_label)

	_players_label = UITheme.big_label(tr("PLAYERS") + " 1", 40)
	top_row.add_child(_players_label)

	var btn_pause := UITheme.accent_button("| |")
	btn_pause.custom_minimum_size = Vector2(72, 56)
	btn_pause.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		pause_requested.emit())
	top_row.add_child(btn_pause)

	# Countdown besar di tengah (di luar flow, anchor tengah).
	_countdown_label = UITheme.big_label("", 140)
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_countdown_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_countdown_label.modulate = UITheme.COLOR_ACCENT
	root.add_child(_countdown_label)

	NetManager.match_countdown_started.connect(_on_countdown_started)
	NetManager.match_started.connect(_on_match_started)
	NetManager.checkpoint_ack_received.connect(_on_checkpoint_ack)
	NetManager.match_results_received.connect(_on_match_results)


func _process(_delta: float) -> void:
	if _race_running:
		var now: int = Time.get_ticks_msec()
		_timer_label.text = UITheme.format_time_ms(maxi(now - _race_start_ms, 0))


func set_player_position(rank: int, total: int) -> void:
	_position_label.text = "%d/%d" % [rank, total]


func set_player_count(count: int) -> void:
	_players_label.text = tr("PLAYERS") + " %d" % count


func _on_countdown_started(start_server_ms: int, countdown_sec: int) -> void:
	# Countdown lokal diturunkan tiap detik via timer tick sederhana.
	_countdown_label.text = str(countdown_sec)
	AudioManager.play_sfx("countdown_tick")
	var remaining := countdown_sec
	for i: int in range(countdown_sec):
		var t := get_tree().create_timer(1.0)
		t.timeout.connect(func() -> void:
			remaining -= 1
			if remaining > 0:
				_countdown_label.text = str(remaining)
				AudioManager.play_sfx("countdown_tick"))


func _on_match_started(_race_start_server_ms: int) -> void:
	_countdown_label.text = tr("GO")
	AudioManager.play_sfx("countdown_go")
	_race_running = true
	_race_start_ms = Time.get_ticks_msec()
	var t := get_tree().create_timer(1.0)
	t.timeout.connect(func() -> void:
		_countdown_label.text = "")


func _on_checkpoint_ack(index: int, accepted: bool) -> void:
	if accepted:
		_next_checkpoint = index + 1
		AudioManager.play_sfx("checkpoint")
	_checkpoint_label.text = "CP %d/%d" % [_next_checkpoint, _total_checkpoints]


func _on_match_results(_results: Array) -> void:
	_race_running = false
