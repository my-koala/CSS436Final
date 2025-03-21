@tool
extends Control
class_name GameLeaderboard

const ENTRY_SCENE: PackedScene = preload("uid://cstqcudoy2wth")

@onready
var _game_data: GameData = %game_data as GameData
var _game_data_dirty: bool = false

var _entries: Dictionary[int, GameLeaderboardEntry] = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_game_data.updated.connect(_on_game_data_updated)

func _on_game_data_updated() -> void:
	_game_data_dirty = true

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if _game_data_dirty:
		_game_data_dirty = false
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
		var entry: GameLeaderboardEntry
		if _entries.has(player_id):
			entry = _entries[player_id]
		else:
			entry = ENTRY_SCENE.instantiate() as GameLeaderboardEntry
			add_child(entry)
			_entries[player_id] = entry
		
		entry.set_player_name(_game_data.get_player_name(player_id))
		entry.set_player_points(_game_data.get_player_points(player_id))
		entry.set_player_place(_game_data.get_player_place(player_id))
		
		if _game_data.get_player_spectator(player_id):
			entry.set_player_status(GameLeaderboardEntry.PlayerStatus.SPECTATOR)
		elif _game_data.get_player_submitted(player_id):
			entry.set_player_status(GameLeaderboardEntry.PlayerStatus.SUBMITTED)
		else:
			entry.set_player_status(GameLeaderboardEntry.PlayerStatus.NOT_SUBMITTED)
		
		move_child(entry, _game_data.get_player_place(player_id))
