extends RefCounted

# Fights with the Silt Crab under the Undertow passage's colonnade, played by
# tests/playtest_runner.gd with its harness: the real Room, real input and physics.

const PASSAGE_PATH := "res://scenes/rooms/undertow_3.tscn"
const CRAB_PATH := "Enemies/SiltCrab"
# Near enough sideways to set it shaking, and far enough to be clear of its drop.
const UNDER_EDGE := 20.0
const CLEAR := 40.0
# In the sword's reach of it once it lies stunned on the floor.
const STRIKE_DISTANCE := 14.0
const DROP_HIT := 15
const EXPERIENCE := 15

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Stepping back from the Silt Crab's drop, a Charged blow defeats it stunned", _dodge],
		["The Silt Crab's drop hurts a Player standing under it", _drop_hurts],
	]


# Walks in under the edge of it, steps back clear as it shakes, turns to face it and starts a
# Charge; once it lies stunned, walks in and lets the Charge go: gone in one blow, unscathed.
func _dodge() -> bool:
	var player := await _in_passage()
	var crab := _crab()
	if crab == null:
		await _harness.call("_leave_scene")
		return false
	var brain = crab.get("brain")
	await _harness.call("_walk_to_x", player, crab.position.x + UNDER_EDGE)
	var valid: bool = brain.state == brain.State.SHAKING or brain.state == brain.State.FALLING
	await _harness.call("_walk_to_x", player, crab.position.x + CLEAR)
	# Facing it again before the Charge starts, since a Charge holds the way the Player faces.
	await _harness.call("_tap", &"move_left")
	_harness.call("_press", &"melee_attack")
	valid = (
		valid
		and await _harness.call(
			"_frames_until", func() -> bool: return brain.state == brain.State.STUNNED, 90
		)
	)
	# Straight in, and the Charge let go on arrival, inside the stun.
	_harness.call("_press", &"move_left")
	var strike_x: float = crab.position.x + STRIKE_DISTANCE
	await _harness.call(
		"_frames_until", func() -> bool: return player.global_position.x <= strike_x, 60
	)
	_harness.call("_release", &"move_left")
	_harness.call("_release", &"melee_attack")
	valid = (
		valid
		and await _harness.call(
			"_frames_until", func() -> bool: return not is_instance_valid(crab), 90
		)
	)
	var health = player.get("health")
	valid = valid and health.current == health.maximum
	valid = valid and player.get("level").experience == EXPERIENCE
	await _harness.call("_leave_scene")
	return valid


# Standing still right under it, the Player takes its drop.
func _drop_hurts() -> bool:
	var player := await _in_passage()
	var crab := _crab()
	if crab == null:
		await _harness.call("_leave_scene")
		return false
	var health = player.get("health")
	await _harness.call("_walk_to_x", player, crab.position.x)
	var hurt: bool = await _harness.call(
		"_frames_until", func() -> bool: return health.current == health.maximum - DROP_HIT, 90
	)
	await _harness.call("_leave_scene")
	return hurt


# Into the passage from the hall, with its Wraith gone so only the Silt Crab is met.
func _in_passage() -> CharacterBody2D:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"undertow_3", &"east", PASSAGE_PATH
	)
	var wraith := _harness.current_scene.get_node_or_null("Enemies/Wraith")
	if wraith != null:
		wraith.free()
	return player


func _crab() -> Node2D:
	return _harness.current_scene.get_node_or_null(CRAB_PATH) as Node2D
