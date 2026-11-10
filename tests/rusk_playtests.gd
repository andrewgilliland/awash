extends RefCounted

# Rusk at the root's mouth, played by tests/playtest_runner.gd with its harness: the real Room,
# real input and physics. His ambush, his charge, his quake, and his retreat.

const MOUTH_PATH := "res://scenes/rooms/low_canopy_jungle_8.tscn"
const HOLLOW_PATH := "res://scenes/rooms/low_canopy_jungle_7.tscn"
const RUSK_THEME := "res://assets/enemies/rusk/rusk_theme.wav"
const RuskBrain := preload("res://scripts/enemies/rusk_brain.gd")
const ARENA_WEST := 160.0
# Just short of the step up into the root.
const STEP_X := 92.0
# Close enough, across, that his charge passes over a Player who jumps straight up now.
const JUMP_GAP := 50.0
# Within his slam's range, clear of his touch.
const SLAM_X := 248.0
# A wind-up lasts 42 frames: the Player backs away for 30 of them, then jumps 6 before it lands.
const BACK_AWAY_FRAMES := 30
const JUMP_AFTER_FRAMES := 6

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Walking into the root's mouth, Rusk speaks and his roots shut the Player in", _shut_in],
		["The Player jumps Rusk's charge, and strikes him dazed against his roots", _jump_charge],
		["Backing off Rusk's maul but standing on the floor, its quake hurts", _quake_hurts],
		["Backing off Rusk's maul and jumping as it lands, the Player is unhurt", _quake_jumped],
		["Beaten, Rusk leaps away, his roots wither and the way back opens", _beaten],
	]


func _shut_in() -> bool:
	var player := await _meet_rusk()
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var music := _harness.root.get_node("Music")
	var valid: bool = music.call("current").resource_path == RUSK_THEME
	_harness.call("_press", &"move_left")
	await _harness.call("_frames", 90)
	_harness.call("_release", &"move_left")
	valid = valid and player.global_position.x > ARENA_WEST + 8.0
	valid = valid and _harness.current_scene.scene_file_path == MOUTH_PATH
	await _harness.call("_leave_scene")
	return valid


# As his charge closes in, a jump straight up lets him pass under; he meets his roots behind the
# Player and stands dazed, and the Player walks up and strikes him.
func _jump_charge() -> bool:
	var player := await _meet_rusk()
	var rusk := _rusk()
	if player == null or rusk == null:
		await _harness.call("_leave_scene")
		return false
	var brain: RuskBrain = rusk.get("brain")
	var health = player.get("health")
	var closing := func() -> bool:
		return (
			brain.state == RuskBrain.State.CHARGE
			and rusk.global_position.x - player.global_position.x <= JUMP_GAP
		)
	var valid: bool = await _harness.call("_frames_until", closing, 240)
	_harness.call("_press", &"jump")
	var dazed := func() -> bool: return brain.state == RuskBrain.State.DAZED
	valid = valid and await _harness.call("_frames_until", dazed, 120)
	_harness.call("_release", &"jump")
	valid = valid and health.current == health.maximum
	valid = valid and rusk.global_position.x < player.global_position.x
	var near := func() -> bool: return player.global_position.x - rusk.global_position.x <= 20.0
	_harness.call("_press", &"move_left")
	await _harness.call("_frames_until", near, 60)
	_harness.call("_release", &"move_left")
	await _harness.call("_swing")
	var rusk_health = rusk.get("health")
	valid = valid and rusk_health.current < rusk_health.maximum
	valid = valid and health.current == health.maximum
	await _harness.call("_leave_scene")
	return valid


func _quake_hurts() -> bool:
	var player := await _meet_rusk()
	if player == null or _rusk() == null:
		await _harness.call("_leave_scene")
		return false
	var health = player.get("health")
	var valid: bool = await _back_off_maul(player)
	valid = valid and await _harness.call("_frames_until", _slammed(), 30)
	await _harness.call("_frames", 10)
	# Hurt, but by the quake, not the maul's blow.
	valid = valid and health.current < health.maximum
	valid = valid and health.current > health.maximum - 20
	await _harness.call("_leave_scene")
	return valid


func _quake_jumped() -> bool:
	var player := await _meet_rusk()
	if player == null or _rusk() == null:
		await _harness.call("_leave_scene")
		return false
	var health = player.get("health")
	var valid: bool = await _back_off_maul(player)
	await _harness.call("_frames", JUMP_AFTER_FRAMES)
	_harness.call("_press", &"jump")
	valid = valid and await _harness.call("_frames_until", _slammed(), 30)
	await _harness.call("_frames", 10)
	_harness.call("_release", &"jump")
	await _harness.call("_frames_until", player.is_on_floor, 60)
	valid = valid and health.current == health.maximum
	await _harness.call("_leave_scene")
	return valid


# Struck down, he kneels and speaks; once read he leaps away, his roots wither, the Run remembers
# him beaten, and the Player walks back west into the root hollow.
func _beaten() -> bool:
	var player := await _meet_rusk()
	var rusk := _rusk()
	if player == null or rusk == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	var experience: int = player.get("level").experience
	rusk.get("health").current = 10
	player.global_position = rusk.global_position - Vector2(18.0, 0.0)
	await _harness.call("_tap", &"move_right")
	await _harness.call("_swing")
	var left: WeakRef = weakref(rusk)
	var speaking := func() -> bool: return _harness.call("_dialogue_box").visible
	var valid: bool = await _harness.call("_frames_until", speaking, 60)
	valid = valid and _harness.call("_speaker") == "RUSK"
	valid = valid and await _harness.call("_read_through_dialogue")
	var gone := func() -> bool: return left.get_ref() == null
	valid = valid and await _harness.call("_frames_until", gone, 120)
	valid = valid and run.call("has_defeated_boss", &"rusk_jungle")
	valid = valid and player.get("level").experience == experience + 150
	await _harness.call("_frames", 60)
	valid = valid and not _harness.current_scene.get_node("Arena/RootsWest").call("is_up")
	# Back past where the roots stood, and up the step into the root.
	await _harness.call("_walk_to_x", player, STEP_X)
	await _harness.call("_jump_toward", player, -1)
	valid = valid and await _harness.call("_walk_until_scene", &"move_left", HOLLOW_PATH)
	valid = valid and run.get("room_id") == &"low_canopy_jungle_7"
	await _harness.call("_leave_scene")
	return valid


# Into the root's mouth, walking east until Rusk speaks; his words read, his roots risen.
func _meet_rusk() -> CharacterBody2D:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"low_canopy_jungle_8", &"west", MOUTH_PATH
	)
	if player == null:
		return null
	var speaking := func() -> bool: return _harness.call("_dialogue_box").visible
	_harness.call("_press", &"move_right")
	var spoke: bool = await _harness.call("_frames_until", speaking, 240)
	_harness.call("_release", &"move_right")
	if not spoke or _harness.call("_speaker") != "RUSK":
		return null
	if not await _harness.call("_read_through_dialogue"):
		return null
	var roots := _harness.current_scene.get_node("Arena/RootsWest")
	var risen := func() -> bool: return roots.call("is_up")
	if not await _harness.call("_frames_until", risen, 30):
		return null
	return player


# Close in to his slam's range before his first move; as he winds up, back away out of the
# maul's reach, facing him.
func _back_off_maul(player: CharacterBody2D) -> bool:
	var brain: RuskBrain = _rusk().get("brain")
	_harness.call("_press", &"move_right")
	var close := func() -> bool: return player.global_position.x >= SLAM_X
	await _harness.call("_frames_until", close, 90)
	_harness.call("_release", &"move_right")
	var winding := func() -> bool: return brain.state == RuskBrain.State.WIND_UP
	var valid: bool = await _harness.call("_frames_until", winding, 90)
	_harness.call("_press", &"move_left")
	await _harness.call("_frames", BACK_AWAY_FRAMES)
	_harness.call("_release", &"move_left")
	return valid and _rusk().global_position.x - player.global_position.x > 48.0


func _slammed() -> Callable:
	var brain: RuskBrain = _rusk().get("brain")
	return func() -> bool: return brain.state == RuskBrain.State.SLAM


func _rusk() -> Node2D:
	if _harness.current_scene == null:
		return null
	return _harness.current_scene.get_node_or_null("Rusk") as Node2D
