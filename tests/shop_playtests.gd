extends RefCounted

# The Supply Shop, played by tests/playtest_runner.gd with its harness: the real Room, real
# input and physics.

const TIDEFEN_PATH := "res://scenes/rooms/tidefen_village_1.tscn"
const Supplies := preload("res://scripts/items/supplies.gd")
# Just east of the TRADER at the stall, set down above the sand.
const BESIDE_TRADER := Vector2(14, -20)

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Player buys a Meat Pie and a Brinecap from Tidefen's TRADER", _buys_from_trader],
	]


# With 30 Gold, the Player talks to the TRADER: the Shop opens and play pauses. Choosing the first
# row buys a Meat Pie for 15, down and choosing again a Brinecap for 8, and cancel closes it.
func _buys_from_trader() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"tidefen_village_1", &"west", TIDEFEN_PATH
	)
	var trader := _harness.current_scene.get_node_or_null("Trader") as Node2D
	if player == null or trader == null:
		await _harness.call("_leave_scene")
		return false
	player.call("gain_gold", 30)
	player.global_position = trader.global_position + BESIDE_TRADER
	await _harness.call("_frames_until", player.is_on_floor, 60)
	await _harness.call("_tap", &"interact")
	await _harness.call("_frames", 3)
	var shop := _harness.current_scene.get_node("CanvasLayer/ShopPanel")
	var valid: bool = shop.call("is_open") and _harness.paused
	await _harness.call("_tap", &"ui_accept")
	await _harness.call("_frames", 3)
	valid = valid and player.get("gold") == 15
	valid = valid and player.get("supplies").count(Supplies.MEAT_PIE) == 1
	await _harness.call("_tap", &"ui_down")
	await _harness.call("_tap", &"ui_accept")
	await _harness.call("_frames", 3)
	valid = valid and player.get("gold") == 7
	valid = valid and player.get("supplies").count(Supplies.BRINECAP) == 1
	await _harness.call("_tap", &"ui_cancel")
	await _harness.call("_frames", 3)
	valid = valid and not shop.call("is_open") and not _harness.paused
	await _harness.call("_leave_scene")
	return valid
