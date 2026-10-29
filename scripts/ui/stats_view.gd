extends Label

# The Stats Panel's readout: the Player's Health left out of its total, read each time the
# Panel opens.

const PLAYER_GROUP := &"player"
const NO_PLAYER := "No stats yet"


func _ready() -> void:
	visibility_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) if is_inside_tree() else null
	var health: Object = player.get("health") if player != null else null
	if health == null:
		text = NO_PLAYER
		return
	text = "Health %d / %d" % [health.get("current"), health.get("maximum")]
