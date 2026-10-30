extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const Equipment := preload("res://scripts/items/equipment.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")

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
