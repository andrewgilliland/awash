extends RefCounted

# The Map's zoom on the Pause menu's Map Panel: it opens on the whole World, Jump zooms in round
# the Player and Attack back out, and the Map key opens and closes the menu on the Map.

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MapView := preload("res://scripts/ui/map_view.gd")
const MapLayout := preload("res://scripts/ui/map_layout.gd")
const World := preload("res://scripts/core/world.gd")
const MENU_ROOT := "CenterContainer/MenuPanel/MarginContainer/VBoxContainer/"
const INPUT_SETUP_SCRIPT_PATH := "res://scripts/core/input_setup.gd"
# The Map Panel's view as the Pause menu lays it out on the game's screen.
const MAP_VIEW_SIZE := Vector2(142, 73)
# The smallest a screen may be drawn and still read as a block with its walls: a pixel of wall
# round a room of its own.
const SMALLEST_SCREEN := Vector2(5, 4)

# Needs a root that is already in the tree: the Pause menu pauses through get_tree().
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["The Map opens on the whole World", _test_opens_on_world],
		["The whole built World fits the Map Panel at World zoom", _test_world_fits_panel],
		["Jump zooms the Map in and Attack out, a step at a time, to each end", _test_zooms],
		["The zoom keys work only while the Map's button has focus", _test_zoom_needs_focus],
		["The Map keeps its zoom when opened again", _test_keeps_zoom],
		["The Map key opens the Pause menu on the Map, and closes it", _test_map_key_toggles],
		["The Map key turns to the Map from another Panel", _test_map_key_from_panel],
		["The Map key does nothing while the Shop holds play paused", _test_map_key_over_shop],
	]


func _test_opens_on_world() -> bool:
	var menu := _paused_menu()
	_map_button(menu).grab_focus()
	var valid: bool = _map_view(menu).call("zoom") == &"world"
	_close(menu)
	return valid


func _test_world_fits_panel() -> bool:
	var rooms := {}
	for room_id in World.room_ids():
		rooms[room_id] = MapView.map_room(room_id)
	var first: StringName = World.room_ids()[0]
	var layout := MapLayout.layout(
		rooms, first, rooms.keys(), World.SCREEN_SIZE / 2.0, MAP_VIEW_SIZE, &"world"
	)
	var view := Rect2(Vector2.ZERO, MAP_VIEW_SIZE)
	var valid: bool = layout.rooms.size() == rooms.size()
	for room: Dictionary in layout.rooms:
		valid = valid and view.encloses(room.block)
	var screen: Vector2 = layout.current.size / Vector2(World.size(first))
	return valid and screen.x >= SMALLEST_SCREEN.x and screen.y >= SMALLEST_SCREEN.y


func _test_zooms() -> bool:
	_register_inputs()
	var menu := _paused_menu()
	_map_button(menu).grab_focus()
	var view := _map_view(menu)
	_zoom_to_world(menu)
	var seen: Array[StringName] = []
	for action in [&"jump", &"jump", &"jump", &"melee_attack", &"melee_attack", &"melee_attack"]:
		_tap(menu, action)
		seen.append(view.call("zoom"))
	var valid := seen == [&"near", &"close", &"close", &"near", &"world", &"world"]
	# Zooming stays on the Map's button: neither key moves the menu on.
	valid = valid and _map_button(menu).has_focus() and menu.get_tree().paused
	_close(menu)
	return valid


func _test_zoom_needs_focus() -> bool:
	_register_inputs()
	var menu := _paused_menu()
	_map_button(menu).grab_focus()
	_zoom_to_world(menu)
	(menu.get_node(MENU_ROOT + "ResumeButton") as Button).grab_focus()
	_tap(menu, &"jump")
	var valid: bool = _map_view(menu).call("zoom") == &"world"
	_close(menu)
	return valid


func _test_keeps_zoom() -> bool:
	_register_inputs()
	var menu := _paused_menu()
	_map_button(menu).grab_focus()
	_zoom_to_world(menu)
	_tap(menu, &"jump")
	_close(menu)
	menu = _paused_menu()
	_map_button(menu).grab_focus()
	var valid: bool = _map_view(menu).call("zoom") == &"near"
	_zoom_to_world(menu)
	_close(menu)
	return valid


func _test_map_key_toggles() -> bool:
	_register_inputs()
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	_press_key(menu, KEY_TAB)
	var valid := menu.get_tree().paused and _shown_panel(menu) == "Map"
	valid = valid and _map_button(menu).has_focus()
	_press_key(menu, KEY_TAB)
	valid = valid and not menu.get_tree().paused
	valid = valid and not menu.get_node("CenterContainer/MenuPanel").visible
	_close(menu)
	return valid


func _test_map_key_from_panel() -> bool:
	_register_inputs()
	var menu := _paused_menu()
	_press_key(menu, KEY_TAB)
	var valid := menu.get_tree().paused and _shown_panel(menu) == "Map"
	valid = valid and _map_button(menu).has_focus()
	_close(menu)
	return valid


# Something else, such as the Shop, has paused play with the menu shut, last shut on the Map.
func _test_map_key_over_shop() -> bool:
	_register_inputs()
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	_press_key(menu, KEY_TAB)
	_press_key(menu, KEY_TAB)
	menu.get_tree().paused = true
	_press_key(menu, KEY_TAB)
	var valid := menu.get_tree().paused
	valid = valid and not menu.get_node("CenterContainer/MenuPanel").visible
	_close(menu)
	return valid


func _zoom_to_world(menu: Control) -> void:
	for i in MapLayout.ZOOMS.size():
		_tap(menu, &"melee_attack")


func _register_inputs() -> void:
	var input_setup := (load(INPUT_SETUP_SCRIPT_PATH) as GDScript).new() as Node
	input_setup.call("_register_inputs")
	input_setup.free()


func _paused_menu() -> Control:
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	menu.call("toggle_pause")
	return menu


func _close(menu: Control) -> void:
	menu.get_tree().paused = false
	menu.free()


func _map_button(menu: Control) -> Button:
	return menu.get_node(MENU_ROOT + "MenuButtons/MapButton") as Button


func _map_view(menu: Control) -> Control:
	return menu.get_node(MENU_ROOT + "ContentRoot/MapPanel/MapView") as Control


func _tap(menu: Control, action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		menu.get_viewport().push_input(event)


func _press_key(menu: Control, key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
		menu.get_viewport().push_input(event)


# The name of the one visible Panel, or "" when none or several are visible.
func _shown_panel(menu: Control) -> String:
	var shown: Array[String] = []
	for panel in menu.get_node(MENU_ROOT + "ContentRoot").get_children():
		if (panel as Control).visible:
			shown.append(panel.name.trim_suffix("Panel"))
	return shown[0] if shown.size() == 1 else ""
