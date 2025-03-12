@tool
extends Button
class_name GameLobbyListEntry

# TODO:
# add spectator icon, gold silver bronze icons

enum PlayerStatus {
	NOT_READY,
	READY,
	SPECTATOR,
}

@onready
var _color_rect: ColorRect = $color_rect as ColorRect
@onready
var _content_label_name: RichTextLabel = $content/label_name as RichTextLabel
@onready
var _content_label_status: RichTextLabel = $content/label_status as RichTextLabel

func set_player_name(player_name: String) -> void:
	if player_name == "James" || player_name == "MyKoala":
		_content_label_name.text = "[color=gold][b]%s[/b][/color]" % [player_name]
	elif player_name.to_lower() == "tim" || player_name.to_lower() == "sl1ghtly":
		_content_label_name.text = "[color=brown]%s[/color]" % [player_name]
	elif player_name.to_lower() == "anoop" || player_name.to_lower() == "sonpac":
		_content_label_name.text = "[color=blue]%s[/color]" % [player_name]
	else:
		_content_label_name.text = "[color=white]%s[/color]" % [player_name]

func set_player_status(player_status: PlayerStatus) -> void:
	match player_status:
		PlayerStatus.NOT_READY:
			_color_rect.color = Color(1.0, 0.0, 0.0, 0.375)
			_content_label_status.text = "[color=red]Not Ready[/color]"
		PlayerStatus.READY:
			_color_rect.color = Color(0.5, 0.625, 0.375, 0.75)
			_content_label_status.text = "[color=green]Ready[/color]"
		PlayerStatus.SPECTATOR:
			_color_rect.color = Color(0.1, 0.1, 0.1, 0.75)
			_content_label_status.text = "[color=grey]Spectator[/color]"
