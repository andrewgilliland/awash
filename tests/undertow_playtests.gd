extends RefCounted

# The Undertow's playtests, played by tests/playtest_runner.gd with its harness: real Rooms, real
# input and physics.

const TIDEFEN_PATH := "res://scenes/rooms/waking_coast_8.tscn"
const SHAFT_PATH := "res://scenes/rooms/undertow_1.tscn"
const TUNNEL_PATH := "res://scenes/rooms/waking_coast_9.tscn"
# The shaft's floor, two screens below the well.
const SHAFT_FLOOR_Y := 240.0
const PASSAGE_PATH := "res://scenes/rooms/undertow_3.tscn"
const SEA_CAVE_PATH := "res://scenes/rooms/waking_coast_5.tscn"
const SCAVENGER_PATH := "Enemies/Scavenger"
const WRAITH_PATH := "Enemies/Wraith"
# West along the tunnel from its east end: through three pools and over two rocks.
const TUNNEL_WEST: Array[float] = [470.0, 400.0, 280.0, 200.0, 90.0, 20.0]
# Up against the Shortcut's wall, in the sword's reach of it.
const AT_WALL_X := 76.0
# A full Charge is half a second of holding melee; a few frames more to be sure.
const CHARGE_FRAMES := 36

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Tidefen's well drops home through the undertow and its Shortcut", _drops_home],
		["A quick Attack leaves the Shortcut's wall standing", _quick_attack_glances],
	]


# The way home with real input: wade into Tidefen's well, land at the foot of its shaft, run the
# tunnel west, along the passage to the Shortcut's wall, break it with a Charged Attack, and on
# into the sea cave and up out of it at the salt cliffs' foot. The tunnel's Scavenger and Wraith
# are taken out first.
func _drops_home() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"waking_coast_8", &"west", TIDEFEN_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	var valid: bool = await _harness.call("_walk_until_scene", &"move_right", SHAFT_PATH)
	valid = valid and run.get("room_id") == &"undertow_1"
	player = _harness.call("_current_player")
	valid = valid and player != null and player.is_on_floor()
	valid = valid and absf(player.global_position.y - SHAFT_FLOOR_Y) < 1.0
	valid = valid and await _harness.call("_walk_until_scene", &"move_left", TUNNEL_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_9"
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x > 600.0
	if not valid:
		await _harness.call("_leave_scene")
		return false
	_harness.current_scene.get_node(SCAVENGER_PATH).free()
	_harness.current_scene.get_node(WRAITH_PATH).free()
	await _harness.call("_wade_to", player, TUNNEL_WEST)
	valid = await _harness.call("_walk_until_scene", &"move_left", PASSAGE_PATH)
	valid = valid and run.get("room_id") == &"undertow_3"
	player = _harness.call("_current_player")
	if not valid or player == null:
		await _harness.call("_leave_scene")
		return false
	await _charge_at_wall(player)
	valid = run.call("has_opened_shortcut", &"sea_cave_wall")
	valid = valid and await _harness.call("_walk_until_scene", &"move_left", SEA_CAVE_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_5"
	player = _harness.call("_current_player")
	if not valid or player == null:
		await _harness.call("_leave_scene")
		return false
	valid = await _harness.call("_climb_out_of_cave", player)
	await _harness.call("_leave_scene")
	return valid


# A quick swing at the wall glances off: it stands, and walking west stays in the passage.
func _quick_attack_glances() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"undertow_3", &"east", PASSAGE_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	await _harness.call("_walk_to_x", player, AT_WALL_X)
	await _harness.call("_swing")
	var wall := _harness.current_scene.get_node("ShortcutWall") as StaticBody2D
	var valid: bool = wall.visible and not run.call("has_opened_shortcut", &"sea_cave_wall")
	await _harness.call("_walk_to_x", player, 0.0)
	valid = valid and player.global_position.x > AT_WALL_X - 16.0
	valid = valid and _harness.current_scene.scene_file_path == PASSAGE_PATH
	await _harness.call("_leave_scene")
	return valid


# Walks up to the wall, faces it and lets a full Charge go.
func _charge_at_wall(player: CharacterBody2D) -> void:
	await _harness.call("_walk_to_x", player, AT_WALL_X)
	await _harness.call("_tap", &"move_left")
	_harness.call("_press", &"melee_attack")
	await _harness.call("_frames", CHARGE_FRAMES)
	_harness.call("_release", &"melee_attack")
	await _harness.call("_frames", 20)
