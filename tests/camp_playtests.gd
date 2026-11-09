extends RefCounted

# The Shrinekeeper Camp, played by tests/playtest_runner.gd with its harness: the real Rooms, real
# input and physics. Through the shrine steps' open gate into the camp, down its steps, ringing its
# bell to rest and waking at it after a defeat, and buying from its SHRINEKEEPER.

const Hitbox := preload("res://scripts/combat/hitbox.gd")
const Supplies := preload("res://scripts/items/supplies.gd")
const SHRINE_STEPS_PATH := "res://scenes/rooms/low_canopy_jungle_6.tscn"
const CAMP_PATH := "res://scenes/rooms/shrinekeeper_camp_1.tscn"
# Through the gate, onto the camp's landing at the top step's height.
const LANDING_Y := 48.0
# Down the camp's steps to its floor, at the shrine's bell.
const FLOOR_Y := 96.0
const AT_BELL_X := 132.0
const BELL_ENTRY := Vector2(124, 96)
# Just west of the SHRINEKEEPER, set down above the floor.
const BESIDE_KEEPER := Vector2(-14, -20)
const MOURNING_SALT_PRICE := 30

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Player walks through the shrine steps' open gate into the camp", _through_the_gate],
		["Player rings the camp's bell to rest, falls, and wakes beside it", _rests_at_bell],
		["Player buys a Mourning Salt from the SHRINEKEEPER", _buys_from_keeper],
	]


func _through_the_gate() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"low_canopy_jungle_6", &"east", SHRINE_STEPS_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var valid: bool = await _harness.call("_walk_until_scene", &"move_right", CAMP_PATH)
	player = _harness.call("_current_player")
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and absf(player.global_position.y - LANDING_Y) < 1.0
	await _harness.call("_leave_scene")
	return valid


# Down the steps to the bell, hurt: ringing it refills Health and makes it the Rest point. Then a
# defeat wakes the Player at its foot with full Health.
func _rests_at_bell() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"shrinekeeper_camp_1", &"west", CAMP_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	await _harness.call("_walk_to_x", player, AT_BELL_X)
	var valid := absf(player.global_position.y - FLOOR_Y) < 1.0
	var run := _harness.root.get_node("RunState")
	var health = player.get("health")
	health.current = 10
	await _harness.call("_tap", &"interact")
	await _harness.call("_frames", 3)
	valid = valid and health.current == health.maximum
	valid = valid and run.get("rest_room_id") == &"shrinekeeper_camp_1"
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
	valid = valid and woke and _harness.current_scene.scene_file_path == CAMP_PATH
	var awake := _harness.current_scene.get_node("Player") as CharacterBody2D
	await _harness.call("_frames_until", awake.is_on_floor, 60)
	valid = valid and awake.global_position.distance_to(BELL_ENTRY) < 4.0
	await _harness.call("_leave_scene")
	return valid


# With 40 Gold, the Player talks to the SHRINEKEEPER: the Shop lists the camp's stock, and the third
# row, a Mourning Salt, costs 30.
func _buys_from_keeper() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"shrinekeeper_camp_1", &"west", CAMP_PATH
	)
	var keeper := _harness.current_scene.get_node_or_null("Shrinekeeper") as Node2D
	if player == null or keeper == null:
		await _harness.call("_leave_scene")
		return false
	player.call("gain_gold", 40)
	player.global_position = keeper.global_position + BESIDE_KEEPER
	await _harness.call("_frames_until", player.is_on_floor, 60)
	await _harness.call("_tap", &"interact")
	await _harness.call("_frames", 3)
	var shop := _harness.current_scene.get_node("CanvasLayer/ShopPanel")
	var valid: bool = shop.call("is_open") and _harness.paused
	await _harness.call("_tap", &"ui_down")
	await _harness.call("_tap", &"ui_down")
	await _harness.call("_tap", &"ui_accept")
	await _harness.call("_frames", 3)
	valid = valid and player.get("gold") == 40 - MOURNING_SALT_PRICE
	valid = valid and player.get("supplies").count(Supplies.MOURNING_SALT) == 1
	await _harness.call("_tap", &"ui_cancel")
	await _harness.call("_frames", 3)
	valid = valid and not shop.call("is_open") and not _harness.paused
	await _harness.call("_leave_scene")
	return valid
