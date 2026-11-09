# scripts/ui/result_screen.gd
# Scene UI: Layar hasil. Owner: A8. Kontrak README 5.7.
# Pemenang, tabel ranking (nickname, waktu, status), Play Again (host), Return to Lobby.
extends Control

const LOBBY_SCENE: String = "res://scenes/lobby/lobby_ui.tscn"

const STATUS_NAMES: Dictionary = {
	int(Protocol.PlayerStatus.FINISHED): "FINISHED",
	int(Protocol.PlayerStatus.ALIVE): "ALIVE",
	int(Protocol.PlayerStatus.DNF): "DNF",
	int(Protocol.PlayerStatus.DISCONNECTED): "DISCONNECTED",
}

var _winner_label: Label
var _results_table: VBoxContainer
var _btn_play_again: Button
var _is_host: bool = false


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
	vbox.add_theme_constant_override("separation", 20)
	root.add_child(vbox)

	_winner_label = UITheme.big_label(tr("RESULTS"), 72)
	_winner_label.modulate = UITheme.COLOR_ACCENT
	vbox.add_child(_winner_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_results_table = VBoxContainer.new()
	_results_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_table.add_theme_constant_override("separation", 8)
	scroll.add_child(_results_table)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	vbox.add_child(buttons)

	_btn_play_again = UITheme.accent_button(tr("PLAY_AGAIN"))
	_btn_play_again.custom_minimum_size = Vector2(280, 60)
	_btn_play_again.pressed.connect(_on_play_again)
	buttons.add_child(_btn_play_again)

	var btn_lobby := Button.new()
	btn_lobby.text = tr("RETURN_LOBBY")
	btn_lobby.custom_minimum_size = Vector2(280, 60)
	btn_lobby.pressed.connect(_on_return_lobby)
	buttons.add_child(btn_lobby)

	NetManager.match_results_received.connect(show_results)
	NetManager.returned_to_lobby.connect(_on_back_to_lobby)


## Tampilkan hasil dari rpc_match_results.
func show_results(results: Array) -> void:
	if results.is_empty():
		return
	ProfileManager.apply_match_results(results, multiplayer.get_unique_id())
	var first: Dictionary = results[0] as Dictionary
	if int(first.get("status", -1)) == int(Protocol.PlayerStatus.FINISHED):
		_winner_label.text = tr("WINNER_IS") + " " + str(first.get("nickname", "?"))
		AudioManager.play_sfx("victory")
	else:
		AudioManager.play_sfx("defeat")
	for child: Node in _results_table.get_children():
		child.queue_free()
	_results_table.add_child(_header_row())
	for r: Variant in results:
		var entry: Dictionary = r as Dictionary
		_results_table.add_child(_result_row(entry))
	_update_host_buttons()


func _header_row() -> Control:
	var row := HBoxContainer.new()
	for text: String in ["#", tr("NICKNAME"), tr("TIME"), tr("STATUS")]:
		var l := Label.new()
		l.text = text
		l.modulate = UITheme.COLOR_TEXT_DIM
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
	return row


func _result_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var cells: Array[String] = [
		str(entry.get("rank", "?")),
		str(entry.get("nickname", "?")),
		UITheme.format_time_ms(int(entry.get("time_ms", -1))),
		_status_text(int(entry.get("status", -1))),
	]
	var is_me: bool = int(entry.get("peer_id", -1)) == multiplayer.get_unique_id()
	for text: String in cells:
		var l := Label.new()
		l.text = text
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_me:
			l.modulate = UITheme.COLOR_ACCENT
		row.add_child(l)
	return row


func _status_text(status: int) -> String:
	if STATUS_NAMES.has(status):
		return str(STATUS_NAMES[status])
	return str(status)


func _update_host_buttons() -> void:
	var snap: Dictionary = NetManager.last_room_snapshot
	_is_host = int(snap.get("host_peer", -1)) == multiplayer.get_unique_id()
	_btn_play_again.visible = _is_host


func _on_play_again() -> void:
	AudioManager.play_sfx("button")
	NetManager.request_start_match()


func _on_return_lobby() -> void:
	AudioManager.play_sfx("button")
	SceneRouter.goto_scene(LOBBY_SCENE)


func _on_back_to_lobby(_snapshot: Dictionary) -> void:
	SceneRouter.goto_scene(LOBBY_SCENE)
