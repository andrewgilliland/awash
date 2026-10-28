extends RefCounted

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MENU_ROOT := "CenterContainer/MenuPanel/MarginContainer/VBoxContainer/"
const PANEL_NAMES: Array[String] = ["Stats", "Equipment", "Map"]

# Needs a root that is already in the tree: the Pause menu pauses through get_tree().
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Pause menu pauses on Home", _test_pauses_on_home],
		["Pause menu opens each Panel from its button", _test_opens_each_panel],
		["Pause menu Back returns to Home", _test_back_returns_home],
		["Pause menu Resume unpauses", _test_resume_unpauses],
		["Pause menu Back refocuses the opening button", _test_back_refocuses_opener],
		["Pause menu pairs every button with a Panel", _test_pairs_buttons_with_panels],
		["Pause menu disables a button with no Panel", _test_disables_unpaired_button],
	]


func _test_pauses_on_home() -> bool:
	var menu := _paused_menu()
	var valid := menu.get_tree().paused
	valid = valid and menu.get_node("Backdrop").visible
	valid = valid and menu.get_node("CenterContainer/MenuPanel").visible
	valid = valid and _shown_panel(menu) == "Home"
	valid = valid and _menu_button(menu, "Stats").has_focus()
	_close(menu)
	return valid


func _test_opens_each_panel() -> bool:
	var menu := _paused_menu()
	var valid := true
	for panel_name in PANEL_NAMES:
		_menu_button(menu, panel_name).pressed.emit()
		valid = valid and _shown_panel(menu) == panel_name
		valid = valid and _back_button(menu, panel_name).has_focus()
	_close(menu)
	return valid


func _test_back_returns_home() -> bool:
	var menu := _paused_menu()
	_menu_button(menu, "Equipment").pressed.emit()
	_back_button(menu, "Equipment").pressed.emit()
	var valid := _shown_panel(menu) == "Home"
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


func _test_back_refocuses_opener() -> bool:
	var menu := _paused_menu()
	_menu_button(menu, "Map").pressed.emit()
	_back_button(menu, "Map").pressed.emit()
	var valid := _menu_button(menu, "Map").has_focus()
	_close(menu)
	return valid


# Every <Name>Button opens a <Name>Panel that has a BackButton; every Panel but Home has a button.
func _test_pairs_buttons_with_panels() -> bool:
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	var menu_buttons := menu.get_node(MENU_ROOT + "MenuButtons")
	var content_root := menu.get_node(MENU_ROOT + "ContentRoot")
	var valid := true
	for button in menu_buttons.get_children():
		var panel_name := button.name.trim_suffix("Button")
		var panel := content_root.get_node_or_null("%sPanel" % panel_name)
		valid = valid and button is Button and button.name.ends_with("Button")
		valid = valid and panel != null and panel.get_node_or_null("BackButton") is Button
	for panel in content_root.get_children():
		var panel_name := panel.name.trim_suffix("Panel")
		if panel_name != "Home":
			valid = valid and menu_buttons.get_node_or_null("%sButton" % panel_name) != null
	menu.free()
	return valid


func _test_disables_unpaired_button() -> bool:
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	menu.get_node(MENU_ROOT + "ContentRoot/MapPanel").name = "AtlasPanel"
	_root.add_child(menu)
	var valid := _menu_button(menu, "Map").disabled
	valid = valid and not _menu_button(menu, "Stats").disabled
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


func _back_button(menu: Control, panel_name: String) -> Button:
	return menu.get_node(MENU_ROOT + "ContentRoot/%sPanel/BackButton" % panel_name) as Button


# The name of the one visible Panel, or "" when none or several are visible.
func _shown_panel(menu: Control) -> String:
	var shown: Array[String] = []
	for panel in menu.get_node(MENU_ROOT + "ContentRoot").get_children():
		if (panel as Control).visible:
			shown.append(panel.name.trim_suffix("Panel"))
	return shown[0] if shown.size() == 1 else ""
