@tool
extends Node
class_name GameData

# Global game player data.
# Some data is synchronized across all peers (name, ready, points, etc.)
# Some data is private to the server and individual peers (tiles).

# TODO: Test/look up how RPCs are optimized/grouped into packets by the engine.
# Should RPCs be consolidated? e.g. _on_multiplayer_peer_connected can potentially make many RPCs.

# game board
# - 
# - tiles (public server, private player)
# - if player is spectator (public server, public player)
#   - _rpc_set_tiles() server -> player
#   - _rpc_set_spectator(bool) server -> player
# - 


const PLAYER_NAME_MAX_LENGTH: int = 16

class Player:
	extends RefCounted
	var id: int = 1
	var name: String = "Player"
	var spectator: bool = false
	var ready: bool = false
	var submitted: bool = true
	var points: int = 0
	var tiles: PackedByteArray = PackedByteArray()
	
	var place: int = -1

signal updated()
signal game_ended()

func end_game() -> void:
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_end_game.rpc()
		game_ended.emit()

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_end_game() -> void:
	game_ended.emit()

static func is_valid_player_name(player_name: String) -> bool:
	if player_name.is_empty():
		return false
	if player_name.contains("\n"):
		return false
	if player_name.length() > PLAYER_NAME_MAX_LENGTH:
		return false
	return true

var _local_player: Player = Player.new()
var _remote_players: Array[Player] = []

func get_player_ids() -> Array[int]:
	var player_ids: Array[int] = []
	player_ids.append(_local_player.id)
	for remote_player: Player in _remote_players:
		player_ids.append(remote_player.id)
	return player_ids

func _get_player(player_id: int) -> Player:
	if _local_player.id == player_id:
		return _local_player
	for remote_player: Player in _remote_players:
		if remote_player.id == player_id:
			return remote_player
	return null

#region Player Name

func get_local_player_name() -> String:
	return _local_player.name

func set_local_player_name(player_name: String) -> void:
	set_player_name(_local_player.id, player_name)

func get_player_name(player_id: int) -> String:
	var player: Player = _get_player(player_id)
	if is_instance_valid(player):
		return player.name
	return "<unknown>"

func set_player_name(player_id: int, player_name: String) -> void:
	if multiplayer.has_multiplayer_peer():
		if is_multiplayer_authority():
			_set_player_name(player_id, player_name)
		else:
			_rpc_request_set_player_name.rpc_id(get_multiplayer_authority(), player_id, player_name)

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_player_name(player_id: int, player_name: String) -> void:
	_set_player_name(player_id, player_name)

@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_request_set_player_name(player_id: int, player_name: String) -> void:
	if is_multiplayer_authority() && (player_id == multiplayer.get_remote_sender_id()):
		_set_player_name(player_id, player_name)

func _set_player_name(player_id: int, player_name: String) -> bool:
	var player: Player = _get_player(player_id)
	if !is_instance_valid(player):
		return false
	
	if player.name == player_name:
		return false
	
	player.name = player_name
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_set_player_name.rpc(player_id, player_name)
	updated.emit()
	return true

#endregion
#region Player Ready

func get_all_players_ready() -> bool:
	if _remote_players.is_empty() && _local_player.spectator:
		return false
	if !_local_player.spectator && !_local_player.ready:
		return false
	for remote_player: Player in _remote_players:
		if !remote_player.ready && !remote_player.spectator:
			return false
	return true

func set_all_players_ready(player_ready: bool) -> void:
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_set_player_ready(_local_player.id, player_ready)
		for player_id: int in get_player_ids():
			_set_player_ready(player_id, player_ready)

func get_local_player_ready() -> bool:
	return _local_player.ready

func set_local_player_ready(player_ready: bool) -> void:
	set_player_ready(_local_player.id, player_ready)

func get_player_ready(player_id: int) -> bool:
	var player: Player = _get_player(player_id)
	if is_instance_valid(player):
		return player.ready
	return false

func set_player_ready(player_id: int, player_ready: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		if is_multiplayer_authority():
			_set_player_ready(player_id, player_ready)
		else:
			_rpc_request_set_player_ready.rpc_id(get_multiplayer_authority(), player_id, player_ready)

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_player_ready(player_id: int, player_ready: bool) -> void:
	_set_player_ready(player_id, player_ready)

@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_request_set_player_ready(player_id: int, player_ready: bool) -> void:
	if is_multiplayer_authority() && (player_id == multiplayer.get_remote_sender_id()):
		_set_player_ready(player_id, player_ready)

func _set_player_ready(player_id: int, player_ready: bool) -> bool:
	var player: Player = _get_player(player_id)
	if !is_instance_valid(player):
		return false
	
	if player.ready == player_ready:
		return false
	
	player.ready = player_ready
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_set_player_ready.rpc(player_id, player_ready)
	updated.emit()
	return true

#endregion
#region Player Spectator

func get_local_player_spectator() -> bool:
	return _local_player.spectator

func set_local_player_spectator(player_spectator: bool) -> void:
	set_player_spectator(_local_player.id, player_spectator)

func get_player_spectator(player_id: int) -> bool:
	var player: Player = _get_player(player_id)
	if is_instance_valid(player):
		return player.spectator
	return false

func set_player_spectator(player_id: int, player_spectator: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		if is_multiplayer_authority():
			_set_player_spectator(player_id, player_spectator)
		else:
			_rpc_request_set_player_spectator.rpc_id(get_multiplayer_authority(), player_id, player_spectator)

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_player_spectator(player_id: int, player_spectator: bool) -> void:
	_set_player_spectator(player_id, player_spectator)

@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_request_set_player_spectator(player_id: int, player_spectator: bool) -> void:
	if is_multiplayer_authority() && (player_id == multiplayer.get_remote_sender_id()):
		_set_player_spectator(player_id, player_spectator)

func _set_player_spectator(player_id: int, player_spectator: bool) -> bool:
	var player: Player = _get_player(player_id)
	if !is_instance_valid(player):
		return false
	
	if player.spectator == player_spectator:
		return false
	
	player.spectator = player_spectator
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_set_player_spectator.rpc(player_id, player_spectator)
	updated.emit()
	return true

#endregion
#region Player Submit

func get_all_players_submitted() -> bool:
	# If a player has just joined from spectators, their tiles will be empty.
	if !_local_player.spectator && !_local_player.submitted && !_local_player.tiles.is_empty():
		return false
	for remote_player: Player in _remote_players:
		if !remote_player.spectator && !remote_player.submitted && !remote_player.tiles.is_empty():
			return false
	return true

func set_all_players_submitted(player_submitted: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		if is_multiplayer_authority():
			for player_id: int in get_player_ids():
				_set_player_submitted(player_id, player_submitted)

func get_local_player_submitted() -> bool:
	return _local_player.submitted

func get_player_submitted(player_id: int) -> bool:
	var player: Player = _get_player(player_id)
	if is_instance_valid(player):
		return player.submitted
	return false

func set_player_submitted(player_id: int, player_submitted: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		if is_multiplayer_authority():
			_set_player_submitted(player_id, player_submitted)

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_player_submitted(player_id: int, player_submitted: bool) -> void:
	_set_player_submitted(player_id, player_submitted)

func _set_player_submitted(player_id: int, player_submitted: bool) -> bool:
	var player: Player = _get_player(player_id)
	if !is_instance_valid(player):
		return false
	
	if player.submitted == player_submitted:
		return false
	
	player.submitted = player_submitted
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_set_player_submitted.rpc(player_id, player_submitted)
	updated.emit()
	return true

#endregion
#region Player Tiles

func clear_all_player_tiles() -> void:
	if multiplayer.has_multiplayer_peer():
		if is_multiplayer_authority():
			_local_player.tiles = PackedByteArray()
			for remote_player: Player in _remote_players:
				remote_player.tiles = PackedByteArray()
			_rpc_clear_all_player_tiles.rpc()
			updated.emit()

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_clear_all_player_tiles() -> void:
	_local_player.tiles = PackedByteArray()
	for remote_player: Player in _remote_players:
		remote_player.tiles = PackedByteArray()

func get_local_player_tiles() -> Array[int]:
	var player_tiles: Array[int] = []
	for index: int in _local_player.tiles.size():
		player_tiles.append(_local_player.tiles.decode_u8(index))
	return player_tiles

func get_player_tiles(player_id: int) -> Array[int]:
	var player: Player = _get_player(player_id)
	if is_instance_valid(player):
		var player_tiles: Array[int] = []
		for index: int in player.tiles.size():
			player_tiles.append(player.tiles.decode_u8(index))
		return player_tiles
	return []

func set_player_tiles(player_id: int, player_tiles: Array[int]) -> void:
	if multiplayer.has_multiplayer_peer():
		if is_multiplayer_authority():
			var bytes: PackedByteArray = PackedByteArray()
			bytes.resize(player_tiles.size())
			for index: int in player_tiles.size():
				bytes.encode_u8(index, player_tiles[index])
			_set_player_tiles(player_id, bytes)

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_player_tiles(player_id: int, player_tiles: PackedByteArray) -> void:
	_set_player_tiles(player_id, player_tiles)

func _set_player_tiles(player_id: int, player_tiles: PackedByteArray) -> bool:
	var player: Player = _get_player(player_id)
	if !is_instance_valid(player):
		return false
	
	if player.tiles == player_tiles:
		return false
	
	player.tiles = player_tiles
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_set_player_tiles.rpc(player_id, player_tiles)
	updated.emit()
	return true

#endregion
#region Player Points

func clear_all_player_points() -> void:
	if multiplayer.has_multiplayer_peer():
		if is_multiplayer_authority():
			_clear_all_player_points()

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_clear_all_player_points() -> void:
	_clear_all_player_points()

func _clear_all_player_points() -> bool:
	_local_player.points = 0
	for remote_player: Player in _remote_players:
		remote_player.points = 0
	
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_clear_all_player_points.rpc()
	updated.emit()
	return true

func get_local_player_points() -> int:
	return _local_player.points

func get_player_points(player_id: int) -> int:
	var player: Player = _get_player(player_id)
	if is_instance_valid(player):
		return player.points
	return -1

func set_player_points(player_id: int, player_points: int) -> void:
	if multiplayer.has_multiplayer_peer():
		if is_multiplayer_authority():
			_set_player_points(player_id, player_points)

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_player_points(player_id: int, player_points: int) -> void:
	_set_player_points(player_id, player_points)

func _set_player_points(player_id: int, player_points: int) -> bool:
	var player: Player = _get_player(player_id)
	if !is_instance_valid(player):
		return false
	
	if player.points == player_points:
		return false
	
	player.points = player_points
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_set_player_points.rpc(player_id, player_points)
	updated.emit()
	return true

#endregion

func get_player_place(player_id: int) -> int:
	var player: Player = _get_player(player_id)
	if !is_instance_valid(player):
		return -1
	return player.place

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_multiplayer_connected_to_server)
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)
	
	updated.connect(_on_updated)

func _on_updated() -> void:
	# Update player places.
	var players_sorted: Array[Player] = [_local_player]
	players_sorted.append_array(_remote_players)
	players_sorted.sort_custom(_player_points_sort)
	var place: int = -1
	var place_points: int = 0
	for player: Player in players_sorted:
		if player.spectator:
			player.place = - 1
			continue
		if place == -1 || player.points < place_points:
			place += 1
			place_points = player.points
		player.place = place

func _player_points_sort(a: Player, b: Player) -> bool:
	return (a.points > b.points)

func _on_multiplayer_peer_connected(player_id: int) -> void:
	if is_multiplayer_authority():
		# Update player with server data.
		_rpc_set_player_name.rpc_id(player_id, _local_player.id, _local_player.name)
		_rpc_set_player_ready.rpc_id(player_id, _local_player.id, _local_player.ready)
		_rpc_set_player_spectator.rpc_id(player_id, _local_player.id, _local_player.spectator)
		_rpc_set_player_submitted.rpc_id(player_id, _local_player.id, _local_player.submitted)
		_rpc_set_player_tiles.rpc_id(player_id, _local_player.id, _local_player.tiles)
		_rpc_set_player_points.rpc_id(player_id, _local_player.id, _local_player.points)
		for remote_player: Player in _remote_players:
			_rpc_set_player_name.rpc_id(player_id, remote_player.id, remote_player.name)
			_rpc_set_player_ready.rpc_id(player_id, remote_player.id, remote_player.ready)
			_rpc_set_player_spectator.rpc_id(player_id, remote_player.id, remote_player.spectator)
			_rpc_set_player_submitted.rpc_id(player_id, remote_player.id, remote_player.submitted)
			_rpc_set_player_tiles.rpc_id(player_id, remote_player.id, remote_player.tiles)
			_rpc_set_player_points.rpc_id(player_id, remote_player.id, remote_player.points)
	
	var player: Player = Player.new()
	player.id = player_id
	_remote_players.append(player)
	
	updated.emit()

func _on_multiplayer_peer_disconnected(player_id: int) -> void:
	for player: Player in _remote_players:
		if player.id == player_id:
			_remote_players.erase(player)
			break
	updated.emit()

func _on_multiplayer_connected_to_server() -> void:
	_local_player.id = multiplayer.get_unique_id()
	updated.emit()

func _on_multiplayer_server_disconnected() -> void:
	_local_player = Player.new()
	_remote_players.clear()
	updated.emit()
