extends Label

# The Stats Panel's readout: the Player's Level, Experience toward the next one (MAX at the
# highest), Health left out of its total and Strength, read each time the Panel opens.

const PLAYER_GROUP := &"player"
const NO_PLAYER := "No stats yet"
const AT_HIGHEST := "MAX"


func _ready() -> void:
	visibility_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) if is_inside_tree() else null
	var health: Object = player.get("health") if player != null else null
	var level: Object = player.get("level") if player != null else null
	if health == null or level == null:
		text = NO_PLAYER
		return
	var experience: int = level.get("experience")
	var to_next: int = level.call("experience_to_next")
	var next := AT_HIGHEST if to_next < 0 else str(experience + to_next)
	text = (
		"\n"
		. join(
			[
				"Level %d" % level.get("level"),
				"Experience %d / %s" % [experience, next],
				"Health %d / %d" % [health.get("current"), health.get("maximum")],
				"Strength %d" % level.call("strength"),
			]
		)
	)
