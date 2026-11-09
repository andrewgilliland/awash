extends RefCounted

# The Spore Beast's lair, played by tests/playtest_runner.gd with its harness: the real Rooms, real
# input and physics. Down the hole in the lower terraces' floor into the lair and back up; and the
# Spore Beast, struck from afar and up close.

const TERRACES_PATH := "res://scenes/rooms/low_canopy_jungle_2.tscn"
const LAIR_PATH := "res://scenes/rooms/low_canopy_jungle_5.tscn"
const BEAST_PATH := "Enemies/SporeBeast"
# Dropped in, the Player lands on the ledge under the hole; climbed out, on the step at its rim.
const UNDER_HOLE_Y := 48.0
const UNDER_HOLE_X := 80.0
const RIM_STEP_Y := 272.0
# On the lair's floor, facing the Spore Beast from well outside its spores, then close in.
const FLOOR_Y := 112.0
const AFAR_X := 168.0
const CLOSE := 26.0
# A full Charge is half a second of holding melee; a few frames more to be sure.
const CHARGE_FRAMES := 36
const MAX_HEALTH := 60
const SPORE_HIT := 8

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Player drops into the Spore Beast's lair and climbs back out", _down_and_up],
		["A Charged beam from afar strikes the Spore Beast, its spores far off", _strike_from_afar],
		["Striking the Spore Beast up close, its spores catch the Player", _spores_up_close],
	]


# From the step at the hole's rim, east into the hole: down into the lair onto the ledge under it;
# then straight up from the ledge, out through the hole onto the step.
func _down_and_up() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"low_canopy_jungle_2", &"south", TERRACES_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var valid: bool = absf(player.global_position.y - RIM_STEP_Y) < 1.0
	valid = valid and await _harness.call("_walk_until_scene", &"move_right", LAIR_PATH)
	player = _harness.call("_current_player")
	valid = valid and player != null and absf(player.global_position.y - UNDER_HOLE_Y) < 1.0
	_harness.call("_clear_enemies")
	await _harness.call("_walk_to_x", player, UNDER_HOLE_X)
	_harness.call("_press", &"jump")
	var out := func() -> bool:
		return (
			_harness.current_scene != null
			and _harness.current_scene.scene_file_path == TERRACES_PATH
		)
	valid = valid and await _harness.call("_frames_until", out, 90)
	_harness.call("_release", &"jump")
	player = _harness.call("_current_player")
	await _harness.call("_frames_until", func() -> bool: return player.is_on_floor(), 60)
	valid = valid and absf(player.global_position.y - RIM_STEP_Y) < 1.0
	await _harness.call("_leave_scene")
	return valid


# Standing far off on the floor, facing it, a Charged Attack's beam flies to it: it loses Health and
# vents, and the Player, far from the spores, is unhurt.
func _strike_from_afar() -> bool:
	var player := await _on_floor_at(AFAR_X)
	var beast := _beast()
	if player == null or beast == null:
		await _harness.call("_leave_scene")
		return false
	await _harness.call("_tap", &"move_right")
	_harness.call("_press", &"melee_attack")
	await _harness.call("_frames", CHARGE_FRAMES)
	_harness.call("_release", &"melee_attack")
	var health = beast.get("health")
	var struck := func() -> bool: return health.current < MAX_HEALTH
	var valid: bool = await _harness.call("_frames_until", struck, 60)
	var vented := func() -> bool: return not _harness.get_nodes_in_group(&"spore_cloud").is_empty()
	valid = valid and await _harness.call("_frames_until", vented, 10)
	await _harness.call("_frames", 30)
	var player_health = player.get("health")
	valid = valid and player_health.current == player_health.maximum
	await _harness.call("_leave_scene")
	return valid


# Close in, a quick slash lands, and the spores it vents burst on the Player.
func _spores_up_close() -> bool:
	var player := await _on_floor_at(AFAR_X)
	var beast := _beast()
	if player == null or beast == null:
		await _harness.call("_leave_scene")
		return false
	await _harness.call("_tap", &"move_right")
	var near := func() -> bool: return beast.global_position.x - player.global_position.x <= CLOSE
	await _harness.call("_frames_until", near, 240)
	await _harness.call("_tap", &"melee_attack")
	var health = beast.get("health")
	var player_health = player.get("health")
	var valid: bool = await _harness.call(
		"_frames_until", func() -> bool: return health.current < MAX_HEALTH, 30
	)
	var caught := func() -> bool: return player_health.current <= player_health.maximum - SPORE_HIT
	valid = valid and await _harness.call("_frames_until", caught, 30)
	await _harness.call("_leave_scene")
	return valid


# Into the lair and set down on its floor, where the Spore Beast notices the Player.
func _on_floor_at(x: float) -> CharacterBody2D:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"low_canopy_jungle_5", &"north", LAIR_PATH
	)
	if player == null:
		return null
	player.global_position = Vector2(x, FLOOR_Y - 4.0)
	await _harness.call("_frames_until", player.is_on_floor, 60)
	return player


func _beast() -> Node2D:
	if _harness.current_scene == null:
		return null
	return _harness.current_scene.get_node_or_null(BEAST_PATH) as Node2D
