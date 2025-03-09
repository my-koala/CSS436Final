@tool
extends RichTextLabel

@export
var game_players: GamePlayers = null:
	get:
		return game_players
	set(value):
		if game_players != value:
			if is_instance_valid(game_players):
				game_players.updated.disconnect(_on_game_players_updated)
			game_players = value
			if is_instance_valid(game_players):
				game_players.updated.connect(_on_game_players_updated)

@onready
var _label_ready: RichTextLabel = $label_ready as RichTextLabel

var _dirty: bool = false

func _on_game_players_updated() -> void:
	_dirty = true

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if !is_visible_in_tree():
		return
	
	if !is_instance_valid(game_players):
		return
	
	if !_dirty:
		return
	_dirty = false
	
	clear()
	text = ""
	_label_ready.clear()
	_label_ready.text = ""
	var a: Array[String] = []
	var b: Array[String] = []
	var c: Array[String] = []
	for player_id: int in game_players.get_player_ids():
		var player_name: String = game_players.get_player_name(player_id)
		if game_players.get_player_spectator(player_id):
			a.append(player_name)
		elif game_players.get_player_ready(player_id):
			b.append(player_name)
		else:
			c.append(player_name)
	
	for player_name: String in b:
		append_text("[color=white]%s[/color]\n" % [player_name])
		_label_ready.append_text("[color=green]%s[/color]\n" % ["READY"])
	for player_name: String in c:
		append_text("[color=white]%s[/color]\n" % [player_name])
		_label_ready.append_text("[color=red]%s[/color]\n" % ["NOT READY"])
	for player_name: String in a:
		append_text("[color=white]%s[/color]\n" % [player_name])
		_label_ready.append_text("[color=gray]%s[/color]\n" % ["SPECTATOR"])
