@tool
extends Node
class_name Game

# TODO: lobby also displays results of previous game

# if no --host arg
# 1. get player name + validation
# 2. connect to server (if --join, skip prompt)
# 3. if connected, start game loop
# 4. else, display connect error and return to prompt
# 5. on disconnection, display disconnected and return to prompt

# if --host
# 1. start server
# 2. if server start successful, start game loop
# 3. else, print error and exit application

signal client_started()
signal client_stopped()
signal server_started()
signal server_stopped()

signal _client_updated(connected: bool)

enum Mode {
	NONE,
	CLIENT,
	SERVER,
}
var _mode: Mode = Mode.NONE

enum State {
	NONE,
	LOBBY,
	PLAY,
}
var _state_curr: State = State.NONE
var _state_prev: State = State.NONE

@onready
var _network: Network = $network as Network

@onready
var _game_players: GamePlayers = $game_players as GamePlayers
@onready
var _game_timer: GameTimer = $gui/play/game_timer as GameTimer

@onready
var _tile_board: TileBoard = $world/tile_board as TileBoard

@onready
var _tile_rack: TileRack = $gui/play/tile_rack as TileRack

@onready
var _drag: CanvasLayer = $drag as CanvasLayer

@onready
var _world: Node2D = $world as Node2D

@onready
var _gui_play: Control = $gui/play as Control

@onready
var _gui_lobby: Control = $gui/lobby as Control

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_game_state(state: int) -> void:
	pass

# Server to client: sends tile faces.
@rpc("authority", "call_remote", "reliable", 0)
func _rpc_add_rack_tiles(bytes: PackedByteArray) -> void:
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
		if !_tile_rack.add_tile(tile):
			push_error("HUGE PROBLEM: Could not add tile!")

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

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)

func _on_multiplayer_peer_connected(player_id: int) -> void:
	print("%d: peer connected: %d" % [multiplayer.get_unique_id(), player_id])
	if is_multiplayer_authority():
		_rpc_set_state.rpc_id(player_id, _state_curr)

func _on_multiplayer_peer_disconnected(player_id: int) -> void:
	print("%d: peer disconnected: %d" % [multiplayer.get_unique_id(), player_id])

func _on_multiplayer_server_disconnected() -> void:
	_set_state(State.NONE)

func is_active() -> bool:
	return _mode != Mode.NONE

func start_client(address: String, port: int, player_name: String = "Player") -> bool:
	if await _network.join_server(address, port) != OK:
		return false
	
	_game_players.set_local_player_name(player_name)
	_game_players.set_local_player_spectator(false)
	
	_mode = Mode.CLIENT
	_set_state(State.LOBBY)
	client_started.emit()
	return true

func start_server(port: int, spectator: bool = true, player_name: String = "Host") -> bool:
	if _network.host_server(port) != OK:
		return false
	
	_game_players.set_local_player_name(player_name)
	_game_players.set_local_player_spectator(spectator)
	
	_mode = Mode.SERVER
	_set_state(State.LOBBY)
	server_started.emit()
	return true

func stop() -> void:
	match _mode:
		Mode.NONE:
			pass
		Mode.CLIENT:
			# TODO: Reset board, tiles, players, etc.
			# though much of reset would be through rpcs and multiplayer callbacks?
			_network.quit_server()
			_mode = Mode.NONE
			_set_state(State.NONE)
		Mode.SERVER:
			_network.stop_server()
			_mode = Mode.NONE
			_set_state(State.NONE)

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_state(state: State) -> void:
	_set_state(state)

func _set_state(state: State) -> void:
	if _state_curr == state:
		return
	_state_curr = state
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_set_state.rpc(_state_curr)
	
	match _state_curr:
		State.NONE:
			_world.visible = false
			_gui_lobby.visible = false
			_gui_play.visible = false
		State.LOBBY:
			_world.visible = false
			_gui_lobby.visible = true
			_gui_play.visible = false
		State.PLAY:
			_world.visible = true
			_gui_lobby.visible = false
			_gui_play.visible = true

var _temp_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		pass
	
	match _mode:
		Mode.NONE:
			pass
		Mode.CLIENT:
			match _state_curr:
				State.LOBBY:
					pass
				State.PLAY:
					pass
		Mode.SERVER:
			match _state_curr:
				State.LOBBY:
					# TODO: check if all players are ready, start play
					if _game_players.get_all_players_ready():
						_game_players.set_all_players_ready(false)
						_set_state(State.PLAY)
				State.PLAY:
					_temp_timer += delta
					if _temp_timer > 3.0:
						_set_state(State.LOBBY)
						_temp_timer = 0.0

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
