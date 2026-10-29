extends RefCounted

const SCAVENGER_SCENE := preload("res://scenes/enemies/scavenger.tscn")
const STORM_WISP_SCENE := preload("res://scenes/enemies/storm_wisp.tscn")
const WRAITH_SCENE := preload("res://scenes/enemies/wraith.tscn")
const RUNE_SHORE_SCENE := preload("res://scenes/rooms/waking_coast_2.tscn")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
# Each enemy kind and the Experience its defeat is worth, as its spec says.
const WORTH := [[SCAVENGER_SCENE, 10], [STORM_WISP_SCENE, 15], [WRAITH_SCENE, 20]]

# Needs a root that is already in the tree: enemies wire their hurtboxes in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Each enemy kind is worth its own Experience", _test_each_kind_has_its_worth],
		["An enemy reports its defeat once, with its Experience", _test_reports_defeat_once],
		["A Room hands an enemy's defeat to the Player", _test_room_hands_defeat_to_player],
	]


func _test_each_kind_has_its_worth() -> bool:
	var valid := true
	for spec in WORTH:
		var enemy := (spec[0] as PackedScene).instantiate()
		valid = valid and enemy.is_in_group(&"enemy") and _worth(enemy) == spec[1]
		enemy.free()
	return valid


func _test_reports_defeat_once() -> bool:
	var valid := true
	for spec in WORTH:
		var enemy := (spec[0] as PackedScene).instantiate()
		_root.add_child(enemy)
		var reported: Array[int] = []
		enemy.connect(&"defeated", func(experience: int) -> void: reported.append(experience))
		var hitbox := Hitbox.new()
		hitbox.damage = 1000
		var hurtbox := enemy.get_node("Hurtbox")
		hurtbox.call("take_hit", hitbox)
		hurtbox.call("take_hit", hitbox)
		valid = valid and reported == [spec[1]]
		hitbox.free()
		enemy.free()
	return valid


func _test_room_hands_defeat_to_player() -> bool:
	var run := _root.get_node("RunState")
	run.call("start_run")
	run.call("enter_room", &"waking_coast_2", &"west")
	var room := RUNE_SHORE_SCENE.instantiate()
	_root.add_child(room)
	var scavenger := room.get_node("Enemies/Scavenger")
	scavenger.emit_signal(&"defeated", _worth(scavenger))
	var player := room.get_node("Player")
	var valid: bool = player.get("level").experience == _worth(scavenger)
	valid = valid and run.get("player_experience") == _worth(scavenger)
	room.free()
	run.call("start_run")
	return valid


static func _worth(enemy: Node) -> int:
	return enemy.get_script().get_script_constant_map().get("EXPERIENCE", -1)
