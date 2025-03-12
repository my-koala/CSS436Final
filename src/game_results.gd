@tool
extends Control
class_name GameResults

const ENTRY_SCENE: PackedScene = preload("uid://4m1x2mfhttcy")

@onready
var _game_data: GameData = %game_data as GameData
var _game_data_dirty: bool = false
@onready
var _confetti: CPUParticles2D = $confetti as CPUParticles2D

var _entries: Dictionary[int, GameResultsEntry] = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_game_data.game_ended.connect(_on_game_data_game_ended)

func _on_game_data_game_ended() -> void:
	_game_data_dirty = true

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if _game_data_dirty:
		_game_data_dirty = false
		_confetti.emitting = true
		_refresh_entries()

func _refresh_entries() -> void:
	# Add missing entries
	var player_ids: Array[int] = _game_data.get_player_ids()
	
	# Remove missing players.
	for entry: int in _entries.keys():
		if !player_ids.has(entry):
			_entries[entry].queue_free()
			_entries.erase(entry)
	
	# Update current players, add new players.
	for player_id: int in player_ids:
		var entry: GameResultsEntry
		if _entries.has(player_id):
			entry = _entries[player_id]
		else:
			entry = ENTRY_SCENE.instantiate() as GameResultsEntry
			add_child(entry)
			_entries[player_id] = entry
		
		entry.set_player_name(_game_data.get_player_name(player_id))
		entry.set_player_points(_game_data.get_player_points(player_id))
		entry.set_player_place(_game_data.get_player_place(player_id))
		
		move_child(entry, _game_data.get_player_place(player_id))
