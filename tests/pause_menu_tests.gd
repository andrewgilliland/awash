extends RefCounted

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MENU_ROOT := "CenterContainer/MenuPanel/MarginContainer/VBoxContainer/"
const PANEL_NAMES: Array[String] = ["Stats", "Equipment", "Map"]
const SCREEN_SIZE := Vector2(160, 144)
const COMPACT_FONT_PATH := "res://assets/fonts/awash_pixel_3x5.png"
const INPUT_SETUP_SCRIPT_PATH := "res://scripts/core/input_setup.gd"

# Needs a root that is already in the tree: the Pause menu pauses through get_tree().
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Pause menu opens on the first Panel", _test_opens_on_first_panel],
		["Focusing a menu button shows its Panel", _test_focus_shows_panel],
		["Left and right move from Panel to Panel, wrapping", _test_left_right_moves_panels],
		["The Player's move keys page the Pause menu too", _test_move_keys_page_menu],
		["Down to Resume keeps the Panel; up returns to its button", _test_down_keeps_panel],
		["Pause menu opens on the first Panel each time", _test_reopens_on_first_panel],
		["Pause menu Resume unpauses", _test_resume_unpauses],
		["Pause menu pairs every button with a Panel", _test_pairs_buttons_with_panels],
		["Pause menu disables a button with no Panel", _test_disables_unpaired_button],
		["Pause menu fits the screen", _test_fits_the_screen],
		["Pause menu text uses the compact pixel font", _test_text_uses_pixel_font],
		["Map Panel names the Room's region", _test_map_names_region],
		["Map keeps far Rooms inside its Panel", _test_map_clips_far_rooms],
	]


func _test_opens_on_first_panel() -> bool:
	var menu := _paused_menu()
	var valid := menu.get_tree().paused
	valid = valid and menu.get_node("Backdrop").visible
	valid = valid and menu.get_node("CenterContainer/MenuPanel").visible
	valid = valid and _shown_panel(menu) == "Stats"
	valid = valid and _menu_button(menu, "Stats").has_focus()
	_close(menu)
	return valid


func _test_focus_shows_panel() -> bool:
	var menu := _paused_menu()
	var valid := true
	for panel_name in PANEL_NAMES:
		_menu_button(menu, panel_name).grab_focus()
		valid = valid and _shown_panel(menu) == panel_name
	_close(menu)
	return valid


func _test_left_right_moves_panels() -> bool:
	var menu := _paused_menu()
	var valid := true
	for panel_name in ["Equipment", "Map", "Stats"]:
		_navigate(menu, &"ui_right")
		valid = valid and _menu_button(menu, panel_name).has_focus()
		valid = valid and _shown_panel(menu) == panel_name
	_navigate(menu, &"ui_left")
	valid = valid and _menu_button(menu, "Map").has_focus() and _shown_panel(menu) == "Map"
	_close(menu)
	return valid


# A and D walk the Player, so they page the menu as the arrows do.
func _test_move_keys_page_menu() -> bool:
	var input_setup := (load(INPUT_SETUP_SCRIPT_PATH) as GDScript).new() as Node
	input_setup.call("_register_inputs")
	input_setup.free()
	var menu := _paused_menu()
	_press_key(menu, KEY_D)
	var valid := _shown_panel(menu) == "Equipment"
	_press_key(menu, KEY_A)
	_press_key(menu, KEY_A)
	valid = valid and _shown_panel(menu) == "Map"
	_close(menu)
	return valid


func _test_down_keeps_panel() -> bool:
	var menu := _paused_menu()
	_navigate(menu, &"ui_right")
	_navigate(menu, &"ui_down")
	var valid := (menu.get_node(MENU_ROOT + "ResumeButton") as Button).has_focus()
	valid = valid and _shown_panel(menu) == "Equipment"
	# Up returns to the shown Panel's button.
	_navigate(menu, &"ui_up")
	valid = valid and _menu_button(menu, "Equipment").has_focus()
	_close(menu)
	return valid


func _test_reopens_on_first_panel() -> bool:
	var menu := _paused_menu()
	_navigate(menu, &"ui_left")
	menu.call("toggle_pause")
	menu.call("toggle_pause")
	var valid := _shown_panel(menu) == "Stats" and _menu_button(menu, "Stats").has_focus()
	_close(menu)
	return valid


func _test_resume_unpauses() -> bool:
	var menu := _paused_menu()
	(menu.get_node(MENU_ROOT + "ResumeButton") as Button).pressed.emit()
	var valid := not menu.get_tree().paused
	valid = valid and not menu.get_node("Backdrop").visible
	valid = valid and not menu.get_node("CenterContainer/MenuPanel").visible
	_close(menu)
	return valid


# Every <Name>Button shows a <Name>Panel, every Panel has a button, and no Panel needs a Back.
func _test_pairs_buttons_with_panels() -> bool:
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	var menu_buttons := menu.get_node(MENU_ROOT + "MenuButtons")
	var content_root := menu.get_node(MENU_ROOT + "ContentRoot")
	var valid := true
	for button in menu_buttons.get_children():
		var panel_name := button.name.trim_suffix("Button")
		var panel := content_root.get_node_or_null("%sPanel" % panel_name)
		valid = valid and button is Button and button.name.ends_with("Button")
		valid = valid and panel != null and panel.get_node_or_null("BackButton") == null
	for panel in content_root.get_children():
		var panel_name := panel.name.trim_suffix("Panel")
		valid = valid and menu_buttons.get_node_or_null("%sButton" % panel_name) != null
	menu.free()
	return valid


func _test_disables_unpaired_button() -> bool:
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	menu.get_node(MENU_ROOT + "ContentRoot/MapPanel").name = "AtlasPanel"
	_root.add_child(menu)
	var valid := _menu_button(menu, "Map").disabled
	valid = valid and not _menu_button(menu, "Stats").disabled
	# Left and right pass over it, from Equipment round to Stats.
	menu.call("toggle_pause")
	_navigate(menu, &"ui_right")
	_navigate(menu, &"ui_right")
	valid = valid and _menu_button(menu, "Stats").has_focus() and _shown_panel(menu) == "Stats"
	_close(menu)
	return valid


# The game draws at 160x144, so the menu and every Panel's content must fit inside it.
func _test_fits_the_screen() -> bool:
	var menu := _paused_menu()
	var menu_panel := menu.get_node("CenterContainer/MenuPanel") as Control
	var menu_size := menu_panel.get_combined_minimum_size()
	var content_root := menu.get_node(MENU_ROOT + "ContentRoot") as Control
	var content_height := content_root.get_combined_minimum_size().y
	var valid := menu_size.x <= SCREEN_SIZE.x and menu_size.y <= SCREEN_SIZE.y
	for panel in content_root.get_children():
		var panel_size := (panel as Control).get_combined_minimum_size()
		valid = valid and panel_size.y <= content_height and panel_size.x <= menu_size.x
	_close(menu)
	return valid


func _test_text_uses_pixel_font() -> bool:
	var menu := _paused_menu()
	var valid := true
	for node in menu.find_children("*", "Control", true, false):
		if node is not Label and node is not Button:
			continue
		var font := (node as Control).get_theme_font(&"font")
		valid = valid and font != null and font.resource_path == COMPACT_FONT_PATH
		var text: String = node.text
		for i in text.length():
			valid = valid and font != null and font.has_char(text.unicode_at(i))
		# The menu's own look still applies around the smaller text.
		if node is Button:
			valid = valid and (node as Button).get_theme_stylebox(&"focus") is StyleBoxFlat
	_close(menu)
	return valid


func _test_map_names_region() -> bool:
	var menu := _paused_menu()
	_menu_button(menu, "Map").grab_focus()
	var title := menu.get_node(MENU_ROOT + "ContentRoot/MapPanel/Title") as Label
	var valid := title.text == "Waking Coast"
	_close(menu)
	return valid


# A coast wider than the Panel runs off its edges rather than over the menu's frame.
func _test_map_clips_far_rooms() -> bool:
	var menu := _paused_menu()
	var map_view := menu.get_node(MENU_ROOT + "ContentRoot/MapPanel/MapView") as Control
	var valid := map_view.clip_contents
	_close(menu)
	return valid


func _paused_menu() -> Control:
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	menu.call("toggle_pause")
	return menu


func _close(menu: Control) -> void:
	menu.get_tree().paused = false
	menu.free()


func _menu_button(menu: Control, panel_name: String) -> Button:
	return menu.get_node(MENU_ROOT + "MenuButtons/%sButton" % panel_name) as Button


func _press_key(menu: Control, key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
		menu.get_viewport().push_input(event)


# Presses and lets go of a ui_ direction, as a keyboard or pad would, moving the menu's focus.
func _navigate(menu: Control, action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		menu.get_viewport().push_input(event)


# The name of the one visible Panel, or "" when none or several are visible.
func _shown_panel(menu: Control) -> String:
	var shown: Array[String] = []
	for panel in menu.get_node(MENU_ROOT + "ContentRoot").get_children():
		if (panel as Control).visible:
			shown.append(panel.name.trim_suffix("Panel"))
	return shown[0] if shown.size() == 1 else ""
