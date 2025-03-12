@tool
extends Node2D
class_name GameBoard

# TODO:
# where to instantiate newly created tiles?
# sync game board state (need a dictionary i suppose)

# TODO:
# do a submission check locally before sending to server (save time and rpcs)
# only send if local validated

const DEFAULT_TURN_COUNT: int = 8
const DEFAULT_TURN_TIME: float = 60.0
const DEFAULT_TILE_COUNT: int = 7

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
	TILES_NOT_CONTIGUOUS,
	TILES_NOT_CONNECTED,
	FIRST_CENTER,
	TOO_SHORT,
	INVALID_WORD,
}

static func get_submission_result_message(submission_result: SubmissionResult) -> String:
	match submission_result:
		SubmissionResult.OK:
			return "Submission passed!"
		SubmissionResult.ERROR:
			return "Submission error!"
		SubmissionResult.TIMED_OUT:
			return "Submission time out!"
		SubmissionResult.STILL_PROCESSING:
			return "Submission still processing!"
		SubmissionResult.ALREADY_SUBMITTED:
			return "Already submitted this turn!"
		SubmissionResult.EMPTY_SUBMISSION:
			return "Empty submission!"
		SubmissionResult.INVALID_SUBMISSION:
			return "Invalid submission!"
		SubmissionResult.INVALID_TILES:
			return "Invalid submission tiles! (Game problem)"
		SubmissionResult.TILES_OVERLAPPING:
			return "Submission is out of date!"
		SubmissionResult.TILES_REDUNDANT:
			return "Invalid submission! (Game problem)"
		SubmissionResult.TILES_NOT_COLLINEAR:
			return "Submission tiles are not aligned!"
		SubmissionResult.TILES_NOT_CONTIGUOUS:
			return "Submission tiles are not contiguous!"
		SubmissionResult.TILES_NOT_CONNECTED:
			return "Submission tiles are not connected!"
		SubmissionResult.FIRST_CENTER:
			return "The first word must be on the center tile!"
		SubmissionResult.TOO_SHORT:
			return "Submission word is too short!"
		SubmissionResult.INVALID_WORD:
			return "Not a valid word!"
	return "<submission result>"

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
var _game_camera: GameCamera = $game_camera as GameCamera
@onready
var _gui_label_turn: RichTextLabel = $gui/gui/panel_top/label_turn as RichTextLabel
@onready
var _gui_alert: Control = $gui/gui/alert as Control
var _gui_alert_tween: Tween = null
@onready
var _gui_alert_label: RichTextLabel = $gui/gui/alert/rich_text_label as RichTextLabel
@onready
var _button_submit: Button = $gui/gui/panel_bottom/h_box_container/button_submit as Button
@onready
var _button_recall: Button = $gui/gui/panel_bottom/h_box_container/button_recall as Button
@onready
var _button_swap: Button = $gui/gui/panel_bottom/h_box_container/button_swap as Button
@onready
var _word_check: WordCheck = $word_check as WordCheck

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
	
	_tile_board.clear_tiles()
	_game_data.clear_all_player_points()
	
	next_turn()

func next_turn() -> void:
	# Start next turn.
	_turn_count += 1
	_turn_time = _turn_time_max
	# set players submit
	# NOTE: players dont set submit at all, only server
	# server game board submit passes submission, then sets submit and notifies all peers
	_game_data.set_all_players_submitted(false)
	
	_rpc_set_turn_count.rpc(_turn_count, _turn_count_max)
	_rpc_set_turn_time.rpc(_turn_time, _turn_time_max)
	
	for player_id: int in _game_data.get_player_ids():
		_fill_player_tiles(player_id)

var _await_submit_results: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_game_data.updated.connect(_on_game_data_updated)
	
	_button_submit.pressed.connect(_on_button_submit_pressed)
	_button_submit.disabled = true
	_button_recall.pressed.connect(_on_button_recall_pressed)
	_button_recall.disabled = true
	_button_swap.pressed.connect(_on_button_swap_pressed)
	_button_swap.disabled = true
	
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	
	_gui_alert.modulate.a = 0.0

func _on_multiplayer_peer_connected(player_id: int) -> void:
	if is_multiplayer_authority():
		_rpc_set_turn_count.rpc_id(player_id, _turn_count, _turn_count_max)
		_rpc_set_turn_time.rpc_id(player_id, _turn_time, _turn_time_max)

func _on_button_submit_pressed() -> void:
	if _await_submit_results:
		return
	if multiplayer.has_multiplayer_peer():
		var bytes: PackedByteArray = _game_tiles.encode_submission_bytes()
		if !bytes.is_empty():
			_rpc_request_submit.rpc_id(get_multiplayer_authority(), bytes)
			_await_submit_results = true

func _on_button_recall_pressed() -> void:
	_game_tiles.recall_tiles()

func _on_button_swap_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		_rpc_request_swap.rpc_id(get_multiplayer_authority())

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if !is_visible_in_tree():
		return
	
	_gui_label_turn.clear()
	_gui_label_turn.text = ""
	_gui_label_turn.append_text("[color=white]Turn %d / %d | Time Left: [/color]" % [_turn_count, _turn_count_max])
	if _turn_time > 10.0:
		_gui_label_turn.append_text("[color=white]%01d:%02d[/color]" % [int(_turn_time / 60.0), int(fmod(_turn_time, 60.0))])
	else:
		_gui_label_turn.append_text("[color=red][b]%01d:%02d[/b][/color]" % [int(_turn_time / 60.0), int(fmod(_turn_time, 60.0))])

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_turn_count(turn_count: int, turn_count_max: int) -> void:
	_turn_count = turn_count
	_turn_count_max = turn_count_max

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_turn_time(turn_time: float, turn_time_max: float) -> void:
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
	_game_data.end_game()

func _fill_player_tiles(player_id: int) -> void:
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		if _game_data.get_player_spectator(player_id):
			return
		var player_tiles: Array[int] = _game_data.get_player_tiles(player_id)
		while player_tiles.size() < DEFAULT_TILE_COUNT:
			player_tiles.append(Tile.get_random_face())
		_game_data.set_player_tiles(player_id, player_tiles)

var _player_submission_ids: Array[int] = []
var _player_submission_processes: Array[Callable] = []
var _player_submission_processing: bool = false

# Client to server: submit tiles.
# tile_pos_x: 2 bytes (16 bit signed int)
# tile_pos_y: 2 bytes (16 bit signed int)
# tile_face: 1 byte (8 bit unsigned int)
@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_submit(bytes: PackedByteArray) -> void:
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		var player_id: int = multiplayer.get_remote_sender_id()
		
		var player_submission: Dictionary[Vector2i, int] = _game_tiles.decode_submission_bytes(bytes)
		if player_submission.is_empty():
			_rpc_submit_result.rpc_id(player_id, SubmissionResult.INVALID_SUBMISSION)
			return
		
		if _player_submission_ids.has(player_id):
			_rpc_submit_result.rpc_id(player_id, SubmissionResult.STILL_PROCESSING)
			return
		
		_player_submission_ids.append(player_id)
		_player_submission_processes.append(_validate_submission.bind(player_id, player_submission))

@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_swap() -> void:
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		var player_id: int = multiplayer.get_remote_sender_id()
		if !_game_data.get_player_submitted(player_id):
			_game_data.set_player_submitted(player_id, true)
			var player_tiles: Array[int] = []
			while player_tiles.size() < DEFAULT_TILE_COUNT:
				player_tiles.append(Tile.get_random_face())
			_game_data.set_player_tiles(player_id, player_tiles)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if !active:
		_game_camera.global_position = Vector2.ZERO
		return
	
	if _await_submit_results || _game_data.get_local_player_submitted():
		_button_submit.disabled = true
		_button_submit.text = "Submitted"
		_button_recall.disabled = true
		_button_swap.disabled = true
	else:
		_button_submit.disabled = false
		_button_submit.text = "Submit"
		_button_recall.disabled = false
		_button_swap.disabled = false
	
	if _turn_time > 0.0:
		_turn_time = maxf(_turn_time - delta, 0.0)
	
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		while !_player_submission_processes.is_empty():
			if _player_submission_processing:
				break
			_player_submission_processing = true
			await _player_submission_processes[0].call()
			_player_submission_ids.pop_front()
			_player_submission_processes.pop_front()
			_player_submission_processing = false
		
		# Fast forward turn timer if everyone has already submitted.
		if _turn_time > 3.0 && _game_data.get_all_players_submitted():
			_turn_time = 3.0
			_rpc_set_turn_time.rpc(_turn_time, _turn_time_max)
		if is_zero_approx(_turn_time) && _loop:
			if _turn_count < _turn_count_max:
				next_turn()
			else:
				# Out of turns, end the game loop.
				stop_loop()

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_submit_result(submission_result: SubmissionResult, points: int = 0) -> void:
	var submission_result_message: String = get_submission_result_message(submission_result)
	_gui_alert_label.text = ""
	_gui_alert_label.clear()
	if submission_result == SubmissionResult.OK:
		_gui_alert_label.append_text("[color=white]%s[/color]" % [submission_result_message])
		_gui_alert_label.append_text(" ")
		_gui_alert_label.append_text("[color=green]+%d points![/color]" % [points])
	else:
		_gui_alert_label.append_text("[color=red]%s[/color]" % [submission_result_message])
	
	if is_instance_valid(_gui_alert_tween):
		_gui_alert_tween.kill()
	_gui_alert_tween = _gui_alert.create_tween()
	_gui_alert_tween.tween_property(_gui_alert, "modulate:a", 1.0, 0.125)
	_gui_alert_tween.set_parallel(false)
	_gui_alert_tween.tween_interval(3.0)
	_gui_alert_tween.tween_property(_gui_alert, "modulate:a", 0.0, 1.0)
	_await_submit_results = false

func _validate_submission(player_id: int, submission: Dictionary[Vector2i, int]) -> SubmissionResult:
	# Check if player has already submitted this turn.
	if _game_data.get_player_submitted(player_id):
		_rpc_submit_result.rpc_id(player_id, SubmissionResult.ALREADY_SUBMITTED)
		return SubmissionResult.ALREADY_SUBMITTED
	
	# Empty submissions are invalid.
	if submission.is_empty():
		_rpc_submit_result.rpc_id(player_id, SubmissionResult.EMPTY_SUBMISSION)
		return SubmissionResult.EMPTY_SUBMISSION
	
	# Check for invalid player tile data.
	var player_tiles: Array[int] = _game_data.get_player_tiles(player_id)
	for tile_position: Vector2i in submission:
		var face: int = submission[tile_position]
		if !player_tiles.has(face):
			_rpc_submit_result.rpc_id(player_id, SubmissionResult.INVALID_TILES)
			return SubmissionResult.INVALID_TILES# game code problem
		player_tiles.erase(face)
	
	# Check for first word length.
	if _tile_board.is_empty() && submission.size() < 2:
		_rpc_submit_result.rpc_id(player_id, SubmissionResult.TOO_SHORT)
		return SubmissionResult.TOO_SHORT
	
	var tile_positions: Array[Vector2i] = submission.keys()
	
	# Check for overlapping tile positions.
	for tile_position: Vector2i in tile_positions:
		if _tile_board.has_tile_at(tile_position):
			_rpc_submit_result.rpc_id(player_id, SubmissionResult.TILES_OVERLAPPING)
			return SubmissionResult.TILES_OVERLAPPING# too slow!
	
	# Check for redundant tile positions.
	for index_a: int in tile_positions.size():
		for index_b: int in tile_positions.size():
			if index_a == index_b:
				continue
			if tile_positions[index_a] == tile_positions[index_b]:
				_rpc_submit_result.rpc_id(player_id, SubmissionResult.TILES_REDUNDANT)
				return SubmissionResult.TILES_REDUNDANT# game code problem
	
	var tile_major_axis: Vector2i = Vector2i.RIGHT# Valid submission has all tiles on one major axis.
	var tile_major_axis_min: Vector2i = tile_positions[0]# Min tile on major axis (including board tiles)
	var tile_major_axis_max: Vector2i = tile_positions[0]# Max tile on major axis (including board tiles)
	var tile_minor_axis: Vector2i = Vector2i.DOWN# Not the major axis.
	
	# Check if tiles are collinear and contiguous.
	# Get component-wise min and max (upper-left and bottom-right 2D rect).
	var tile_rect_min: Vector2i = tile_positions[0]
	var tile_rect_max: Vector2i = tile_positions[0]
	for tile_position: Vector2i in tile_positions:
		tile_rect_min = tile_rect_min.min(tile_position)
		tile_rect_max = tile_rect_max.max(tile_position)
	
	# If both axis components are non-zero, tiles are not collinear.
	var tile_rect_delta: Vector2i = (tile_rect_max - tile_rect_min).mini(1)
	if tile_rect_delta == Vector2i.ONE:
		_rpc_submit_result.rpc_id(player_id, SubmissionResult.TILES_NOT_COLLINEAR)
		return SubmissionResult.TILES_NOT_COLLINEAR
	
	if submission.size() > 1:
		tile_major_axis = tile_rect_delta
		tile_minor_axis = Vector2i.ONE - tile_major_axis
	
	# NOTE: An axis is either Vector2i.DOWN or Vector2i.RIGHT.
	assert(tile_major_axis == Vector2i.DOWN || tile_major_axis == Vector2i.RIGHT)
	assert(tile_minor_axis == Vector2i.DOWN || tile_minor_axis == Vector2i.RIGHT)
	assert(tile_major_axis != tile_minor_axis)
	
	# Get major axis min and max.
	while true:
		var tile_position: Vector2i = tile_major_axis_min - tile_major_axis
		if !submission.has(tile_position) && !_tile_board.has_tile_at(tile_position):
			break
		tile_major_axis_min = tile_position
	
	while true:
		var tile_position: Vector2i = tile_major_axis_max + tile_major_axis
		if !submission.has(tile_position) && !_tile_board.has_tile_at(tile_position):
			break
		tile_major_axis_max = tile_position
	
	# If axis min/max is more/less than rect min/max, tiles are not contiguous.
	if tile_major_axis_min > tile_rect_min || tile_major_axis_max < tile_rect_max:
		_rpc_submit_result.rpc_id(player_id, SubmissionResult.TILES_NOT_CONTIGUOUS)
		return SubmissionResult.TILES_NOT_CONTIGUOUS
	
	# Check for center tile position (if first submission).
	if _tile_board.is_empty():
		var has_center: bool = false
		for tile_position: Vector2i in tile_positions:
			if tile_position == Vector2i.ZERO:
				has_center = true
		if !has_center:
			_rpc_submit_result.rpc_id(player_id, SubmissionResult.FIRST_CENTER)
			return SubmissionResult.FIRST_CENTER
	
	# Check if connects to tiles already on the board.
	if !_tile_board.is_empty():
		var check_connectivity: bool = false
		for tile_position: Vector2i in tile_positions:
			var check: bool = false
			if _tile_board.has_tile_neighor_at(tile_position):
				check_connectivity = true
				break
		if !check_connectivity:
			_rpc_submit_result.rpc_id(player_id, SubmissionResult.TILES_NOT_CONNECTED)
			return SubmissionResult.TILES_NOT_CONNECTED
	
	var points: int = 0
	
	# Get all words created by submission and calculate points.
	# Words are 2 or more consecutive tiles in left->right and top->bottom directions.
	var words: Array[String] = []
	# Get major axis word.
	var tile_major_axis_word: String = ""
	var tile_major_axis_position: Vector2i = tile_major_axis_min
	var tile_major_axis_points: int = 0
	var tile_major_axis_points_multiplier: int = 1
	while tile_major_axis_position <= tile_major_axis_max:
		var tile_face: int = -1
		if _tile_board.has_tile_at(tile_major_axis_position):
			tile_face = _tile_board.get_tile_at(tile_major_axis_position)
		elif submission.has(tile_major_axis_position):
			tile_face = submission[tile_major_axis_position]
		
		tile_major_axis_word += Tile.get_face_string(tile_face)
		tile_major_axis_points += Tile.get_face_points(tile_face) * _tile_board.get_board_letter_multiplier(tile_major_axis_position)
		tile_major_axis_points_multiplier *= _tile_board.get_board_word_multiplier(tile_major_axis_position)
		tile_major_axis_position += tile_major_axis
	
	if tile_major_axis_word.length() > 1:
		words.append(tile_major_axis_word)
		points += tile_major_axis_points * tile_major_axis_points_multiplier
	
	# Get minor axis words (only from submission tiles!)
	for tile_position: Vector2i in tile_positions:
		var tile_face: int = submission[tile_position]
		var tile_minor_axis_word: String = Tile.get_face_string(tile_face)
		var tile_minor_axis_points: int = Tile.get_face_points(tile_face) * _tile_board.get_board_letter_multiplier(tile_position)
		var tile_minor_axis_points_multiplier: int = 1 * _tile_board.get_board_word_multiplier(tile_position)
		
		# Navigate to minor axis min.
		var tile_minor_axis_min: Vector2i = tile_position
		while true:
			tile_minor_axis_min -= tile_minor_axis
			if _tile_board.has_tile_at(tile_minor_axis_min):
				tile_face = _tile_board.get_tile_at(tile_minor_axis_min)
			elif submission.has(tile_minor_axis_min):
				tile_face = submission[tile_minor_axis_min]
			else:
				break
			
			tile_minor_axis_word = Tile.get_face_string(tile_face) + tile_minor_axis_word
			tile_minor_axis_points += Tile.get_face_points(tile_face) * _tile_board.get_board_letter_multiplier(tile_minor_axis_min)
			tile_minor_axis_points_multiplier *= _tile_board.get_board_word_multiplier(tile_minor_axis_min)
		
		# Navigate to minor axis max.
		var tile_minor_axis_max: Vector2i = tile_position
		while true:
			tile_minor_axis_max += tile_minor_axis
			if _tile_board.has_tile_at(tile_minor_axis_max):
				tile_face = _tile_board.get_tile_at(tile_minor_axis_max)
			elif submission.has(tile_minor_axis_max):
				tile_face = submission[tile_minor_axis_max]
			else:
				break
			
			tile_minor_axis_word = Tile.get_face_string(tile_face) + tile_minor_axis_word
			tile_minor_axis_points += Tile.get_face_points(tile_face) * _tile_board.get_board_letter_multiplier(tile_minor_axis_max)
			tile_minor_axis_points_multiplier *= _tile_board.get_board_word_multiplier(tile_minor_axis_max)
		
		if tile_minor_axis_word.length() > 1:
			words.append(tile_minor_axis_word)
			points += tile_minor_axis_points * tile_minor_axis_points_multiplier
	
	# Check words with WordCheck.
	for word: String in words:
		if !(await _word_check.get_word_valid(word)):
			_rpc_submit_result.rpc_id(player_id, SubmissionResult.INVALID_WORD)
			return SubmissionResult.INVALID_WORD
	
	# Time out in case disconnection has happened since word check.
	if !multiplayer.has_multiplayer_peer() || !multiplayer.get_peers().has(player_id):
		return SubmissionResult.TIMED_OUT
	
	# Submission passed all checks!
	# Update game board state (add tiles), remove player tiles, and set player as submitted.
	for coordinates: Vector2i in submission:
		var face: int = submission[coordinates]
		_tile_board.add_tile(coordinates, face)
	
	_game_data.set_player_tiles(player_id, player_tiles)
	_game_data.set_player_points(player_id, _game_data.get_player_points(player_id) + points)
	_game_data.set_player_submitted(player_id, true)
	
	_fill_player_tiles(player_id)
	
	_rpc_submit_result.rpc_id(player_id, SubmissionResult.OK, points)
	return SubmissionResult.OK
