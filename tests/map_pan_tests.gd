extends RefCounted

# Exploring the Map on the Pause menu's Map Panel: Interact on its button starts and stops it;
# while exploring, the direction keys pan Near and Close as far as the World's edge, instead of
# moving the menu on, and the menu opened again starts centred on the Player.

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MapLayout := preload("res://scripts/ui/map_layout.gd")
const MENU_ROOT := "CenterContainer/MenuPanel/MarginContainer/VBoxContainer/"
const INPUT_SETUP_SCRIPT_PATH := "res://scripts/core/input_setup.gd"
# Held this long, a direction pans one Close screen.
const ONE_SCREEN_TIME := 0.15

# Needs a root that is already in the tree: the Pause menu pauses through get_tree().
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Interact on the Map's button explores the Map, and again stops", _test_interact_toggles],
		["Interact away from the Map's button doesn't explore it", _test_interact_needs_map],
		["Exploring, the directions pan the Map and leave the menu be", _test_directions_pan],
		["Exploring pans the same Map distance at every zoom", _test_same_speed],
		["At World zoom, exploring doesn't pan while the whole World fits", _test_world_still],
		["At World zoom, exploring pans a World too wide, across only", _test_world_too_wide_pans],
		["A pan stops at the World's edge", _test_pan_clamped],
		["Zooming, or leaving the Map, keeps the pan", _test_pan_kept],
		["The menu opened again is centred on the Player, not exploring", _test_reopen_centres],
		["Exploring, the Map key still closes the menu", _test_map_key_closes],
	]


func _test_interact_toggles() -> bool:
	var menu := _map_menu()
	var view := _map_view(menu)
	_tap(menu, &"interact")
	var valid: bool = view.call("is_exploring")
	_tap(menu, &"interact")
	valid = valid and not view.call("is_exploring")
	_close(menu)
	return valid


func _test_interact_needs_map() -> bool:
	var menu := _map_menu()
	(menu.get_node(MENU_ROOT + "ResumeButton") as Button).grab_focus()
	_tap(menu, &"interact")
	var valid: bool = not _map_view(menu).call("is_exploring")
	_close(menu)
	return valid


func _test_directions_pan() -> bool:
	var menu := _map_menu(&"close")
	var view := _map_view(menu)
	_tap(menu, &"interact")
	for action in [&"ui_right", &"ui_down", &"ui_left", &"move_right"]:
		_tap(menu, action)
	var valid := _map_button(menu).has_focus() and _shown_panel(menu) == "Map"
	_hold(view, &"move_right", ONE_SCREEN_TIME)
	var pan: Vector2 = view.call("pan")
	valid = valid and pan.is_equal_approx(Vector2(1, 0))
	_close(menu)
	return valid


func _test_same_speed() -> bool:
	var menu := _map_menu(&"near")
	var view := _map_view(menu)
	_tap(menu, &"interact")
	_hold(view, &"move_down", ONE_SCREEN_TIME)
	# The 20 pixels a Close screen spans, across Near screens 9 pixels tall.
	var pan: Vector2 = view.call("pan")
	var valid := pan.is_equal_approx(Vector2(0, 20.0 / 9.0))
	_close(menu)
	return valid


# A view wide and tall enough for the whole built World.
func _test_world_still() -> bool:
	var menu := _map_menu(&"world")
	var view := _map_view(menu)
	view.size = Vector2(400, 100)
	_tap(menu, &"interact")
	_hold(view, &"move_right", ONE_SCREEN_TIME)
	_hold(view, &"move_down", ONE_SCREEN_TIME)
	var valid: bool = view.call("pan") == Vector2.ZERO
	_close(menu)
	return valid


# A view too narrow for the built World at World zoom's smallest screen, 5 pixels wide; it still
# fits from top to bottom.
func _test_world_too_wide_pans() -> bool:
	var menu := _map_menu(&"world")
	var view := _map_view(menu)
	view.size = Vector2(100, view.size.y)
	_tap(menu, &"interact")
	# Far longer than the World is wide, to its east edge at the view's.
	_hold(view, &"move_right", 60.0)
	var held: Vector2 = view.call("pan")
	_hold(view, &"move_left", ONE_SCREEN_TIME)
	_hold(view, &"move_down", ONE_SCREEN_TIME)
	# The 20 pixels a Close screen spans, across World screens 5 pixels wide; none down.
	var back: Vector2 = view.call("pan")
	var valid := held.x > 0.0 and back.is_equal_approx(held - Vector2(4, 0))
	_close(menu)
	return valid


func _test_pan_clamped() -> bool:
	var menu := _map_menu(&"close")
	var view := _map_view(menu)
	_tap(menu, &"interact")
	# Far longer than the World is wide.
	_hold(view, &"move_left", 60.0)
	var held: Vector2 = view.call("pan")
	_hold(view, &"move_right", ONE_SCREEN_TIME)
	# Straight back off the edge: nothing piled up past it.
	var back: Vector2 = view.call("pan")
	var valid := held.x < 0.0 and is_equal_approx(back.x, held.x + 1.0)
	_close(menu)
	return valid


func _test_pan_kept() -> bool:
	var menu := _map_menu(&"close")
	var view := _map_view(menu)
	_tap(menu, &"interact")
	_hold(view, &"move_right", ONE_SCREEN_TIME)
	var pan: Vector2 = view.call("pan")
	_tap(menu, &"melee_attack")
	var valid: bool = view.call("zoom") == &"near" and view.call("pan") == pan
	_tap(menu, &"interact")
	valid = valid and not view.call("is_exploring") and view.call("pan") == pan
	_close(menu)
	return valid


func _test_reopen_centres() -> bool:
	var menu := _map_menu(&"close")
	var view := _map_view(menu)
	_tap(menu, &"interact")
	_hold(view, &"move_right", ONE_SCREEN_TIME)
	menu.call("toggle_pause")
	menu.call("toggle_pause")
	var valid: bool = view.call("pan") == Vector2.ZERO and not view.call("is_exploring")
	_close(menu)
	return valid


func _test_map_key_closes() -> bool:
	var menu := _map_menu()
	_tap(menu, &"interact")
	_press_key(menu, KEY_TAB)
	var valid := not menu.get_tree().paused
	_close(menu)
	return valid


# A paused menu on the Map, at the zoom given.
func _map_menu(zoom: StringName = &"world") -> Control:
	var input_setup := (load(INPUT_SETUP_SCRIPT_PATH) as GDScript).new() as Node
	input_setup.call("_register_inputs")
	input_setup.free()
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	menu.call("toggle_pause")
	_map_button(menu).grab_focus()
	for i in MapLayout.ZOOMS.size():
		_tap(menu, &"melee_attack")
	for i in MapLayout.ZOOMS.find(zoom):
		_tap(menu, &"jump")
	return menu


func _close(menu: Control) -> void:
	menu.get_tree().paused = false
	menu.free()


# Holds a direction down for the time given, as the Map's frames pass.
func _hold(view: Control, action: StringName, seconds: float) -> void:
	Input.action_press(action)
	view.call("_process", seconds)
	Input.action_release(action)


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
