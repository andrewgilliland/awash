extends RefCounted

const WraithBrain := preload("res://scripts/enemies/wraith_brain.gd")
const DELTA := 0.05
const LEFT := 448.0
const RIGHT := 528.0
const HOME_Y := 80.0
const MIDDLE := Vector2(488, HOME_Y)
# Close enough to set it manifesting, and too far.
const NEAR := Vector2(20, 10)
const FAR := Vector2(140, 0)


func get_tests() -> Array:
	return [
		["Wraith drifts phased across its haunt, bobbing at its height", _test_drifts_phased],
		["Wraith drifts toward a Player in sight, inside its haunt", _test_drifts_toward_player],
		["Wraith manifests facing a near Player", _test_manifests_near_player],
		["Wraith lashes after manifesting, then exposes its anchor", _test_lashes_then_exposes],
		["Wraith stays phased a while before manifesting again", _test_waits_to_manifest],
		["A hit on its anchor knocks the Wraith back and phases it", _test_hit_phases],
		["A defeated Wraith stays still", _test_defeated_stays_still],
	]


func _test_drifts_phased() -> bool:
	var brain := _brain()
	var position := MIDDLE
	var low := position.y
	var high := position.y
	var turned_left := false
	var valid := true
	for i in 300:
		brain.step(_frame(position), DELTA)
		position += brain.velocity * DELTA
		low = minf(low, position.y)
		high = maxf(high, position.y)
		turned_left = turned_left or brain.velocity.x < 0.0
		valid = valid and not brain.solid and not brain.exposed and not brain.lash_active
	valid = valid and brain.state == WraithBrain.State.DRIFT and turned_left
	valid = valid and position.x >= LEFT - 2.0 and position.x <= RIGHT + 2.0
	valid = valid and high - low > brain.bob_height
	return (
		valid and low >= HOME_Y - brain.bob_height - 2.0 and high <= HOME_Y + brain.bob_height + 2.0
	)


func _test_drifts_toward_player() -> bool:
	var brain := _brain()
	brain.step(_frame(MIDDLE, Vector2(-60, 0)), DELTA)
	var valid := brain.velocity.x == -brain.chase_speed
	brain = _brain()
	brain.step(_frame(MIDDLE, Vector2(60, 0)), DELTA)
	valid = valid and brain.velocity.x == brain.chase_speed
	# A Player out past its haunt's edge draws it only to the edge.
	brain = _brain()
	brain.step(_frame(Vector2(LEFT, HOME_Y), Vector2(-60, 0)), DELTA)
	return valid and brain.velocity.x >= 0.0


func _test_manifests_near_player() -> bool:
	var far := _brain()
	far.step(_frame(MIDDLE, FAR), DELTA)
	var valid := far.state == WraithBrain.State.DRIFT
	var near := _brain()
	near.step(_frame(MIDDLE, Vector2(-NEAR.x, NEAR.y)), DELTA)
	valid = valid and near.state == WraithBrain.State.MANIFEST and near.facing == -1.0
	valid = valid and near.solid and not near.exposed and not near.lash_active
	return valid and near.velocity == Vector2.ZERO


func _test_lashes_then_exposes() -> bool:
	var brain := _brain()
	var near := _frame(MIDDLE, NEAR)
	brain.step(near, DELTA)
	var steps := _steps_until(brain, near, WraithBrain.State.LASH)
	var valid := steps * DELTA >= brain.manifest_time - DELTA
	valid = valid and brain.lash_active and not brain.exposed and brain.solid
	steps = _steps_until(brain, near, WraithBrain.State.EXPOSED)
	valid = valid and steps * DELTA >= brain.lash_time - DELTA
	valid = valid and brain.exposed and not brain.lash_active and brain.solid
	valid = valid and brain.velocity == Vector2.ZERO
	steps = _steps_until(brain, near, WraithBrain.State.DRIFT)
	valid = valid and steps * DELTA >= brain.exposed_time - DELTA
	return valid and not brain.solid and not brain.exposed


func _test_waits_to_manifest() -> bool:
	var brain := _brain()
	var near := _frame(MIDDLE, NEAR)
	brain.step(near, DELTA)
	_steps_until(brain, near, WraithBrain.State.EXPOSED)
	_steps_until(brain, near, WraithBrain.State.DRIFT)
	var steps := _steps_until(brain, near, WraithBrain.State.MANIFEST)
	return steps * DELTA >= brain.rephase_time - DELTA and steps < 200


func _test_hit_phases() -> bool:
	var brain := _brain()
	var near := _frame(MIDDLE, NEAR)
	brain.step(near, DELTA)
	_steps_until(brain, near, WraithBrain.State.EXPOSED)
	var hit := _frame(MIDDLE, NEAR)
	hit.knocked_toward = -1.0
	brain.step(hit, DELTA)
	var valid := brain.state == WraithBrain.State.HURT and brain.velocity.x < 0.0
	valid = valid and not brain.exposed and not brain.lash_active
	var steps := _steps_until(brain, near, WraithBrain.State.DRIFT)
	valid = valid and steps * DELTA >= brain.hurt_time - DELTA and not brain.solid
	# It stays phased a while before it can manifest again.
	steps = _steps_until(brain, near, WraithBrain.State.MANIFEST)
	return valid and steps * DELTA >= brain.rephase_time - DELTA


func _test_defeated_stays_still() -> bool:
	var brain := _brain()
	var down := _frame(MIDDLE, NEAR)
	down.defeated = true
	brain.step(down, DELTA)
	var valid := brain.state == WraithBrain.State.DEFEATED
	brain.step(_frame(MIDDLE, NEAR), DELTA)
	valid = valid and brain.state == WraithBrain.State.DEFEATED
	return valid and brain.velocity == Vector2.ZERO and not brain.exposed and not brain.lash_active


func _brain() -> WraithBrain:
	var brain := WraithBrain.new()
	brain.haunt_left = LEFT
	brain.haunt_right = RIGHT
	brain.home_y = HOME_Y
	return brain


func _frame(position: Vector2, player_offset: Variant = null) -> WraithBrain.Frame:
	var frame := WraithBrain.Frame.new()
	frame.position = position
	if player_offset != null:
		frame.sees_player = true
		frame.player_offset = player_offset
	return frame


func _steps_until(brain: WraithBrain, frame: WraithBrain.Frame, state: int) -> int:
	var steps := 0
	while brain.state != state and steps < 200:
		brain.step(frame, DELTA)
		steps += 1
	return steps
