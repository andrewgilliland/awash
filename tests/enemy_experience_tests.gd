extends RefCounted

const SCAVENGER_SCENE := preload("res://scenes/enemies/scavenger.tscn")
const STORM_WISP_SCENE := preload("res://scenes/enemies/storm_wisp.tscn")
const WRAITH_SCENE := preload("res://scenes/enemies/wraith.tscn")
const RUNE_SHORE_SCENE := preload("res://scenes/rooms/waking_coast_2.tscn")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
# Each enemy kind and the Experience its defeat is worth, as its spec says.
const WORTH := [[SCAVENGER_SCENE, 10], [STORM_WISP_SCENE, 15], [WRAITH_SCENE, 20]]
# Each enemy kind and its chance of leaving a Brinecap where it falls.
const DROP_CHANCES := [[SCAVENGER_SCENE, 0.25], [STORM_WISP_SCENE, 0.2], [WRAITH_SCENE, 0.35]]
const BRINECAP_SCENE_PATH := "res://scenes/items/brinecap.tscn"
const WORLD_LAYER := 1 << 0
const PLAYER_LAYER := 1 << 1
const TRIGGER_LAYER := 1 << 7

# Needs a root that is already in the tree: enemies wire their hurtboxes in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Each enemy kind is worth its own Experience", _test_each_kind_has_its_worth],
		["An enemy reports its defeat once, with its Experience", _test_reports_defeat_once],
		["A Room hands an enemy's defeat to the Player", _test_room_hands_defeat_to_player],
		["Each enemy kind has its own drop chance", _test_each_kind_has_drop_chance],
		["A lucky roll leaves a Brinecap where the enemy fell", _test_lucky_roll_drops],
		["An unlucky roll leaves nothing", _test_unlucky_roll_leaves_nothing],
		["A Brinecap rests on the world and watches for the Player", _test_brinecap_scene],
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


func _test_each_kind_has_drop_chance() -> bool:
	var valid := true
	for spec in DROP_CHANCES:
		var enemy := (spec[0] as PackedScene).instantiate()
		var chance: float = enemy.get_script().get_script_constant_map().get("DROP_CHANCE", -1.0)
		valid = valid and is_equal_approx(chance, spec[1])
		enemy.free()
	return valid


func _test_lucky_roll_drops() -> bool:
	var room := _rune_shore(0.0)
	var scavenger := room.get_node("Enemies/Scavenger") as Node2D
	scavenger.emit_signal(&"defeated", _worth(scavenger))
	# The Brinecap joins on the Room's next physics step, not mid-hit.
	var valid := _brinecaps(room).is_empty()
	room.call("_physics_process", 0.0)
	var dropped := _brinecaps(room)
	valid = valid and dropped.size() == 1
	if valid:
		var brinecap := dropped[0] as Node2D
		valid = brinecap.get("kind") == &"brinecap"
		valid = valid and brinecap.global_position == scavenger.global_position
	room.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _test_unlucky_roll_leaves_nothing() -> bool:
	var room := _rune_shore(0.99)
	var scavenger := room.get_node("Enemies/Scavenger")
	scavenger.emit_signal(&"defeated", _worth(scavenger))
	room.call("_physics_process", 0.0)
	var valid := _brinecaps(room).is_empty()
	room.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _test_brinecap_scene() -> bool:
	var scene := load(BRINECAP_SCENE_PATH) as PackedScene
	if scene == null:
		return false
	var brinecap := scene.instantiate() as CharacterBody2D
	var reach := brinecap.get_node_or_null("Reach") as Area2D if brinecap != null else null
	var valid := brinecap != null and reach != null
	valid = valid and brinecap.collision_layer == 0 and brinecap.collision_mask == WORLD_LAYER
	valid = valid and reach.collision_layer == TRIGGER_LAYER
	valid = valid and reach.collision_mask == PLAYER_LAYER
	valid = valid and brinecap.get_node_or_null("Sprite2D") is Sprite2D
	if brinecap != null:
		brinecap.free()
	return valid


# The rune shore, entered at its Entry, with its drop roll fixed at the given value.
func _rune_shore(roll: float) -> Node:
	var run := _root.get_node("RunState")
	run.call("start_run")
	run.call("enter_room", &"waking_coast_2", &"west")
	var room := RUNE_SHORE_SCENE.instantiate()
	room.set("drop_roll", func() -> float: return roll)
	_root.add_child(room)
	return room


func _brinecaps(room: Node) -> Array:
	return room.get_children().filter(
		func(node: Node) -> bool: return node.scene_file_path == BRINECAP_SCENE_PATH
	)
