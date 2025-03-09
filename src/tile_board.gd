@tool
extends TileMapLayer
class_name TileBoard

# TODO: rpcs to sync board state

var _tiles: Dictionary[Vector2i, Tile] = {}

func add_tile(tile: Tile, coordinates: Vector2i) -> bool:
	if _tiles.has(coordinates):
		return false
	
	if is_instance_valid(tile.get_parent()):
		return false
	
	add_child(tile)
	_tiles[coordinates] = tile
	
	var snap_position: Vector2 = global_transform * (Vector2(coordinates * tile_set.tile_size) - position)
	tile.global_position = snap_position
	tile.reset_physics_interpolation()
	return true

func remove_tile(tile: Tile) -> bool:
	return _tiles.erase(_tiles.find_key(tile))

func remove_tile_at(coordinates: Vector2i) -> bool:
	if !_tiles.has(coordinates):
		return false
	_tiles.erase(coordinates)
	return true

func has_tile_at(coordinates: Vector2i) -> bool:
	return _tiles.has(coordinates)

func is_empty() -> bool:
	return _tiles.is_empty()
