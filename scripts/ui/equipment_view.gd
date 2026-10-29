extends GridContainer

# The Equipment Panel's readout: a row for each slot, its name on the left and the piece in it
# on the right, read each time the Panel opens. Only the Armor slot so far, and nothing to choose
# between, so no row takes focus.

const PLAYER_GROUP := &"player"
const NO_PLAYER := "No Equipment yet"


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
	var equipment: Object = player.get("equipment") if player != null else null
	if equipment == null:
		_add_label(NO_PLAYER, HORIZONTAL_ALIGNMENT_LEFT)
		return
	_add_label("Armor", HORIZONTAL_ALIGNMENT_LEFT)
	var piece := _add_label(equipment.call("armor_name"), HORIZONTAL_ALIGNMENT_RIGHT)
	piece.size_flags_horizontal = SIZE_EXPAND_FILL


func _add_label(text: String, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	add_child(label)
	return label
