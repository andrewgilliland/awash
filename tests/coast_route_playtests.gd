extends RefCounted

# The Waking Coast's walks through the Rooms built from the Plan, played by
# tests/playtest_runner.gd with its harness: real Rooms, real input and physics.

const PALM_SHORE_PATH := "res://scenes/rooms/waking_coast_2.tscn"
const SALT_CLIFFS_PATH := "res://scenes/rooms/waking_coast_3.tscn"
const WRECK_GRAVEYARD_PATH := "res://scenes/rooms/waking_coast_4.tscn"
const WAKING_COAST_SAND_Y := 96.0
# The salt cliffs' beach, two screens down, and the cliff top the climb ends on.
const SALT_CLIFFS_BEACH_Y := 240.0
const SALT_CLIFFS_TOP_Y := 64.0
const CLIFF_TOP_Y := 64.0
const TIDE_POOLS_PATH := "res://scenes/rooms/waking_coast_10.tscn"
# The sand between the tide pools, east and back west: points to walk to, jumping out of a pool
# when the walk falls short.
const TIDE_POOLS_EAST: Array[float] = [80.0, 112.0, 150.0, 200.0, 224.0, 256.0, 300.0]
const TIDE_POOLS_WEST: Array[float] = [256.0, 224.0, 200.0, 150.0, 112.0, 80.0, 40.0]
const CLIFF_TOPS_PATH := "res://scenes/rooms/waking_coast_12.tscn"
# Along the cliff tops, east and back west: into the hollow and out, and over the mossy rock,
# jumping whenever the walk stops short.
const CLIFF_TOPS_EAST: Array[float] = [150.0, 176.0, 210.0, 280.0, 300.0]
const CLIFF_TOPS_WEST: Array[float] = [210.0, 176.0, 150.0, 100.0, 40.0]
const GULL_LEDGES_PATH := "res://scenes/rooms/waking_coast_11.tscn"
# The gull ledges' ground, on from the salt cliffs' top, and the climb up its planks to the cliff
# top, a jump at a time: [direction, launch x, height landed on].
const GULL_LEDGES_GROUND_Y := 208.0
const GULL_LEDGES_CLIMB := [
	[-1, 56.0, 176.0],
	[1, 40.0, 144.0],
	[-1, 56.0, 112.0],
	[1, 40.0, 80.0],
	[1, 72.0, CLIFF_TOP_Y],
]
# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Player wades the tide pools from the palm shore to the salt cliffs", _walks_to_cliffs],
		[
			"Player climbs the gull ledges from the salt cliffs to the cliff tops",
			_climbs_gull_ledges
		],
		["Player walks the cliff tops from the gull ledges to the graveyard", _walks_cliff_tops],
	]


# From the palm shore's east end through the tide pools into the salt cliffs' beach, then back.
func _walks_to_cliffs() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"waking_coast_2", &"east", PALM_SHORE_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	var valid: bool = await _harness.call("_walk_until_scene", &"move_right", TIDE_POOLS_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_10"
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and absf(player.global_position.y - WAKING_COAST_SAND_Y) < 1.0
	if not valid:
		await _harness.call("_leave_scene")
		return false
	await _harness.call("_wade_to", player, TIDE_POOLS_EAST)
	valid = valid and await _harness.call("_walk_until_scene", &"move_right", SALT_CLIFFS_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_3"
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and absf(player.global_position.y - SALT_CLIFFS_BEACH_Y) < 1.0

	valid = valid and await _harness.call("_walk_until_scene", &"move_left", TIDE_POOLS_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_10"
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x > 280.0
	if not valid:
		await _harness.call("_leave_scene")
		return false
	await _harness.call("_wade_to", player, TIDE_POOLS_WEST)
	valid = valid and await _harness.call("_walk_until_scene", &"move_left", PALM_SHORE_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_2"
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x > 280.0
	await _harness.call("_leave_scene")
	return valid


# From the salt cliffs' top onto the gull ledges' ground, up its planks to the cliff top and on
# along the cliff tops; back west to the cliff top, and from the ledges' ground back to the salt
# cliffs' top.
func _climbs_gull_ledges() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"waking_coast_3", &"east", SALT_CLIFFS_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	var valid: bool = await _harness.call("_walk_until_scene", &"move_right", GULL_LEDGES_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_11"
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and absf(player.global_position.y - GULL_LEDGES_GROUND_Y) < 1.0
	for step in GULL_LEDGES_CLIMB:
		if not valid:
			break
		await _harness.call("_walk_to_x", player, step[1])
		await _harness.call("_jump_toward", player, step[0])
		valid = player.is_on_floor() and absf(player.global_position.y - step[2]) < 1.0
	valid = valid and await _harness.call("_walk_until_scene", &"move_right", CLIFF_TOPS_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_12"
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and absf(player.global_position.y - CLIFF_TOP_Y) < 1.0

	valid = valid and await _harness.call("_walk_until_scene", &"move_left", GULL_LEDGES_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_11"
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x > 120.0
	valid = valid and absf(player.global_position.y - CLIFF_TOP_Y) < 1.0
	await _harness.call("_leave_scene")

	player = await _harness.call("_enter_room", &"waking_coast_11", &"west", GULL_LEDGES_PATH)
	valid = valid and player != null
	valid = valid and await _harness.call("_walk_until_scene", &"move_left", SALT_CLIFFS_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_3"
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x > 120.0
	valid = valid and absf(player.global_position.y - SALT_CLIFFS_TOP_Y) < 1.0
	await _harness.call("_leave_scene")
	return valid


# From the gull ledges' cliff top along the cliff tops, through the hollow and over the rock, to
# the wreck graveyard's cliff; then back west to the gull ledges.
func _walks_cliff_tops() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"waking_coast_12", &"west", CLIFF_TOPS_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	await _harness.call("_wade_to", player, CLIFF_TOPS_EAST)
	var valid: bool = await _harness.call("_walk_until_scene", &"move_right", WRECK_GRAVEYARD_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_4"
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and absf(player.global_position.y - CLIFF_TOP_Y) < 1.0

	valid = valid and await _harness.call("_walk_until_scene", &"move_left", CLIFF_TOPS_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_12"
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x > 280.0
	valid = valid and absf(player.global_position.y - CLIFF_TOP_Y) < 1.0
	if not valid:
		await _harness.call("_leave_scene")
		return false
	await _harness.call("_wade_to", player, CLIFF_TOPS_WEST)
	valid = valid and await _harness.call("_walk_until_scene", &"move_left", GULL_LEDGES_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_11"
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x > 120.0
	valid = valid and absf(player.global_position.y - CLIFF_TOP_Y) < 1.0
	await _harness.call("_leave_scene")
	return valid
