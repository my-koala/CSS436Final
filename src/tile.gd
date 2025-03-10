@tool
extends Node2D
class_name Tile

# NOTE: Dummy Physics Engine disables physics object picking.

const FACE_MIN: int = 0
const FACE_MAX: int = 25
const FACE_UNICODE_OFFSET: int = 65

@export_range(FACE_MIN, FACE_MAX, 1)
var face: int = 0:
	get:
		return face
	set(value):
		face = clampi(value, FACE_MIN, FACE_MAX)

var _input_mouse_hovering: bool = false

@export
var locked: bool = false:
	get:
		return locked
	set(value):
		locked = value

@export
var locked_modulate: Color = Color(0.7, 0.7, 0.85, 1.0)

@onready
var _sprite: Sprite2D = $sprite_2d as Sprite2D
@onready
var _pickable: Control = $pickable as Control
@onready
var _label_face: Label = $display/label_face as Label
@onready
var _label_points: Label = $display/label_points as Label

# TODO: probably a big match statement
func get_face_points() -> int:
	return 1

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_pickable.mouse_entered.connect(_on_pickable_mouse_entered)
	_pickable.mouse_exited.connect(_on_pickable_mouse_exited)

func _on_pickable_mouse_entered() -> void:
	_input_mouse_hovering = true

func _on_pickable_mouse_exited() -> void:
	_input_mouse_hovering = false

func is_mouse_hovered() -> bool:
	return _input_mouse_hovering

func _process(delta: float) -> void:
	if !locked:
		modulate = Color.WHITE
	else:
		modulate = locked_modulate
	_label_face.text = String.chr(face + FACE_UNICODE_OFFSET)
	_label_points.text = str(get_face_points())

func _physics_process(delta: float) -> void:
	if !locked:
		_pickable.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_pickable.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		_pickable.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_pickable.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
