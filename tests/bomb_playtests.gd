extends RefCounted

# The Bomb's playtests, played by tests/playtest_runner.gd with its harness: real Rooms, real
# input and physics.

const TIDEFEN_PATH := "res://scenes/rooms/tidefen_village_1.tscn"
const PASSAGE_PATH := "res://scenes/rooms/undertow_3.tscn"
const SEA_CAVE_PATH := "res://scenes/rooms/waking_coast_5.tscn"
const BOMB := &"bomb"
# The fishers' pier at Tidefen's east end, where the bomb crate stands; the Player is set down
# on it, east of the crate.
const PIER_Y := 80.0
const ON_PIER := Vector2(840, 60)
const CRATE_X := 790.0
# Back from the Shortcut's wall, out of the sword's reach of it.
const BACK_FROM_WALL_X := 100.0
# In the sea cave, back from the rock across the Shortcut to lob a Bomb at it, and up against it.
const SEA_CAVE_THROW_X := 236.0
const AT_ROCK_X := 276.0
# A full Charge, held.
const CHARGE_FRAMES := 36
# A Bomb's fuse and burst, and a few frames more to be sure.
const FUSE_FRAMES := 60
const BURST_FRAMES := 30

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Player opens Tidefen's bomb crate and lobs a Bomb onto the pier", _crate_and_lob],
		["A Bomb's blast breaks the Shortcut's wall", _bomb_breaks_wall],
		["A Bomb breaks the sea cave's rock, and the Shortcut leads on", _bomb_breaks_rock],
		["A Charged Attack knocks off the sea cave's rock", _charge_knocks_rock],
	]


# Set down on the pier, the Player walks to the bomb crate and opens it, then throws a Bomb
# east: it lands and rests on the pier's planks, then bursts and is gone.
func _crate_and_lob() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"tidefen_village_1", &"west", TIDEFEN_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	player.global_position = ON_PIER
	await _harness.call("_frames_until", player.is_on_floor, 60)
	await _harness.call("_walk_to_x", player, CRATE_X)
	await _harness.call("_tap", &"interact")
	await _harness.call("_frames", 10)
	var sub_weapons = player.get("sub_weapons")
	var valid: bool = sub_weapons.held == BOMB and sub_weapons.count(BOMB) == 5
	await _harness.call("_tap", &"move_right")
	await _harness.call("_tap", &"ranged_attack")
	var bombs := _harness.get_nodes_in_group(&"bomb")
	valid = valid and bombs.size() == 1 and sub_weapons.count(BOMB) == 4
	if valid:
		var bomb := bombs[0] as CharacterBody2D
		await _harness.call("_frames", FUSE_FRAMES - 10)
		# At rest on the planks, east of where it left the hand.
		valid = absf(bomb.global_position.y + 4.0 - PIER_Y) < 1.0
		valid = valid and bomb.global_position.x > player.global_position.x
		valid = valid and bomb.velocity == Vector2.ZERO
		await _harness.call("_frames", BURST_FRAMES)
		valid = valid and not is_instance_valid(bomb)
	await _harness.call("_leave_scene")
	return valid


# Back from the Shortcut's wall, facing it, the Player lobs a Bomb at it: its blast breaks the
# wall, as a Charged Attack's would.
func _bomb_breaks_wall() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"undertow_3", &"east", PASSAGE_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	player.call("collect_sub_weapon", BOMB)
	await _harness.call("_walk_to_x", player, BACK_FROM_WALL_X)
	await _harness.call("_tap", &"move_left")
	await _harness.call("_tap", &"ranged_attack")
	await _harness.call("_frames", FUSE_FRAMES + BURST_FRAMES)
	var wall := _harness.current_scene.get_node("ShortcutWall") as StaticBody2D
	var valid: bool = run.call("has_opened_shortcut", &"sea_cave_wall") and not wall.visible
	await _harness.call("_leave_scene")
	return valid


# In the sea cave, back from the rock across the Shortcut, the Player lobs a Bomb east at it: it
# crumbles, the Run remembers, and walking east leads into the Undertow's passage, its cracked
# wall open too.
func _bomb_breaks_rock() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"waking_coast_5", &"north", SEA_CAVE_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	player.call("collect_sub_weapon", BOMB)
	await _harness.call("_walk_to_x", player, SEA_CAVE_THROW_X)
	await _harness.call("_tap", &"ranged_attack")
	await _harness.call("_frames", FUSE_FRAMES + BURST_FRAMES)
	var rock := _harness.current_scene.get_node("BreakableWall")
	var valid: bool = rock.call("is_broken") and run.call("has_broken_wall", &"sea_cave_rock")
	valid = valid and run.call("has_opened_shortcut", &"sea_cave_wall")
	valid = valid and await _harness.call("_walk_until_scene", &"move_right", PASSAGE_PATH)
	if valid:
		var wall := _harness.current_scene.get_node("ShortcutWall") as StaticBody2D
		valid = not wall.visible
	await _harness.call("_leave_scene")
	return valid


# Up against the rock, the Player lets a full Charge go at it: it knocks off, the rock stands,
# and walking east stays in the sea cave.
func _charge_knocks_rock() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"waking_coast_5", &"north", SEA_CAVE_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	await _harness.call("_walk_to_x", player, AT_ROCK_X)
	_harness.call("_press", &"melee_attack")
	await _harness.call("_frames", CHARGE_FRAMES)
	_harness.call("_release", &"melee_attack")
	await _harness.call("_frames", 20)
	var rock := _harness.current_scene.get_node("BreakableWall") as Node2D
	var valid: bool = rock.visible and not rock.call("is_broken")
	valid = valid and not run.call("has_opened_shortcut", &"sea_cave_wall")
	await _harness.call("_walk_to_x", player, 330.0)
	valid = valid and _harness.current_scene.scene_file_path == SEA_CAVE_PATH
	await _harness.call("_leave_scene")
	return valid
