@tool
extends Node

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
var _tile: Tile = $game/tiles/tile as Tile

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Input.set_default_cursor_shape()
	_tile.drag_stopped.connect(_on_tile_drag_stopped.bind(_tile))

func _on_tile_drag_stopped(tile: Tile) -> void:
	pass
	# Snap to board grid.
	# TODO: check if tile position is outside board bounds
	# TODO: track tiles and check if a tile was already placed at coordinate
	
	var snap_coordinates: Vector2i = _board.local_to_map(_board.to_local(tile.global_position))
	var snap_position: Vector2 = Vector2(snap_coordinates * _board.tile_set.tile_size)
	snap_position = _board.global_transform * (snap_position - _board.position)
	tile.global_position = snap_position
