@tool
extends Node2D
class_name TileBoard

# TODO: rpcs to sync board state

# locked tiles cant be moved (tiles that are submitted)
# temporary tiles are moveable (tiles that are pending submission)

# probably game_board will track submission tiles
# though that requires getting snap positions, etc.

# if this handles tile conflicts, then signal to notify game_board?
# thats the only problem with this keeping track of both tile types (locked and submission) i think?

# ok new script
# game tiles
# this will track the tile scenes
# move the tile logic from game_board into game_tiles

enum BoardMultiplier {
	LETTER_1X,
	LETTER_2X,
	LETTER_3X,
	LETTER_4X,
	WORD_1X,
	WORD_2X,
	WORD_3X,
	WORD_4X,
}

const TILE_PACKED_SCENE: PackedScene = preload("res://assets/tile.tscn")

signal updated()

@onready
var _tile_map_layer: TileMapLayer = $parallax_2d/tile_map_layer as TileMapLayer

var _tiles: Dictionary[Vector2i, Tile] = {}

func global_to_map(global_pos: Vector2) -> Vector2i:
	return _tile_map_layer.local_to_map(to_local(global_pos - _tile_map_layer.position))

func map_to_global(coordinates: Vector2i) -> Vector2:
	return global_transform * (Vector2(coordinates * _tile_map_layer.tile_set.tile_size))

#region Tiles

func clear_tiles() -> bool:
	if multiplayer.has_multiplayer_peer():
		if is_multiplayer_authority():
			return _clear_tiles()
	return false

func _clear_tiles() -> bool:
	for coordinates: Vector2i in _tiles:
		remove_child(_tiles[coordinates])
		_tiles[coordinates].queue_free()
	_tiles.clear()
	
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_clear_tiles.rpc()
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 2)
func _rpc_clear_tiles() -> void:
	_clear_tiles()

func add_tile(coordinates: Vector2i, face: int) -> bool:
	if multiplayer.has_multiplayer_peer():
		if is_multiplayer_authority():
			return _add_tile(coordinates, face)
	return false

func _add_tile(coordinates: Vector2i, face: int) -> bool:
	if _tiles.has(coordinates):
		return false
	
	var tile: Tile = TILE_PACKED_SCENE.instantiate() as Tile
	add_child(tile)
	tile.face = face
	tile.locked = true
	tile.global_position = map_to_global(coordinates)
	tile.reset_physics_interpolation()
	
	_tiles[coordinates] = tile
	
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_add_tile.rpc(coordinates, face)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 2)
func _rpc_add_tile(coordinates: Vector2i, face: int) -> void:
	_add_tile(coordinates, face)

func remove_tile(coordinates: Vector2i) -> bool:
	if multiplayer.has_multiplayer_peer():
		if is_multiplayer_authority():
			return _remove_tile(coordinates)
	return false

func _remove_tile(coordinates: Vector2i) -> bool:
	if !_tiles.has(coordinates):
		return false
	
	var tile: Tile = _tiles[coordinates]
	remove_child(tile)
	tile.queue_free()
	
	_tiles.erase(coordinates)
	
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_remove_tile.rpc(coordinates)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 2)
func _rpc_remove_tile(coordinates: Vector2i) -> void:
	_remove_tile(coordinates)

func get_tile_at(coordinates: Vector2i) -> int:
	if _tiles.has(coordinates):
		return _tiles[coordinates].face
	return -1

func has_tile_at(coordinates: Vector2i) -> bool:
	return _tiles.has(coordinates)

func has_tile_neighor_at(coordinates: Vector2i) -> bool:
	return (_tiles.has(coordinates + Vector2i.DOWN) ||
			_tiles.has(coordinates + Vector2i.UP) ||
			_tiles.has(coordinates + Vector2i.LEFT) ||
			_tiles.has(coordinates + Vector2i.RIGHT))

#endregion

func is_empty() -> bool:
	return _tiles.is_empty()

@export
var board_repeat_size: Vector2i = Vector2i(16, 16):
	get:
		return board_repeat_size
	set(value):
		board_repeat_size = value.maxi(1)

var _board_multipliers: Array[Array] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	
	# Initialize board multiplier 2D array.
	_board_multipliers.resize(board_repeat_size.x)
	for x: int in board_repeat_size.x:
		_board_multipliers[x].resize(board_repeat_size.y)
		for y: int in board_repeat_size.y:
			var atlas_coords: Vector2i = _tile_map_layer.get_cell_atlas_coords(Vector2i(x, y))
			var atlas_id: int = atlas_coords.x + (atlas_coords.y * 4)
			match atlas_id:
				0:
					_board_multipliers[x][y] = BoardMultiplier.LETTER_1X
				1:
					_board_multipliers[x][y] = BoardMultiplier.LETTER_2X
				2:
					_board_multipliers[x][y] = BoardMultiplier.LETTER_3X
				3:
					_board_multipliers[x][y] = BoardMultiplier.LETTER_4X
				4:
					_board_multipliers[x][y] = BoardMultiplier.WORD_1X
				5:
					_board_multipliers[x][y] = BoardMultiplier.WORD_2X
				6:
					_board_multipliers[x][y] = BoardMultiplier.WORD_3X
				7:
					_board_multipliers[x][y] = BoardMultiplier.WORD_4X
				_:
					_board_multipliers[x][y] = BoardMultiplier.LETTER_1X

func get_board_letter_multiplier(tile_position: Vector2i) -> int:
	var wrapped: Vector2i = Vector2i(
		posmod(tile_position.x, _board_multipliers.size()),
		posmod(tile_position.y, _board_multipliers[0].size())
	)
	match _board_multipliers[wrapped.x][wrapped.y]:
		BoardMultiplier.LETTER_1X:
			return 1
		BoardMultiplier.LETTER_2X:
			return 2
		BoardMultiplier.LETTER_3X:
			return 3
		BoardMultiplier.LETTER_4X:
			return 4
	return 1

func get_board_word_multiplier(tile_position: Vector2i) -> int:
	var wrapped: Vector2i = Vector2i(
		posmod(tile_position.x, _board_multipliers.size()),
		posmod(tile_position.y, _board_multipliers[0].size())
	)
	match _board_multipliers[wrapped.x][wrapped.y]:
		BoardMultiplier.WORD_1X:
			return 1
		BoardMultiplier.WORD_2X:
			return 2
		BoardMultiplier.WORD_3X:
			return 3
		BoardMultiplier.WORD_4X:
			return 4
	return 1

func _on_multiplayer_server_disconnected() -> void:
	_clear_tiles()

func _on_multiplayer_peer_connected(player_id: int) -> void:
	if is_multiplayer_authority():
		for coordinates: Vector2i in _tiles:
			_rpc_add_tile.rpc_id(player_id, coordinates, _tiles[coordinates].face)
