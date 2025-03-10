@tool
extends TileMapLayer
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

const TILE_PACKED_SCENE: PackedScene = preload("res://assets/tile.tscn")

signal updated()

signal temporary_tile_conflicted(tile: Tile)

var _tiles: Dictionary[Vector2i, Tile] = {}

func get_snap_position(coordinates: Vector2i) -> Vector2:
	return global_transform * (Vector2(coordinates * tile_set.tile_size) - position)

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
	tile.global_position = get_snap_position(coordinates)
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

#endregion

func get_tile_at(coordinates: Vector2i) -> Tile:
	return _tiles[coordinates]

func has_tile_at(coordinates: Vector2i) -> bool:
	return _tiles.has(coordinates)

func is_empty() -> bool:
	return _tiles.is_empty()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)

func _on_multiplayer_server_disconnected() -> void:
	_clear_tiles()

func _on_multiplayer_peer_connected(player_id: int) -> void:
	for coordinates: Vector2i in _tiles:
		_rpc_add_tile.rpc_id(player_id, coordinates, _tiles[coordinates].face)
