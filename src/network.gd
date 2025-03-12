# code by my-koala ͼ•ᴥ•ͽ #
@tool
extends Node
class_name Network

## MyKoala's wrapper node for multiplayer.

# NOTE: Offline: 127.0.0.1
# NOTE: Supplied multiplayer.multiplayer_peer must be connecting or connected.
# NOTE: Currently configured using Web Socket Multiplayer.

const MAX_PLAYERS: int = 100

const CERTIFICATE_PATH: String = "res://certificate.pem"
const PRIVATE_KEY_PATH: String = "private_key.pem"

## Path to node to set as root for multiplayer branch.
## Leave null for scene tree root.
@export
var multiplayer_root: Node = null

var _multiplayer_api: SceneMultiplayer = SceneMultiplayer.new()

func _ready() -> void:
	_multiplayer_api.multiplayer_peer = null
	_multiplayer_api.server_disconnected.connect(_on_multiplayer_api_server_disconnected)

func _on_multiplayer_api_server_disconnected() -> void:
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
		push_error("Network (Server) | Failed to host server on port %d (a connection is already active)." % [port])
		return ERR_ALREADY_IN_USE
	
	# Load private key.
	var key: CryptoKey = CryptoKey.new()
	var key_file: FileAccess = FileAccess.open(PRIVATE_KEY_PATH, FileAccess.READ)
	if !is_instance_valid(key_file):
		print("Network (Server) | Could not load private key (file read failed).")
		key = null
	elif key.load_from_string(key_file.get_as_text()) != OK:
		print("Network (Server) | Could not load private key (invalid file format).")
		key = null
	else:
		print("Network (Server) | Loaded private key.")
	
	# Load full-chain certificate.
	var certificate: X509Certificate = X509Certificate.new()
	var certificate_file: FileAccess = FileAccess.open(CERTIFICATE_PATH, FileAccess.READ)
	if !is_instance_valid(certificate_file):
		print("Network (Server) | Could not load certificate (file read failed).")
		certificate = null
	elif certificate.load_from_string(certificate_file.get_as_text()) != OK:
		print("Network (Server) | Could not load certificate (invalid file format).")
		certificate = null
	else:
		print("Network (Server) | Loaded certificate.")
	
	var tls_options: TLSOptions = null
	if !is_instance_valid(key) || !is_instance_valid(certificate):
		print("Network (Server) | Hosting server without private key and certificate.")
		tls_options = null
	else:
		print("Network (Server) | Hosting server with private key and certificate.")
		tls_options = TLSOptions.server(key, certificate)
	
	# Create server and return error.
	var multiplayer_peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	var error: Error = multiplayer_peer.create_server(port, "*", tls_options)
	
	if error == OK:
		print("Network (Server) | Hosted server on port %d." % [port])
		_multiplayer_api.multiplayer_peer = multiplayer_peer
	else:
		push_error("Network (Server) | Failed to host server on port %d (server could not be created)." % [port])
	return error

## Stops active server.
## Returns OK if successfully stopped server.
## Returns ERR_DOES_NOT_EXIST if not hosting server.
func stop_server() -> Error:
	# Return error if not currently hosting a server.
	if !_multiplayer_api.has_multiplayer_peer() || !_multiplayer_api.is_server():
		push_error("Network (Server) | Failed to stop server (not currently hosting a server).")
		return ERR_DOES_NOT_EXIST
	
	# Disconnect all peers and stop server.
	var peer_ids: PackedInt32Array = _multiplayer_api.get_peers()
	for peer_id: int in peer_ids:
		_multiplayer_api.multiplayer_peer.disconnect_peer(peer_id, false)
	_multiplayer_api.multiplayer_peer.close()
	
	print("Network (Server) | Stopped server.")
	return OK

## Asynchronously creates client and starts connection to a server.
## Returns OK if successfully created client.
## Returns ERR_ALREADY_IN_USE if a connection is currently active.
## Returns ERR_CANT_CREATE if client could not be created.
## Returns ERR_CANT_CONNECT if client could not connect.
func join_server(address: String = "127.0.0.1", port: int = 4000, unsafe: bool = false) -> Error:
	# Return error if a connection is currently active.
	if _multiplayer_api.has_multiplayer_peer():
		push_error("Network (Client) | Failed to join server '%s:%d' (a connection is already active)." % [address, port])
		return ERR_ALREADY_IN_USE
	
	# NOTE: Client certificate is optional.
	# See: https://github.com/godotengine/godot/blob/master/thirdparty/certs/ca-certificates.crt
	
	# Load certificate.
	var certificate: X509Certificate = X509Certificate.new()
	var certificate_file: FileAccess = FileAccess.open(CERTIFICATE_PATH, FileAccess.READ)
	if !is_instance_valid(certificate_file):
		print("Network (Client) | Could not load certificate (file read failed).")
		certificate = null
	elif certificate.load_from_string(certificate_file.get_as_text()) != OK:
		print("Network (Client) | Could not load certificate (invalid file format).")
		certificate = null
	else:
		print("Network (Client) | Loaded certificate.")
	
	var tls_options: TLSOptions
	if unsafe || !is_instance_valid(certificate):
		print("Network (Client) | Joining server without custom certificate.")
		tls_options = null
	else:
		print("Network (Client) | Joining server with custom certificate.")
		tls_options = TLSOptions.client(certificate)
	
	# Create client and return error.
	var multiplayer_peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	
	var url: String = "wss://" + address + ":" + str(port)
	if unsafe:
		url = address + ":" + str(port)
	var error: Error = multiplayer_peer.create_client(url, tls_options)
	if error != OK:
		push_error("Network (Client) | Failed to join server '%s:%d' (could not connect)." % [address, port])
		return error
	
	_multiplayer_api.multiplayer_peer = multiplayer_peer
	print("Network (Client) | Joining server '%s:%d'..." % [address, port])
	
	while _multiplayer_api.multiplayer_peer.get_connection_status() == MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTING:
		await get_tree().physics_frame
	
	if _multiplayer_api.multiplayer_peer.get_connection_status() != MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED:
		push_error("Network (Client) | Failed to join server '%s:%d' (disconnected)." % [address, port])
		_multiplayer_api.multiplayer_peer.close()
		_multiplayer_api.set_deferred(&"multiplayer_peer", null)
		return ERR_CANT_CONNECT
	
	print("Network (Client) | Joined server '%s:%d'." % [address, port])
	return error

## Stops client and disconnects from server.
## Returns OK if successfully disconnected from server.
## Returns ERR_DOES_NOT_EXIST if not connected to a server.
func quit_server() -> Error:
	# Return error if not connected to a server.
	if !_multiplayer_api.has_multiplayer_peer() || _multiplayer_api.is_server():
		push_error("Network (Client) | Failed to quit server (not currently connected to a server).")
		return ERR_DOES_NOT_EXIST
	
	# Stop connection to server.
	print("Network (Client) | Quit server.")
	_multiplayer_api.multiplayer_peer.close()
	return OK
