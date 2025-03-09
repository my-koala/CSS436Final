@tool
extends Node

# i think i need a DockerFile for running on docker container
# https://github.com/rivet-gg/godot-docker/blob/main/Dockerfile
# https://learn.microsoft.com/en-us/azure/container-apps/quickstart-code-to-cloud?tabs=bash%2Ccsharp
# https://docs.docker.com/reference/dockerfile/

# look into websocket multiplayer
# server can run web host, since its a linux app (and not web)

# server will run headless on azure docker container, probably linux
# user clients will run on azure web apps, github, and itchio
# use some sort of dictionary api, or use our own database

# on first game bootup, check if client or server.
# probably cmdline arg --is_server=true
# see OS.get_cmdline_args()

# if client
#    boot to title screen with prompt for display name
#    connect to server on name submit
#    once connected:
#       show list of players that have joined
#       ready button, when every player is ready, game starts
# 

# tiles have to be sprites, snapped to tile map

# game states
# lobby (main menu)
#   players joining, show list of players

const DEFAULT_SERVER_PORT: int = 43517
const DEFAULT_SERVER_ADDRESS: String = "127.0.0.1"

enum State {
	SPLASH,
	NETWORK,
	TITLE,
	GAME,
}
var _state: State = State.SPLASH

@onready
var _menu_config: MenuConfig = $gui/menu_config as MenuConfig

@onready
var _game: Game = $game/game as Game

const TIMEOUT: float = 300.0
var _timeout: float = 0.0

var _auto_connect: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_menu_config.network_join_request.connect(_on_menu_config_network_join_request)
	
	_game.server_started.connect(_on_game_server_started)
	_game.server_stopped.connect(_on_game_server_stopped)
	_game.client_started.connect(_on_game_client_started)
	_game.client_stopped.connect(_on_game_client_stopped)
	
	# Process command line arguments.
	var args: Dictionary[String, String] = {}
	var args_raw: PackedStringArray = OS.get_cmdline_user_args()
	for arg_raw: String in args_raw:
		var split: int = arg_raw.find("=")
		var key: String = arg_raw.substr(0, split).trim_prefix("--")
		if split > -1:
			args[key] = arg_raw.substr(split + 1, -1)
		else:
			args[key] = ""
	
	var server: bool = false
	
	var address: String = DEFAULT_SERVER_ADDRESS
	var port: int = DEFAULT_SERVER_PORT
	
	if args.has("address"):
		_auto_connect = true
		address = args["address"]
	if args.has("server"):
		server = true
	
	if server:
		if !_game.start_server(port):
			push_error("Error hosting server!")
			get_tree().quit(1)
			return
		
		_menu_config.set_state(MenuConfig.State.NONE)
	else:
		_menu_config.set_network_details(address, port, true)
		_menu_config.set_state(MenuConfig.State.NAME)

func _on_game_server_started() -> void:
	_menu_config.set_state(MenuConfig.State.NONE)

func _on_game_server_stopped() -> void:
	_menu_config.set_state(MenuConfig.State.NETWORK)

func _on_game_client_started() -> void:
	_menu_config.set_state(MenuConfig.State.NONE)

func _on_game_client_stopped() -> void:
	_menu_config.set_state(MenuConfig.State.NETWORK)

func _on_menu_config_network_join_request(address: String, port: int) -> void:
	_game.start_client(_menu_config.get_network_address(), _menu_config.get_network_port(), _menu_config.get_player_name())

func set_state(state: State) -> void:
	_state = state
	match state:
		State.SPLASH:
			pass
		State.TITLE:
			pass
		State.GAME:
			pass
