extends VBoxContainer

# The Equipment Panel's readout: the Armor row, "Armor" on the left and the piece worn on the
# right with its icon, read each time the Panel opens. While the Armor row or the list under it
# has focus, the list shows every Armor the Player owns, the worn one marked; choosing one puts
# it on, and choosing the one worn takes it off.

# The rows focus moves through changed, so the Pause menu relinks them.
signal focus_rows_changed

const Equipment := preload("res://scripts/items/equipment.gd")
const PLAYER_GROUP := &"player"
const SLOT := "Armor"
const WORN := "Worn"
# Room on the right of the Armor row for the worn piece's icon.
const ICON_ROOM := 11.0
# Tall enough for an 8x8 icon, so the Armor row keeps its height with nothing worn.
const ROW_HEIGHT := 10.0

var _armor_row: Button
var _armor_list: VBoxContainer
var _list_rows: Array[Button] = []


func _ready() -> void:
	_build()
	visibility_changed.connect(_refresh)
	if is_inside_tree():
		get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_refresh()


# The rows focus moves through, top to bottom: the Armor row, then its list while it shows.
func focus_rows() -> Array[Button]:
	var rows: Array[Button] = [_armor_row]
	if _armor_list.visible:
		rows.append_array(_list_rows)
	return rows


func _build() -> void:
	_armor_row = Button.new()
	_armor_row.name = "ArmorRow"
	_armor_row.text = SLOT
	_armor_row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_armor_row.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_armor_row.custom_minimum_size.y = ROW_HEIGHT
	_armor_row.add_child(_right_label("Piece", ICON_ROOM))
	add_child(_armor_row)
	_armor_list = VBoxContainer.new()
	_armor_list.name = "ArmorList"
	_armor_list.hide()
	add_child(_armor_list)


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	for row in _list_rows:
		_armor_list.remove_child(row)
		row.queue_free()
	_list_rows.clear()
	var equipment := _equipment()
	for armor_id: StringName in equipment.owned if equipment != null else []:
		var row := Button.new()
		row.text = Equipment.ARMOR[armor_id].name
		row.icon = load(Equipment.ARMOR[armor_id].icon)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(_right_label("Worn", 0.0))
		row.pressed.connect(_on_armor_chosen.bind(armor_id))
		_armor_list.add_child(row)
		_list_rows.append(row)
	_show_worn()
	_set_list_shown(false)


# What each row says about the Armor worn: the piece and its icon on the Armor row, and which row
# of the list it is.
func _show_worn() -> void:
	var equipment := _equipment()
	var worn: StringName = equipment.armor if equipment != null else &""
	(_armor_row.get_node("Piece") as Label).text = (
		equipment.armor_name() if equipment != null else Equipment.NO_ARMOR
	)
	_armor_row.icon = load(Equipment.ARMOR[worn].icon) if not worn.is_empty() else null
	var owned: Array = equipment.owned if equipment != null else []
	for index in _list_rows.size():
		var label := _list_rows[index].get_node("Worn") as Label
		label.text = WORN if owned[index] == worn else ""


func _on_armor_chosen(armor_id: StringName) -> void:
	var player := _player()
	if player == null:
		return
	if player.get("equipment").armor == armor_id:
		player.call("take_off_armor")
	else:
		player.call("wear_armor", armor_id)
	_show_worn()
	_armor_row.grab_focus()


# The list shows while the Armor row or one of its own rows has focus.
func _on_focus_changed(focused: Control) -> void:
	if is_visible_in_tree():
		_set_list_shown(focused == _armor_row or _list_rows.has(focused))


func _set_list_shown(shown: bool) -> void:
	if _armor_list.visible == shown:
		return
	_armor_list.visible = shown
	focus_rows_changed.emit()


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
