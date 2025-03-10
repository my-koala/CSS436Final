@tool
extends Node2D
class_name GameBoard

# TODO:
# where to instantiate newly created tiles?
# sync game board state (need a dictionary i suppose)

const DEFAULT_TURN_COUNT: int = 8
const DEFAULT_TURN_TIME: float = 60.0

signal loop_stopped()

enum SubmissionResult {
	OK,
	ERROR,
	TIMED_OUT,
	STILL_PROCESSING,
	ALREADY_SUBMITTED,
	EMPTY_SUBMISSION,
	INVALID_SUBMISSION,
	INVALID_TILES,
	TILES_OVERLAPPING,
	TILES_REDUNDANT,
	TILES_NOT_COLLINEAR,
	TILES_NOT_CONTINOUS,
	FIRST_CENTER,
	INVALID_WORD,
}


@export
var _game_data: GameData = null

var _game_data_dirty: bool = false
func _on_game_data_updated() -> void:
	_game_data_dirty = true

var active: bool = false

@onready
var _game_tiles: GameTiles = $game_tiles as GameTiles

@onready
var _tile_board: TileBoard = $tile_board as TileBoard

@onready
var _gui_label_turn: Label = $gui/play/label_turn as Label

@onready
var _button_submit: Button = $gui/play/button_submit as Button

var _turn_count: int = 0
var _turn_count_max: int = 0
var _turn_time: float = 0.0
var _turn_time_max: float = 0.0

var _loop: bool = false
func is_loop() -> bool:
	return _loop

func start_loop(turn_count: int = DEFAULT_TURN_COUNT, turn_time: float = DEFAULT_TURN_TIME) -> void:
	if !multiplayer.has_multiplayer_peer() || !is_multiplayer_authority():
		return
	
	if _loop:
		return
	_loop = true
	
	_turn_count = 0
	_turn_count_max = turn_count
	_turn_time = 0.0
	_turn_time_max = turn_time
	
	next_turn()

func next_turn() -> void:
	# Start next turn.
	_turn_count += 1
	_turn_time = _turn_time_max
	# set players submit
	# NOTE: players dont set submit at all, only server
	# server game board submit passes submission, then sets submit and notifies all peers
	_game_data.set_all_players_submitted(false)
	_rpc_set_turn.rpc(_turn_count, _turn_count_max, _turn_time, _turn_time_max)
	
	_game_tiles.assign_tiles()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_game_data.updated.connect(_on_game_data_updated)
	_button_submit.pressed.connect(_on_button_submit_pressed)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if _turn_time > 0.0:
		_turn_time = maxf(_turn_time - delta, 0.0)
	elif _loop:
		if _turn_count < _turn_count_max:
			next_turn()
		else:
			# Out of turns, end the game loop.
			stop_loop()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if !is_visible_in_tree():
		return
	
	_gui_label_turn.text = "Turn %d/%d | Time Left: %01d:%02d" % [_turn_count, _turn_count_max, int(_turn_time / 60.0), int(fmod(_turn_time, 60.0))]

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
	
	_game_data.clear_all_player_tiles()
	
	loop_stopped.emit()

func _on_button_submit_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		var bytes: PackedByteArray = _game_tiles.encode_submission_bytes()
		if !bytes.is_empty():
			print("Submitting!")
			_rpc_request_submit.rpc_id(get_multiplayer_authority(), bytes)

var _player_submissions_processing: Array[int] = []

# Client to server: submit tiles.
# tile_pos_x: 2 bytes (16 bit signed int)
# tile_pos_y: 2 bytes (16 bit signed int)
# tile_face: 1 byte (8 bit unsigned int)
@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_submit(bytes: PackedByteArray) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	
	var submission: Dictionary[Vector2i, int] = _game_tiles.decode_submission_bytes(bytes)
	if submission.is_empty():
		_rpc_submit_result.rpc_id(player_id, SubmissionResult.INVALID_SUBMISSION)
		return
	
	if _player_submissions_processing.has(player_id):
		_rpc_submit_result.rpc_id(player_id, SubmissionResult.STILL_PROCESSING)
		return
	
	_player_submissions_processing.append(player_id)
	
	var submission_result: SubmissionResult = await _validate_submission(player_id, submission)
	if submission_result == SubmissionResult.OK:
		# Update game board state (add tiles), remove submitter player tiles, and notify all peers.
		var player_tiles: Array[int] = _game_data.get_player_tiles(player_id)
		for coordinates: Vector2i in submission:
			var face: int = submission[coordinates]
			player_tiles.erase(face)
			_tile_board.add_tile(coordinates, face)
		_game_data.set_player_tiles(player_id, player_tiles)
		_game_data.set_player_submitted(player_id, true)
	
	_rpc_submit_result.rpc_id(player_id, submission_result)
	_player_submissions_processing.erase(player_id)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_submit_result(submission_result: SubmissionResult) -> void:
	print("got result: " + str(submission_result))

func _validate_submission(player_id: int, submission: Dictionary[Vector2i, int]) -> SubmissionResult:
	# Check if player has already submitted this turn.
	if _game_data.get_player_submitted(player_id):
		return SubmissionResult.ALREADY_SUBMITTED
	
	# Empty submissions are invalid.
	if submission.is_empty():
		return SubmissionResult.EMPTY_SUBMISSION
	
	var player_tiles: Array[int] = _game_data.get_player_tiles(player_id)
	var submission_tile_faces: Array[int] = submission.values()
	for submission_tile_face: int in submission_tile_faces:
		if player_tiles.has(submission_tile_face):
			player_tiles.erase(submission_tile_face)
		else:
			return SubmissionResult.INVALID_TILES# game code problem
	
	var tile_positions: Array[Vector2i] = submission.keys()
	
	# Check for overlapping tile positions.
	for tile_position: Vector2i in tile_positions:
		if _tile_board.has_tile_at(tile_position):
			return SubmissionResult.TILES_OVERLAPPING# too slow!
	
	# Check for redundant tile positions.
	for index_a: int in tile_positions.size():
		for index_b: int in tile_positions.size():
			if index_a == index_b:
				continue
			if tile_positions[index_a] == tile_positions[index_b]:
				return SubmissionResult.TILES_REDUNDANT# game code problem
	
	# Check tile collinearity and continuity.
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
			return SubmissionResult.TILES_NOT_COLLINEAR
		
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
			if !submission.has(tile_position) && !_tile_board.has_tile_at(tile_position):
				return SubmissionResult.TILES_NOT_CONTINOUS
			step += 1
	
	# Check for center tile position (if first submission).
	if _tile_board.is_empty():
		var has_center: bool = false
		for tile_position: Vector2i in tile_positions:
			if tile_position == Vector2i.ZERO:
				has_center = true
		if !has_center:
			return SubmissionResult.FIRST_CENTER
	
	# Prahas:
	# TODO: Check if connects to tiles already on the board.
	# <insert code here>
	# TODO: Word check.
	# Make code that generates all words that are created with this submission.
	# Words are 2 or more consecutive tiles in left->right and top->bottom directions.
	# submission dictionary (submission tiles), _tile_board for getting board tiles
	var words: Array[String] = []
	# <insert code here>
	
	# TODO: Check word with API via HTTP request.
	# james can port dong's code here
	for word: String in words:
		if false:
			return SubmissionResult.INVALID_WORD
	
	await get_tree().physics_frame
	
	return SubmissionResult.OK
