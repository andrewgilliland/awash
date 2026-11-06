extends RefCounted

const SCAVENGER_SCENE := preload("res://scenes/enemies/scavenger.tscn")
const STORM_WISP_SCENE := preload("res://scenes/enemies/storm_wisp.tscn")
const WRAITH_SCENE := preload("res://scenes/enemies/wraith.tscn")
const LURELIGHT_SCENE := preload("res://scenes/enemies/lurelight.tscn")
const PALM_SHORE_SCENE := preload("res://scenes/rooms/waking_coast_2.tscn")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
# Each enemy kind and the Experience its defeat is worth, as its spec says.
const WORTH := [
	[SCAVENGER_SCENE, 10], [STORM_WISP_SCENE, 15], [WRAITH_SCENE, 20], [LURELIGHT_SCENE, 15]
]
# Each enemy kind, its chance of leaving a Supply where it falls, and which Supply.
const DROPS := [
	[SCAVENGER_SCENE, 0.25, &"brinecap"],
	[STORM_WISP_SCENE, 0.2, &"brinecap"],
	[WRAITH_SCENE, 0.35, &"mourning_salt"],
	[LURELIGHT_SCENE, 0.2, &"glowroe"],
]
const BRINECAP_SCENE_PATH := "res://scenes/items/brinecap.tscn"
const OATHBLADE_SCENE_PATH := "res://scenes/items/oathblade.tscn"
const SUPPLY_SCENE_PATHS := [
	BRINECAP_SCENE_PATH, "res://scenes/items/glowroe.tscn", "res://scenes/items/mourning_salt.tscn"
]
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
		["Each enemy kind drops its own Supply, a Brinecap by default", _test_each_kind_drops],
		["A lucky roll leaves a Brinecap where the enemy fell", _test_lucky_roll_drops],
		["A lucky roll leaves the Supply that enemy drops", _test_lucky_roll_drops_its_kind],
		["An unlucky roll leaves nothing", _test_unlucky_roll_leaves_nothing],
		["A Wraith may also leave the Oathblade, on a roll of its own", _test_wraith_weapon],
		["A lucky Wraith leaves the Oathblade beside its Supply", _test_lucky_wraith_weapon],
		["A Wraith leaves no Oathblade once the Player owns it", _test_no_second_oathblade],
		["The Oathblade rests on the world, and a touch collects it", _test_oathblade_scene],
		["Each dropped Supply rests on the world and watches for the Player", _test_supply_scenes],
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
	var room := PALM_SHORE_SCENE.instantiate()
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
	for spec in DROPS:
		var enemy := (spec[0] as PackedScene).instantiate()
		var chance: float = enemy.get_script().get_script_constant_map().get("DROP_CHANCE", -1.0)
		valid = valid and is_equal_approx(chance, spec[1])
		enemy.free()
	return valid


func _test_each_kind_drops() -> bool:
	var valid := true
	for spec in DROPS:
		var enemy := (spec[0] as PackedScene).instantiate()
		var drop: StringName = enemy.get_script().get_script_constant_map().get("DROP", &"brinecap")
		valid = valid and drop == spec[2]
		enemy.free()
	return valid


func _test_lucky_roll_drops() -> bool:
	var room := _palm_shore(0.0)
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


# A Wraith and a Lurelight brought into the palm shore each leave their own kind.
func _test_lucky_roll_drops_its_kind() -> bool:
	var room := _palm_shore(0.0, [WRAITH_SCENE, LURELIGHT_SCENE])
	var wraith := room.get_node("Enemies/Wraith") as Node2D
	var lurelight := room.get_node("Enemies/Lurelight") as Node2D
	wraith.emit_signal(&"defeated", _worth(wraith))
	lurelight.emit_signal(&"defeated", _worth(lurelight))
	room.call("_physics_process", 0.0)
	var dropped := _supplies(room)
	var valid := dropped.size() == 2
	if valid:
		valid = dropped[0].get("kind") == &"mourning_salt"
		valid = valid and dropped[0].scene_file_path == SUPPLY_SCENE_PATHS[2]
		valid = valid and dropped[0].global_position == wraith.global_position
		valid = valid and dropped[1].get("kind") == &"glowroe"
		valid = valid and dropped[1].scene_file_path == SUPPLY_SCENE_PATHS[1]
		valid = valid and dropped[1].global_position == lurelight.global_position
	room.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _test_wraith_weapon() -> bool:
	var wraith := WRAITH_SCENE.instantiate()
	var constants: Dictionary = wraith.get_script().get_script_constant_map()
	var valid: bool = constants.get("WEAPON_DROP") == &"oathblade"
	valid = valid and is_equal_approx(constants.get("WEAPON_DROP_CHANCE", -1.0), 0.1)
	wraith.free()
	for spec in [SCAVENGER_SCENE, STORM_WISP_SCENE, LURELIGHT_SCENE]:
		var enemy := (spec as PackedScene).instantiate()
		valid = valid and not enemy.get_script().get_script_constant_map().has("WEAPON_DROP")
		enemy.free()
	return valid


func _test_lucky_wraith_weapon() -> bool:
	var room := _palm_shore(0.0, [WRAITH_SCENE])
	var wraith := room.get_node("Enemies/Wraith") as Node2D
	wraith.emit_signal(&"defeated", _worth(wraith))
	room.call("_physics_process", 0.0)
	var weapons := _oathblades(room)
	var valid := weapons.size() == 1 and _supplies(room).size() == 1
	if valid:
		valid = weapons[0].get("kind") == &"oathblade"
		valid = valid and weapons[0].global_position == wraith.global_position + Vector2(8, 0)
	room.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _test_no_second_oathblade() -> bool:
	var room := _palm_shore(0.0, [WRAITH_SCENE])
	room.get_node("Player").call("collect_weapon", &"oathblade")
	var wraith := room.get_node("Enemies/Wraith") as Node2D
	wraith.emit_signal(&"defeated", _worth(wraith))
	room.call("_physics_process", 0.0)
	var valid := _oathblades(room).is_empty() and _supplies(room).size() == 1
	room.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _test_oathblade_scene() -> bool:
	if not _rests_and_watches(OATHBLADE_SCENE_PATH):
		return false
	var oathblade := (load(OATHBLADE_SCENE_PATH) as PackedScene).instantiate()
	var valid: bool = oathblade.get("collect_method") == &"collect_weapon"
	oathblade.free()
	var brinecap := (load(BRINECAP_SCENE_PATH) as PackedScene).instantiate()
	valid = valid and brinecap.get("collect_method") == &"collect"
	brinecap.free()
	return valid


func _test_unlucky_roll_leaves_nothing() -> bool:
	var room := _palm_shore(0.99)
	var scavenger := room.get_node("Enemies/Scavenger")
	scavenger.emit_signal(&"defeated", _worth(scavenger))
	room.call("_physics_process", 0.0)
	var valid := _brinecaps(room).is_empty() and _oathblades(room).is_empty()
	room.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _test_supply_scenes() -> bool:
	var valid := true
	for path: String in SUPPLY_SCENE_PATHS:
		valid = valid and _rests_and_watches(path)
	return valid


func _rests_and_watches(path: String) -> bool:
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		return false
	var supply := scene.instantiate() as CharacterBody2D
	var reach := supply.get_node_or_null("Reach") as Area2D if supply != null else null
	var valid := supply != null and reach != null
	valid = valid and supply.collision_layer == 0 and supply.collision_mask == WORLD_LAYER
	valid = valid and reach.collision_layer == TRIGGER_LAYER
	valid = valid and reach.collision_mask == PLAYER_LAYER
	valid = valid and supply.get_node_or_null("Sprite2D") is Sprite2D
	valid = valid and supply.get("kind") == StringName(path.get_file().get_basename())
	if supply != null:
		supply.free()
	return valid


# The palm shore, entered at its Entry, with its drop roll fixed at the given value, and any
# extra enemies brought in among its own.
func _palm_shore(roll: float, extra: Array = []) -> Node:
	var run := _root.get_node("RunState")
	run.call("start_run")
	run.call("enter_room", &"waking_coast_2", &"west")
	var room := PALM_SHORE_SCENE.instantiate()
	room.set("drop_roll", func() -> float: return roll)
	for i in extra.size():
		var enemy := (extra[i] as PackedScene).instantiate() as Node2D
		enemy.position = Vector2(64 + 48 * i, 40)
		room.get_node("Enemies").add_child(enemy)
	_root.add_child(room)
	return room


func _supplies(room: Node) -> Array:
	return room.get_children().filter(
		func(node: Node) -> bool: return node.scene_file_path in SUPPLY_SCENE_PATHS
	)


func _oathblades(room: Node) -> Array:
	return room.get_children().filter(
		func(node: Node) -> bool: return node.scene_file_path == OATHBLADE_SCENE_PATH
	)


func _brinecaps(room: Node) -> Array:
	return room.get_children().filter(
		func(node: Node) -> bool: return node.scene_file_path == BRINECAP_SCENE_PATH
	)
