@tool
extends Control
class_name TileRack

const TILE_COUNT: int = 7

signal tile_added(tile: Tile)
signal tile_removed(tile: Tile)

@export
var tile_size: Vector2 = Vector2(128.0, 128.0)

var _tiles: Array[Tile] = []

func _init() -> void:
	if Engine.is_editor_hint():
		return
	
	for index: int in TILE_COUNT:
		_tiles.append(null)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	

func shuffle() -> void:
	pass

func add_tile(tile: Tile) -> bool:
	var index: int = get_next_empty_index()
	if index == -1:
		return false
	_tiles[index] = tile
	tile.global_position = get_index_position(index)
	return true

func remove_tile(tile: Tile) -> bool:
	var index: int = _tiles.find(tile)
	if index == -1:
		return false
	_tiles[index] = null
	return true

func has_tile(tile: Tile) -> bool:
	return _tiles.has(tile)

func get_index_position(index: int) -> Vector2:
	if index < 0 || index >= TILE_COUNT:
		return Vector2.ZERO
	var offset: float = (float(index) * tile_size.x) - ((tile_size.x * TILE_COUNT) * 0.5)
	return get_rect().get_center() + Vector2(offset, 0.0)

func get_next_empty_index() -> int:
	for index: int in TILE_COUNT:
		if !is_instance_valid(_tiles[index]):
			return index
	return -1

func is_empty() -> bool:
	for tile: Tile in _tiles:
		if is_instance_valid(tile):
			return false
	return true

func is_hovered() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())
