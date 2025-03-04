@tool
extends Node2D
class_name Tile

# NOTE: Dummy Physics Engine disables physics object picking.
# TODO: gui blocks mouse inputs

signal drag_started()
signal drag_stopped()

@export
var locked: bool = false

@export
var pickable_rect: Rect2 = Rect2(-64.0, -64.0, 128.0, 128.0):
	get:
		return pickable_rect
	set(value):
		pickable_rect = value
		queue_redraw()

var _input_mouse: bool = false

var _input_drag: bool = false
var _input_drag_position: Vector2 = Vector2.ZERO

var _drag: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	
	var viewport: Viewport = get_viewport()
	var mouse_position: Vector2 = viewport.get_mouse_position() * viewport.canvas_transform
	var mouse_hovering: bool = pickable_rect.has_point(global_transform.affine_inverse() * mouse_position)
	
	_input_drag_position = mouse_position
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if !_input_mouse && mouse_hovering:
			_input_drag = true
		_input_mouse = true
	else:
		_input_drag = false
		_input_mouse = false
	
	# Consume input if hovering.
	if !mouse_hovering:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		viewport.set_input_as_handled()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if _input_drag:
		global_position = _input_drag_position
		if !_drag:
			_drag = true
			drag_started.emit()
	else:
		if _drag:
			_drag = false
			drag_stopped.emit()
	

func _draw() -> void:
	if !Engine.is_editor_hint():
		return
	
	# Draw pickable rect.
	draw_rect(pickable_rect, Color(0.0, 1.0, 1.0, 0.25), true, -1.0, false)
