extends Control

# The Player's Gold on screen, under the Sub Weapon count: a coin and how much is carried. It
# hides when the Room has no Player.

const PLAYER_GROUP := &"player"

@onready var _count: Label = $Count


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) if is_inside_tree() else null
	visible = player != null
	if visible:
		_count.text = str(player.get("gold"))
