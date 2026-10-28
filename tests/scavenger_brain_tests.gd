extends RefCounted

const ScavengerBrain := preload("res://scripts/enemies/scavenger_brain.gd")
const DELTA := 0.05
const LEFT := 100.0
const RIGHT := 140.0


func get_tests() -> Array:
	return [
		["Scavenger patrols between its bounds", _test_patrols_between_bounds],
		["Scavenger winds up when the Player is near and level", _test_winds_up_near_player],
		["Scavenger lunges after winding up, then recovers", _test_lunges_then_recovers],
		["A hit knocks the Scavenger back mid-lunge", _test_hit_knocks_back],
		["A defeated Scavenger stays still", _test_defeated_stays_still],
	]


func _test_patrols_between_bounds() -> bool:
	var brain := _brain()
	brain.step(_frame(Vector2(120, 0)), DELTA)
	var valid := brain.state == ScavengerBrain.State.PATROL and brain.velocity.x > 0.0
	brain.step(_frame(Vector2(RIGHT + 1.0, 0)), DELTA)
	valid = valid and brain.facing == -1.0 and brain.velocity.x < 0.0
	brain.step(_frame(Vector2(LEFT - 1.0, 0)), DELTA)
	valid = valid and brain.facing == 1.0 and brain.velocity.x > 0.0
	return valid and not brain.spear_active


func _test_winds_up_near_player() -> bool:
	var above := _brain()
	above.step(_frame(Vector2(120, 0), Vector2(30, -40)), DELTA)
	var valid := above.state == ScavengerBrain.State.PATROL

	var behind := _brain()
	behind.step(_frame(Vector2(120, 0), Vector2(-30, 0)), DELTA)
	valid = valid and behind.state == ScavengerBrain.State.WINDUP
	valid = valid and behind.facing == -1.0 and behind.velocity.x == 0.0
	return valid and not behind.spear_active


func _test_lunges_then_recovers() -> bool:
	var brain := _brain()
	var near := _frame(Vector2(120, 0), Vector2(30, 0))
	brain.step(near, DELTA)
	var steps := _steps_until(brain, near, ScavengerBrain.State.LUNGE)
	var valid := steps * DELTA >= brain.windup_time - DELTA
	valid = valid and brain.spear_active and brain.velocity.x == brain.lunge_speed
	_steps_until(brain, near, ScavengerBrain.State.RECOVER)
	valid = valid and not brain.spear_active and brain.velocity.x == 0.0
	_steps_until(brain, _frame(Vector2(120, 0)), ScavengerBrain.State.PATROL)
	return valid and brain.state == ScavengerBrain.State.PATROL


func _test_hit_knocks_back() -> bool:
	var brain := _brain()
	var near := _frame(Vector2(120, 0), Vector2(30, 0))
	brain.step(near, DELTA)
	_steps_until(brain, near, ScavengerBrain.State.LUNGE)
	var hit := _frame(Vector2(120, 0), Vector2(30, 0))
	hit.knocked_toward = -1.0
	brain.step(hit, DELTA)
	var valid := brain.state == ScavengerBrain.State.HURT and not brain.spear_active
	valid = valid and brain.velocity.x == -brain.knockback_speed and brain.facing == 1.0
	return valid


func _test_defeated_stays_still() -> bool:
	var brain := _brain()
	var defeat := _frame(Vector2(120, 0), Vector2(20, 0))
	defeat.defeated = true
	brain.step(defeat, DELTA)
	brain.step(_frame(Vector2(120, 0), Vector2(20, 0)), DELTA)
	var valid := brain.state == ScavengerBrain.State.DEFEATED
	return valid and brain.velocity == Vector2.ZERO and not brain.spear_active


func _brain() -> ScavengerBrain:
	var brain := ScavengerBrain.new()
	brain.patrol_left = LEFT
	brain.patrol_right = RIGHT
	return brain


# A frame at the given position; no Player in sight unless an offset to the Player is given.
func _frame(position: Vector2, player_offset = null) -> ScavengerBrain.Frame:
	var frame := ScavengerBrain.Frame.new()
	frame.position = position
	if player_offset != null:
		frame.sees_player = true
		frame.player_offset = player_offset
	return frame


func _steps_until(brain: ScavengerBrain, frame: ScavengerBrain.Frame, state: int) -> int:
	for i in 100:
		if brain.state == state:
			return i
		brain.step(frame, DELTA)
	return 100
