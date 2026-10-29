extends GridContainer

# The Stats Panel's readout, one row per stat with its name on the left and its value on the
# right: the Player's Level, Experience toward the next one (MAX at the highest), Health left
# out of its total, Strength and the Armor's Defense, read each time the Panel opens.

const PLAYER_GROUP := &"player"
const NO_PLAYER := "No stats yet"
const AT_HIGHEST := "MAX"


func _ready() -> void:
	columns = 2
	visibility_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	for row in get_children():
		remove_child(row)
		row.queue_free()
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) if is_inside_tree() else null
	var health: Object = player.get("health") if player != null else null
	var level: Object = player.get("level") if player != null else null
	if health == null or level == null:
		_add_label(NO_PLAYER, HORIZONTAL_ALIGNMENT_LEFT)
		return
	var experience: int = level.get("experience")
	var to_next: int = level.call("experience_to_next")
	var next := AT_HIGHEST if to_next < 0 else str(experience + to_next)
	_add_row("Level", str(level.get("level")))
	_add_row("Experience", "%d / %s" % [experience, next])
	_add_row("Health", "%d / %d" % [health.get("current"), health.get("maximum")])
	_add_row("Strength", str(level.call("strength")))
	var equipment: Object = player.get("equipment")
	_add_row("Defense", str(equipment.call("defense")) if equipment != null else "0")


func _add_row(stat: String, value: String) -> void:
	_add_label(stat, HORIZONTAL_ALIGNMENT_LEFT)
	_add_label(value, HORIZONTAL_ALIGNMENT_RIGHT).size_flags_horizontal = SIZE_EXPAND_FILL


func _add_label(text: String, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	add_child(label)
	return label
