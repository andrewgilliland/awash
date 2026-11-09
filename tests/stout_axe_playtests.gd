extends RefCounted

# The Stout Axe's playtests, played by tests/playtest_runner.gd with its harness: real Rooms, real
# input and physics. The pools' chest holds it, its quick slash chops the Shortcut's cracked wall,
# and its Charged Attack throws it spinning in an arc.

const POOLS_PATH := "res://scenes/rooms/undertow_4.tscn"
const PASSAGE_PATH := "res://scenes/rooms/undertow_3.tscn"
const STOUT_AXE := &"stout_axe"
# The pools' chest stands by their east Entry.
const CHEST_X := 300.0
# Long enough for a spill to land.
const LAND_FRAMES := 60
# Up against the Shortcut's wall, in the sword's reach of it.
const AT_WALL_X := 76.0
# Out in the passage, with room ahead for a throw to land.
const OPEN_FLOOR_X := 240.0
# A full Charge is half a second of holding melee; a few frames more to be sure.
const CHARGE_FRAMES := 36

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Player opens the pools' chest and takes up the Stout Axe", _chest_holds_axe],
		["A quick slash of the Stout Axe chops the Shortcut's wall", _axe_chops_wall],
		["A Charged Attack with the Stout Axe throws it in an arc", _axe_throw_arcs],
	]


# At the chest, Interact opens it and spills the Stout Axe; once it lands it is taken, owned and
# held.
func _chest_holds_axe() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"undertow_4", &"east", POOLS_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	_harness.call("_clear_enemies")
	await _harness.call("_walk_to_x", player, CHEST_X)
	await _harness.call("_frames", 5)
	await _harness.call("_tap", &"interact")
	await _harness.call("_frames", 3)
	var chest := _harness.current_scene.get_node("Cache")
	var valid: bool = chest.call("is_open")
	var equipment = player.get("equipment")
	var held := func() -> bool: return equipment.weapon == STOUT_AXE
	valid = valid and await _harness.call("_frames_until", held, LAND_FRAMES)
	valid = valid and equipment.owns_weapon(STOUT_AXE)
	await _harness.call("_leave_scene")
	return valid


# Holding the Stout Axe, up against the cracked wall, one quick slash breaks it.
func _axe_chops_wall() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"undertow_3", &"east", PASSAGE_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	_harness.call("_clear_enemies")
	var run := _harness.root.get_node("RunState")
	player.call("collect_weapon", STOUT_AXE)
	await _harness.call("_walk_to_x", player, AT_WALL_X)
	await _harness.call("_swing")
	await _harness.call("_frames", 5)
	var wall := _harness.current_scene.get_node("ShortcutWall") as StaticBody2D
	var valid: bool = run.call("has_opened_shortcut", &"sea_cave_wall") and not wall.visible
	await _harness.call("_leave_scene")
	return valid


# A full Charge let go throws the axe: it rises above the Player, comes down ahead of it, and is
# gone once it meets the floor.
func _axe_throw_arcs() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"undertow_3", &"east", PASSAGE_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	_harness.call("_clear_enemies")
	player.call("collect_weapon", STOUT_AXE)
	await _harness.call("_walk_to_x", player, OPEN_FLOOR_X)
	await _harness.call("_tap", &"move_left")
	_harness.call("_press", &"melee_attack")
	await _harness.call("_frames", CHARGE_FRAMES)
	_harness.call("_release", &"melee_attack")
	await _harness.call("_frames", 2)
	var throws := _harness.root.get_tree().get_nodes_in_group(&"axe_throw")
	var valid := throws.size() == 1
	if valid:
		var axe := throws[0] as Node2D
		var start := axe.global_position
		var highest := start.y
		var lowest := start.y
		var gone := false
		for i in 90:
			await _harness.call("_frames", 1)
			if not is_instance_valid(axe):
				gone = true
				break
			highest = minf(highest, axe.global_position.y)
			lowest = maxf(lowest, axe.global_position.y)
		valid = gone and highest < start.y - 10.0 and lowest > start.y
	await _harness.call("_leave_scene")
	return valid
