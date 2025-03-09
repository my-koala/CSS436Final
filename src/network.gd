# code by my-koala ͼ•ᴥ•ͽ #
@tool
extends Node
class_name Network

## Wrapper node for multiplayer.

# NOTE: Offline server: 127.0.0.1:4000
# NOTE: Supplied multiplayer.multiplayer_peer must be connecting or connected.
# NOTE: This uses Web Socket Multiplayer.

# TODO: Steam integration.
# TODO: X509Certificate

const MAX_PLAYERS: int = 100

## Path to node to set as root for multiplayer branch.
## Leave null for scene tree root.
@export
var multiplayer_root: Node = null

var _multiplayer_api: SceneMultiplayer = SceneMultiplayer.new()

func _ready() -> void:
	_multiplayer_api.multiplayer_peer = null

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	var multiplayer_root_path: NodePath = get_tree().root.get_path()
	if is_instance_valid(multiplayer_root) && multiplayer_root.is_inside_tree():
		multiplayer_root_path = multiplayer_root.get_path()
	if get_tree().get_multiplayer(multiplayer_root_path) != _multiplayer_api:
		get_tree().set_multiplayer(_multiplayer_api, multiplayer_root_path)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	var multiplayer_root_path: NodePath = get_tree().root.get_path()
	if is_instance_valid(multiplayer_root) && multiplayer_root.is_inside_tree():
		multiplayer_root_path = multiplayer_root.get_path()
	if get_tree().get_multiplayer(multiplayer_root_path) == _multiplayer_api:
		get_tree().set_multiplayer(null, multiplayer_root_path)

func is_active() -> bool:
	return _multiplayer_api.has_multiplayer_peer()

func is_server() -> bool:
	return _multiplayer_api.has_multiplayer_peer() && _multiplayer_api.is_server()

func is_client() -> bool:
	return _multiplayer_api.has_multiplayer_peer() && !_multiplayer_api.is_server()

## Starts server (leave default arguments for offline).
## Returns OK if successfully created server.
## Returns ERR_ALREADY_IN_USE if a connection is currently active.
## Returns ERR_CANT_CREATE if server could not be created.
func host_server(port: int = 4000) -> Error:
	# Return error if a connection is currently active.
	if _multiplayer_api.has_multiplayer_peer():
		push_error("Network | Failed to host server on port %d: a connection is already active." % [port])
		return ERR_ALREADY_IN_USE
	
	# Create server and return error.
	var multiplayer_peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	var error: Error = multiplayer_peer.create_server(port, "*", null)
	
	if error == OK:
		_multiplayer_api.multiplayer_peer = multiplayer_peer
		print("Network | Hosted server on port %d." % [port])
	else:
		push_error("Network | Failed to host server on port %d: server could not be created." % [port])
	return error

## Stops active server.
## Returns OK if successfully stopped server.
## Returns ERR_DOES_NOT_EXIST if not hosting server.
func stop_server() -> Error:
	# Return error if not currently hosting a server.
	if !_multiplayer_api.has_multiplayer_peer() || !_multiplayer_api.is_server():
		push_error("Network | Failed to stop server: not currently hosting a server.")
		return ERR_DOES_NOT_EXIST
	
	# Disconnect all peers and stop server.
	var peer_ids: PackedInt32Array = _multiplayer_api.get_peers()
	for peer_id: int in peer_ids:
		_multiplayer_api.multiplayer_peer.disconnect_peer(peer_id, false)
	_multiplayer_api.multiplayer_peer.close()
	
	print("Network | Stopped server.")
	return OK

signal _connection_updated()

## Asynchronously creates client and starts connection to a server.
## Returns OK if successfully created client.
## Returns ERR_ALREADY_IN_USE if a connection is currently active.
## Returns ERR_CANT_CREATE if client could not be created.
## Returns ERR_CANT_CONNECT if client could not connect.
func join_server(address: String = "127.0.0.1", port: int = 4000) -> Error:
	# Return error if a connection is currently active.
	if _multiplayer_api.has_multiplayer_peer():
		push_error("Network | Failed to join server '%s:%d': a connection is already active." % [address, port])
		return ERR_ALREADY_IN_USE
	
	# Create client and return error.
	var multiplayer_peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	
	var error: Error = multiplayer_peer.create_client(address + ":" + str(port), null)
	if error != OK:
		push_error("Network | Failed to join server '%s:%d': could not connect." % [address, port])
		return error
	
	_multiplayer_api.multiplayer_peer = multiplayer_peer
	while _multiplayer_api.multiplayer_peer.get_connection_status() == MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTING:
		await get_tree().physics_frame
	
	if _multiplayer_api.multiplayer_peer.get_connection_status() != MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED:
		push_error("Network | Failed to join server '%s:%d': disconnected." % [address, port])
		_multiplayer_api.multiplayer_peer.close()
		_multiplayer_api.set_deferred(&"multiplayer_peer", null)
		return ERR_CANT_CONNECT
	
	print("Network | Joined server '%s:%d'." % [address, port])
	return error

## Stops client and disconnects from server.
## Returns OK if successfully disconnected from server.
## Returns ERR_DOES_NOT_EXIST if not connected to a server.
func quit_server() -> Error:
	# Return error if not connected to a server.
	if !_multiplayer_api.has_multiplayer_peer() || _multiplayer_api.is_server():
		push_error("Network | Failed to quit server: not currently connected to a server.")
		return ERR_DOES_NOT_EXIST
	
	# Stop connection to server.
	_multiplayer_api.multiplayer_peer.close()
	print("Network | Disconnected from server.")
	return OK
