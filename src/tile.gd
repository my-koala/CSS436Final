@tool
extends Node2D
class_name Tile

# NOTE: Dummy Physics Engine disables physics object picking.

const FACE_MIN: int = 0
const FACE_MAX: int = 25
const FACE_UNICODE_OFFSET: int = 65

const TEXTURE_A: Texture2D = preload("res://assets/tile.png")
const TEXTURE_B: Texture2D = preload("res://assets/temporary_tile.png")

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

@onready
var _sprite: Sprite2D = $sprite_2d as Sprite2D
@onready
var _pickable: Control = $pickable as Control
@onready
var _label_face: Label = $display/label_face as Label
@onready
var _label_points: Label = $display/label_points as Label

static var _random: RandomNumberGenerator = RandomNumberGenerator.new()

const FACE_POINTS: PackedInt32Array = [
	01, 03, 03, 02,# A B C D
	01, 05, 02, 05,# E F G H
	01, 07, 07, 02,# I J K L
	03, 03, 01, 03,# M N O P
	10, 01, 01, 01,# Q R S T
	01, 05, 05, 07,# U V W X
	05, 10,        # Y Z
]
const FACE_WEIGHTS: PackedFloat32Array = [
	2.0, 1.2, 1.2, 1.5,# A B C D
	2.0, 0.7, 1.5, 0.7,# E F G H
	2.0, 0.3, 0.3, 1.5,# I J K L
	1.2, 1.2, 2.0, 1.2,# M N O P
	0.1, 2.0, 2.0, 2.0,# Q R S T
	2.0, 0.7, 0.7, 0.3,# U V W X
	0.7, 0.1,          # Y Z
]

static func get_face_points(tile_face: int) -> int:
	return FACE_POINTS[tile_face]

static func get_face_string(tile_face: int) -> String:
	return String.chr(tile_face + FACE_UNICODE_OFFSET)

static func get_random_face() -> int:
	return _random.rand_weighted(FACE_WEIGHTS)

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
	if locked:
		if _sprite.texture != TEXTURE_A:
			_sprite.texture = TEXTURE_A
	else:
		if _sprite.texture != TEXTURE_B:
			_sprite.texture = TEXTURE_B
	_label_face.text = get_face_string(face)
	_label_points.text = str(get_face_points(face))

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if !locked:
		_pickable.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_pickable.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		_pickable.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_pickable.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
