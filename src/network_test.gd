@tool
extends Control

@onready
var _test_line_edit: LineEdit = $line_edit as LineEdit
@onready
var _test_button_reliable: Button = $button_reliable as Button
@onready
var _test_button_unreliable: Button = $button_unreliable as Button

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_test_button_reliable.pressed.connect(_on_test_button_reliable_pressed)
	_test_button_unreliable.pressed.connect(_on_test_button_unreliable_pressed)

@rpc("any_peer", "call_remote", "reliable", 0)
func _message_reliable(message: String) -> void:
	print("%d: Received reliable message from peer %d: %s" % [multiplayer.get_unique_id(), multiplayer.get_remote_sender_id(), message])

@rpc("any_peer", "call_remote", "unreliable", 0)
func _message_unreliable(message: String) -> void:
	print("%d: Received unreliable message from peer %d: %s" % [multiplayer.get_unique_id(), multiplayer.get_remote_sender_id(), message])

func _on_test_button_reliable_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		_message_reliable.rpc(_test_line_edit.text)
		print("Sent reliable message.")
	else:
		print("Could not send reliable message: not connected!")

func _on_test_button_unreliable_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		_message_unreliable.rpc(_test_line_edit.text)
		print("Sent unreliable message.")
	else:
		print("Could not send unreliable message: not connected!")
