@tool
extends Control
class_name MenuNetwork

signal join_request(address: String, port: int)
signal host_request(port: int)
signal stop_request()

enum State {
	NONE,
	MAIN,
	HOST,
	JOIN,
	STATUS,
}
var _state: State = State.NONE

@onready
var _button_toggle: Button = $button_toggle

@onready
var _panel: Panel = $panel as Panel

@onready
var _main: Control = $panel/main as Control
@onready
var _main_button_host: Button = $panel/main/v_box_container/button_host as Button
@onready
var _main_button_join: Button = $panel/main/v_box_container/button_join as Button

@onready
var _host: Control = $panel/host as Control
@onready
var _host_line_edit_port: LineEdit = $panel/host/v_box_container/port/line_edit_port as LineEdit
@onready
var _host_button_host: Button = $panel/host/v_box_container/button_host as Button
@onready
var _host_button_back: Button = $panel/host/v_box_container/button_back as Button

var _host_line_edit_port_text: String = ""

@onready
var _join: Control = $panel/join as Control
@onready
var _join_line_edit_address: LineEdit = $panel/join/v_box_container/address/line_edit_address as LineEdit
@onready
var _join_line_edit_port: LineEdit = $panel/join/v_box_container/port/line_edit_port as LineEdit
@onready
var _join_button_join: Button = $panel/join/v_box_container/button_join as Button
@onready
var _join_button_back: Button = $panel/join/v_box_container/button_back as Button

var _join_line_edit_port_text: String = ""

@onready
var _status: Control = $panel/status as Control
@onready
var _status_label_status: Label = $panel/status/v_box_container/label_status as Label
@onready
var _status_button_back: Button = $panel/status/v_box_container/button_back as Button

@onready
var _network_test: Control = $network_test as Control

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_button_toggle.pressed.connect(_on_button_toggle_pressed)
	
	_host_line_edit_port.text_changed.connect(_on_host_line_edit_port_text_changed)
	_join_line_edit_port.text_changed.connect(_on_join_line_edit_port_text_changed)
	
	_main_button_host.pressed.connect(set_state.bind(State.HOST))
	_main_button_join.pressed.connect(set_state.bind(State.JOIN))
	
	_host_button_host.pressed.connect(_host_server)
	_host_button_back.pressed.connect(set_state.bind(State.MAIN))
	
	_join_button_join.pressed.connect(_join_server)
	_join_button_back.pressed.connect(set_state.bind(State.MAIN))
	
	_status_button_back.pressed.connect(_stop_connection)
	
	set_state(_state)

func _on_button_toggle_pressed() -> void:
	if _state == State.NONE:
		set_state(State.MAIN)
	else:
		set_state(State.NONE)

func _host_server() -> void:
	var port: int = _host_line_edit_port.text.to_int()
	host_request.emit(port)
	set_state(State.STATUS)

func _join_server() -> void:
	var address: String = _join_line_edit_address.text
	var port: int = _join_line_edit_port.text.to_int()
	join_request.emit(address, port)
	set_state(State.STATUS)

func _stop_connection() -> void:
	stop_request.emit()
	set_state(State.MAIN)

func _on_host_line_edit_port_text_changed(new_text: String) -> void:
	if !new_text.is_empty() && (!new_text.is_valid_int() || new_text[0] == "+" || new_text[0] == "-"):
		_host_line_edit_port.text = _host_line_edit_port_text
	else:
		_host_line_edit_port_text = _host_line_edit_port.text

func _on_join_line_edit_port_text_changed(new_text: String) -> void:
	if !new_text.is_empty() && (!new_text.is_valid_int() || new_text[0] == "+" || new_text[0] == "-"):
		_join_line_edit_port.text = _join_line_edit_port_text
	else:
		_join_line_edit_port_text = _join_line_edit_port.text

func set_state(state: State) -> void:
	_state = state
	match state:
		State.NONE:
			_network_test.visible = false
			
			_panel.visible = false
			_main.visible = false
			_host.visible = false
			_join.visible = false
			_status.visible = false
			
			_button_toggle.grab_focus()
		State.MAIN:
			_network_test.visible = true
			
			_panel.visible = true
			_main.visible = true
			_host.visible = false
			_join.visible = false
			_status.visible = false
			
			_main_button_host.grab_focus()
		State.HOST:
			_network_test.visible = true
			
			_panel.visible = true
			_main.visible = false
			_host.visible = true
			_join.visible = false
			_status.visible = false
			
			_host_line_edit_port.grab_focus()
		State.JOIN:
			_network_test.visible = true
			
			_panel.visible = true
			_main.visible = false
			_host.visible = false
			_join.visible = true
			_status.visible = false
			
			_join_line_edit_address.grab_focus()
		State.STATUS:
			_network_test.visible = true
			
			_panel.visible = true
			_main.visible = false
			_host.visible = false
			_join.visible = false
			_status.visible = true
			
			_status_button_back.grab_focus()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if _state == State.STATUS:
		if multiplayer.has_multiplayer_peer():
			if !multiplayer.is_server():
				match multiplayer.multiplayer_peer.get_connection_status():
					MultiplayerPeer.ConnectionStatus.CONNECTION_DISCONNECTED:
						_status_label_status.text = "Disconnected from server."
					MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTING:
						_status_label_status.text = "Connecting to server ..."
					MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED:
						_status_label_status.text = "Connected to server."
			else:
				_status_label_status.text = "Server hosted."
		else:
			_status_label_status.text = "Not connected."
	else:
		_status_label_status.text = ""
