extends RefCounted

# Tidefen's Villagers, played by tests/playtest_runner.gd with its harness: the real Room, real
# input and physics.

const TIDEFEN_PATH := "res://scenes/rooms/tidefen_village_1.tscn"
# [node, speaker]: each of Tidefen's Villagers, west to east.
const VILLAGERS := [
	["Netter", "NETTER"],
	["KnotWeaver", "KNOT-WEAVER"],
	["BellKeeper", "BELL-KEEPER"],
	["Fisher", "FISHER"],
]
# The Player is set down a little east of each, above its floor, and lands.
const BESIDE := Vector2(14, -20)

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Player talks to each of Tidefen's Villagers in turn", _talks_to_each],
	]


# Beside each Villager in turn, the Player presses Interact: the Villager turns to face them and
# talks in its own name, with the Dialogue box clear of them both, and the Player reads on until
# the box closes.
func _talks_to_each() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"tidefen_village_1", &"west", TIDEFEN_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	var valid := true
	for spec in VILLAGERS:
		var villager := _harness.current_scene.get_node_or_null("Villagers/%s" % spec[0])
		if villager == null:
			valid = false
			break
		player.global_position = (villager as Node2D).global_position + BESIDE
		player.velocity = Vector2.ZERO
		await _harness.call("_frames_until", player.is_on_floor, 60)
		await _harness.call("_frames", 5)
		await _harness.call("_tap", &"interact")
		await _harness.call("_frames", 3)
		var box: Control = _harness.call("_dialogue_box")
		valid = valid and box.visible and _harness.call("_speaker") == spec[1]
		valid = valid and _harness.call("_dialogue_box_clears", [player, villager])
		var sprite := villager.get_node("AnimatedSprite2D") as AnimatedSprite2D
		# Its sheet faces west; it turns east to the Player.
		valid = valid and sprite.flip_h
		valid = valid and await _harness.call("_read_through_dialogue")
	await _harness.call("_leave_scene")
	return valid
