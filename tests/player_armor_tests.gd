extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const Equipment := preload("res://scripts/items/equipment.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MENU_ROOT := "CenterContainer/MenuPanel/MarginContainer/VBoxContainer/"

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
		["Equipment shows the Armor worn, slot left and piece right", _test_equipment_panel],
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


func _test_equipment_panel() -> bool:
	_root.get_node("RunState").call("start_run")
	var player := _player()
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	menu.call("toggle_pause")
	(menu.get_node(MENU_ROOT + "MenuButtons/EquipmentButton") as Button).grab_focus()
	var body := menu.get_node(MENU_ROOT + "ContentRoot/EquipmentPanel/Body") as GridContainer
	var valid := body != null and body.columns == 2 and body.get_child_count() == 2
	if valid:
		var slot := body.get_child(0) as Label
		var piece := body.get_child(1) as Label
		valid = slot.text == "Armor" and piece.text == "Worn Leather Tunic"
		valid = valid and slot.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT
		valid = valid and piece.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
		valid = valid and piece.size_flags_horizontal & Control.SIZE_EXPAND != 0
		valid = valid and piece.focus_mode == Control.FOCUS_NONE
	menu.get_tree().paused = false
	menu.free()
	player.free()
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
