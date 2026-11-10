extends RefCounted

# The Pirate at the root hollow's foot, played by tests/playtest_runner.gd with its harness: the
# real Room, real input and physics. Its bombs, its rush, and its defeat.

const HOLLOW_PATH := "res://scenes/rooms/low_canopy_jungle_7.tscn"
const PIRATE_PATH := "Enemies/Pirate"
const STALKER_PATH := "Enemies/Stalker"
const PirateBrain := preload("res://scripts/enemies/pirate_brain.gd")
const FOOT_Y := 384.0
# Too far for its rush, so it throws; and a step away, under the low ledge its bombs cannot reach.
const BOMB_RANGE_X := 70.0
const STEPPED_AWAY_X := 24.0
# Close enough that it rushes.
const RUSH_RANGE_X := 80.0
# Within a sword's reach of it.
const CLOSE_X := 118.0

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["A Pirate's bomb catches a Player standing still", _bomb_catches],
		["A Player who steps away from where a Pirate's bomb lands is unhurt", _bomb_misses],
		["The Player jumps a Pirate's rush and strikes it, unhurt", _jump_the_rush],
		["Quick hits defeat a Pirate before it can rush, for its Experience and Gold", _defeat],
	]


# Standing off where it throws rather than rushes, the Player takes its bomb's burst.
func _bomb_catches() -> bool:
	var player := await _on_foot_at(BOMB_RANGE_X)
	var pirate := _pirate()
	if player == null or pirate == null:
		await _harness.call("_leave_scene")
		return false
	var health = player.get("health")
	var thrown := func() -> bool: return not _harness.get_nodes_in_group(&"pirate_bomb").is_empty()
	var valid: bool = await _harness.call("_frames_until", thrown, 60)
	var hurt := func() -> bool: return health.current < health.maximum
	valid = valid and await _harness.call("_frames_until", hurt, 90)
	await _harness.call("_leave_scene")
	return valid


# Once it lets go, the Player walks away from where they stood; its bomb bursts behind them.
func _bomb_misses() -> bool:
	var player := await _on_foot_at(BOMB_RANGE_X)
	var pirate := _pirate()
	if player == null or pirate == null:
		await _harness.call("_leave_scene")
		return false
	var health = player.get("health")
	var thrown := func() -> bool: return not _harness.get_nodes_in_group(&"pirate_bomb").is_empty()
	var valid: bool = await _harness.call("_frames_until", thrown, 60)
	var bomb: WeakRef = weakref(_harness.get_nodes_in_group(&"pirate_bomb")[0]) if valid else null
	await _harness.call("_walk_to_x", player, STEPPED_AWAY_X)
	var gone := func() -> bool: return bomb == null or bomb.get_ref() == null
	valid = valid and await _harness.call("_frames_until", gone, 90)
	valid = valid and health.current == health.maximum
	await _harness.call("_leave_scene")
	return valid


# Close enough that it rushes: as its rush sets off, a running jump carries the Player over it;
# landed behind it, the Player turns and strikes it before it can rush again.
func _jump_the_rush() -> bool:
	var player := await _on_foot_at(RUSH_RANGE_X)
	var pirate := _pirate()
	if player == null or pirate == null:
		await _harness.call("_leave_scene")
		return false
	var brain = pirate.get("brain")
	var rushing := func() -> bool: return brain.state == PirateBrain.State.RUSH
	var valid: bool = await _harness.call("_frames_until", rushing, 60)
	_harness.call("_press", &"move_right")
	_harness.call("_press", &"jump")
	await _harness.call("_frames", 4)
	await _harness.call(
		"_frames_until",
		func() -> bool: return player.is_on_floor() and player.velocity.y >= 0.0,
		60
	)
	_harness.call("_release", &"jump")
	_harness.call("_release", &"move_right")
	var health = player.get("health")
	valid = valid and health.current == health.maximum
	valid = valid and player.global_position.x > pirate.global_position.x
	await _harness.call("_tap", &"move_left")
	var near := func() -> bool: return player.global_position.x - pirate.global_position.x <= 18.0
	_harness.call("_press", &"move_left")
	await _harness.call("_frames_until", near, 60)
	_harness.call("_release", &"move_left")
	await _harness.call("_swing")
	var pirate_health = pirate.get("health")
	valid = valid and pirate_health.current < pirate_health.maximum
	valid = valid and health.current == health.maximum
	await _harness.call("_leave_scene")
	return valid


# Close in, facing it, each quick hit lands in its tell, before it can rush; four bring it down,
# and the Player gains its Experience and Gold.
func _defeat() -> bool:
	var player := await _on_foot_at(CLOSE_X)
	var pirate := _pirate()
	if player == null or pirate == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	var experience: int = run.get("player_experience")
	var gold: int = run.get("player_gold")
	await _harness.call("_tap", &"move_right")
	var left: WeakRef = weakref(pirate)
	for i in 6:
		if left.get_ref() == null or left.get_ref().get("health").is_defeated():
			break
		await _harness.call("_swing")
	var gone := func() -> bool: return left.get_ref() == null
	var valid: bool = await _harness.call("_frames_until", gone, 60)
	valid = valid and run.get("player_experience") == experience + 30
	valid = valid and run.get("player_gold") == gold + 10
	var health = player.get("health")
	valid = valid and health.current == health.maximum
	await _harness.call("_leave_scene")
	return valid


# Into the root hollow, its Stalker gone, and set down on its foot's floor.
func _on_foot_at(x: float) -> CharacterBody2D:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"low_canopy_jungle_7", &"west", HOLLOW_PATH
	)
	if player == null:
		return null
	var stalker := _harness.current_scene.get_node_or_null(STALKER_PATH)
	if stalker != null:
		stalker.free()
	player.global_position = Vector2(x, FOOT_Y - 4.0)
	await _harness.call("_frames_until", player.is_on_floor, 60)
	return player


func _pirate() -> Node2D:
	if _harness.current_scene == null:
		return null
	return _harness.current_scene.get_node_or_null(PIRATE_PATH) as Node2D
