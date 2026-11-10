extends RefCounted

const RuskBrain := preload("res://scripts/enemies/rusk_brain.gd")
const DELTA := 0.05
# The Player as he first stands at his post: out of his notice, then 32 pixels into the arena.
const UNSEEN := Vector2(-120, 0)
const WAKING := Vector2(-88, 0)
# Beyond his slam's range, so he charges; and within it, so he slams.
const FAR := Vector2(-90, 0)
const NEAR := Vector2(-30, 0)
const HURRIED := 0.4


func get_tests() -> Array:
	return [
		["Rusk stands dormant until the Player comes 32 pixels into the arena", _test_dormant],
		["Rusk speaks, then drives his maul down as the roots rise", _test_speaks_and_summons],
		["Rusk charges a Player far off until he meets a wall, then stands dazed", _test_charges],
		["A charge that meets no wall ends dazed all the same", _test_charge_ends],
		["Rusk raises his maul at a Player close by and slams once, then rests", _test_slams],
		["Rusk faces the Player at the end of each rest", _test_faces_player],
		["Below half Health a charge's wall leads into a slam, then a charge dazed", _test_hurries],
		["Beaten, Rusk kneels and speaks, then leaps away east and is gone", _test_retreats],
	]


func _test_dormant() -> bool:
	var brain := RuskBrain.new()
	brain.step(_frame(UNSEEN), DELTA)
	var valid := brain.state == RuskBrain.State.DORMANT and not brain.is_fighting()
	valid = valid and not brain.touch_harms and brain.velocity.x == 0.0
	brain.step(_frame(WAKING), DELTA)
	valid = valid and brain.state == RuskBrain.State.SPEAKING and not brain.is_fighting()
	return valid and brain.facing == -1.0 and not brain.touch_harms


func _test_speaks_and_summons() -> bool:
	var brain := RuskBrain.new()
	brain.step(_frame(WAKING), DELTA)
	for i in 40:
		brain.step(_frame(FAR), DELTA)
	var valid := brain.state == RuskBrain.State.SPEAKING
	var read := _frame(FAR)
	read.words_read = true
	brain.step(read, DELTA)
	valid = valid and brain.state == RuskBrain.State.SUMMONING and brain.roots_called
	valid = valid and brain.is_fighting() and not brain.touch_harms
	var called := 0
	var steps := 0
	while brain.state == RuskBrain.State.SUMMONING and steps < 100:
		brain.step(_frame(FAR), DELTA)
		steps += 1
		called += 1 if brain.roots_called else 0
	valid = valid and _near(steps * DELTA, brain.summon_time) and called == 0
	valid = valid and brain.state == RuskBrain.State.REST
	valid = valid and brain.touch_harms
	steps = _steps_until(brain, FAR, RuskBrain.State.TELL)
	return valid and _near(steps * DELTA, brain.beat_time)


func _test_charges() -> bool:
	var brain := _fighting()
	_steps_until(brain, FAR, RuskBrain.State.TELL)
	var valid := brain.velocity.x == 0.0 and not brain.plated
	var steps := _steps_until(brain, FAR, RuskBrain.State.CHARGE)
	valid = valid and _near(steps * DELTA, brain.tell_time)
	valid = valid and brain.velocity.x == -brain.charge_speed and brain.plated
	valid = valid and brain.charging() and brain.touch_harms
	brain.step(_frame(FAR), DELTA)
	valid = valid and brain.state == RuskBrain.State.CHARGE
	var wall := _frame(FAR)
	wall.met_wall = true
	brain.step(wall, DELTA)
	valid = valid and brain.state == RuskBrain.State.DAZED and brain.crashed
	valid = valid and brain.velocity.x == 0.0 and not brain.plated and not brain.touch_harms
	steps = _steps_until(brain, FAR, RuskBrain.State.REST)
	valid = valid and _near(steps * DELTA, brain.dazed_time) and brain.touch_harms
	steps = _steps_until(brain, FAR, RuskBrain.State.TELL)
	return valid and _near(steps * DELTA, brain.rest_time)


func _test_charge_ends() -> bool:
	var brain := _fighting()
	_steps_until(brain, FAR, RuskBrain.State.CHARGE)
	var steps := _steps_until(brain, FAR, RuskBrain.State.DAZED)
	return _near(steps * DELTA, brain.charge_limit)


func _test_slams() -> bool:
	var brain := _fighting()
	var steps := _steps_until(brain, NEAR, RuskBrain.State.WIND_UP)
	var valid := brain.velocity.x == 0.0 and not brain.maul_active
	steps = 0
	var slams := 0
	while brain.state == RuskBrain.State.WIND_UP and steps < 100:
		brain.step(_frame(NEAR), DELTA)
		steps += 1
		slams += 1 if brain.slammed else 0
	valid = valid and _near(steps * DELTA, brain.windup_time) and slams == 1
	valid = valid and brain.state == RuskBrain.State.SLAM and brain.maul_active
	steps = 0
	while brain.state == RuskBrain.State.SLAM and steps < 100:
		brain.step(_frame(NEAR), DELTA)
		steps += 1
		slams += 1 if brain.slammed else 0
	valid = valid and _near(steps * DELTA, brain.slam_time) and slams == 1
	return valid and brain.state == RuskBrain.State.REST and not brain.maul_active


func _test_faces_player() -> bool:
	var brain := _fighting()
	var east := Vector2(90, 0)
	_steps_until(brain, east, RuskBrain.State.TELL)
	var valid := brain.facing == 1.0
	_steps_until(brain, east, RuskBrain.State.CHARGE)
	return valid and brain.velocity.x == brain.charge_speed


func _test_hurries() -> bool:
	var brain := _fighting()
	_steps_until(brain, FAR, RuskBrain.State.TELL, HURRIED)
	var steps := _steps_until(brain, FAR, RuskBrain.State.CHARGE, HURRIED)
	var valid := _near(steps * DELTA, brain.hurried_time)
	var wall := _frame(Vector2(60, 0), HURRIED)
	wall.met_wall = true
	brain.step(wall, DELTA)
	valid = valid and brain.state == RuskBrain.State.WIND_UP and brain.facing == 1.0
	steps = _steps_until(brain, Vector2(60, 0), RuskBrain.State.SLAM, HURRIED)
	valid = valid and _near(steps * DELTA, brain.hurried_time)
	_steps_until(brain, Vector2(60, 0), RuskBrain.State.TELL, HURRIED)
	_steps_until(brain, Vector2(60, 0), RuskBrain.State.CHARGE, HURRIED)
	valid = valid and brain.velocity.x == brain.charge_speed
	wall = _frame(Vector2(-60, 0), HURRIED)
	wall.met_wall = true
	brain.step(wall, DELTA)
	return valid and brain.state == RuskBrain.State.DAZED


func _test_retreats() -> bool:
	var brain := _fighting()
	_steps_until(brain, FAR, RuskBrain.State.CHARGE)
	var beaten := _frame(FAR, 0.0)
	beaten.defeated = true
	brain.step(beaten, DELTA)
	var valid := brain.state == RuskBrain.State.KNEEL and not brain.is_fighting()
	valid = valid and brain.velocity.x == 0.0 and not brain.touch_harms and not brain.plated
	for i in 40:
		brain.step(beaten, DELTA)
	valid = valid and brain.state == RuskBrain.State.KNEEL
	beaten.words_read = true
	brain.step(beaten, DELTA)
	valid = valid and brain.state == RuskBrain.State.LEAP and brain.leaped
	valid = valid and brain.facing == 1.0 and not brain.touch_harms
	brain.step(beaten, DELTA)
	valid = valid and not brain.leaped
	var steps := _steps_until(brain, FAR, RuskBrain.State.GONE, 0.0) + 1
	return valid and _near(steps * DELTA, brain.leap_time)


# Woken, his words read and the roots called: at rest, his first beat over.
func _fighting() -> RuskBrain:
	var brain := RuskBrain.new()
	brain.step(_frame(WAKING), DELTA)
	var read := _frame(WAKING)
	read.words_read = true
	brain.step(read, DELTA)
	_steps_until(brain, WAKING, RuskBrain.State.REST)
	return brain


func _frame(offset: Vector2, health_share: float = 1.0) -> RuskBrain.Frame:
	var frame := RuskBrain.Frame.new()
	frame.sees_player = true
	frame.player_offset = offset
	frame.health_share = health_share
	return frame


func _steps_until(
	brain: RuskBrain, offset: Vector2, state: RuskBrain.State, health_share: float = 1.0
) -> int:
	var steps := 0
	while brain.state != state and steps < 400:
		brain.step(_frame(offset, health_share), DELTA)
		steps += 1
	return steps


func _near(a: float, b: float) -> bool:
	return absf(a - b) < DELTA * 1.5
