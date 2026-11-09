# A3: Virtual jump / pause / camera-look touch buttons. Right-half touches
# are locked to the jump button; pause button consumes its own touch so it
# never reaches the joystick or the camera drag.
class_name TouchButtons
extends Control

const JUMP_WIDTH_RATIO: float = 0.22
const PAUSE_HEIGHT_RATIO: float = 0.10

var _provider: Node = null
var _jump_index: int = -1
var _jump_button: Control = null
var _pause_button: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jump_button = _make_button(Color(1, 1, 1, 0.22), "JUMP")
	add_child(_jump_button)
	_pause_button = _make_button(Color(1, 1, 1, 0.28), "II")
	add_child(_pause_button)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()


func _make_button(color: Color, text: String) -> Control:
	var btn: Button = Button.new()
	btn.text = text
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.focus_mode = Control.FOCUS_NONE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(1000)
	for state in ["normal", "hover", "pressed", "disabled"]:
		btn.add_theme_stylebox_override(state, style)
	return btn


func set_provider(provider: Node) -> void:
	_provider = provider


func _on_viewport_resized() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var safe: Rect2 = _safe_area()
	var jump_d: float = JUMP_WIDTH_RATIO * view_size.x
	_jump_button.size = Vector2.ONE * jump_d
	_jump_button.position = Vector2(
		safe.position.x + safe.size.x - jump_d * 1.35,
		safe.position.y + safe.size.y - jump_d * 1.35)
	var pause_h: float = PAUSE_HEIGHT_RATIO * view_size.y
	var pause_w: float = pause_h * 1.4
	_pause_button.size = Vector2(pause_w, pause_h)
	_pause_button.position = Vector2(
		safe.position.x + safe.size.x - pause_w - 12.0,
		safe.position.y + 12.0)


func _safe_area() -> Rect2:
	var view_size: Vector2 = get_viewport_rect().size
	var safe: Rect2 = DisplayServer.get_display_safe_area()
	if safe.size == Vector2.ZERO:
		return Rect2(Vector2.ZERO, view_size)
	var vs: Vector2 = Vector2(DisplayServer.window_get_size())
	if vs == Vector2.ZERO:
		return Rect2(Vector2.ZERO, view_size)
	var scale: Vector2 = view_size / vs
	return Rect2(safe.position * scale, safe.size * scale)


func _hit_jump(pos: Vector2) -> bool:
	var center: Vector2 = _jump_button.position + _jump_button.size * 0.5
	return pos.distance_to(center) <= _jump_button.size.x * 0.5


func _hit_pause(pos: Vector2) -> bool:
	return _pause_button.get_global_rect().has_point(pos)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _hit_pause(touch.position):
				if _provider != null:
					_provider.notify_virtual_pause()
			elif _jump_index == -1 and _hit_jump(touch.position):
				_jump_index = touch.index
				if _provider != null:
					_provider.notify_virtual_jump()
		elif touch.index == _jump_index:
			_jump_index = -1
