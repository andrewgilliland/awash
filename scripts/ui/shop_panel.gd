extends Control

# The Supply Shop, opened by talking to a keeper such as Tidefen's TRADER: play pauses while it
# lists the keeper's stock, each row the Supply's name on the left and how many the Player carries
# and its price on the right, with the Player's Gold above and the focused Supply's description
# below. Choosing a row buys one; a row the Player cannot buy is greyed, and choosing it says why
# for a while. Back, cancel or pause closes it and play goes on.

const Shop := preload("res://scripts/items/shop.gd")
const Supplies := preload("res://scripts/items/supplies.gd")
const GROUP := &"shop_panel"
const PLAYER_GROUP := &"player"
const NO_GOLD := "Not enough Gold"
const NO_ROOM := "Can't carry more"
const DETAIL := "x%d  %dG"
const GREYED := Color(1, 1, 1, 0.5)
const NOTE_TIME := 1.2
const NOTE_COLOR := Color(1, 1, 0.545098)

# The stock of the keeper who opened it.
var _stock: Array = Shop.STOCK
var _rows: Array[Button] = []
var _note := ""

@onready var _rows_box: VBoxContainer = %Rows
@onready var _gold: Label = %Gold
@onready var _description: Label = %Description
@onready var _back: Button = %Back


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_back.pressed.connect(close)
	if is_inside_tree():
		get_viewport().gui_focus_changed.connect(_on_focus_changed)


func open(stock: Array = Shop.STOCK) -> void:
	if _player() == null:
		return
	_stock = stock
	get_tree().paused = true
	show()
	_build_rows()
	if not _rows.is_empty():
		_rows[0].grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


func _build_rows() -> void:
	for row in _rows:
		_rows_box.remove_child(row)
		row.queue_free()
	_rows.clear()
	for item: Array in _stock:
		var row := Button.new()
		row.text = Supplies.KINDS[item[0]].name
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var detail := Label.new()
		detail.name = "Detail"
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		detail.offset_right = -2.0
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(detail)
		row.set_meta(&"kind", item[0])
		row.set_meta(&"price", item[1])
		row.pressed.connect(_on_row_pressed.bind(row))
		_rows_box.add_child(row)
		_rows.append(row)
	for index in _rows.size():
		var above := _rows[index - 1] if index > 0 else _back
		var below := _rows[index + 1] if index < _rows.size() - 1 else _back
		_rows[index].focus_neighbor_top = _rows[index].get_path_to(above)
		_rows[index].focus_neighbor_bottom = _rows[index].get_path_to(below)
	if not _rows.is_empty():
		_back.focus_neighbor_top = _back.get_path_to(_rows[-1])
		_back.focus_neighbor_bottom = _back.get_path_to(_rows[0])
	_show_state()


# The Gold, each row's count and price, and greyed rows, as they stand now.
func _show_state() -> void:
	var player := _player()
	if player == null:
		return
	_gold.text = str(player.get("gold"))
	for row in _rows:
		var kind: StringName = row.get_meta(&"kind")
		var price: int = row.get_meta(&"price")
		var carried: int = player.get("supplies").count(kind)
		(row.get_node("Detail") as Label).text = DETAIL % [carried, price]
		var buyable: bool = player.call("can_buy", kind, price)
		row.modulate = Color.WHITE if buyable else GREYED


func _on_row_pressed(row: Button) -> void:
	var player := _player()
	if player == null:
		return
	var kind: StringName = row.get_meta(&"kind")
	var price: int = row.get_meta(&"price")
	if not player.call("buy_supply", kind, price):
		_show_note(NO_GOLD if player.get("gold") < price else NO_ROOM)
	_show_state()


func _on_focus_changed(focused: Control) -> void:
	if visible and _note.is_empty():
		var kind: StringName = focused.get_meta(&"kind", &"") if _rows.has(focused) else &""
		_description.text = Supplies.KINDS[kind].description if not kind.is_empty() else ""


func _show_note(text: String) -> void:
	_note = text
	_description.text = text
	_description.add_theme_color_override(&"font_color", NOTE_COLOR)
	if not is_inside_tree():
		return
	await get_tree().create_timer(NOTE_TIME, true).timeout
	if not is_instance_valid(self) or _note != text:
		return
	_note = ""
	_description.remove_theme_color_override(&"font_color")
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		_on_focus_changed(focused)


func _player() -> Node:
	return get_tree().get_first_node_in_group(PLAYER_GROUP) if is_inside_tree() else null
