# A3: Root script for touch_controls.tscn. Builds and wires the virtual
# joystick, touch buttons, camera drag, and a shared InputProvider. All
# layout logic lives in the child scripts; this scene stays minimal.
class_name TouchControls
extends CanvasLayer

var input_provider: InputProvider = null


func _ready() -> void:
	layer = 10
	input_provider = InputProvider.new()
	input_provider.name = "InputProvider"
	add_child(input_provider)

	var drag: TouchCameraDrag = TouchCameraDrag.new()
	drag.name = "TouchCameraDrag"
	drag.set_provider(input_provider)
	add_child(drag)

	var joystick: VirtualJoystick = VirtualJoystick.new()
	joystick.name = "VirtualJoystick"
	joystick.set_provider(input_provider)
	add_child(joystick)

	var buttons: TouchButtons = TouchButtons.new()
	buttons.name = "TouchButtons"
	buttons.set_provider(input_provider)
	add_child(buttons)


func attach_camera_rig(rig: CameraRig) -> void:
	rig.set_provider(input_provider)
