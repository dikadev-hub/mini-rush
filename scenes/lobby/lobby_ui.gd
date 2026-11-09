# scenes/lobby/lobby_ui.gd
# UI Lobi Mini Rush. Owner: A6. Kontrak README 5.5.
# Root Control; seluruh node UI dibangun di kode (_ready) sesuai aturan proyek.
extends Control

const ROOM_CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const NICKNAME_MAX_LEN: int = 16

var _status_label: Label
var _nickname_input: LineEdit
var _room_code_input: LineEdit
var _ws_checkbox: CheckBox
var _player_list: ItemList
var _btn_create: Button
var _btn_join: Button
var _btn_leave: Button
var _btn_ready: Button
var _btn_start: Button
var _in_room: bool = false
var _is_host: bool = false
var _is_ready: bool = false


func _ready() -> void:
	_build_ui()
	_connect_signals()
	NetManager.connection_failed.connect(_on_connection_failed)
	NetManager.connection_succeeded.connect(_on_connected)
	NetManager.server_lost.connect(_on_server_lost)
	NetManager.room_response_received.connect(_on_room_response)
	NetManager.room_snapshot_updated.connect(_on_room_snapshot)
	NetManager.returned_to_lobby.connect(_on_return_to_lobby)
	_set_room_visible(false)


# ------------------------------------------------------------------
# Pembangunan UI
# ------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var layer := CanvasLayer.new()
	layer.name = "LobbyLayer"
	add_child(layer)

	var root := MarginContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 48)
	root.add_theme_constant_override("margin_right", 48)
	root.add_theme_constant_override("margin_top", 32)
	root.add_theme_constant_override("margin_bottom", 32)
	layer.add_child(root)

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", 32)
	root.add_child(columns)

	# Kolom kiri: koneksi dan aksi room
	var left := VBoxContainer.new()
	left.name = "LeftPanel"
	left.custom_minimum_size = Vector2(420, 0)
	left.add_theme_constant_override("separation", 12)
	columns.add_child(left)

	var title := Label.new()
	title.name = "Title"
	title.text = "Mini Rush - Lobi"
	title.add_theme_font_size_override("font_size", 40)
	left.add_child(title)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = "Status: tidak terhubung"
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_status_label)

	var nick_row := HBoxContainer.new()
	nick_row.add_theme_constant_override("separation", 8)
	left.add_child(nick_row)
	var nick_label := Label.new()
	nick_label.text = "Nickname:"
	nick_label.add_theme_font_size_override("font_size", 22)
	nick_row.add_child(nick_label)
	_nickname_input = LineEdit.new()
	_nickname_input.name = "NicknameInput"
	_nickname_input.placeholder_text = "Nama pemain"
	_nickname_input.max_length = NICKNAME_MAX_LEN
	_nickname_input.text = "Player"
	_nickname_input.custom_minimum_size = Vector2(220, 44)
	_nickname_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nick_row.add_child(_nickname_input)

	# Transport WebSocket: untuk server publik yang memblokir UDP (ENet tidak jalan).
	# Default tidak dicentang (ENet); dicentang -> connect_to_server_ws().
	_ws_checkbox = CheckBox.new()
	_ws_checkbox.name = "WsCheckbox"
	_ws_checkbox.text = "pakai websocket (untuk server publik)"
	_ws_checkbox.add_theme_font_size_override("font_size", 18)
	# Default WS: endpoint publik ws://servergame.new.tg:3450 (VPS blokir UDP).
	# Local test: --address=127.0.0.1 --port=... (dan TRANSPORT=enet untuk ENet).
	_ws_checkbox.button_pressed = GameConfig.transport == "ws"
	left.add_child(_ws_checkbox)

	_btn_create = _make_button("Buat Room", left)
	_btn_join = _make_button("Gabung Room", left)

	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	left.add_child(code_row)
	var code_label := Label.new()
	code_label.text = "Kode:"
	code_label.add_theme_font_size_override("font_size", 22)
	code_row.add_child(code_label)
	_room_code_input = LineEdit.new()
	_room_code_input.name = "RoomCodeInput"
	_room_code_input.placeholder_text = "6 karakter"
	_room_code_input.max_length = 6
	_room_code_input.custom_minimum_size = Vector2(180, 44)
	_room_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_row.add_child(_room_code_input)

	_btn_leave = _make_button("Keluar Room", left)
	_btn_ready = _make_button("Ready", left)
	_btn_start = _make_button("Mulai (Host)", left)

	# Kolom kanan: daftar pemain
	var right := VBoxContainer.new()
	right.name = "RightPanel"
	right.custom_minimum_size = Vector2(420, 0)
	right.add_theme_constant_override("separation", 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)

	var list_title := Label.new()
	list_title.text = "Pemain di room"
	list_title.add_theme_font_size_override("font_size", 28)
	right.add_child(list_title)

	_player_list = ItemList.new()
	_player_list.name = "PlayerList"
	_player_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_player_list.custom_minimum_size = Vector2(0, 300)
	right.add_child(_player_list)


func _make_button(text: String, parent: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 24)
	parent.add_child(b)
	return b


func _connect_signals() -> void:
	_nickname_input.text_changed.connect(_on_nickname_changed)
	_room_code_input.text_changed.connect(_on_room_code_changed)
	_btn_create.pressed.connect(_on_create_pressed)
	_btn_join.pressed.connect(_on_join_pressed)
	_btn_leave.pressed.connect(_on_leave_pressed)
	_btn_ready.pressed.connect(_on_ready_pressed)
	_btn_start.pressed.connect(_on_start_pressed)


# ------------------------------------------------------------------
# Filter input
# ------------------------------------------------------------------

func _on_nickname_changed(new_text: String) -> void:
	# Batasi panjang; karakter bebas, server yang memvalidasi penuh.
	if new_text.length() > NICKNAME_MAX_LEN:
		_nickname_input.text = new_text.substr(0, NICKNAME_MAX_LEN)


func _on_room_code_changed(new_text: String) -> void:
	var upper: String = new_text.to_upper()
	var filtered := ""
	for i in upper.length():
		if ROOM_CODE_ALPHABET.contains(upper[i]):
			filtered += upper[i]
	if filtered != new_text:
		_room_code_input.text = filtered
		_room_code_input.caret_column = filtered.length()


# ------------------------------------------------------------------
# Aksi tombol
# ------------------------------------------------------------------

func _get_nickname() -> String:
	var nick: String = _nickname_input.text.strip_edges()
	if nick.is_empty():
		nick = "Player"
	return nick


func _ensure_connection() -> bool:
	if NetManager.is_connected_to_server():
		return true
	var address: String = GameConfig.server_address
	var port: int = GameConfig.server_port
	_set_status("Menghubungi %s:%d ... (%s)" % [address, port, "ws" if _ws_checkbox.button_pressed else "enet"])
	if _ws_checkbox.button_pressed:
		NetManager.connect_to_server_ws(address, port)
	else:
		NetManager.connect_to_server(address, port)
	return false


func _on_create_pressed() -> void:
	if not NetManager.is_connected_to_server():
		_ensure_connection()
		_pending_action = "create"
		return
	NetManager.request_create_room(_get_nickname(), 0)
	_set_status("Membuat room ...")


func _on_join_pressed() -> void:
	var code: String = _room_code_input.text.strip_edges()
	if code.length() != GameConfig.ROOM_CODE_LENGTH:
		_set_status("Kode room harus 6 karakter.")
		return
	if not NetManager.is_connected_to_server():
		_ensure_connection()
		_pending_action = "join"
		return
	NetManager.request_join_room(code, _get_nickname(), 0)
	_set_status("Gabung room %s ..." % code)


var _pending_action: String = ""


func _on_leave_pressed() -> void:
	if _in_room:
		NetManager.request_leave_room()
	_set_room_visible(false)
	_set_status("Keluar dari room.")


func _on_ready_pressed() -> void:
	if not _in_room:
		_set_status("Belum berada di room.")
		return
	_is_ready = not _is_ready
	NetManager.set_ready(_is_ready)
	_btn_ready.text = "Batal Ready" if _is_ready else "Ready"


func _on_start_pressed() -> void:
	if not _in_room:
		return
	if not _is_host:
		_set_status("Hanya host yang bisa memulai match.")
		return
	NetManager.request_start_match()
	_set_status("Meminta mulai match ...")


# ------------------------------------------------------------------
# Sinyal NetManager
# ------------------------------------------------------------------

func _on_connection_failed(reason: String) -> void:
	_pending_action = ""
	_set_status("Gagal: " + reason)


func _on_connected() -> void:
	_set_status("Terhubung ke server.")
	if _pending_action == "create":
		_pending_action = ""
		_on_create_pressed()
	elif _pending_action == "join":
		_pending_action = ""
		_on_join_pressed()


func _on_server_lost(_reason: String) -> void:
	_pending_action = ""
	_in_room = false
	_set_room_visible(false)
	_set_status("Koneksi ke server terputus.")


func _on_room_response(error_code: int, room_snapshot: Dictionary) -> void:
	if error_code != Protocol.ErrorCode.OK:
		_set_status("Server menolak: %s (kode %d)" % [error_string_from_code(error_code), error_code])
		return
	_in_room = true
	_apply_snapshot(room_snapshot)
	_set_status("Berhasil masuk room.")


func error_string_from_code(error_code: int) -> String:
	match error_code:
		Protocol.ErrorCode.ROOM_NOT_FOUND:
			return "Room tidak ditemukan"
		Protocol.ErrorCode.ROOM_FULL:
			return "Room penuh"
		Protocol.ErrorCode.ROOM_ALREADY_STARTED:
			return "Match sudah berjalan"
		Protocol.ErrorCode.INVALID_NICKNAME:
			return "Nickname tidak valid (2-16, huruf/angka/spasi/strip)"
		Protocol.ErrorCode.SERVER_BUSY:
			return "Server sibuk"
		Protocol.ErrorCode.VERSION_MISMATCH:
			return "Versi protokol tidak cocok"
		Protocol.ErrorCode.NOT_HOST:
			return "Bukan host"
		Protocol.ErrorCode.INVALID_STATE:
			return "State tidak valid"
		_:
			return "Error tidak diketahui"


func _on_room_snapshot(room_snapshot: Dictionary) -> void:
	_apply_snapshot(room_snapshot)


func _on_return_to_lobby(room_snapshot: Dictionary) -> void:
	_in_room = true
	_apply_snapshot(room_snapshot)
	_set_status("Kembali ke lobi.")


func _apply_snapshot(room_snapshot: Dictionary) -> void:
	_set_room_visible(true)
	_player_list.clear()
	var players = room_snapshot.get("players", {})
	var my_id: int = multiplayer.get_unique_id()
	var host_peer = room_snapshot.get("host_peer", 0)
	if players is Dictionary:
		for key in players.keys():
			var entry = players[key]
			if entry is Dictionary:
				var pid: int = int(entry.get("peer_id", int(key)))
				var nick: String = str(entry.get("nickname", "?"))
				var ready_mark: String = " [READY]" if bool(entry.get("is_ready", false)) else ""
				var host_mark: String = " [HOST]" if pid == int(host_peer) else ""
				_player_list.add_item("%s (id %d)%s%s" % [nick, pid, host_mark, ready_mark])
				if pid == my_id:
					_is_host = pid == int(host_peer)
	_btn_start.visible = _is_host
	_btn_ready.disabled = false


func _set_room_visible(visible_in_room: bool) -> void:
	_in_room = visible_in_room
	_btn_leave.disabled = not visible_in_room
	_btn_ready.disabled = not visible_in_room
	_btn_start.disabled = not visible_in_room
	_btn_create.disabled = visible_in_room
	_btn_join.disabled = visible_in_room
	if not visible_in_room:
		_is_host = false
		_is_ready = false
		_btn_ready.text = "Ready"
		_player_list.clear()


func _set_status(text: String) -> void:
	_status_label.text = "Status: " + text
