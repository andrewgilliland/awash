extends VBoxContainer

# The Inventory's list: a row for each kind of Supply the Player carries, its name on the left
# and how many on the right, read each time the Panel opens. The strip at the Panel's foot
# describes the kind focused. Choosing a row uses one of that kind; at full Health nothing is
# spent, and a note in the strip's place says so for a while.

# The rows changed, so the Pause menu relinks focus through them.
signal focus_rows_changed

const Supplies := preload("res://scripts/items/supplies.gd")
const PLAYER_GROUP := &"player"
const NO_SUPPLIES := "No Supplies carried"
const HEALTH_FULL := "Health is full"
# How long the note stays up, and its colour.
const NOTE_TIME := 1.2
const NOTE_COLOR := Color(1, 1, 0.545098)

@export var description: Label

var _rows: Array[Button] = []
# What the strip says once no note is up.
var _described := ""
var _note := ""


func _ready() -> void:
	visibility_changed.connect(_refresh)
	if is_inside_tree():
		get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_refresh()


# The rows focus moves through, top to bottom.
func focus_rows() -> Array[Button]:
	return _rows


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rows.clear()
	_describe("")
	var supplies := _supplies()
	var carried: Array = supplies.call("kinds") if supplies != null else []
	if carried.is_empty():
		var label := Label.new()
		label.text = NO_SUPPLIES
		add_child(label)
	for kind: StringName in carried:
		_rows.append(_add_row(kind, supplies.call("count", kind)))
	focus_rows_changed.emit()


func _add_row(kind: StringName, count: int) -> Button:
	var row := Button.new()
	row.text = Supplies.KINDS[kind].name
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var count_label := Label.new()
	count_label.name = "Count"
	count_label.text = str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count_label.offset_right = -2.0
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(count_label)
	row.pressed.connect(_on_row_pressed.bind(kind, count_label))
	row.set_meta(&"kind", kind)
	add_child(row)
	return row


func _on_row_pressed(kind: StringName, count_label: Label) -> void:
	var player := _player()
	if player == null:
		return
	if not player.call("use_supply", kind):
		var health: Object = player.get("health")
		if health.get("current") >= health.get("maximum"):
			_show_note(HEALTH_FULL)
		return
	var left: int = _supplies().call("count", kind)
	if left > 0:
		count_label.text = str(left)
	else:
		_refresh()


# A Supply row describes its kind; anything else leaves the strip empty.
func _on_focus_changed(focused: Control) -> void:
	if is_visible_in_tree():
		var kind: StringName = focused.get_meta(&"kind", &"") if _rows.has(focused) else &""
		_describe(Supplies.KINDS[kind].description if not kind.is_empty() else "")


func _describe(text: String) -> void:
	_described = text
	if description != null and _note.is_empty():
		description.text = text


func _show_note(text: String) -> void:
	if description == null:
		return
	_note = text
	description.text = text
	description.add_theme_color_override(&"font_color", NOTE_COLOR)
	# Play is paused, so the timer runs through the pause.
	await get_tree().create_timer(NOTE_TIME, true).timeout
	if is_instance_valid(self):
		_end_note(text)


# The note is done, unless a newer one replaced it: the strip goes back to its description.
func _end_note(text: String) -> void:
	if _note != text:
		return
	_note = ""
	description.remove_theme_color_override(&"font_color")
	description.text = _described


func _player() -> Node:
	return get_tree().get_first_node_in_group(PLAYER_GROUP) if is_inside_tree() else null


func _supplies() -> Object:
	var player := _player()
	return player.get("supplies") if player != null else null
