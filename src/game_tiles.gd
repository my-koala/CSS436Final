@tool
extends Node
class_name GameTiles


# problems with this?
# need export tile board, 

# should tile board add/remove only create/destroy/manage its own tile objects?
# in other words, add/remove only provides the

# where do i keep temporary tiles?
# on game_tiles:
# on tile_board updated, check for conflicts
# 
# need to position manually (no big deal)
# 

# TODO: this will handle tile dragging logic

# TODO: move drag logic, remove locked

const TILE_HOTBAR_COUNT: int = 7
const TILE_PACKED_SCENE: PackedScene = preload("res://assets/tile.tscn")
const TILE_SIZE: Vector2 = Vector2(128.0, 128.0)

@export
var _game_data: GameData = null

var _game_data_dirty: bool = false
@onready
var _tile_board: TileBoard = $"../tile_board" as TileBoard
var _tile_board_dirty: bool = false
@onready
var _tile_drag_layer: CanvasLayer = $"../tile_drag_layer" as CanvasLayer
@onready
var _tile_hotbar: Control = $"../gui/gui/tile_hotbar" as Control

var _player_tile_drag: Tile = null
var _player_tiles_hotbar: Array[Tile] = []
var _player_tiles_board: Dictionary[Vector2i, Tile] = {}

var _input_mouse: bool = false
var _input_mouse_event: bool = false

func encode_submission_bytes() -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(_player_tiles_board.size() * 5)
	
	var index: int = 0
	for coordinates: Vector2i in _player_tiles_board:
		bytes.encode_s16(index + 0, coordinates.x)
		bytes.encode_s16(index + 2, coordinates.y)
		bytes.encode_u8(index + 4, _player_tiles_board[coordinates].face)
		index += 5
	return bytes

func decode_submission_bytes(bytes: PackedByteArray) -> Dictionary[Vector2i, int]:
	if bytes.size() % 5 != 0:
		return {}
	
	var submission: Dictionary[Vector2i, int] = {}
	var index: int = 0
	while index < bytes.size():
		var tile_position_x: int = bytes.decode_s16(index + 0)
		var tile_position_y: int = bytes.decode_s16(index + 2)
		var tile_face: int = bytes.decode_u8(index + 4)
		submission[Vector2i(tile_position_x, tile_position_y)] = tile_face
		index += 5
	return submission

func recall_tiles() -> void:
	var tiles: Array[Tile] = _player_tiles_board.values()
	for tile: Tile in tiles:
		_move_tile_to_hotbar(tile)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_game_data.updated.connect(_on_game_data_updated)
	_tile_board.updated.connect(_on_tile_board_updated)

func _on_game_data_updated() -> void:
	_game_data_dirty = true

func _on_tile_board_updated() -> void:
	_tile_board_dirty = true

func is_dragging_tile() -> bool:
	return is_instance_valid(_player_tile_drag)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	
	if is_dragging_tile():
		get_viewport().set_input_as_handled()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if !_input_mouse:
			_input_mouse_event = true
		_input_mouse = true
	else:
		_input_mouse = false

func _get_tile_hotbar_position(index: int) -> Vector2:
	var left: Vector2 = _tile_hotbar.get_global_rect().get_center() - Vector2((TILE_SIZE.x * float(TILE_HOTBAR_COUNT) * 0.5) - (TILE_SIZE.x * 0.5), 0.0)
	var offset: float = (float(index) * TILE_SIZE.x)
	return left + Vector2(offset, 0.0)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	for index: int in _player_tiles_hotbar.size():
		var tile: Tile = _player_tiles_hotbar[index]
		tile.global_position = _get_tile_hotbar_position(index)
	
	if _game_data_dirty:
		_game_data_dirty = false
		_refresh_tiles()
	
	if _tile_board_dirty:
		_tile_board_dirty = false
		# Check for tile conflicts.
		for tile_position: Vector2i in _player_tiles_board:
			if _tile_board.has_tile_at(tile_position):
				_move_tile_to_hotbar(_player_tiles_board[tile_position])
	
	if is_dragging_tile():
		_player_tile_drag.global_position = _player_tile_drag.get_global_mouse_position()
		if !_input_mouse:
			# Stop tile drag.
			_tile_drag_stop()
	elif _input_mouse_event:
		# Check for tile hover over hotbar.
		if !is_dragging_tile():
			for tile: Tile in _player_tiles_hotbar:
				if tile.is_mouse_hovered():
					_tile_drag_start(tile)
					break
		
		# Check for tile hover over board.
		if !is_dragging_tile():
			for tile_position: Vector2i in _player_tiles_board:
				var tile: Tile = _player_tiles_board[tile_position]
				if tile.is_mouse_hovered():
					_tile_drag_start(tile)
					break
	
	_input_mouse_event = false

func _tile_drag_start(tile: Tile) -> void:
	_player_tile_drag = tile
	
	_player_tiles_hotbar.erase(_player_tile_drag)
	for coordinates: Vector2i in _player_tiles_board:
		if _player_tiles_board[coordinates] == tile:
			_player_tiles_board.erase(coordinates)
			break
	
	var tile_global_position: Vector2 = _player_tile_drag.global_position
	var parent: Node = tile.get_parent()
	if is_instance_valid(parent):
		parent.remove_child(tile)
	_tile_drag_layer.add_child(_player_tile_drag)
	#_player_tile_drag.global_position = get_viewport().get_mouse_position() * _tile_drag_layer.get_final_transform()
	_player_tile_drag.global_position = _player_tile_drag.get_global_mouse_position()
	_player_tile_drag.reset_physics_interpolation()

func _tile_drag_stop() -> void:
	var tile_position: Vector2i = _tile_board.global_to_map(_player_tile_drag.global_position)
	var tile_conflict: bool = _tile_board.has_tile_at(tile_position) || _player_tiles_board.has(tile_position)
	var hotbar_hovered: bool = _tile_hotbar.get_global_rect().has_point(_tile_hotbar.get_global_mouse_position())
	var viewport_check: bool = get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position())
	
	if tile_conflict || hotbar_hovered || !viewport_check:
		_move_tile_to_hotbar(_player_tile_drag)
	else:
		_move_tile_to_board(_player_tile_drag, tile_position)
	
	_player_tile_drag = null

func _move_tile_to_board(tile: Tile, tile_position: Vector2i) -> bool:
	var key: Variant = _player_tiles_board.find_key(tile)
	if is_instance_valid(key):
		push_error("Board already has tile!")
		return false
	
	_player_tiles_hotbar.erase(tile)
	
	var parent: Node = tile.get_parent()
	if is_instance_valid(parent):
		parent.remove_child(tile)
	_tile_board.add_child(tile)
	tile.global_position = _tile_board.map_to_global(tile_position)
	tile.reset_physics_interpolation()
	_player_tiles_board[tile_position] = tile
	return true

func _move_tile_to_hotbar(tile: Tile) -> bool:
	if _player_tiles_hotbar.has(tile):
		push_error("Hotbar already has tile!")
		return false
	
	for coordinates: Vector2i in _player_tiles_board:
		if _player_tiles_board[coordinates] == tile:
			_player_tiles_board.erase(coordinates)
			break
	
	var parent: Node = tile.get_parent()
	if is_instance_valid(parent):
		parent.remove_child(tile)
	_tile_hotbar.add_child(tile)
	tile.global_position = _get_tile_hotbar_position(_player_tiles_hotbar.size())
	tile.reset_physics_interpolation()
	_player_tiles_hotbar.append(tile)
	return true

func _refresh_tiles() -> void:
	# Refresh local player tiles.
	var player_tiles: Array[int] = _game_data.get_local_player_tiles()
	if player_tiles.is_empty():
		for tile: Tile in _player_tiles_hotbar:
			tile.queue_free()
		_player_tiles_hotbar.clear()
		
		for tile_position: Vector2i in _player_tiles_board:
			_player_tiles_board[tile_position].queue_free()
		_player_tiles_board.clear()
	else:
		# Remove missing tiles.
		var tiles_remove: Array[Tile] = []
		var tile_check: Array[int] = player_tiles.duplicate()
		
		var index: int = 0
		while index < _player_tiles_hotbar.size():
			var tile: Tile = _player_tiles_hotbar[index]
			if tile_check.has(tile.face):
				tile_check.erase(tile.face)
				index += 1
			else:
				_player_tiles_hotbar.remove_at(index)
				tile.queue_free()
		
		for tile_position: Vector2i in _player_tiles_board.keys():
			var tile: Tile = _player_tiles_board[tile_position]
			if tile_check.has(tile.face):
				tile_check.erase(tile.face)
			else:
				_player_tiles_board[tile_position].queue_free()
				_player_tiles_board.erase(tile_position)
		
		if is_instance_valid(_player_tile_drag) && !tile_check.has(_player_tile_drag.face):
			_player_tile_drag.queue_free()
			_player_tile_drag = null
		
		# Create remaining tiles.
		tile_check.clear()
		for tile: Tile in _player_tiles_hotbar:
			tile_check.append(tile.face)
		
		for tile_position: Vector2i in _player_tiles_board:
			tile_check.append(_player_tiles_board[tile_position].face)
		
		if is_instance_valid(_player_tile_drag):
			tile_check.append(_player_tile_drag.face)
		
		for player_tile: int in player_tiles:
			if tile_check.has(player_tile):
				tile_check.erase(player_tile)
			else:
				var tile: Tile = TILE_PACKED_SCENE.instantiate() as Tile
				tile.face = player_tile
				_move_tile_to_hotbar(tile)
