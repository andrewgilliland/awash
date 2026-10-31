extends RefCounted

# The Reefback's playtests, played by tests/playtest_runner.gd with its harness: the real
# Warden's gate, real input and physics.

const WARDENS_GATE_PATH := "res://scenes/rooms/waking_coast_7.tscn"
const TIDEFEN_PATH := "res://scenes/rooms/waking_coast_8.tscn"
const ReefbackBrain := preload("res://scripts/enemies/reefback_brain.gd")
# Where to stand by the Reefback: in the sword's reach, clear of its touch.
const STRIKE_DISTANCE := 22.0
# A full Charge is half a second of holding melee; a few frames more to be sure.
const CHARGE_FRAMES := 36
# Long enough for the Reefback to fade and the Gate to dissolve after it.
const DISSOLVE_FRAMES := 180

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["A Charged Attack breaks the Reefback's Ward; a quick one then lands", _breaks_ward],
		["Defeating the Reefback opens the road to Tidefen", _defeat_opens_road],
	]


func _breaks_ward() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"waking_coast_7", &"west", WARDENS_GATE_PATH
	)
	var boss := _harness.current_scene.get_node_or_null("Reefback") if player else null
	if boss == null:
		await _harness.call("_leave_scene")
		return false
	await _break_ward(player, boss)
	var brain: ReefbackBrain = boss.get("brain")
	var valid: bool = brain.state == ReefbackBrain.State.STAGGERED
	valid = valid and boss.get("health").current == 140
	await _harness.call("_swing")
	valid = valid and boss.get("health").current == 130
	await _harness.call("_leave_scene")
	return valid


func _defeat_opens_road() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"waking_coast_7", &"west", WARDENS_GATE_PATH
	)
	var boss := _harness.current_scene.get_node_or_null("Reefback") if player else null
	if boss == null:
		await _harness.call("_leave_scene")
		return false
	var run := _harness.root.get_node("RunState")
	await _break_ward(player, boss)
	boss.get("health").current = 10
	await _harness.call("_swing")
	var valid: bool = run.call("has_defeated_boss", &"reefback")
	valid = valid and player.get("level").experience == 100
	await _harness.call("_frames", DISSOLVE_FRAMES)
	valid = valid and await _harness.call("_walk_until_scene", &"move_right", TIDEFEN_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_8"
	await _harness.call("_leave_scene")
	return valid


# Faces the Reefback from in reach, then holds melee through a full Charge and lets go. It
# wakes as the Charge begins, and the Charged Attack lands before its first wind-up ends.
func _break_ward(player: CharacterBody2D, boss: Node2D) -> void:
	player.global_position = boss.global_position - Vector2(STRIKE_DISTANCE, 0.0)
	player.velocity = Vector2.ZERO
	await _harness.call("_tap", &"move_right")
	_harness.call("_press", &"melee_attack")
	await _harness.call("_frames", CHARGE_FRAMES)
	_harness.call("_release", &"melee_attack")
	await _harness.call("_frames", 20)
