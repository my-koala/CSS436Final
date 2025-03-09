@tool
extends Control
class_name MenuConfig

signal player_name_submitted(player_name: String)
signal network_join_request()

enum State {
	NONE,
	NAME,
	NETWORK,
}
var _state: State = State.NONE

@onready
var _name: Control = $name as Control
@onready
var _name_line_edit: LineEdit = $name/line_edit as LineEdit
@onready
var _name_button_submit: Button = $name/button_submit as Button

@onready
var _network: Control = $network as Control
@onready
var _network_label_status: Label = $network/label_status as Label
@onready
var _network_v_box_container: VBoxContainer = $network/v_box_container as VBoxContainer
@onready
var _network_button_join: Button = $network/v_box_container/button_join as Button
@onready
var _network_line_edit_address: LineEdit = $network/v_box_container/address/line_edit_address as LineEdit
@onready
var _network_line_edit_port: LineEdit = $network/v_box_container/port/line_edit_port as LineEdit
var _network_line_edit_port_text: String = ""

var _auto_connect: bool = false

func get_player_name() -> String:
	return _name_line_edit.text

func get_network_address() -> String:
	return _network_line_edit_address.text

func get_network_port() -> int:
	return _network_line_edit_port.text.to_int()

func set_network_details(address: String, port: int, auto_connect: bool = false) -> void:
	_network_line_edit_address.text = address
	_network_line_edit_port.text = str(port)
	_auto_connect = auto_connect

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_name_button_submit.pressed.connect(_on_name_button_submit_pressed)
	_network_button_join.pressed.connect(_on_network_button_join_pressed)
	
	set_state(State.NONE)

func _on_name_button_submit_pressed() -> void:
	if GamePlayers.is_valid_player_name(get_player_name()):
		set_state(State.NETWORK)
		player_name_submitted.emit()

func _on_join_line_edit_port_text_changed(new_text: String) -> void:
	if !new_text.is_empty() && (!new_text.is_valid_int() || new_text[0] == "+" || new_text[0] == "-"):
		_network_line_edit_port.text = _network_line_edit_port_text
	else:
		_network_line_edit_port_text = _network_line_edit_port.text

func _on_network_button_join_pressed() -> void:
	var address: String = _network_line_edit_address.text
	var port: int = _network_line_edit_port.text.to_int()
	network_join_request.emit()

func set_state(state: State) -> void:
	_state = state
	match _state:
		State.NONE:
			visible = false
			_name.visible = false
			_network.visible = false
		State.NAME:
			visible = true
			_name.visible = true
			_network.visible = false
		State.NETWORK:
			visible = true
			_name.visible = false
			_network.visible = true
			
			if _auto_connect:
				_auto_connect = false
				network_join_request.emit()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	_name_button_submit.disabled = !GamePlayers.is_valid_player_name(_name_button_submit.name)
	
	if multiplayer.has_multiplayer_peer():
		if !multiplayer.is_server():
			match multiplayer.multiplayer_peer.get_connection_status():
				MultiplayerPeer.ConnectionStatus.CONNECTION_DISCONNECTED:
					_network_label_status.text = "Disconnected from server."
					_network_v_box_container.visible = true
				MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTING:
					_network_label_status.text = "Connecting to server ..."
					_network_v_box_container.visible = false
				MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED:
					_network_label_status.text = "Connected to server."
					_network_v_box_container.visible = false
		else:
			_network_label_status.text = "Server hosted."
			_network_v_box_container.visible = false
	else:
		_network_label_status.text = "Not connected."
		_network_v_box_container.visible = true
