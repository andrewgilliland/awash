extends RefCounted

# Fights with the Stalker on the canopy walk's east deck, played by tests/playtest_runner.gd with
# its harness: the real Room, real input and physics.

const CANOPY_WALK_PATH := "res://scenes/rooms/low_canopy_jungle_3.tscn"
const STALKER_PATH := "Enemies/Stalker"
# Off the mark, west along the deck, clear of its landing.
const OFF_MARK_X := 270.0
# In the sword's reach of it once it lands on the mark.
const STRIKE_DISTANCE := 14.0
const CHARGED_HIT := 20
const MAX_HEALTH := 30
const LEAP_HIT := 12
# Long enough for a mark, a leap and a landing.
const POUNCE_FRAMES := 120

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Stepping off the Stalker's mark, a Charged blow strikes it as it recovers", _dodge],
		["Standing on the Stalker's mark, its pounce hurts the Player", _pounce_hurts],
	]


# Entering by the east deck, under its perch, it marks the Player; walking off the mark, turning to
# face it and starting a Charge, then walking in once it lands and letting the Charge go: struck
# hard, the Player unscathed.
func _dodge() -> bool:
	var player := await _on_east_deck()
	var stalker := _stalker()
	if stalker == null:
		await _harness.call("_leave_scene")
		return false
	var brain = stalker.get("brain")
	var marked := func() -> bool: return brain.state == brain.State.MARKING
	var valid: bool = await _harness.call("_frames_until", marked, 60)
	var mark: Vector2 = brain.mark
	await _harness.call("_walk_to_x", player, OFF_MARK_X)
	# Facing it again before the Charge starts, since a Charge holds the way the Player faces.
	await _harness.call("_tap", &"move_right")
	_harness.call("_press", &"melee_attack")
	var recovering := func() -> bool: return brain.state == brain.State.RECOVERING
	valid = valid and await _harness.call("_frames_until", recovering, POUNCE_FRAMES)
	valid = valid and absf(stalker.global_position.x - mark.x) < 4.0
	_harness.call("_press", &"move_right")
	var strike_x: float = stalker.global_position.x - STRIKE_DISTANCE
	await _harness.call(
		"_frames_until", func() -> bool: return player.global_position.x >= strike_x, 60
	)
	_harness.call("_release", &"move_right")
	_harness.call("_release", &"melee_attack")
	var health = stalker.get("health")
	var struck := func() -> bool: return health.current == MAX_HEALTH - CHARGED_HIT
	valid = valid and await _harness.call("_frames_until", struck, 30)
	var player_health = player.get("health")
	valid = valid and player_health.current == player_health.maximum
	await _harness.call("_leave_scene")
	return valid


# Standing still where it marked them, the Player takes its landing.
func _pounce_hurts() -> bool:
	var player := await _on_east_deck()
	if _stalker() == null:
		await _harness.call("_leave_scene")
		return false
	var health = player.get("health")
	var hurt: bool = await _harness.call(
		"_frames_until",
		func() -> bool: return health.current == health.maximum - LEAP_HIT,
		POUNCE_FRAMES
	)
	await _harness.call("_leave_scene")
	return hurt


# Onto the canopy walk by its east deck, from the upper terraces, under the Stalker's perch.
func _on_east_deck() -> CharacterBody2D:
	return await _harness.call("_enter_room", &"low_canopy_jungle_3", &"east", CANOPY_WALK_PATH)


func _stalker() -> Node2D:
	if _harness.current_scene == null:
		return null
	return _harness.current_scene.get_node_or_null(STALKER_PATH) as Node2D
