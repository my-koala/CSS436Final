@tool
extends Button
class_name GameLobbyReady

@onready
var _game_data: GameData = $"../../../game_data" as GameData
var _game_data_dirty: bool = false
func _on_game_data_updated() -> void:
	_game_data_dirty = true

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	pressed.connect(_on_button_ready_pressed)
	_game_data.updated.connect(_on_game_data_updated)

func _on_button_ready_pressed() -> void:
	_game_data.set_local_player_ready(!_game_data.get_local_player_ready())

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if _game_data_dirty:
		_game_data_dirty = false
		if !_game_data.get_local_player_ready():
			text = "Click to READY"
		else:
			text = "Click to UNREADY"
