extends GridContainer

# The Equipment Panel's readout: each kind of Supply the Player carries, its name on the left and
# how many on the right, read each time the Panel opens.

const Supplies := preload("res://scripts/items/supplies.gd")
const PLAYER_GROUP := &"player"
const NO_SUPPLIES := "No Supplies carried"


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
	var supplies: Object = player.get("supplies") if player != null else null
	var carried: Array = supplies.call("kinds") if supplies != null else []
	if carried.is_empty():
		_add_label(NO_SUPPLIES, HORIZONTAL_ALIGNMENT_LEFT)
		return
	for kind: StringName in carried:
		_add_label(Supplies.KINDS[kind].name, HORIZONTAL_ALIGNMENT_LEFT)
		var count := _add_label(str(supplies.call("count", kind)), HORIZONTAL_ALIGNMENT_RIGHT)
		count.size_flags_horizontal = SIZE_EXPAND_FILL


func _add_label(text: String, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	add_child(label)
	return label
