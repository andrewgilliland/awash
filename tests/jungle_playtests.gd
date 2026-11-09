extends RefCounted

# The Low Canopy Jungle's walks with real input, played by tests/playtest_runner.gd with its
# harness: off Tidefen's landing onto the harbour trail, up past its waterfall to the lower
# terraces, and up the terraces' beds to the relief.

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

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Player walks off Tidefen's landing onto the harbour trail", _off_tidefen],
		["Player climbs the harbour trail past its waterfall to the terraces", _up_the_trail],
		["Player climbs the medicine beds and crosses the deck to the relief", _up_the_terraces],
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
