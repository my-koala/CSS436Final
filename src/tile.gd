@tool
extends Node2D
class_name Tile

# tile data: 
# 

# NOTE: Dummy Physics Engine disables physics object picking.
# TODO: draw face letter

signal drag_started()
signal drag_stopped()

@export
var face: int = 0

@export
var points: int = 1

@export
var locked: bool = false

var _input_mouse: bool = false
var _input_mouse_event: bool = false
var _input_mouse_hovering: bool = false

var _drag: bool = false

@onready
var _sprite: Sprite2D = $sprite_2d as Sprite2D
@onready
var _pickable: Control = $pickable as Control

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_pickable.mouse_entered.connect(_on_pickable_mouse_entered)
	_pickable.mouse_exited.connect(_on_pickable_mouse_exited)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	
	if _drag:
		get_viewport().set_input_as_handled()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if !_input_mouse:
			_input_mouse_event = true
		_input_mouse = true
	else:
		_input_mouse = false

func _on_pickable_mouse_entered() -> void:
	_input_mouse_hovering = true

func _on_pickable_mouse_exited() -> void:
	_input_mouse_hovering = false

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if locked || _drag:
		global_position = get_global_mouse_position()
		if !_input_mouse:
			_drag = false
			drag_stopped.emit()
	else:
		if !locked && (_input_mouse_event && _input_mouse_hovering):
			_drag = true
			drag_started.emit()
	
	_input_mouse_event = false
