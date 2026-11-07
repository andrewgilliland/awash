extends RefCounted

# The Undertow's playtests, played by tests/playtest_runner.gd with its harness: real Rooms, real
# input and physics.

const TIDEFEN_PATH := "res://scenes/rooms/tidefen_village_1.tscn"
const SHAFT_PATH := "res://scenes/rooms/undertow_1.tscn"
const TUNNEL_PATH := "res://scenes/rooms/waking_coast_9.tscn"
# The shaft's floor, two screens below the well.
const SHAFT_FLOOR_Y := 240.0
const HALL_PATH := "res://scenes/rooms/undertow_2.tscn"
const PASSAGE_PATH := "res://scenes/rooms/undertow_3.tscn"
const POOLS_PATH := "res://scenes/rooms/undertow_4.tscn"
const DEAD_END_PATH := "res://scenes/rooms/undertow_5.tscn"
const STAIR_PATH := "res://scenes/rooms/undertow_6.tscn"
const LAKE_PATH := "res://scenes/rooms/undertow_7.tscn"
# Down the temple stair: walking off each landing's end onto the one below, to the floor.
const STAIR_DOWN: Array[float] = [100.0, 120.0, 100.0, 120.0, 100.0, 40.0]
const STAIR_FLOOR_Y := 256.0
# Back up, a jump at a time: [direction, launch x, height landed on].
const STAIR_UP := [
	[1, 96.0, 224.0],
	[-1, 128.0, 192.0],
	[1, 96.0, 160.0],
	[-1, 128.0, 128.0],
	[1, 96.0, 96.0],
]
# West across the lake's shallows to its sealed door, and back east: a point on each sand bank,
# and one past the stepping stone in the middle shallow, which takes a hop from the water.
const LAKE_WEST: Array[float] = [440.0, 352.0, 230.0, 192.0, 40.0]
const LAKE_EAST: Array[float] = [192.0, 300.0, 352.0, 440.0]
const LAKE_FLOOR_Y := 96.0
# Down off the dead end's ledge to the wreck's floor, to its Cache, then back up the ledges a jump
# at a time: [direction, launch x, height landed on].
const DEAD_END_FLOOR_Y := 240.0
const CACHE_X := 268.0
# The wreck's Cache itself, where what it spills lands.
const SPILL_X := 280.0
const DEAD_END_CLIMB := [
	[-1, 256.0, 208.0],
	[-1, 200.0, 176.0],
	[1, 176.0, 144.0],
	[-1, 200.0, 112.0],
	[-1, 136.0, 96.0],
]
# The pools' floor, wading east through the first pool to the sand short of the way east, and
# back; then up, landing to landing, and a jump
# up through the opening into the tunnel: [direction, launch x, height landed on].
const POOLS_FLOOR_Y := 96.0
const POOLS_EAST: Array[float] = [150.0, 220.0]
const POOLS_WEST: Array[float] = [150.0, 60.0]
const POOLS_CLIMB := [[0, 72.0, 64.0], [0, 88.0, 32.0]]
const POOLS_LEAVE_X := 104.0
# Where the climb comes out: on the tunnel's sand beside the hole.
const TUNNEL_SOUTH_ENTRY := Vector2(296, 96)
# Up the temple hall from its floor, slab to slab, to the west ledge: [direction, launch x, height
# landed on].
const HALL_FLOOR_Y := 240.0
const HALL_CLIMB := [
	[-1, 256.0, 208.0],
	[-1, 200.0, 176.0],
	[1, 176.0, 144.0],
	[-1, 200.0, 112.0],
	[-1, 136.0, 96.0],
]
const SEA_CAVE_PATH := "res://scenes/rooms/waking_coast_5.tscn"
const SCAVENGER_PATH := "Enemies/Scavenger"
const WRAITH_PATH := "Enemies/Wraith"
const LURELIGHT_SCENE_PATH := "res://scenes/enemies/lurelight.tscn"
# West along the tunnel from its east end: through two pools to the hole in its floor, a jump over
# the hole, then through the last pool and over two rocks.
const TUNNEL_TO_HOLE: Array[float] = [470.0, 400.0, 300.0]
const TUNNEL_PAST_HOLE: Array[float] = [200.0, 90.0, 20.0]
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
		["Player drops into the pools under the tunnel and climbs back up", _pools_and_back],
		["Player opens the Cache in the dead end's wreck and climbs back out", _opens_cache],
		["Player goes down the temple stair, wades the lake and climbs back", _stair_and_lake],
	]


# The way home with real input: wade into Tidefen's well, land at the foot of its shaft, run the
# tunnel west, climb the temple hall, go along the passage to the Shortcut's wall, break it with a
# Charged Attack, and go on into the sea cave and up out of it at the salt cliffs' foot. The
# tunnel's Scavenger and Wraith are taken out first.
func _drops_home() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"tidefen_village_1", &"west", TIDEFEN_PATH
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
	await _harness.call("_wade_to", player, TUNNEL_TO_HOLE)
	await _harness.call("_jump_toward", player, -1)
	await _harness.call("_wade_to", player, TUNNEL_PAST_HOLE)
	valid = await _harness.call("_walk_until_scene", &"move_left", HALL_PATH)
	valid = valid and run.get("room_id") == &"undertow_2"
	player = _harness.call("_current_player")
	valid = valid and player != null and absf(player.global_position.y - HALL_FLOOR_Y) < 1.0
	for step in HALL_CLIMB:
		if not valid:
			break
		await _harness.call("_walk_to_x", player, step[1])
		await _harness.call("_jump_toward", player, step[0])
		valid = player.is_on_floor() and absf(player.global_position.y - step[2]) < 1.0
	valid = valid and await _harness.call("_walk_until_scene", &"move_left", PASSAGE_PATH)
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


# Down the hole in the tunnel's floor into the pools, onto the landing under it and off it to the
# floor, wading a pool east and back, then up the
# landings and out through the opening onto the tunnel's sand beside the hole. The tunnel's
# Scavenger and the pools' Lurelights are taken out first.
func _pools_and_back() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"waking_coast_9", &"south", TUNNEL_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	_harness.current_scene.get_node(SCAVENGER_PATH).free()
	var valid: bool = await _harness.call("_walk_until_scene", &"move_left", POOLS_PATH)
	valid = valid and run.get("room_id") == &"undertow_4"
	player = _harness.call("_current_player")
	if not valid or player == null:
		await _harness.call("_leave_scene")
		return false
	_take_out_lurelights()
	await _harness.call("_wade_to", player, POOLS_EAST)
	valid = absf(player.global_position.y - POOLS_FLOOR_Y) < 1.0
	valid = valid and player.global_position.x > 210.0
	await _harness.call("_wade_to", player, POOLS_WEST)
	for step in POOLS_CLIMB:
		await _harness.call("_walk_to_x", player, step[1])
		await _harness.call("_jump_toward", player, step[0])
		valid = valid and player.is_on_floor() and absf(player.global_position.y - step[2]) < 1.0
	await _harness.call("_walk_to_x", player, POOLS_LEAVE_X)
	_harness.call("_press", &"jump")
	valid = (
		valid
		and await _harness.call(
			"_frames_until",
			func() -> bool:
				return (
					_harness.current_scene != null
					and _harness.current_scene.scene_file_path == TUNNEL_PATH
				),
			180
		)
	)
	_harness.call("_release", &"jump")
	valid = valid and run.get("room_id") == &"waking_coast_9"
	await _harness.call(
		"_frames_until",
		func() -> bool:
			var landed: CharacterBody2D = _harness.call("_current_player")
			return landed != null and landed.is_on_floor(),
		120
	)
	player = _harness.call("_current_player")
	valid = valid and player != null
	valid = valid and player.global_position.distance_to(TUNNEL_SOUTH_ENTRY) < 1.0
	await _harness.call("_leave_scene")
	return valid


# From the pools east into the dead end, off its ledge down to the wreck, Interact with the Cache
# and take the Scale Mail it spills, worn at once, then back up the ledges and out west to the
# pools.
func _opens_cache() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"undertow_4", &"east", POOLS_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	var valid: bool = await _harness.call("_walk_until_scene", &"move_right", DEAD_END_PATH)
	valid = valid and run.get("room_id") == &"undertow_5"
	player = _harness.call("_current_player")
	if not valid or player == null:
		await _harness.call("_leave_scene")
		return false
	await _harness.call("_walk_to_x", player, CACHE_X)
	valid = absf(player.global_position.y - DEAD_END_FLOOR_Y) < 1.0
	await _harness.call("_tap", &"interact")
	await _harness.call("_walk_to_x", player, SPILL_X)
	var equipment = player.get("equipment")
	var worn := func() -> bool: return equipment.armor == &"scale_mail"
	valid = valid and await _harness.call("_frames_until", worn, 60)
	valid = valid and run.call("has_taken_cache", &"wreck_mail")
	for step in DEAD_END_CLIMB:
		if not valid:
			break
		await _harness.call("_walk_to_x", player, step[1])
		await _harness.call("_jump_toward", player, step[0])
		valid = player.is_on_floor() and absf(player.global_position.y - step[2]) < 1.0
	valid = valid and await _harness.call("_walk_until_scene", &"move_left", POOLS_PATH)
	valid = valid and run.get("room_id") == &"undertow_4"
	await _harness.call("_leave_scene")
	return valid


# From the pools' west end down the temple stair, landing to landing, into the lake; west across
# its shallows to the sealed door and back; then up the stair a jump at a time and out east. The
# lake's Lurelights are taken out first.
func _stair_and_lake() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"undertow_6", &"east", STAIR_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	for x in STAIR_DOWN:
		await _harness.call("_walk_to_x", player, x)
	var valid := player.is_on_floor() and absf(player.global_position.y - STAIR_FLOOR_Y) < 1.0
	valid = valid and await _harness.call("_walk_until_scene", &"move_left", LAKE_PATH)
	valid = valid and run.get("room_id") == &"undertow_7"
	player = _harness.call("_current_player")
	if not valid or player == null:
		await _harness.call("_leave_scene")
		return false
	_take_out_lurelights()
	await _harness.call("_wade_to", player, LAKE_WEST)
	valid = player.global_position.x < 48.0
	valid = valid and absf(player.global_position.y - LAKE_FLOOR_Y) < 1.0
	await _harness.call("_wade_to", player, LAKE_EAST)
	valid = valid and await _harness.call("_walk_until_scene", &"move_right", STAIR_PATH)
	valid = valid and run.get("room_id") == &"undertow_6"
	player = _harness.call("_current_player")
	valid = valid and player != null and absf(player.global_position.y - STAIR_FLOOR_Y) < 1.0
	for step in STAIR_UP:
		if not valid:
			break
		await _harness.call("_walk_to_x", player, step[1])
		await _harness.call("_jump_toward", player, step[0])
		valid = player.is_on_floor() and absf(player.global_position.y - step[2]) < 1.0
	valid = valid and await _harness.call("_walk_until_scene", &"move_right", POOLS_PATH)
	valid = valid and run.get("room_id") == &"undertow_4"
	await _harness.call("_leave_scene")
	return valid


# Frees every Lurelight in the current Room, for a playtest about the way rather than the fight.
func _take_out_lurelights() -> void:
	for enemy in _harness.current_scene.get_node("Enemies").get_children():
		if enemy.scene_file_path == LURELIGHT_SCENE_PATH:
			enemy.free()
