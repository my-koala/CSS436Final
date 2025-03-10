@tool
extends Node2D
class_name GameBoard

# TODO:
# 

signal loop_stopped()

@export
var game_data: GameData = null:
	get:
		return game_data
	set(value):
		if game_data != value:
			if is_instance_valid(game_data):
				game_data.updated.disconnect(_on_game_data_updated)
			game_data = value
			if is_instance_valid(game_data):
				game_data.updated.connect(_on_game_data_updated)

var _game_data_dirty: bool = false
func _on_game_data_updated() -> void:
	_game_data_dirty = true

var active: bool = false

@onready
var _tile_board: TileBoard = $tile_board as TileBoard

@onready
var _tile_rack: TileRack = $gui/play/tile_rack as TileRack

@onready
var _gui_label_turn: Label = $gui/play/label_turn as Label

@onready
var _drag: CanvasLayer = $drag as CanvasLayer

var _turn_count: int = 0
var _turn_count_max: int = 0
var _turn_time: float = 0.0
var _turn_time_max: float = 0.0

var _loop: bool = false
func is_loop() -> bool:
	return _loop

func start_loop(turn_count: int = 2, turn_time: float = 4.0) -> void:
	if !multiplayer.has_multiplayer_peer() || !is_multiplayer_authority():
		return
	
	if _loop:
		return
	_loop = true
	
	_turn_count = 0
	_turn_count_max = turn_count
	_turn_time = 0.0
	_turn_time_max = turn_time
	

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	_gui_label_turn.text = "Turn %d/%d | Time Left: %01d:%02d" % [_turn_count, _turn_count_max, int(_turn_time / 60.0), int(fmod(_turn_time, 60.0))]

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if _turn_time > 0.0:
		_turn_time = maxf(_turn_time - delta, 0.0)
	elif _loop:
		if _turn_count < _turn_count_max:
			# Start next turn.
			_turn_count += 1
			_turn_time = _turn_time_max
			# set players submit
			# NOTE: players dont set submit at all, only server
			# server game board submit passes submission, then sets submit and notifies all peers
			game_data.set_all_players_submitted(false)
			_rpc_set_turn.rpc(_turn_count, _turn_count_max, _turn_time, _turn_time_max)
			
			# assign players tiles
			for player_id: int in game_data.get_player_ids():
				if game_data.get_player_spectator(player_id):
					continue
	
		else:
			# Out of turns, end the game loop.
			stop_loop()
	

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_turn(turn_count: int, turn_count_max: int, turn_time: float, turn_time_max: float) -> void:
	_turn_count = turn_count
	_turn_count_max = turn_count_max
	_turn_time = turn_time
	_turn_time_max = turn_time_max

func stop_loop() -> void:
	if !_loop:
		return
	_loop = false
	
	_turn_count = 0
	_turn_count_max = 0
	_turn_time = 0.0
	_turn_time_max = 0.0
	# get 
	
	loop_stopped.emit()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	

# Server to client: sends tile faces.
# TODO: replace, dont add
@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_rack_tiles(bytes: PackedByteArray) -> void:
	# Read bytes as tile faces.
	var tile_faces: Array[int] = []
	var index: int = 0
	while index < bytes.size():
		tile_faces.append(bytes.decode_u8(index * 8))
		index += 1
	print("Received tiles: " + str(tile_faces))
	for tile_face: int in tile_faces:
		var tile: Tile = Tile.new()
		tile.face = tile_face
		#if !_tile_rack.add_tile(tile):
		#	push_error("HUGE PROBLEM: Could not add tile!")

# Client to server: submit tiles.
# tile_pos_x: 2 bytes (16 bit signed int)
# tile_pos_y: 2 bytes (16 bit signed int)
# tile_face: 1 byte (8 bit unsigned int)
@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_submit(bytes: PackedByteArray) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	var submission: Dictionary[Vector2i, int] = {}
	var index: int = 0
	
	while index < bytes.size():
		var tile_position_x: int = bytes.decode_s16(index + 0)
		var tile_position_y: int = bytes.decode_s16(index + 16)
		var tile_face: int = bytes.decode_u8(index + 32)
		submission[Vector2i(tile_position_x, tile_position_y)] = tile_face
		index += 5
	
	if _validate_submission(peer_id, submission):
		_rpc_submit_result.rpc_id(peer_id, true)
		# TODO: Change game board state (add tiles) and notify all peers.
	else:
		_rpc_submit_result.rpc_id(peer_id, false)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_submit_result(result: bool) -> void:
	print("got result: " + str(result))

func _validate_submission(peer_id: int, submission: Dictionary[Vector2i, int]) -> bool:
	# TODO: Check if player has already submitted this turn.
	
	# Empty submissions are invalid.
	if submission.is_empty():
		return false
	
	var tile_positions: Array[Vector2i] = submission.keys()
	
	# Check for overlapping tile positions.
	for tile_position: Vector2i in tile_positions:
		if _tile_board.has_tile_at(tile_position):
			return false
	
	# Check for redundant tile positions.
	for index_a: int in tile_positions.size():
		for index_b: int in tile_positions.size():
			if index_a == index_b:
				continue
			if tile_positions[index_a] == tile_positions[index_b]:
				return false
	
	# Check tile collinearity and connectivity.
	if tile_positions.size() > 1:
		# Get component-wise min and max (upper-left and bottom-right 2D rect).
		var tile_rect_min: Vector2i = tile_positions[0]
		var tile_rect_max: Vector2i = tile_positions[0]
		for tile_position: Vector2i in tile_positions:
			tile_rect_min = tile_rect_min.min(tile_position)
			tile_rect_max = tile_rect_max.max(tile_position)
		
		# If both axis components are non-zero, tiles are not collinear.
		var axis: Vector2i = (tile_rect_max - tile_rect_min).mini(1)
		if axis.x != 0 && axis.y != 0:
			return false
		
		# NOTE: axis is either Vector2i.DOWN or Vector2i.RIGHT
		assert(axis == Vector2i.DOWN || axis == Vector2i.RIGHT)
		
		# Get both ends of tile positions.
		var tile_position_min: Vector2i = tile_positions[0]
		var tile_position_max: Vector2i = tile_positions[0]
		for tile_position: Vector2i in tile_positions:
			if tile_position < tile_position_min:
				tile_position_min = tile_position
			elif tile_position > tile_position_max:
				tile_position_max = tile_position
		
		# Step through the tiles from min to max.
		var step: int = 1
		var length: int = (tile_position_max - tile_position_min)[axis.max_axis_index()]
		while step < length:
			var tile_position: Vector2i = (step * axis) + tile_position_min
			if !submission.has(tile_position) || _tile_board.has_tile_at(tile_position):
				return false
			step += 1
	
	# Check for center tile position (if first submission).
	if _tile_board.is_empty():
		var has_center: bool = false
		for tile_position: Vector2i in tile_positions:
			if tile_position == Vector2i.ZERO:
				has_center = true
		if !has_center:
			return false
	
	# TODO: Implement word check algorithm.
	
	return true

#func _on_tile_drag_started(tile: Tile) -> void:
	#if _tile_rack.has_tile(tile):
		#_tile_rack.remove_tile(tile)
	#tile.reparent(_drag, true)
	#tile.global_position = get_global_mouse_position()
	#tile.reset_physics_interpolation()

#func _on_tile_drag_stopped(tile: Tile) -> void:
	## Snap to board grid.
	## TODO: check if tile position is outside board bounds
	## TODO: track tiles and check if a tile was already placed at coordinate
	#if _tile_rack.is_hovered():
		#tile.reparent(_tile_rack, true)
		#tile.global_position = _tile_rack.get_global_mouse_position()
		#_tile_rack.add_tile(tile)
		#tile.reset_physics_interpolation()
	#else:
		#tile.reparent(_tile_board, true)
		#tile.global_position = get_global_mouse_position()
		#tile.reset_physics_interpolation()
		#_tile_board.add_tile(tile, _tile_board.local_to_map(_tile_board.to_local(tile.global_position)))
