extends Control

# The ready Supply on screen, under the Health bar: its icon and how many the Player carries, so
# Use can be found in play. It hides while the Player carries none.

const Supplies := preload("res://scripts/items/supplies.gd")
const PLAYER_GROUP := &"player"

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) if is_inside_tree() else null
	var supplies: Object = player.get("supplies") if player != null else null
	var kind: StringName = supplies.call("ready_kind") if supplies != null else &""
	visible = not kind.is_empty()
	if not visible:
		return
	_icon.texture = load(Supplies.KINDS[kind].icon)
	_count.text = str(supplies.call("count", kind))
