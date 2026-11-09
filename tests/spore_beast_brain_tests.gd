extends RefCounted

const SporeBeastBrain := preload("res://scripts/enemies/spore_beast_brain.gd")
const DELTA := 1.0 / 60.0
const AT := Vector2(248, 112)
# A Player on its floor to the west, within its notice; too far, and too high above it.
const WEST := Vector2(140, 112)
const OUT_OF_NOTICE: Array[Vector2] = [Vector2(40, 112), Vector2(240, 40)]
const TOUCH_DAMAGE := 10
const SPEED := 24.0


func get_tests() -> Array:
	return [
		["Spore Beast stands still with no Player near, its hide harmful", _test_idle],
		["Spore Beast lumbers toward a Player it notices", _test_lumbers],
		["Spore Beast turns to follow the Player", _test_follows],
		["A hit vents spores, once, and it stands puffed, then lumbers on", _test_vents],
		["Every hit vents again, even while puffed", _test_every_hit_vents],
		["Its defeat bursts a last cloud, and it stays still and harmless", _test_defeated],
	]


static func _frame(player: Variant, struck := false) -> SporeBeastBrain.Frame:
	var frame := SporeBeastBrain.Frame.new()
	frame.position = AT
	frame.on_floor = true
	frame.struck = struck
	if player != null:
		frame.sees_player = true
		frame.player_position = player
	return frame


static func _run(brain: SporeBeastBrain, player: Variant, seconds: float) -> void:
	for i in range(roundi(seconds / DELTA)):
		brain.step(_frame(player), DELTA)


func _test_idle() -> bool:
	var brain := SporeBeastBrain.new()
	var valid := true
	for player in [null] + OUT_OF_NOTICE:
		brain.step(_frame(player), DELTA)
		valid = valid and brain.state == SporeBeastBrain.State.IDLE
		valid = valid and brain.velocity == Vector2.ZERO and brain.touch_damage == TOUCH_DAMAGE
		valid = valid and not brain.vented
	return valid


func _test_lumbers() -> bool:
	var brain := SporeBeastBrain.new()
	brain.step(_frame(WEST), DELTA)
	var valid := brain.state == SporeBeastBrain.State.LUMBERING
	return valid and is_equal_approx(brain.velocity.x, -SPEED) and brain.facing < 0.0


func _test_follows() -> bool:
	var brain := SporeBeastBrain.new()
	brain.step(_frame(WEST), DELTA)
	brain.step(_frame(AT + Vector2(60, 0)), DELTA)
	return is_equal_approx(brain.velocity.x, SPEED) and brain.facing > 0.0


func _test_vents() -> bool:
	var brain := SporeBeastBrain.new()
	brain.step(_frame(WEST), DELTA)
	brain.step(_frame(WEST, true), DELTA)
	var valid := brain.vented and brain.state == SporeBeastBrain.State.VENTING
	valid = valid and brain.velocity.x == 0.0 and brain.touch_damage == TOUCH_DAMAGE
	brain.step(_frame(WEST), DELTA)
	valid = valid and not brain.vented and brain.state == SporeBeastBrain.State.VENTING
	_run(brain, WEST, brain.vent_time)
	valid = valid and brain.state == SporeBeastBrain.State.LUMBERING and not brain.vented
	return valid and brain.velocity.x < 0.0


func _test_every_hit_vents() -> bool:
	var brain := SporeBeastBrain.new()
	brain.step(_frame(WEST), DELTA)
	brain.step(_frame(WEST, true), DELTA)
	_run(brain, WEST, brain.vent_time / 2.0)
	brain.step(_frame(WEST, true), DELTA)
	var valid := brain.vented and brain.state == SporeBeastBrain.State.VENTING
	# The puff starts over from the second hit.
	_run(brain, WEST, brain.vent_time - 2.0 * DELTA)
	return valid and brain.state == SporeBeastBrain.State.VENTING


func _test_defeated() -> bool:
	var brain := SporeBeastBrain.new()
	brain.step(_frame(WEST), DELTA)
	var defeated := _frame(WEST, true)
	defeated.defeated = true
	brain.step(defeated, DELTA)
	var valid := brain.state == SporeBeastBrain.State.DEFEATED and brain.vented
	valid = valid and brain.velocity == Vector2.ZERO and brain.touch_damage == 0
	brain.step(_frame(WEST), DELTA)
	valid = valid and brain.state == SporeBeastBrain.State.DEFEATED and not brain.vented
	return valid and brain.touch_damage == 0
