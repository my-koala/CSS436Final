@tool
extends Button

@export
var game_players: GamePlayers = null:
	get:
		return game_players
	set(value):
		game_players = value

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	game_players.set_local_player_ready(!game_players.get_local_player_ready())

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if !game_players.get_local_player_ready():
		text = "Click to READY"
	else:
		text = "Click to UNREADY"
