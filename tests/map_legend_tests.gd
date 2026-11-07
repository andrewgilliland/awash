extends RefCounted

# The Map's legend: a LEGEND button under the Map, between the MAP tab and RESUME, opens a sheet
# over the Map naming its marks, the Regions visited and the Map's keys; it closes with the
# button again, Interact or Back, holds the menu still while open, and is shut each time the menu
# opens.

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MapLegend := preload("res://scripts/ui/map_legend.gd")
const MENU_ROOT := "CenterContainer/MenuPanel/MarginContainer/VBoxContainer/"
const MAP_PANEL := MENU_ROOT + "ContentRoot/MapPanel/"
const INPUT_SETUP_SCRIPT_PATH := "res://scripts/core/input_setup.gd"

# Needs a root that is already in the tree: the Pause menu pauses through get_tree().
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["LEGEND sits under the Map, between the MAP tab and RESUME", _test_button_in_chain],
		["LEGEND opens the legend over the Map, and again closes it", _test_button_toggles],
		["Interact or Back closes the legend, back on LEGEND", _test_interact_back_close],
		["While the legend is open, the directions leave the menu be", _test_directions_held],
		["The legend is shut each time the menu opens", _test_shut_on_open],
		["Space on LEGEND opens the legend rather than zooming", _test_space_opens],
		["The legend names each Region visited, and only those", _test_regions_visited],
		["The legend names the Map's marks", _test_marks],
		["Each key the legend shows is bound to what it says it does", _test_keys_bound],
	]


func _test_button_in_chain() -> bool:
	var menu := _map_menu()
	var legend := _legend_button(menu)
	var resume := menu.get_node(MENU_ROOT + "ResumeButton") as Button
	_tap(menu, &"ui_down")
	var valid := legend.has_focus() and _shown_panel(menu) == "Map"
	_tap(menu, &"ui_down")
	valid = valid and resume.has_focus()
	_tap(menu, &"ui_up")
	valid = valid and legend.has_focus()
	_tap(menu, &"ui_up")
	valid = valid and _map_button(menu).has_focus()
	_close(menu)
	return valid


func _test_button_toggles() -> bool:
	var menu := _map_menu()
	_legend_button(menu).grab_focus()
	_tap(menu, &"ui_accept")
	var valid: bool = _sheet(menu).visible and _body(menu).call("is_open")
	_tap(menu, &"ui_accept")
	valid = valid and not _sheet(menu).visible and _legend_button(menu).has_focus()
	_close(menu)
	return valid


func _test_interact_back_close() -> bool:
	var menu := _map_menu()
	var valid := true
	for closer in [&"interact", &"ui_cancel"]:
		_legend_button(menu).grab_focus()
		_tap(menu, &"ui_accept")
		valid = valid and _sheet(menu).visible
		_tap(menu, closer)
		valid = valid and not _sheet(menu).visible and _legend_button(menu).has_focus()
		valid = valid and menu.get_tree().paused
	_close(menu)
	return valid


func _test_directions_held() -> bool:
	var menu := _map_menu()
	_legend_button(menu).grab_focus()
	_tap(menu, &"ui_accept")
	var valid := true
	for action in [&"ui_down", &"ui_up", &"ui_left", &"ui_right", &"move_left"]:
		_tap(menu, action)
		valid = valid and _sheet(menu).visible and _legend_button(menu).has_focus()
		valid = valid and _shown_panel(menu) == "Map"
	_close(menu)
	return valid


func _test_shut_on_open() -> bool:
	var menu := _map_menu()
	_legend_button(menu).grab_focus()
	_tap(menu, &"ui_accept")
	menu.call("toggle_pause")
	menu.call("toggle_pause")
	var valid: bool = not _sheet(menu).visible and not _body(menu).call("is_open")
	_close(menu)
	return valid


func _test_space_opens() -> bool:
	var menu := _map_menu()
	var view := menu.get_node(MAP_PANEL + "MapView")
	var zoom: StringName = view.call("zoom")
	_legend_button(menu).grab_focus()
	_press_key(menu, KEY_SPACE)
	var valid: bool = _sheet(menu).visible and view.call("zoom") == zoom
	_close(menu)
	return valid


func _test_regions_visited() -> bool:
	var run := _root.get_node("RunState")
	run.call("start_run")
	var menu := _map_menu()
	var valid: bool = _body(menu).call("regions") == ["Waking Coast"]
	_close(menu)
	run.call("enter_room", &"tidefen_village_1", &"west")
	menu = _map_menu()
	valid = valid and _body(menu).call("regions") == ["Waking Coast", "Tidefen Village"]
	_close(menu)
	run.call("start_run")
	return valid


func _test_marks() -> bool:
	var names: Array = MapLegend.MARKS.map(func(mark: Dictionary) -> String: return mark.name)
	return names == ["YOU", "THIS ROOM", "REST BELL", "BOSS"]


func _test_keys_bound() -> bool:
	_register_inputs()
	var valid := not MapLegend.KEYS.is_empty()
	for key: Dictionary in MapLegend.KEYS:
		var bound := false
		for event in InputMap.action_get_events(key.action):
			if event is InputEventKey and (event as InputEventKey).physical_keycode == key.key:
				bound = true
		if not bound:
			push_error("Legend shows %s for %s, which is not bound to it." % [key.keys, key.does])
		valid = valid and bound
	return valid


# A paused menu with the MAP tab focused.
func _map_menu() -> Control:
	_register_inputs()
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	menu.call("toggle_pause")
	_map_button(menu).grab_focus()
	return menu


func _register_inputs() -> void:
	var input_setup := (load(INPUT_SETUP_SCRIPT_PATH) as GDScript).new() as Node
	input_setup.call("_register_inputs")
	input_setup.free()


func _close(menu: Control) -> void:
	menu.get_tree().paused = false
	menu.free()


func _map_button(menu: Control) -> Button:
	return menu.get_node(MENU_ROOT + "MenuButtons/MapButton") as Button


func _legend_button(menu: Control) -> Button:
	return menu.get_node(MAP_PANEL + "Body/LegendButton") as Button


func _body(menu: Control) -> Node:
	return menu.get_node(MAP_PANEL + "Body")


func _sheet(menu: Control) -> Control:
	return menu.get_node(MAP_PANEL + "MapView/Legend") as Control


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
		event.keycode = key
		event.pressed = pressed
		menu.get_viewport().push_input(event)


# The name of the one visible Panel, or "" when none or several are visible.
func _shown_panel(menu: Control) -> String:
	var shown: Array[String] = []
	for panel in menu.get_node(MENU_ROOT + "ContentRoot").get_children():
		if (panel as Control).visible:
			shown.append(panel.name.trim_suffix("Panel"))
	return shown[0] if shown.size() == 1 else ""
