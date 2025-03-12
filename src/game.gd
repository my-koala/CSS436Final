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
var _game_data: GameData = $game_data as GameData
@onready
var _game_lobby: GameLobby = $game_lobby/game_lobby as GameLobby
@onready
var _game_board: GameBoard = $game_board/game_board as GameBoard

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)

func _on_multiplayer_peer_connected(player_id: int) -> void:
	if is_multiplayer_authority():
		_rpc_set_state.rpc_id(player_id, _state_curr)

func _on_multiplayer_server_disconnected() -> void:
	_set_state(State.NONE)

func is_active() -> bool:
	return _mode != Mode.NONE

func start_client(address: String, port: int, player_name: String = "Player", unsafe: bool = false) -> bool:
	if await _network.join_server(address, port, unsafe) != OK:
		return false
	
	_game_data.set_local_player_name(player_name)
	_game_data.set_local_player_spectator(false)
	
	_mode = Mode.CLIENT
	client_started.emit()
	return true

func start_server(port: int, spectator: bool = true, player_name: String = "Host") -> bool:
	if _network.host_server(port) != OK:
		return false
	
	_game_data.set_local_player_name(player_name)
	_game_data.set_local_player_spectator(spectator)
	
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
			_game_lobby.active = false
			_game_lobby.visible = false
			_game_board.active = false
			_game_board.visible = false
		State.LOBBY:
			_game_lobby.active = true
			_game_lobby.visible = true
			_game_board.active = false
			_game_board.visible = false
		State.PLAY:
			_game_lobby.active = false
			_game_lobby.visible = false
			_game_board.active = true
			_game_board.visible = true

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
					if _game_data.get_all_players_ready():
						_game_data.set_all_players_ready(false)
						_set_state(State.PLAY)
						_game_board.start_loop()
				State.PLAY:
					if !_game_board.is_loop():
						print("game.gd: game ended!")
						_set_state(State.LOBBY)
