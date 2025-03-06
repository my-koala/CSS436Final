@tool
extends Camera2D
class_name GameCamera

var _input_mouse: bool = false

var _input_pan: bool = false
var _input_pan_pivot: Vector2 = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if !_input_mouse:
			_input_mouse = true
			_input_pan = true
			_input_pan_pivot = get_viewport().get_mouse_position()
	else:
		_input_mouse = false
		_input_pan = false
		_input_pan_pivot = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if _input_pan:
		global_position += _input_pan_pivot - get_viewport().get_mouse_position()
		_input_pan_pivot = get_viewport().get_mouse_position()
