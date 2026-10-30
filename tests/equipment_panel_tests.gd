extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const Equipment := preload("res://scripts/items/equipment.gd")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MENU_ROOT := "CenterContainer/MenuPanel/MarginContainer/VBoxContainer/"
const BODY := MENU_ROOT + "ContentRoot/EquipmentPanel/Body/"
const SWORD_ICON := "res://assets/sprites/items/short_sword.png"
const TUNIC_ICON := "res://assets/sprites/items/worn_leather_tunic.png"
const PANEL := MENU_ROOT + "ContentRoot/EquipmentPanel/"
const SWORD_TEXT := "A plain blade Mara pulled from the sand."
const TUNIC_TEXT := "Faded by salt. Light, but gives no Defense."

# Needs a root that is already in the tree: the Player reads the Run from /root in _ready.
var _root: Window


# Armor that gives Defense 5, standing in for the upgrades that will give it.
class GuardedEquipment:
	extends "res://scripts/items/equipment.gd"

	func defense_with(armor_id: StringName) -> int:
		return 5 if not armor_id.is_empty() else 0


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["The Equipment Panel shows the Weapon and the Armor above a divider", _test_slot_rows],
		["Below the divider are the focused slot's pieces, the equipped one marked", _test_choices],
		["Down from the Armor goes to Resume; up comes back", _test_slots_to_resume],
		["Choosing a slot moves into its pieces; up from the top goes back", _test_move_into],
		["Choosing None takes the Armor off; choosing the Armor puts it on", _test_choose_none],
		["Choosing the piece equipped goes back and changes nothing", _test_choose_equipped],
		["Defense shows, with what it would become while an Armor is focused", _test_defense],
		["At the Panel's foot, a slot describes its piece and a piece itself", _test_descriptions],
	]


func _test_slot_rows() -> bool:
	var menu := _equipment_menu()
	var weapon := _row(menu, "WeaponRow")
	var armor := _row(menu, "ArmorRow")
	var valid := weapon != null and armor != null
	if valid:
		valid = weapon.text == "Weapon" and _piece(weapon) == "Short Sword"
		valid = valid and weapon.icon.resource_path == SWORD_ICON
		valid = valid and armor.text == "Armor" and _piece(armor) == "Worn Leather Tunic"
		valid = valid and armor.icon.resource_path == TUNIC_ICON
		valid = valid and armor.icon_alignment == HORIZONTAL_ALIGNMENT_RIGHT
		var divider := menu.get_node(BODY + "Divider")
		valid = valid and weapon.get_index() < armor.get_index()
		valid = valid and armor.get_index() < divider.get_index()
		valid = valid and divider.get_index() < _choices(menu).get_index()
	_close(menu)
	return valid


func _test_choices() -> bool:
	var menu := _equipment_menu()
	var valid := _names(menu) == ["Short Sword"] and _marks(menu) == ["Equipped"]
	_navigate(menu, &"ui_down")
	valid = valid and _row(menu, "WeaponRow").has_focus() and _names(menu) == ["Short Sword"]
	_navigate(menu, &"ui_down")
	valid = valid and _row(menu, "ArmorRow").has_focus()
	valid = valid and _names(menu) == ["None", "Worn Leather Tunic"]
	valid = valid and _marks(menu) == ["", "Equipped"]
	var tunic := _choices(menu).get_child(1) as Button
	valid = valid and tunic.icon.resource_path == TUNIC_ICON
	for row in _choices(menu).get_children():
		valid = valid and (row as Button).focus_mode == Control.FOCUS_NONE
	_close(menu)
	return valid


func _test_slots_to_resume() -> bool:
	var menu := _equipment_menu()
	for i in 3:
		_navigate(menu, &"ui_down")
	var valid := (menu.get_node(MENU_ROOT + "ResumeButton") as Button).has_focus()
	valid = valid and _names(menu) == ["None", "Worn Leather Tunic"]
	_navigate(menu, &"ui_up")
	valid = valid and _row(menu, "ArmorRow").has_focus()
	_close(menu)
	return valid


func _test_move_into() -> bool:
	var menu := _equipment_menu()
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_accept")
	var tunic := _choices(menu).get_child(1) as Button
	var none := _choices(menu).get_child(0) as Button
	var armor := _row(menu, "ArmorRow")
	# The slot being chosen for stays lit, in the colour it has with focus.
	var lit := armor.get_theme_color(&"font_focus_color")
	var valid := tunic.has_focus() and armor.get_theme_color(&"font_color") == lit
	_navigate(menu, &"ui_down")
	valid = valid and tunic.has_focus()
	_navigate(menu, &"ui_up")
	valid = valid and none.has_focus()
	_navigate(menu, &"ui_up")
	valid = valid and armor.has_focus() and not armor.has_theme_color_override(&"font_color")
	valid = valid and none.focus_mode == Control.FOCUS_NONE
	valid = valid and _player().get("equipment").armor == Equipment.STARTING_ARMOR
	_close(menu)
	return valid


func _test_choose_none() -> bool:
	var menu := _equipment_menu()
	var run := _root.get_node("RunState")
	var armor := _row(menu, "ArmorRow")
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_accept")
	_navigate(menu, &"ui_up")
	_navigate(menu, &"ui_accept")
	var valid: bool = _player().get("equipment").armor == &"" and run.get("player_armor") == &""
	valid = valid and armor.has_focus() and _piece(armor) == "None" and armor.icon == null
	# The row keeps its height without the icon.
	valid = valid and armor.get_combined_minimum_size().y == 10.0
	valid = valid and _marks(menu) == ["Equipped", ""]
	_navigate(menu, &"ui_accept")
	valid = valid and (_choices(menu).get_child(0) as Button).has_focus()
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_accept")
	valid = valid and _player().get("equipment").armor == Equipment.STARTING_ARMOR
	valid = valid and _piece(armor) == "Worn Leather Tunic" and _marks(menu) == ["", "Equipped"]
	_close(menu)
	return valid


func _test_choose_equipped() -> bool:
	var menu := _equipment_menu()
	var weapon := _row(menu, "WeaponRow")
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_accept")
	var valid := (_choices(menu).get_child(0) as Button).has_focus()
	_navigate(menu, &"ui_accept")
	valid = valid and weapon.has_focus() and _player().get("equipment").weapon == &"short_sword"
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_accept")
	_navigate(menu, &"ui_accept")
	valid = valid and _row(menu, "ArmorRow").has_focus()
	valid = valid and _player().get("equipment").armor == Equipment.STARTING_ARMOR
	_close(menu)
	return valid


func _test_defense() -> bool:
	var menu := _equipment_menu(GuardedEquipment.new())
	var defense := menu.get_node(BODY + "Defense") as Label
	var valid := defense.text == "DEF 5"
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_accept")
	valid = valid and defense.text == "DEF 5 > 5"
	_navigate(menu, &"ui_up")
	valid = valid and defense.text == "DEF 5 > 0"
	_navigate(menu, &"ui_up")
	valid = valid and defense.text == "DEF 5"
	_close(menu)
	return valid


func _test_descriptions() -> bool:
	var menu := _equipment_menu()
	var strip := menu.get_node_or_null(PANEL + "Description") as Label
	var valid := strip != null and _strip_at_foot(menu.get_node(PANEL), strip)
	valid = valid and strip.text == ""
	var steps := [
		[&"ui_down", SWORD_TEXT],
		[&"ui_down", TUNIC_TEXT],
		[&"ui_accept", TUNIC_TEXT],
		[&"ui_up", ""],
		[&"ui_up", TUNIC_TEXT],
		[&"ui_down", ""],
	]
	for step in steps:
		if valid:
			_navigate(menu, step[0])
			valid = strip.text == step[1]
	_close(menu)
	return valid


# Whether the strip sits under a divider at the foot of the Panel, below its Body, in two lines,
# and keeps its height with one line or none.
static func _strip_at_foot(panel: Node, strip: Label) -> bool:
	var body := panel.get_node("Body") as Control
	var divider := panel.get_node_or_null("Divider")
	var two_lines := strip.get_line_height() * 2 + strip.get_theme_constant(&"line_spacing")
	return (
		strip.custom_minimum_size.y == two_lines
		and divider is HSeparator
		and body.get_index() < divider.get_index()
		and divider.get_index() < strip.get_index()
		and body.size_flags_vertical & Control.SIZE_EXPAND != 0
		and strip.autowrap_mode == TextServer.AUTOWRAP_WORD
		and strip.max_lines_visible == 2
	)


# The Pause menu, on the Equipment tab, with a Player in a fresh Run, in the given Equipment if
# any.
func _equipment_menu(equipment: Object = null) -> Control:
	_root.get_node("RunState").call("start_run")
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	_root.add_child(player)
	if equipment != null:
		player.set("equipment", equipment)
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	menu.call("toggle_pause")
	(menu.get_node(MENU_ROOT + "MenuButtons/EquipmentButton") as Button).grab_focus()
	return menu


func _row(menu: Control, row_name: String) -> Button:
	return menu.get_node_or_null(BODY + row_name) as Button


func _piece(row: Button) -> String:
	return (row.get_node("Piece") as Label).text


func _choices(menu: Control) -> Control:
	return menu.get_node(BODY + "Choices") as Control


func _names(menu: Control) -> Array:
	return _choices(menu).get_children().map(func(row: Button) -> String: return row.text)


func _marks(menu: Control) -> Array:
	return _choices(menu).get_children().map(
		func(row: Button) -> String: return (row.get_node("Mark") as Label).text
	)


func _player() -> Node:
	return _root.get_tree().get_first_node_in_group(&"player")


func _navigate(menu: Control, action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		menu.get_viewport().push_input(event)


func _close(menu: Control) -> void:
	menu.get_tree().paused = false
	menu.free()
	_player().free()
	_root.get_node("RunState").call("start_run")
