@tool
extends Node
class_name GameLeaderboardEntry

# TODO:
# add spectator icon, gold silver bronze icons

enum PlayerStatus {
	NOT_SUBMITTED,
	SUBMITTED,
	SPECTATOR,
}

@onready
var _color_rect: ColorRect = $color_rect as ColorRect
@onready
var _content_icon: TextureRect = $content/icon as TextureRect
@onready
var _content_label_name: RichTextLabel = $content/label_name as RichTextLabel
@onready
var _content_label_place: RichTextLabel = $content/label_place as RichTextLabel
@onready
var _content_label_points: RichTextLabel = $content/label_points as RichTextLabel

func set_player_name(player_name: String) -> void:
	if player_name == "James" || player_name == "MyKoala":
		_content_label_name.text = "[color=gold][b]%s[/b][/color]" % [player_name]
	elif player_name.to_lower() == "tim" || player_name.to_lower() == "sl1ghtly":
		_content_label_name.text = "[color=brown]%s[/color]" % [player_name]
	elif player_name.to_lower() == "anoop" || player_name.to_lower() == "sonpac":
		_content_label_name.text = "[color=blue]%s[/color]" % [player_name]
	else:
		_content_label_name.text = "[color=white]%s[/color]" % [player_name]

func set_player_place(player_place: int) -> void:
	var ordinal: String = ""
	match (player_place + 1) % 10:
		1:
			ordinal = "st"
		2:
			ordinal = "nd"
		3:
			ordinal = "rd"
		_:
			ordinal = "th"
	_content_label_place.text = "[color=white]%d%s[/color]" % [player_place + 1, ordinal]
	_content_icon.modulate.a = int(player_place == 0)

func set_player_points(player_points: int) -> void:
	_content_label_points.text = "[color=white]%d pts[/color]" % [player_points]

func set_player_status(player_status: PlayerStatus) -> void:
	match player_status:
		PlayerStatus.NOT_SUBMITTED:
			_color_rect.color = Color(1.0, 0.0, 0.0, 0.375)
			_content_icon.visible = true
			_content_label_place.visible = true
			_content_label_points.visible = true
		PlayerStatus.SUBMITTED:
			_color_rect.color = Color(0.5, 0.625, 0.375, 0.75)
			_content_icon.visible = true
			_content_label_place.visible = true
			_content_label_points.visible = true
		PlayerStatus.SPECTATOR:
			_color_rect.color = Color(0.1, 0.1, 0.1, 0.75)
			_content_icon.visible = false
			_content_label_place.visible = false
			_content_label_points.visible = false
