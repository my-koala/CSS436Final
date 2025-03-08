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

@onready
var _board: TileMapLayer = $game/board as TileMapLayer

@onready
var _hotbar: Control = $gui/play/hotbar as Control

@onready
var _drag: CanvasLayer = $drag as CanvasLayer

@onready
var _tile: Tile = $game/tiles/tile as Tile

@onready
var _menu_network: MenuNetwork = $gui/menu_network as MenuNetwork

@onready
var _network: Network = $network as Network

# test
@onready
var _test_line_edit: LineEdit = $gui/test/line_edit as LineEdit
@onready
var _test_button_reliable: Button = $gui/test/button_reliable as Button
@onready
var _test_button_unreliable: Button = $gui/test/button_unreliable as Button

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_test_button_reliable.pressed.connect(_on_test_button_reliable_pressed)
	_test_button_unreliable.pressed.connect(_on_test_button_unreliable_pressed)
	
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)
	multiplayer.connected_to_server.connect(_on_multiplayer_connected_to_server)
	multiplayer.connection_failed.connect(_on_multiplayer_connection_failed)
	
	_menu_network.host_request.connect(_on_menu_network_host_request)
	_menu_network.join_request.connect(_on_menu_network_join_request)
	_menu_network.stop_request.connect(_on_menu_network_stop_request)
	_menu_network.set_state(MenuNetwork.State.MAIN)
	
	Input.set_default_cursor_shape()
	_tile.drag_started.connect(_on_tile_drag_started.bind(_tile))
	_tile.drag_stopped.connect(_on_tile_drag_stopped.bind(_tile))
	
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
	
	var network_configured: bool = false
	var server: bool = false
	
	var address: String = DEFAULT_SERVER_ADDRESS
	var port: int = DEFAULT_SERVER_PORT
	
	if args.has("server"):
		print("found server arg")
		server = args["server"].to_lower() == "true"
		network_configured = true
	if args.has("address"):
		address = args["address"]
	if args.has("port"):
		port = args["port"].to_int()
	
	if network_configured:
		_menu_network.set_state(MenuNetwork.State.NONE)
		if server:
			_network.host_server(port)
		else:
			_network.join_server(address, port)

@rpc("any_peer", "call_remote", "reliable", 0)
func _message_reliable(message: String) -> void:
	print("%d: Received reliable message from peer %d: %s" % [multiplayer.get_unique_id(), multiplayer.get_remote_sender_id(), message])

@rpc("any_peer", "call_remote", "unreliable", 0)
func _message_unreliable(message: String) -> void:
	print("%d: Received unreliable message from peer %d: %s" % [multiplayer.get_unique_id(), multiplayer.get_remote_sender_id(), message])

func _on_test_button_reliable_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		_message_reliable.rpc(_test_line_edit.text)

func _on_test_button_unreliable_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		_message_unreliable.rpc(_test_line_edit.text)

func _on_menu_network_host_request(port: int) -> void:
	if port == 0:
		_network.host_server(DEFAULT_SERVER_PORT)
	else:
		_network.host_server(port)

func _on_menu_network_join_request(address: String, port: int) -> void:
	if address.is_empty():
		_network.join_server(DEFAULT_SERVER_ADDRESS, DEFAULT_SERVER_PORT)
	elif port == 0:
		_network.join_server(address, DEFAULT_SERVER_PORT)
	else:
		_network.join_server(address, port)

func _on_menu_network_stop_request() -> void:
	if _network.is_active():
		if _network.is_server():
			_network.stop_server()
		else:
			_network.quit_server()

func _on_tile_drag_started(tile: Tile) -> void:
	tile.reparent(_drag, true)
	tile.reset_physics_interpolation()

func _on_tile_drag_stopped(tile: Tile) -> void:
	# Snap to board grid.
	# TODO: check if tile position is outside board bounds
	# TODO: track tiles and check if a tile was already placed at coordinate
	
	tile.reparent(_board, true)
	tile.reset_physics_interpolation()
	var snap_coordinates: Vector2i = _board.local_to_map(_board.to_local(tile.global_position))
	var snap_position: Vector2 = Vector2(snap_coordinates * _board.tile_set.tile_size)
	snap_position = _board.global_transform * (snap_position - _board.position)
	tile.global_position = snap_position

var _peer_instances: Array[Node] = []

func _on_multiplayer_peer_connected(peer_id: int) -> void:
	print("%d: peer connected: %d" % [multiplayer.get_unique_id(), peer_id])
	pass

func _on_multiplayer_peer_disconnected(peer_id: int) -> void:
	print("%d: peer disconnected: %d" % [multiplayer.get_unique_id(), peer_id])
	# Remove and free peer instance.
	var peer_name: StringName = StringName(str(peer_id))
	for peer_instance: Node in _peer_instances:
		if peer_instance.name != peer_name:
			continue
		_peer_instances.erase(peer_instance)
		peer_instance.queue_free()
		break

func _on_multiplayer_server_disconnected() -> void:
	print("%d: disconnected from server" % [multiplayer.get_unique_id()])
	# Remove all peer instances.
	for peer_instance: Node in _peer_instances:
		peer_instance.queue_free()
	_peer_instances.clear()
	
	_menu_network.set_state(MenuNetwork.State.STATUS)

func _on_multiplayer_connected_to_server() -> void:
	#print("%d: connected to server" % [multiplayer.get_unique_id()])
	
	_menu_network.set_state(MenuNetwork.State.NONE)

func _on_multiplayer_connection_failed() -> void:
	#print("%d: failed to connect to server" % [multiplayer.get_unique_id()])
	
	_menu_network.set_state(MenuNetwork.State.STATUS)
