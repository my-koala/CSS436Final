@tool
extends Control
class_name GameLobby

# Handles lobby display with player list (ready state and spectators).
# TODO: Leaderboard of previous game.

signal all_players_ready()

@export
var game_data: GameData = null:
	get:
		return game_data
	set(value):
		if game_data != value:
			if is_instance_valid(game_data):
				game_data.updated.disconnect(_on_game_data_updated)
			game_data = value
			if is_instance_valid(game_data):
				game_data.updated.connect(_on_game_data_updated)

var _game_data_dirty: bool = false
func _on_game_data_updated() -> void:
	_game_data_dirty = true

var active: bool = false

@onready
var _button_ready: Button = $button_ready as Button

@onready
var _player_list_label_name: RichTextLabel = $panel_players/scroll_container/player_list/label_name as RichTextLabel
@onready
var _player_list_label_ready: RichTextLabel = $panel_players/scroll_container/player_list/label_ready as RichTextLabel

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_button_ready.pressed.connect(_on_button_ready_pressed)

func _on_button_ready_pressed() -> void:
	if active:
		game_data.set_local_player_ready(!game_data.get_local_player_ready())

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if !active:
		return
	
	if !_game_data_dirty:
		return
	_game_data_dirty = false
	
	if !game_data.get_local_player_ready():
		_button_ready.text = "Click to READY"
	else:
		_button_ready.text = "Click to UNREADY"
	
	_player_list_label_name.text = ""
	_player_list_label_name.clear()
	_player_list_label_ready.text = ""
	_player_list_label_ready.clear()
	var list_notready: Array[String] = []
	var list_ready: Array[String] = []
	var list_spectator: Array[String] = []
	for player_id: int in game_data.get_player_ids():
		var player_name: String = game_data.get_player_name(player_id)
		if game_data.get_player_spectator(player_id):
			list_spectator.append(player_name)
		elif game_data.get_player_ready(player_id):
			list_ready.append(player_name)
		else:
			list_notready.append(player_name)
	
	for player_name: String in list_ready:
		_player_list_label_name.append_text("[color=white]%s[/color]\n" % [player_name])
		_player_list_label_ready.append_text("[color=green]%s[/color]\n" % ["READY"])
	for player_name: String in list_notready:
		_player_list_label_name.append_text("[color=white]%s[/color]\n" % [player_name])
		_player_list_label_ready.append_text("[color=red]%s[/color]\n" % ["NOT READY"])
	for player_name: String in list_spectator:
		_player_list_label_name.append_text("[color=white]%s[/color]\n" % [player_name])
		_player_list_label_ready.append_text("[color=gray]%s[/color]\n" % ["SPECTATOR"])
