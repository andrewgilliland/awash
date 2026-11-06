extends RefCounted

# Tidefen's bell, its Rest point, played by tests/playtest_runner.gd with its harness: the real
# Room, real input and physics.

const TIDEFEN_PATH := "res://scenes/rooms/tidefen_village_1.tscn"
const Hitbox := preload("res://scripts/combat/hitbox.gd")
# On the market square's sand, just west of the bell, set down above it.
const BY_BELL := Vector2(520, 92)
# The Entry at the bell's foot.
const BELL_ENTRY := Vector2(524, 112)

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Player rings Tidefen's bell to rest, falls, and wakes beside it", _ring_and_wake],
	]


# Hurt, the Player rings the bell with Interact: Health refills and RESTED shows. Then a hit
# defeats the Player, who wakes in Tidefen at the bell's foot with full Health.
func _ring_and_wake() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"tidefen_village_1", &"west", TIDEFEN_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	player.global_position = BY_BELL
	await _harness.call("_frames_until", player.is_on_floor, 60)
	var health = player.get("health")
	health.current = 10
	await _harness.call("_tap", &"interact")
	await _harness.call("_frames", 3)
	var valid: bool = health.current == health.maximum
	valid = valid and (player.get_node("LevelUp") as Label).text == "RESTED"
	valid = valid and run.get("rest_room_id") == &"tidefen_village_1"
	health.current = 1
	var blow := Hitbox.new()
	blow.global_position = player.global_position + Vector2(8, 0)
	player.call("_on_hurtbox_hit", blow)
	blow.free()
	var fallen := _harness.current_scene
	var woke: bool = await _harness.call(
		"_frames_until",
		func() -> bool: return _harness.current_scene != null and _harness.current_scene != fallen,
		240
	)
	valid = valid and woke and _harness.current_scene.scene_file_path == TIDEFEN_PATH
	valid = valid and run.get("entry_id") == &"bell"
	var awake := _harness.current_scene.get_node("Player") as CharacterBody2D
	await _harness.call("_frames_until", awake.is_on_floor, 60)
	valid = valid and awake.global_position.distance_to(BELL_ENTRY) < 4.0
	var awake_health = awake.get("health")
	valid = valid and awake_health.current == awake_health.maximum
	await _harness.call("_leave_scene")
	return valid
