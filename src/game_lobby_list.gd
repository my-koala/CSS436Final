@tool
extends Control
class_name GameLobbyList

const ENTRY_SCENE: PackedScene = preload("uid://di17ysaiamnvl")

@onready
var _game_data: GameData = %game_data as GameData
var _game_data_dirty: bool = false

var _entries: Dictionary[int, GameLobbyListEntry] = {}

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
		var entry: GameLobbyListEntry
		if _entries.has(player_id):
			entry = _entries[player_id]
		else:
			entry = ENTRY_SCENE.instantiate() as GameLobbyListEntry
			add_child(entry)
			_entries[player_id] = entry
		
		entry.set_player_name(_game_data.get_player_name(player_id))
		
		if _game_data.get_player_spectator(player_id):
			entry.set_player_status(GameLobbyListEntry.PlayerStatus.SPECTATOR)
		elif _game_data.get_player_ready(player_id):
			entry.set_player_status(GameLobbyListEntry.PlayerStatus.READY)
		else:
			entry.set_player_status(GameLobbyListEntry.PlayerStatus.NOT_READY)
	
	# Move spectators to bottom.
	for player_id: int in player_ids:
		if _game_data.get_player_spectator(player_id):
			move_child(_entries[player_id], -1)
