extends RefCounted

const SiltCrabBrain := preload("res://scripts/enemies/silt_crab_brain.gd")
const DELTA := 0.05
const AT := Vector2(96, 84)
# A Player passing under it, on the floor 80 pixels below.
const UNDER := Vector2(10, 80)
# Beside it on the floor but too far over, and level with it on a ledge.
const BESIDE := Vector2(40, 80)
const LEVEL := Vector2(8, 0)
const DROP_DAMAGE := 15
const TOUCH_DAMAGE := 10


func get_tests() -> Array:
	return [
		["Silt Crab clings still, harmless, with no Player under it", _test_clings],
		["Silt Crab shakes silt down when the Player comes under it", _test_shakes],
		["After its shake the Silt Crab drops, its claws harming", _test_drops],
		[
			"A Silt Crab that shakes always drops, even on a Player gone",
			_test_shake_follows_through
		],
		["Landed, the Silt Crab lies stunned and harmless for a second", _test_stunned],
		["After its stun the Silt Crab scuttles toward the Player", _test_scuttles],
		["A hit knocks a clinging Silt Crab down, harmless as it falls", _test_knocked_down],
		["A hit after landing hurts the Silt Crab, then it scuttles on", _test_hurt],
		["A defeated Silt Crab stays still and harmless", _test_defeated],
	]


func _test_clings() -> bool:
	var brain := SiltCrabBrain.new()
	var valid := true
	for offset in [null, BESIDE, LEVEL, Vector2(10, -40)]:
		brain.step(_frame(offset), DELTA)
		valid = valid and brain.state == SiltCrabBrain.State.CLINGING
		valid = valid and brain.velocity == Vector2.ZERO and brain.claws_damage == 0
		valid = valid and not brain.silt_falling
	return valid


func _test_shakes() -> bool:
	var brain := SiltCrabBrain.new()
	brain.step(_frame(UNDER), DELTA)
	var valid := brain.state == SiltCrabBrain.State.SHAKING and brain.silt_falling
	valid = valid and brain.velocity == Vector2.ZERO and brain.claws_damage == 0
	# Just inside its notice either side.
	brain = SiltCrabBrain.new()
	brain.step(_frame(Vector2(-24, 40)), DELTA)
	return valid and brain.state == SiltCrabBrain.State.SHAKING


func _test_drops() -> bool:
	var brain := SiltCrabBrain.new()
	brain.step(_frame(UNDER), DELTA)
	_run(brain, UNDER, brain.shake_time)
	var valid := brain.state == SiltCrabBrain.State.FALLING and not brain.silt_falling
	valid = valid and brain.claws_damage == DROP_DAMAGE
	var before := brain.velocity.y
	brain.step(_frame(UNDER), DELTA)
	# Gathering speed as it falls.
	return valid and brain.velocity.y > before and brain.velocity.y > 0.0


func _test_shake_follows_through() -> bool:
	var brain := SiltCrabBrain.new()
	brain.step(_frame(UNDER), DELTA)
	_run(brain, null, brain.shake_time)
	return brain.state == SiltCrabBrain.State.FALLING


func _test_stunned() -> bool:
	var brain := _landed()
	var valid := brain.state == SiltCrabBrain.State.STUNNED and brain.claws_damage == 0
	valid = valid and brain.velocity.x == 0.0
	_run(brain, UNDER, brain.stun_time - DELTA * 2.0, true)
	valid = valid and brain.state == SiltCrabBrain.State.STUNNED
	_run(brain, UNDER, DELTA * 3.0, true)
	return valid and brain.state == SiltCrabBrain.State.SCUTTLING


func _test_scuttles() -> bool:
	var brain := _landed()
	_run(brain, Vector2(-30, 0), brain.stun_time + DELTA, true)
	var valid := brain.state == SiltCrabBrain.State.SCUTTLING
	valid = valid and brain.velocity.x == -brain.scuttle_speed and brain.facing == -1.0
	valid = valid and brain.claws_damage == TOUCH_DAMAGE
	brain.step(_frame(Vector2(30, 0), false, true), DELTA)
	return valid and brain.velocity.x == brain.scuttle_speed and brain.facing == 1.0


func _test_knocked_down() -> bool:
	var valid := true
	for shaking in [false, true]:
		var brain := SiltCrabBrain.new()
		if shaking:
			brain.step(_frame(UNDER), DELTA)
		brain.step(_frame(UNDER, true), DELTA)
		valid = valid and brain.state == SiltCrabBrain.State.FALLING
		valid = valid and brain.claws_damage == 0 and not brain.silt_falling
		brain.step(_frame(UNDER), DELTA)
		valid = valid and brain.claws_damage == 0
		brain.step(_frame(UNDER, false, true), DELTA)
		valid = valid and brain.state == SiltCrabBrain.State.STUNNED
	return valid


func _test_hurt() -> bool:
	var brain := _landed()
	brain.step(_frame(UNDER, true, true), DELTA)
	var valid := brain.state == SiltCrabBrain.State.HURT and brain.claws_damage == 0
	_run(brain, UNDER, brain.hurt_time + DELTA, true)
	return valid and brain.state == SiltCrabBrain.State.SCUTTLING


func _test_defeated() -> bool:
	var brain := _landed()
	var frame := _frame(UNDER, false, true)
	frame.defeated = true
	brain.step(frame, DELTA)
	brain.step(_frame(UNDER, false, true), DELTA)
	var valid := brain.state == SiltCrabBrain.State.DEFEATED
	return valid and brain.velocity.x == 0.0 and brain.claws_damage == 0


# A Silt Crab dropped onto the floor.
func _landed() -> SiltCrabBrain:
	var brain := SiltCrabBrain.new()
	brain.step(_frame(UNDER), DELTA)
	_run(brain, UNDER, brain.shake_time)
	brain.step(_frame(UNDER, false, true), DELTA)
	return brain


func _run(brain: SiltCrabBrain, offset: Variant, seconds: float, on_floor := false) -> void:
	var left := seconds
	while left > 0.0:
		brain.step(_frame(offset, false, on_floor), DELTA)
		left -= DELTA


# A frame with the Player at an offset from the Silt Crab, or out of sight with none.
func _frame(offset: Variant, struck := false, on_floor := false) -> SiltCrabBrain.Frame:
	var frame := SiltCrabBrain.Frame.new()
	frame.position = AT
	frame.sees_player = offset != null
	if offset != null:
		frame.player_offset = offset
	frame.struck = struck
	frame.on_floor = on_floor
	return frame
