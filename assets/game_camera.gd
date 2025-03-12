@tool
extends Camera2D
class_name GameCamera

const ZOOM_SPEED: float = 0.1
const ZOOM_MIN: float = 0.25
const ZOOM_MAX: float = 1.0

var _input_mouse: bool = false

var _input_pan: bool = false
var _input_pan_pivot: Vector2 = Vector2.ZERO

var _input_zoom: int = 0
var _input_zoom_prev: int = 0

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
	
	var input_event_mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if is_instance_valid(input_event_mouse_button) && input_event_mouse_button.is_pressed():
		if input_event_mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_input_zoom += 1
		elif input_event_mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_input_zoom -= 1

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _input_zoom != _input_zoom_prev:
		var zoom_delta: int = _input_zoom - _input_zoom_prev
		_input_zoom = _input_zoom_prev
		
		var zoom_new: float = clampf(zoom.x + (float(zoom_delta) * ZOOM_SPEED), ZOOM_MIN, ZOOM_MAX)
		zoom = Vector2(zoom_new, zoom_new)
	
	if _input_pan:
		global_position += (_input_pan_pivot - get_viewport().get_mouse_position()) / zoom
		_input_pan_pivot = get_viewport().get_mouse_position()
