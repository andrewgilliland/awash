extends VBoxContainer

# The Equipment Panel, read each time it opens. Above a divider, one row per Equipment slot, its
# name on the left and the piece equipped on the right with its icon, and the Defense. Below it,
# the pieces owned for the slot last focused, the equipped one marked. Choosing a slot moves focus
# into its pieces; choosing one equips it and goes back to the slot, as does up from the top.
# None leads the pieces of a slot that can be empty.

const Equipment := preload("res://scripts/items/equipment.gd")
const PLAYER_GROUP := &"player"
const WEAPON := 0
const ARMOR := 1
const SLOT_NAMES := ["Weapon", "Armor"]
const EQUIPPED := "Equipped"
const DEFENSE := "DEF %d"
const DEFENSE_PREVIEW := "DEF %d > %d"
# Room on the right of a slot row for the piece's icon.
const ICON_ROOM := 11.0
# Tall enough for an 8x8 icon, so a row keeps its height with nothing equipped.
const ROW_HEIGHT := 10.0
const ICON_SIZE := 8

var _slot_rows: Array[Button] = []
var _defense: Label
var _choices: VBoxContainer
# The slot whose pieces show below the divider, and those pieces' ids in order (&"" for None).
var _shown_slot := WEAPON
var _shown_ids: Array[StringName] = []
# Keeps None's name in line with the pieces' names beside their icons.
var _no_icon: Texture2D


func _ready() -> void:
	_build()
	visibility_changed.connect(_refresh)
	if is_inside_tree():
		get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_refresh()


# The rows focus moves through, top to bottom: the slots. Their pieces are reached by choosing one.
func focus_rows() -> Array[Button]:
	return _slot_rows.duplicate()


func _build() -> void:
	for slot in SLOT_NAMES.size():
		var row := Button.new()
		row.name = SLOT_NAMES[slot] + "Row"
		row.text = SLOT_NAMES[slot]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.custom_minimum_size.y = ROW_HEIGHT
		row.add_child(_right_label("Piece", ICON_ROOM))
		row.pressed.connect(_choose_from.bind(slot))
		add_child(row)
		_slot_rows.append(row)
	_defense = Label.new()
	_defense.name = "Defense"
	_defense.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_defense)
	var divider := HSeparator.new()
	divider.name = "Divider"
	add_child(divider)
	_choices = VBoxContainer.new()
	_choices.name = "Choices"
	add_child(_choices)
	var blank := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	_no_icon = ImageTexture.create_from_image(blank)


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	_show_equipped()
	_show_choices(WEAPON)


# What each slot row says about the piece equipped, the Defense, and which piece is marked.
func _show_equipped() -> void:
	var equipment := _equipment()
	for slot in _slot_rows.size():
		var row := _slot_rows[slot]
		var id := _equipped(slot)
		(row.get_node("Piece") as Label).text = (
			_pieces(slot)[id].name if not id.is_empty() else Equipment.NO_ARMOR
		)
		row.icon = load(_pieces(slot)[id].icon) if not id.is_empty() else null
	_defense.text = DEFENSE % (equipment.defense() if equipment != null else 0)
	var equipped := _equipped(_shown_slot)
	for index in _shown_ids.size():
		var mark := _choices.get_child(index).get_node("Mark") as Label
		mark.text = EQUIPPED if _shown_ids[index] == equipped else ""


# Lists the slot's pieces below the divider, None first if it can be empty.
func _show_choices(slot: int) -> void:
	for row in _choices.get_children():
		_choices.remove_child(row)
		row.queue_free()
	_shown_slot = slot
	_shown_ids.clear()
	if slot == ARMOR:
		_shown_ids.append(&"")
	_shown_ids.append_array(_owned(slot))
	for id in _shown_ids:
		var row := Button.new()
		row.text = _pieces(slot)[id].name if not id.is_empty() else Equipment.NO_ARMOR
		row.icon = load(_pieces(slot)[id].icon) if not id.is_empty() else _no_icon
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_NONE
		row.add_child(_right_label("Mark", 0.0))
		row.pressed.connect(_on_piece_chosen.bind(id))
		_choices.add_child(row)
	_link_choices()
	_show_equipped()


# Up from the top piece goes back to the slot; down from the last, and left and right, stay put.
func _link_choices() -> void:
	var rows := _choices.get_children()
	for index in rows.size():
		var row := rows[index] as Button
		var above: Control = rows[index - 1] if index > 0 else _slot_rows[_shown_slot]
		var below: Control = rows[mini(index + 1, rows.size() - 1)]
		row.focus_neighbor_top = row.get_path_to(above)
		row.focus_neighbor_bottom = row.get_path_to(below)
		row.focus_neighbor_left = row.get_path_to(row)
		row.focus_neighbor_right = row.get_path_to(row)


# Moves focus into the slot's pieces, onto the one equipped, the slot staying lit meanwhile.
func _choose_from(slot: int) -> void:
	if _shown_slot != slot:
		_show_choices(slot)
	for row in _choices.get_children():
		(row as Button).focus_mode = Control.FOCUS_ALL
	var slot_row := _slot_rows[slot]
	slot_row.add_theme_color_override(&"font_color", slot_row.get_theme_color(&"font_focus_color"))
	var index := _shown_ids.find(_equipped(slot))
	(_choices.get_child(maxi(index, 0)) as Button).grab_focus()


# Equips the piece chosen, unless it is equipped already, and goes back to its slot. Only Armor
# can change for now: the Short Sword is the only Weapon.
func _on_piece_chosen(id: StringName) -> void:
	var player := _player()
	if player != null and _shown_slot == ARMOR and id != _equipped(ARMOR):
		if id.is_empty():
			player.call("take_off_armor")
		else:
			player.call("wear_armor", id)
	_show_equipped()
	_slot_rows[_shown_slot].grab_focus()


# A slot row shows its pieces; a piece previews its Defense; leaving the pieces closes them.
func _on_focus_changed(focused: Control) -> void:
	if not is_visible_in_tree():
		return
	var slot := _slot_rows.find(focused)
	if slot != -1 and slot != _shown_slot:
		_show_choices(slot)
	var choosing := focused != null and focused.get_parent() == _choices
	if not choosing:
		for row in _choices.get_children():
			(row as Button).focus_mode = Control.FOCUS_NONE
		_slot_rows[_shown_slot].remove_theme_color_override(&"font_color")
	_show_defense(_shown_ids[focused.get_index()] if choosing and _shown_slot == ARMOR else null)


# The Defense, with what it would become with the given Armor (&"" for none), if any.
func _show_defense(preview: Variant) -> void:
	var equipment := _equipment()
	var now: int = equipment.defense() if equipment != null else 0
	if preview == null or equipment == null:
		_defense.text = DEFENSE % now
	else:
		_defense.text = DEFENSE_PREVIEW % [now, equipment.defense_with(preview)]


func _equipped(slot: int) -> StringName:
	var equipment := _equipment()
	if equipment == null:
		return &""
	return equipment.weapon if slot == WEAPON else equipment.armor


func _owned(slot: int) -> Array:
	var equipment := _equipment()
	if equipment == null:
		return []
	return equipment.owned_weapons if slot == WEAPON else equipment.owned


func _pieces(slot: int) -> Dictionary:
	return Equipment.WEAPONS if slot == WEAPON else Equipment.ARMOR


func _right_label(label_name: String, room: float) -> Label:
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_right = -(room + 2.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _player() -> Node:
	return get_tree().get_first_node_in_group(PLAYER_GROUP) if is_inside_tree() else null


func _equipment() -> Object:
	var player := _player()
	return player.get("equipment") if player != null else null
