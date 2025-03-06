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

@onready
var _board: TileMapLayer = $game/board as TileMapLayer

@onready
var _hotbar: Control = $gui/play/hotbar as Control

@onready
var _drag: CanvasLayer = $drag as CanvasLayer

@onready
var _tile: Tile = $game/tiles/tile as Tile

@onready
var _network: Network = $network as Network

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Input.set_default_cursor_shape()
	_tile.drag_started.connect(_on_tile_drag_started.bind(_tile))
	_tile.drag_stopped.connect(_on_tile_drag_stopped.bind(_tile))
	
	# Process command line arguments.
	var args: Dictionary[String, String] = {}
	var args_raw: PackedStringArray = OS.get_cmdline_args()
	for arg_raw: String in args_raw:
		var split: int = arg_raw.find("=")
		var key: String = arg_raw.substr(0, split).trim_prefix("--")
		if split > -1:
			args[key] = arg_raw.substr(split + 1, -1)
		else:
			args[key] = ""
	
	var is_server: bool = false
	var server_address: String = ""
	if args.has("is_server"):
		if args["is_server"].to_lower() == "true":
			is_server = true
		elif args["is_server"].to_lower() == "false":
			is_server = false
	if args.has("server_address"):
		server_address = args["server_address"]
	
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)
	multiplayer.connected_to_server.connect(_on_multiplayer_connected_to_server)
	multiplayer.connection_failed.connect(_on_multiplayer_connection_failed)
	
	if is_server:
		_network.host_server()
	else:
		_network.join_server(server_address)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

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

func _on_multiplayer_connected_to_server() -> void:
	print("%d: connected to server" % [multiplayer.get_unique_id()])

func _on_multiplayer_connection_failed() -> void:
	print("%d: failed to connect to server" % [multiplayer.get_unique_id()])
