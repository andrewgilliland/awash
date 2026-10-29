extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const Equipment := preload("res://scripts/items/equipment.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MENU_ROOT := "CenterContainer/MenuPanel/MarginContainer/VBoxContainer/"
const EQUIPMENT_BODY := MENU_ROOT + "ContentRoot/EquipmentPanel/Body/"
const TUNIC_ICON := "res://assets/sprites/items/worn_leather_tunic.png"

# Needs a root that is already in the tree: the Player reads the Run from /root in _ready.
var _root: Window


# Armor with Defense 5, standing in for the upgrades that will give it.
class GuardedEquipment:
	extends "res://scripts/items/equipment.gd"

	func defense() -> int:
		return 5


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Player wears the Run's Armor", _test_wears_runs_armor],
		["The Worn Leather Tunic leaves a spear hit at 10", _test_tunic_leaves_hits],
		["Defense takes its value off each hit the Player takes", _test_defense_takes_off],
		["Taking Armor off and putting it on goes into the Run", _test_armor_changes_reach_run],
		["Player starts with the Run's Armor taken off", _test_starts_bare],
		["The Armor row shows the piece worn and its icon", _test_armor_row],
		["On the Armor row, the Armor owned is listed, the worn one marked", _test_armor_list],
		["Leaving the Armor hides the list; up from Resume comes back", _test_list_hides],
		["Choosing the worn Armor takes it off; choosing it again puts it on", _test_choose],
	]


func _test_wears_runs_armor() -> bool:
	var run := _root.get_node("RunState")
	run.call("start_run")
	var valid: bool = run.get("player_armor") == Equipment.STARTING_ARMOR
	var player := _player()
	valid = valid and player.get("equipment").armor == Equipment.STARTING_ARMOR
	player.free()
	return valid


func _test_tunic_leaves_hits() -> bool:
	_root.get_node("RunState").call("start_run")
	var player := _player()
	var health = player.get("health")
	var cost := _hit(player, 10)
	player.free()
	return cost == 10 and health.current == health.maximum - 10


func _test_defense_takes_off() -> bool:
	_root.get_node("RunState").call("start_run")
	var player := _player()
	player.set("equipment", GuardedEquipment.new())
	var valid := _hit(player, 10) == 5 and _hit(player, 15) == 10
	player.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _test_armor_row() -> bool:
	var menu := _equipment_menu()
	var row := _armor_row(menu)
	var valid := row != null and row.text == "Armor"
	if valid:
		valid = (row.get_node("Piece") as Label).text == "Worn Leather Tunic"
		valid = valid and row.icon != null and row.icon.resource_path == TUNIC_ICON
		valid = valid and row.icon_alignment == HORIZONTAL_ALIGNMENT_RIGHT
		valid = valid and not _list(menu).visible
	_close(menu)
	return valid


func _test_armor_list() -> bool:
	var menu := _equipment_menu()
	_navigate(menu, &"ui_down")
	var valid := _armor_row(menu).has_focus() and _list(menu).visible
	var rows := _list(menu).get_children()
	valid = valid and rows.size() == 1
	if valid:
		var tunic := rows[0] as Button
		valid = tunic.text == "Worn Leather Tunic" and tunic.icon.resource_path == TUNIC_ICON
		valid = valid and (tunic.get_node("Worn") as Label).text == "Worn"
	_close(menu)
	return valid


func _test_list_hides() -> bool:
	var menu := _equipment_menu()
	var tab := menu.get_node(MENU_ROOT + "MenuButtons/EquipmentButton") as Button
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_up")
	var valid := tab.has_focus() and not _list(menu).visible
	for i in 3:
		_navigate(menu, &"ui_down")
	valid = valid and (menu.get_node(MENU_ROOT + "ResumeButton") as Button).has_focus()
	valid = valid and not _list(menu).visible
	_navigate(menu, &"ui_up")
	valid = valid and _armor_row(menu).has_focus() and _list(menu).visible
	_close(menu)
	return valid


func _test_choose() -> bool:
	var menu := _equipment_menu()
	var run := _root.get_node("RunState")
	var player := _root.get_tree().get_first_node_in_group(&"player")
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_accept")
	var row := _armor_row(menu)
	var tunic := _list(menu).get_child(0) as Button
	var valid: bool = player.get("equipment").armor == &"" and run.get("player_armor") == &""
	valid = valid and (row.get_node("Piece") as Label).text == "None" and row.icon == null
	# The row keeps its height without the icon.
	valid = valid and row.get_combined_minimum_size().y == 10.0
	valid = valid and (tunic.get_node("Worn") as Label).text == "" and row.has_focus()
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_accept")
	valid = valid and player.get("equipment").armor == Equipment.STARTING_ARMOR
	valid = valid and (row.get_node("Piece") as Label).text == "Worn Leather Tunic"
	valid = valid and (tunic.get_node("Worn") as Label).text == "Worn"
	_close(menu)
	return valid


# The Pause menu, on the Equipment tab, with a Player in a fresh Run.
func _equipment_menu() -> Control:
	_root.get_node("RunState").call("start_run")
	_player()
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	menu.call("toggle_pause")
	(menu.get_node(MENU_ROOT + "MenuButtons/EquipmentButton") as Button).grab_focus()
	return menu


func _armor_row(menu: Control) -> Button:
	return menu.get_node_or_null(EQUIPMENT_BODY + "ArmorRow") as Button


func _list(menu: Control) -> Control:
	return menu.get_node(EQUIPMENT_BODY + "ArmorList") as Control


func _navigate(menu: Control, action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		menu.get_viewport().push_input(event)


func _close(menu: Control) -> void:
	menu.get_tree().paused = false
	menu.free()
	_root.get_tree().get_first_node_in_group(&"player").free()
	_root.get_node("RunState").call("start_run")


func _test_armor_changes_reach_run() -> bool:
	var run := _root.get_node("RunState")
	run.call("start_run")
	var player := _player()
	player.call("take_off_armor")
	var valid: bool = player.get("equipment").armor == &"" and run.get("player_armor") == &""
	valid = valid and player.call("wear_armor", Equipment.STARTING_ARMOR)
	valid = valid and run.get("player_armor") == Equipment.STARTING_ARMOR
	valid = valid and not player.call("wear_armor", &"nothing")
	player.free()
	run.call("start_run")
	return valid


func _test_starts_bare() -> bool:
	var run := _root.get_node("RunState")
	run.call("start_run")
	run.set("player_armor", &"")
	var player := _player()
	var equipment = player.get("equipment")
	var valid: bool = equipment.armor == &"" and equipment.owned == [Equipment.STARTING_ARMOR]
	player.free()
	run.call("start_run")
	return valid


# Lands a hit of the given strength on the Player, once it can be hit again, and returns what
# it cost.
func _hit(player: CharacterBody2D, damage: int) -> int:
	var health = player.get("health")
	health.step(10.0)
	var before: int = health.current
	var hitbox := Hitbox.new()
	hitbox.damage = damage
	hitbox.position = player.position + Vector2(10, 0)
	_root.add_child(hitbox)
	player.call("_on_hurtbox_hit", hitbox)
	hitbox.free()
	return before - health.current


func _player() -> CharacterBody2D:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = Vector2(100, 100)
	_root.add_child(player)
	return player
