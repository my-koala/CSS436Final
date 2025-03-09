@tool
extends Node
class_name GamePlayers

# player names are only set by each player

const PLAYER_NAME_MAX_LENGTH: int = 16

class Player:
	var id: int = 1
	var name: String = "Player"
	var spectator: bool = false
	var ready: bool = false
	var submitted: bool = false
	var points: int = 0

signal updated()

static func is_valid_player_name(player_name: String) -> bool:
	if player_name.is_empty():
		return false
	if player_name.contains("\n"):
		return false
	if player_name.length() > PLAYER_NAME_MAX_LENGTH:
		return false
	return true

var _local_player: Player = Player.new()

var _players: Array[Player] = []

func get_player_ids() -> Array[int]:
	var player_ids: Array[int] = []
	player_ids.append(_local_player.id)
	for player: Player in _players:
		player_ids.append(player.id)
	return player_ids

func _get_player(player_id: int) -> Player:
	if player_id == _local_player.id:
		return _local_player
	for player: Player in _players:
		if player.id == player_id:
			return player
	return null

#region Player Name

func get_local_player_name() -> String:
	return _local_player.name

func set_local_player_name(player_name: String) -> void:
	if !is_valid_player_name(player_name):
		return
	_local_player.name = player_name
	
	if multiplayer.has_multiplayer_peer() && !is_multiplayer_authority() && multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_rpc_set_player_name_request.rpc_id(get_multiplayer_authority(), player_name)

func get_player_name(player_id: int) -> String:
	var player: Player = _get_player(player_id)
	if is_instance_valid(player):
		return player.name
	return ""

func _set_player_name(player_id: int, player_name: String) -> bool:
	if !is_valid_player_name(player_name):
		return false
	
	var player: Player = _get_player(player_id)
	if !is_instance_valid(player):
		return false
	
	player.name = player_name
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_player_name(player_id: int, player_name: String) -> void:
	_set_player_name(player_id, player_name)

@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_set_player_name_request(player_name: String) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if _set_player_name(player_id, player_name):
		_rpc_set_player_name.rpc(player_id, player_name)

#endregion
#region Player Ready

func get_local_player_ready() -> bool:
	return _local_player.ready

func set_local_player_ready(player_ready: bool) -> void:
	_local_player.ready = player_ready
	if multiplayer.has_multiplayer_peer() && !is_multiplayer_authority() && multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_rpc_set_player_ready_request.rpc_id(get_multiplayer_authority(), player_ready)

func get_all_players_ready() -> bool:
	if _players.is_empty() && _local_player.spectator:
		return false
	if !_local_player.spectator && !_local_player.ready:
		return false
	for player: Player in _players:
		if !player.spectator && !player.ready:
			return false
	return true

func set_all_players_ready(player_ready: bool) -> void:
	set_local_player_ready(player_ready)
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		for player_id: int in get_player_ids():
			_set_player_ready(player_id, player_ready)
			_rpc_set_player_ready.rpc(player_id, player_ready)

func get_player_ready(player_id: int) -> bool:
	var player: Player = _get_player(player_id)
	if is_instance_valid(player):
		return player.ready
	return false

func _set_player_ready(player_id: int, player_ready: bool) -> bool:
	var player: Player = _get_player(player_id)
	if !is_instance_valid(player):
		return false
	
	player.ready = player_ready
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_player_ready(player_id: int, player_ready: bool) -> void:
	_set_player_ready(player_id, player_ready)

@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_set_player_ready_request(player_ready: bool) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if _set_player_ready(player_id, player_ready):
		_rpc_set_player_ready.rpc(player_id, player_ready)

#endregion
#region Player Spectator #

func get_local_player_spectator() -> bool:
	return _local_player.spectator

func set_local_player_spectator(player_spectator: bool) -> void:
	_local_player.spectator = player_spectator
	if multiplayer.has_multiplayer_peer() && !is_multiplayer_authority() && multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_rpc_set_player_spectator_request.rpc_id(get_multiplayer_authority(), player_spectator)

func get_player_spectator(player_id: int) -> bool:
	var player: Player = _get_player(player_id)
	if is_instance_valid(player):
		return player.spectator
	return false

func _set_player_spectator(player_id: int, player_spectator: bool) -> bool:
	var player: Player = _get_player(player_id)
	if !is_instance_valid(player):
		return false
	
	player.spectator = player_spectator
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_player_spectator(player_id: int, player_spectator: bool) -> void:
	_set_player_spectator(player_id, player_spectator)

@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_set_player_spectator_request(player_spectator: bool) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if _set_player_spectator(player_id, player_spectator):
		_rpc_set_player_spectator.rpc(player_id, player_spectator)

#endregion

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_multiplayer_connected_to_server)
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)

func _on_multiplayer_peer_connected(player_id: int) -> void:
	if is_multiplayer_authority():
		_rpc_set_player_name.rpc_id(player_id, _local_player.id, _local_player.name)
		_rpc_set_player_ready.rpc_id(player_id, _local_player.id, _local_player.ready)
		_rpc_set_player_spectator.rpc_id(player_id, _local_player.id, _local_player.spectator)
		for player: Player in _players:
			_rpc_set_player_name.rpc_id(player_id, player.id, player.name)
			_rpc_set_player_ready.rpc_id(player_id, player.id, player.ready)
			_rpc_set_player_spectator.rpc_id(player_id, player.id, player.spectator)
	
	var new_player: Player = Player.new()
	new_player.id = player_id
	_players.append(new_player)
	
	updated.emit()

func _on_multiplayer_peer_disconnected(player_id: int) -> void:
	for player: Player in _players:
		if player.id == player_id:
			_players.erase(player)
			break
	updated.emit()

func _on_multiplayer_connected_to_server() -> void:
	_local_player.id = multiplayer.get_unique_id()
	_rpc_set_player_name_request.rpc_id(get_multiplayer_authority(), _local_player.name)
	_rpc_set_player_ready_request.rpc_id(get_multiplayer_authority(), _local_player.ready)
	_rpc_set_player_spectator_request.rpc_id(get_multiplayer_authority(), _local_player.spectator)
	updated.emit()

func _on_multiplayer_server_disconnected() -> void:
	_local_player.id = 1
	_players.clear()
	updated.emit()
