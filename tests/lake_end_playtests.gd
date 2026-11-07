extends RefCounted

# The lake's west end, played by tests/playtest_runner.gd with its harness: the real Room, real
# input and physics. Its chest gives two Glowroe, and its sealed door says it is sealed.

const LAKE_PATH := "res://scenes/rooms/undertow_7.tscn"
# Set down on the west bank, east of the chest, above the sand.
const ON_BANK := Vector2(60, 80)
const CHEST_X := 52.0
const DOOR_X := 26.0
const GLOWROE := &"glowroe"

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Player opens the lake's chest, then reads its sealed door", _chest_and_door],
	]


# At the chest, Interact opens it for two Glowroe. At the door, Interact shows Vael's two lines
# about it, read on until the box closes.
func _chest_and_door() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"undertow_7", &"east", LAKE_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	_harness.call("_clear_enemies")
	player.global_position = ON_BANK
	player.velocity = Vector2.ZERO
	await _harness.call("_frames_until", player.is_on_floor, 60)
	await _harness.call("_walk_to_x", player, CHEST_X)
	await _harness.call("_frames", 5)
	await _harness.call("_tap", &"interact")
	await _harness.call("_frames", 3)
	var chest := _harness.current_scene.get_node("Chest")
	var valid: bool = chest.call("is_open")
	valid = valid and player.get("supplies").count(GLOWROE) == 2
	await _harness.call("_walk_to_x", player, DOOR_X)
	await _harness.call("_frames", 5)
	await _harness.call("_tap", &"interact")
	await _harness.call("_frames", 3)
	var box: Control = _harness.call("_dialogue_box")
	valid = valid and box.visible and _harness.call("_speaker") == "???"
	valid = valid and await _harness.call("_read_through_dialogue")
	await _harness.call("_leave_scene")
	return valid
