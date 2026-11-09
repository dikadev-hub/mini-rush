# A3: Touch camera-look drag. Touches starting in the right half of the
# screen (and not on a touch button) rotate the camera; each touch is
# locked to camera control for its lifetime.
class_name TouchCameraDrag
extends Control

var _provider: Node = null
var _drag_index: int = -1
var _last_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_provider(provider: Node) -> void:
	_provider = provider


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _drag_index == -1 and touch.position.x \
					> get_viewport_rect().size.x * 0.5:
				_drag_index = touch.index
				_last_position = touch.position
		elif touch.index == _drag_index:
			_drag_index = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _drag_index:
			var delta_px: Vector2 = drag.position - _last_position
			_last_position = drag.position
			if _provider != null:
				_provider.add_camera_delta(delta_px)
