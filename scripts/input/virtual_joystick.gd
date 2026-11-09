# A3: Multi-touch virtual joystick. Touches starting in the left half of the
# screen are locked to the joystick; reports a Vector2 to InputProvider.
class_name VirtualJoystick
extends Control

const BASE_WIDTH_RATIO: float = 0.18
const BASE_MIN_PX: float = 120.0
const KNOB_RATIO: float = 0.4
## Extra guard so controls never fall off-screen on tiny viewports.
const MARGIN_MIN_PX: float = 8.0
const MARGIN_RATIO: float = 0.06

var _provider: Node = null
var _touch_index: int = -1
var _base_center: Vector2 = Vector2.ZERO
var _base_radius: float = 60.0
var _base_node: Control = null
var _knob_node: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.18)
	style.set_corner_radius_all(1000)
	var knob_style: StyleBoxFlat = StyleBoxFlat.new()
	knob_style.bg_color = Color(1, 1, 1, 0.45)
	knob_style.set_corner_radius_all(1000)

	_base_node = Control.new()
	_base_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_panel: Panel = Panel.new()
	base_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_panel.add_theme_stylebox_override("panel", style)
	_base_node.add_child(base_panel)
	add_child(_base_node)

	_knob_node = Control.new()
	_knob_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_panel: Panel = Panel.new()
	knob_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob_panel.add_theme_stylebox_override("panel", knob_style)
	_knob_node.add_child(knob_panel)
	add_child(_knob_node)

	_layout_for_size(get_viewport_rect().size)
	get_viewport().size_changed.connect(_on_viewport_resized)
	set_process(false)


func set_provider(provider: Node) -> void:
	_provider = provider


func _on_viewport_resized() -> void:
	_layout_for_size(get_viewport_rect().size)


func _layout_for_size(view_size: Vector2) -> void:
	_base_radius = maxf(BASE_WIDTH_RATIO * view_size.x * 0.5, BASE_MIN_PX * 0.5)
	var safe: Rect2 = _safe_area()
	var margin: float = maxf(
		MARGIN_MIN_PX, MARGIN_RATIO * minf(safe.size.x, safe.size.y))
	_base_center = Vector2(
		safe.position.x + margin + _base_radius,
		safe.position.y + safe.size.y - margin - _base_radius)
	var base_size: Vector2 = Vector2.ONE * _base_radius * 2.0
	_base_node.position = _base_center - base_size * 0.5
	_base_node.size = base_size
	var panel: Panel = _base_node.get_child(0) as Panel
	if panel != null:
		panel.size = base_size
	var knob_size: Vector2 = base_size * KNOB_RATIO
	_knob_node.size = knob_size
	var knob_panel: Panel = _knob_node.get_child(0) as Panel
	if knob_panel != null:
		knob_panel.size = knob_size
	_knob_node.position = _base_center - knob_size * 0.5


func _safe_area() -> Rect2:
	var window_rect: Rect2 = Rect2(Vector2.ZERO, get_viewport_rect().size)
	var safe: Rect2 = DisplayServer.get_display_safe_area()
	if safe.size == Vector2.ZERO:
		return window_rect
	# Map safe area (window pixels) into viewport coordinates.
	var vs: Vector2 = Vector2(DisplayServer.window_get_size())
	if vs == Vector2.ZERO:
		return window_rect
	var scale: Vector2 = get_viewport_rect().size / vs
	return Rect2(safe.position * scale, safe.size * scale)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1 and _accepts_start(touch.position):
				_touch_index = touch.index
				_update_knob(touch.position)
		elif touch.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_knob(drag.position)


func _accepts_start(pos: Vector2) -> bool:
	var view_size: Vector2 = get_viewport_rect().size
	var in_left_half: bool = pos.x < view_size.x * 0.5
	var within_reach: bool = pos.distance_to(_base_center) <= _base_radius * 3.0
	return in_left_half and within_reach


func _update_knob(pos: Vector2) -> void:
	var offset: Vector2 = pos - _base_center
	if offset.length() > _base_radius:
		offset = offset.normalized() * _base_radius
	_knob_node.position = _base_center + offset \
		- _knob_node.size * 0.5
	if _provider != null:
		_provider.set_virtual_move(offset / _base_radius)


func _release() -> void:
	_touch_index = -1
	_knob_node.position = _base_center - _knob_node.size * 0.5
	if _provider != null:
		_provider.set_virtual_move(Vector2.ZERO)
