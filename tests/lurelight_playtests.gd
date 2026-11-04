extends RefCounted

# Fights with the Lurelight in the pools under the undertow tunnel, played by
# tests/playtest_runner.gd with its harness: real Rooms, real input and physics.

const POOLS_PATH := "res://scenes/rooms/undertow_4.tscn"
const LURELIGHT_PATH := "Enemies/Lurelight"
# The pools' sand and the water's surface, level with it.
const BANK_Y := 96.0
# On the sand west of the first pool, near enough to draw the Lurelight to the pool's west edge.
const LURE_X := 140.0
# On the bank, near enough to set it dimming, clear of its jaws, and in the sword's reach of its
# head once it lies stranded.
const BAIT_DISTANCE := 14.0
# Wading in the pool beside it, in its jaws' way.
const WADE_DISTANCE := 4.0
const SNAP_HIT := 15
const EXPERIENCE := 15

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Charging through the Lurelight's dim, one blow defeats it stranded", _charged_blow],
		["Two quick Attacks, one each time it strands, defeat the Lurelight", _two_openings],
		["The Lurelight's Snap hurts a Player wading over it", _snap_hurts],
	]


# Draws it to the pool's edge, starts a Charge on the bank as it dims, and lets the Charge go once
# it lies stranded: gone in one blow, without a scratch, for its Experience.
func _charged_blow() -> bool:
	var player := await _at_pools()
	var lurelight := _lurelight()
	if lurelight == null:
		await _harness.call("_leave_scene")
		return false
	var brain = lurelight.get("brain")
	await _draw_to_edge(player, lurelight)
	_harness.call("_press", &"melee_attack")
	await _stand_by(player, lurelight, BAIT_DISTANCE)
	await _harness.call(
		"_frames_until", func() -> bool: return brain.state == brain.State.STRANDED, 120
	)
	_harness.call("_release", &"melee_attack")
	var valid: bool = await _harness.call(
		"_frames_until", func() -> bool: return not is_instance_valid(lurelight), 90
	)
	var health = player.get("health")
	valid = valid and health.current == health.maximum
	valid = valid and player.get("level").experience == EXPERIENCE
	await _harness.call("_leave_scene")
	return valid


# A quick Attack sends it under with Health left; it lights again, and a second bait and a second
# quick Attack finish it.
func _two_openings() -> bool:
	var player := await _at_pools()
	var lurelight := _lurelight()
	if lurelight == null:
		await _harness.call("_leave_scene")
		return false
	var brain = lurelight.get("brain")
	await _draw_to_edge(player, lurelight)
	var sank_after_one := false
	for opening in 2:
		await _stand_by(player, lurelight, BAIT_DISTANCE)
		await _harness.call(
			"_frames_until", func() -> bool: return brain.state == brain.State.STRANDED, 120
		)
		await _harness.call("_swing")
		if opening == 0:
			sank_after_one = is_instance_valid(lurelight) and brain.state != brain.State.STRANDED
			await _harness.call(
				"_frames_until", func() -> bool: return brain.state == brain.State.HIDDEN, 150
			)
	var valid: bool = await _harness.call(
		"_frames_until", func() -> bool: return not is_instance_valid(lurelight), 90
	)
	var health = player.get("health")
	valid = valid and sank_after_one and health.current == health.maximum
	await _harness.call("_leave_scene")
	return valid


# Wades into the pool right beside it and stays until its jaws land.
func _snap_hurts() -> bool:
	var player := await _at_pools()
	var lurelight := _lurelight()
	if lurelight == null:
		await _harness.call("_leave_scene")
		return false
	var health = player.get("health")
	await _stand_by(player, lurelight, -WADE_DISTANCE)
	var valid: bool = await _harness.call(
		"_frames_until", func() -> bool: return health.current < health.maximum, 90
	)
	valid = valid and health.current == health.maximum - SNAP_HIT
	await _harness.call("_leave_scene")
	return valid


func _at_pools() -> CharacterBody2D:
	return await _harness.call("_enter_room", &"undertow_4", &"west", POOLS_PATH)


func _lurelight() -> Node2D:
	if _harness.current_scene == null:
		return null
	return _harness.current_scene.get_node_or_null(LURELIGHT_PATH) as Node2D


# Stands on the sand west of the pool until the Lurelight has drifted to the pool's west edge.
func _draw_to_edge(player: CharacterBody2D, lurelight: Node2D) -> void:
	var brain = lurelight.get("brain")
	await _harness.call("_walk_to_x", player, LURE_X)
	await _harness.call(
		"_frames_until",
		func() -> bool: return brain.velocity.x == 0.0 and brain.state == brain.State.HIDDEN,
		120
	)


# Puts the Player a distance west of the Lurelight, facing it.
func _stand_by(player: CharacterBody2D, lurelight: Node2D, distance: float) -> void:
	_harness.call("_press", &"move_right")
	await _harness.call("_frames", 1)
	_harness.call("_release", &"move_right")
	player.global_position = Vector2(lurelight.global_position.x - distance, BANK_Y)
	player.velocity = Vector2.ZERO
	await _harness.call("_frames", 2)
