extends RefCounted

# The Bomb's playtests, played by tests/playtest_runner.gd with its harness: real Rooms, real
# input and physics.

const TIDEFEN_PATH := "res://scenes/rooms/tidefen_village_1.tscn"
const PASSAGE_PATH := "res://scenes/rooms/undertow_3.tscn"
const BOMB := &"bomb"
# The fishers' pier at Tidefen's east end, where the bomb crate stands; the Player is set down
# on it, east of the crate.
const PIER_Y := 80.0
const ON_PIER := Vector2(840, 60)
const CRATE_X := 790.0
# Back from the Shortcut's wall, out of the sword's reach of it.
const BACK_FROM_WALL_X := 100.0
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
