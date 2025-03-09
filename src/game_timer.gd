@tool
extends Label
class_name GameTimer

signal timeout()

# Time in seconds.
var _time: float = 0.0

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_time(time: float) -> void:
	_time = time

func get_time() -> float:
	return _time

func set_time(time: float) -> void:
	_time = maxf(time, 0.0)
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_set_time.rpc(time)

var _turn: int = 0

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_turn(turn: int) -> void:
	_turn = turn

func get_turn() -> int:
	return _turn

func set_turn(turn: int) -> void:
	_turn = maxi(turn, 0)
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_set_turn.rpc(_turn)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)

func _on_multiplayer_peer_connected(peer_id: int) -> void:
	if is_multiplayer_authority():
		_rpc_set_time.rpc_id(peer_id, _time)
		_rpc_set_turn.rpc_id(peer_id, _turn)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	_time = maxf(_time - delta, 0.0)
	
	text = "Turn: %d | Time Left: %d:%02d" % [_turn, int(_time / 60.0), int(fmod(_time, 60.0))]
