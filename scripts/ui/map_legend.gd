extends HBoxContainer

# The Map's legend: LEGEND, under the Map, opens a sheet over it naming the Map's marks, each
# Region the Player has visited, and the Map's keys. The button again, Interact or Back closes it;
# while it is open the directions hold the menu still, and it is shut each time the menu opens.

const World := preload("res://scripts/core/world.gd")
const MapDrawing := preload("res://scripts/ui/map_drawing.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
# The Map's marks, each drawn as the Map draws it.
const MARKS: Array[Dictionary] = [
	{name = "YOU", kind = &"you"},
	{name = "THIS ROOM", kind = &"here"},
	{name = "REST BELL", kind = &"rest"},
	{name = "BOSS", kind = &"boss"},
]
# The Map's keys: the keyboard's, then the pad's where it differs, its key and what it does.
const KEYS: Array[Dictionary] = [
	{keys = "SPACE/A", key = KEY_SPACE, action = &"jump", does = "ZOOM IN"},
	{keys = "X", key = KEY_X, action = &"melee_attack", does = "ZOOM OUT"},
	{keys = "E/Y", key = KEY_E, action = &"interact", does = "EXPLORE"},
	{keys = "ARROWS", key = KEY_UP, action = &"move_up", does = "PAN"},
	{keys = "TAB", key = KEY_TAB, action = &"map", does = "MAP"},
]
# The directions, held still while the legend is open.
const HELD_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"ui_left",
	&"ui_right",
	&"ui_up",
	&"ui_down",
]
# The sheet's layout: its margin, a row's height, each mark's and swatch's square, the gap after
# it, where the keys' column starts, and how wide its keys are.
const MARGIN := Vector2(4, 3)
const ROW_HEIGHT := 7.0
const ICON := Vector2(5, 5)
const ICON_GAP := 3.0
const KEYS_X := 72.0
const KEYS_WIDTH := 34.0

# The Map's view, which the sheet covers.
@export var sheet: Control
# The Pause menu's frame: each time it opens, the legend is shut.
@export var menu_panel: Control

@onready var _button: Button = $LegendButton


func _ready() -> void:
	_button.pressed.connect(func() -> void: _show(not is_open()))
	if sheet != null:
		sheet.draw.connect(_draw_sheet)
	if menu_panel != null:
		menu_panel.visibility_changed.connect(_on_menu_shown)
	_show(false)


# The rows focus moves through on the Map Panel.
func focus_rows() -> Array[Button]:
	return [_button]


func is_open() -> bool:
	return sheet != null and sheet.visible


# The name of each Region the Player has visited, in the World's order of its Rooms.
func regions() -> Array:
	return _regions_visited().map(func(id: StringName) -> String: return World.name_of_region(id))


# Ahead of the menu, which would take the directions as moving on.
func _input(event: InputEvent) -> void:
	if not is_open() or not is_visible_in_tree():
		return
	var back := event.is_action_pressed(&"ui_cancel") and not event.is_action(&"pause")
	if event.is_action_pressed(&"interact") or back:
		get_viewport().set_input_as_handled()
		_show(false)
	elif HELD_ACTIONS.any(func(action: StringName) -> bool: return event.is_action(action)):
		get_viewport().set_input_as_handled()


func _show(open: bool) -> void:
	if sheet == null:
		return
	sheet.visible = open
	sheet.queue_redraw()
	if not open and is_visible_in_tree():
		_button.grab_focus()


func _on_menu_shown() -> void:
	if menu_panel.visible:
		_show(false)


func _regions_visited() -> Array[StringName]:
	var run := get_node_or_null("/root/RunState") as RunStateScript
	var room_here := run.room_id if run != null else RunStateScript.FIRST_ROOM_ID
	var visited: Array[StringName] = []
	for room_id in World.room_ids():
		var region := World.region(room_id)
		var seen := room_id == room_here or (run != null and run.has_visited_room(room_id))
		if seen and region not in visited:
			visited.append(region)
	return visited


func _draw_sheet() -> void:
	sheet.draw_style_box(
		get_theme_stylebox(&"panel", &"PanelContainer"), Rect2(Vector2.ZERO, sheet.size)
	)
	var font := get_theme_font(&"font", &"Label")
	var font_size := get_theme_font_size(&"font_size", &"Label")
	var at := MARGIN
	_text(font, font_size, at, "LEGEND", MapDrawing.LABEL)
	for mark: Dictionary in MARKS:
		at.y += ROW_HEIGHT
		_mark(Rect2(at, ICON), mark.kind)
		_text(font, font_size, at + Vector2(ICON.x + ICON_GAP, 0), mark.name, MapDrawing.LABEL)
	for region in _regions_visited():
		at.y += ROW_HEIGHT
		sheet.draw_rect(Rect2(at, ICON), World.colour_of_region(region))
		var name := World.name_of_region(region)
		_text(font, font_size, at + Vector2(ICON.x + ICON_GAP, 0), name, MapDrawing.LABEL)
	at = Vector2(KEYS_X, MARGIN.y)
	_text(font, font_size, at, "KEYS", MapDrawing.LABEL)
	for key: Dictionary in KEYS:
		at.y += ROW_HEIGHT
		_text(font, font_size, at, key.keys, MapDrawing.DOT)
		_text(font, font_size, at + Vector2(KEYS_WIDTH, 0), key.does, MapDrawing.LABEL)


# A mark in its square, drawn as the Map draws it.
func _mark(square: Rect2, kind: StringName) -> void:
	match kind:
		&"you":
			var dot := Rect2(square.get_center() - MapDrawing.DOT_SIZE / 2.0, MapDrawing.DOT_SIZE)
			sheet.draw_rect(dot.abs(), MapDrawing.DOT)
		&"here":
			sheet.draw_rect(square, MapDrawing.CURRENT_FILL)
			sheet.draw_rect(square, MapDrawing.WALL, false, 1.0)
		_:
			MapDrawing.draw_marker(sheet, kind, square)


# Text whose top-left is at the point given.
func _text(font: Font, font_size: int, top_left: Vector2, text: String, colour: Color) -> void:
	var baseline := top_left + Vector2(0, font.get_ascent(font_size))
	sheet.draw_string(
		font, baseline.floor(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour
	)
