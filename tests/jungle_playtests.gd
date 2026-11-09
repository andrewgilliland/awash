extends RefCounted

# The Low Canopy Jungle's walks with real input, played by tests/playtest_runner.gd with its
# harness: off Tidefen's landing onto the harbour trail, up past its waterfall to the lower
# terraces, up the terraces' beds to the relief, across the canopy walk's broken bridge, up the
# upper terraces, and up the shrine steps to the camp's open gate.

const TIDEFEN_PATH := "res://scenes/rooms/tidefen_village_1.tscn"
const TRAIL_PATH := "res://scenes/rooms/low_canopy_jungle_1.tscn"
const TERRACES_PATH := "res://scenes/rooms/low_canopy_jungle_2.tscn"
# Where each walk lands: the trail's shore, level with Tidefen's landing; the terraces' entry,
# level with the trail's end.
const SHORE_Y := 112.0
const TERRACES_ENTRY_Y := 208.0
# Up the trail: under the ledge over the pool, a jump onto it, then one across the waterfall onto
# the bank, and on east over the root step.
const UNDER_LEDGE_X := 72.0
const LEDGE_Y := 80.0
const LEDGE_END_X := 104.0
const BANK_Y := 64.0
const TRAIL_EAST: Array[float] = [200.0, 300.0]
# Up the terraces: over the broken wall in the low bed, up each bed's wall, to the top bed.
const BEDS_EAST: Array[float] = [200.0, 300.0, 350.0, 400.0, 450.0]
const TOP_BED_Y := 112.0
# From the top bed's west end, across onto the plank deck, then west along it and down onto the
# terrace the relief stands on.
const TOP_BED_WEST_X := 440.0
const DECK_Y := 80.0
const RELIEF_TERRACE := Vector2(200, 96)
const CANOPY_WALK_PATH := "res://scenes/rooms/low_canopy_jungle_3.tscn"
const UPPER_TERRACES_PATH := "res://scenes/rooms/low_canopy_jungle_4.tscn"
const SHRINE_STEPS_PATH := "res://scenes/rooms/low_canopy_jungle_6.tscn"
# Running along the bridge's west half, the jump over its gap leaves from here, at full pace.
const BRIDGE_LEAP_X := 136.0
const BRIDGE_Y := 80.0
# Up the upper terraces, a jump at a time: [direction, launch x, height landed on]. Onto the first
# ledge, the second bed, three ledges zigzagging up, the third bed, two ledges and the top deck.
const UPPER_CLIMB := [
	[1, 36.0, 336.0],
	[1, 92.0, 304.0],
	[-1, 116.0, 272.0],
	[-1, 52.0, 240.0],
	[1, 40.0, 208.0],
	[1, 104.0, 176.0],
	[-1, 116.0, 144.0],
	[0, 72.0, 112.0],
	[1, 92.0, 80.0],
]
const STEPS_TOP_Y := 80.0
# Up the shrine steps to the camp's open gate.
const STEPS_EAST: Array[float] = [120.0, 200.0, 240.0]
const GATE_Y := 48.0

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Player walks off Tidefen's landing onto the harbour trail", _off_tidefen],
		["Player climbs the harbour trail past its waterfall to the terraces", _up_the_trail],
		["Player climbs the medicine beds and crosses the deck to the relief", _up_the_terraces],
		["Player leaps the canopy walk's broken bridge to the upper terraces", _over_the_bridge],
		["Player climbs the upper terraces to the shrine steps", _up_the_upper_terraces],
		["Player climbs the shrine steps to the camp's open gate", _to_the_gate],
	]


func _off_tidefen() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"tidefen_village_1", &"east", TIDEFEN_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var valid: bool = await _harness.call("_walk_until_scene", &"move_right", TRAIL_PATH)
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and absf(player.global_position.y - SHORE_Y) < 1.0
	await _harness.call("_leave_scene")
	return valid


func _up_the_trail() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"low_canopy_jungle_1", &"west", TRAIL_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	await _harness.call("_walk_to_x", player, UNDER_LEDGE_X)
	await _harness.call("_jump_toward", player, 1)
	var valid := absf(player.global_position.y - LEDGE_Y) < 1.0
	await _harness.call("_walk_to_x", player, LEDGE_END_X)
	await _harness.call("_jump_toward", player, 1)
	valid = valid and absf(player.global_position.y - BANK_Y) < 1.0
	await _harness.call("_wade_to", player, TRAIL_EAST)
	valid = valid and await _harness.call("_walk_until_scene", &"move_right", TERRACES_PATH)
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and absf(player.global_position.y - TERRACES_ENTRY_Y) < 1.0
	await _harness.call("_leave_scene")
	return valid


func _up_the_terraces() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"low_canopy_jungle_2", &"west", TERRACES_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	await _harness.call("_wade_to", player, BEDS_EAST)
	var valid := absf(player.global_position.y - TOP_BED_Y) < 1.0
	await _harness.call("_walk_to_x", player, TOP_BED_WEST_X)
	await _harness.call("_jump_toward", player, -1)
	valid = valid and absf(player.global_position.y - DECK_Y) < 1.0
	await _harness.call("_walk_to_x", player, RELIEF_TERRACE.x)
	valid = valid and player.is_on_floor()
	valid = valid and absf(player.global_position.y - RELIEF_TERRACE.y) < 1.0
	await _harness.call("_leave_scene")
	return valid


# Running east along the bridge, a jump at full pace clears its gap; on to the far deck and off it.
# The walk plays the layout, its Stalker gone; tests/stalker_playtests.gd fights it.
func _over_the_bridge() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"low_canopy_jungle_3", &"west", CANOPY_WALK_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	_harness.call("_clear_enemies")
	_harness.call("_press", &"move_right")
	var at_leap := func() -> bool: return player.global_position.x >= BRIDGE_LEAP_X
	var valid: bool = await _harness.call("_frames_until", at_leap, 240)
	_harness.call("_press", &"jump")
	await _harness.call("_frames", 4)
	var landed := func() -> bool: return player.is_on_floor() and player.velocity.y >= 0.0
	valid = valid and await _harness.call("_frames_until", landed, 120)
	_harness.call("_release", &"jump")
	valid = valid and absf(player.global_position.y - BRIDGE_Y) < 1.0
	_harness.call("_release", &"move_right")
	valid = (valid and await _harness.call("_walk_until_scene", &"move_right", UPPER_TERRACES_PATH))
	player = _harness.call("_current_player")
	valid = valid and player != null and absf(player.global_position.y - 368.0) < 1.0
	await _harness.call("_leave_scene")
	return valid


func _up_the_upper_terraces() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"low_canopy_jungle_4", &"west", UPPER_TERRACES_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	_harness.call("_clear_enemies")
	var valid := true
	for step: Array in UPPER_CLIMB:
		await _harness.call("_walk_to_x", player, step[1])
		await _harness.call("_jump_toward", player, step[0])
		var on := absf(player.global_position.y - step[2]) < 1.0
		if not on:
			push_error("Upper terraces: from x %s landed at %s" % [step[1], player.global_position])
		valid = valid and on
	valid = valid and await _harness.call("_walk_until_scene", &"move_right", SHRINE_STEPS_PATH)
	player = _harness.call("_current_player")
	valid = valid and player != null and absf(player.global_position.y - STEPS_TOP_Y) < 1.0
	await _harness.call("_leave_scene")
	return valid


func _to_the_gate() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"low_canopy_jungle_6", &"west", SHRINE_STEPS_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	await _harness.call("_wade_to", player, STEPS_EAST)
	var valid := absf(player.global_position.y - GATE_Y) < 1.0
	await _harness.call("_leave_scene")
	return valid
