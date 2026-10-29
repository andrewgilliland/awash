extends RefCounted

const StormWispBrain := preload("res://scripts/enemies/storm_wisp_brain.gd")
const DELTA := 0.05
const LEFT := 200.0
const RIGHT := 280.0
const HOME_Y := 34.0


func get_tests() -> Array:
	return [
		["Storm Wisp drifts between its bounds, bobbing at its height", _test_drifts_and_bobs],
		["Storm Wisp crackles when the Player comes near", _test_crackles_near_player],
		["Storm Wisp arcs after crackling, then rests", _test_arcs_then_rests],
		["A hit while it crackles stops the arc", _test_hit_stops_arc],
		["A defeated Storm Wisp stays still", _test_defeated_stays_still],
	]


# Steps a Wisp that moves as its brain says, and returns the lowest and highest y it reaches.
func _test_drifts_and_bobs() -> bool:
	var brain := _brain()
	var position := Vector2(240, HOME_Y)
	var low := position.y
	var high := position.y
	var turned_left := false
	for i in 200:
		brain.step(_frame(position), DELTA)
		position += brain.velocity * DELTA
		low = minf(low, position.y)
		high = maxf(high, position.y)
		turned_left = turned_left or brain.velocity.x < 0.0
	var valid := brain.state == StormWispBrain.State.DRIFT and turned_left
	valid = valid and position.x >= LEFT - 2.0 and position.x <= RIGHT + 2.0
	# It bobs, but stays near its height.
	valid = valid and high - low > brain.bob_height
	return (
		valid and low >= HOME_Y - brain.bob_height - 2.0 and high <= HOME_Y + brain.bob_height + 2.0
	)


func _test_crackles_near_player() -> bool:
	var far := _brain()
	far.step(_frame(Vector2(240, HOME_Y), Vector2(80, 10)), DELTA)
	var valid := far.state == StormWispBrain.State.DRIFT
	var near := _brain()
	near.step(_frame(Vector2(240, HOME_Y), Vector2(-24, 14)), DELTA)
	valid = valid and near.state == StormWispBrain.State.CRACKLE
	return valid and near.velocity == Vector2.ZERO and not near.arc_active


func _test_arcs_then_rests() -> bool:
	var brain := _brain()
	var near := _frame(Vector2(240, HOME_Y), Vector2(20, 14))
	brain.step(near, DELTA)
	var steps := _steps_until(brain, near, StormWispBrain.State.ARC)
	var valid := steps * DELTA >= brain.crackle_time - DELTA and brain.arc_active
	steps = _steps_until(brain, near, StormWispBrain.State.REST)
	valid = valid and steps * DELTA >= brain.arc_time - DELTA and not brain.arc_active
	steps = _steps_until(brain, _frame(Vector2(240, HOME_Y)), StormWispBrain.State.DRIFT)
	return valid and steps * DELTA >= brain.rest_time - DELTA


func _test_hit_stops_arc() -> bool:
	var brain := _brain()
	var near := _frame(Vector2(240, HOME_Y), Vector2(20, 14))
	brain.step(near, DELTA)
	var hit := _frame(Vector2(240, HOME_Y), Vector2(20, 14))
	hit.knocked_toward = -1.0
	brain.step(hit, DELTA)
	var valid := brain.state == StormWispBrain.State.HURT and not brain.arc_active
	valid = valid and brain.velocity.x < 0.0
	for i in 40:
		brain.step(_frame(Vector2(240, HOME_Y)), DELTA)
		valid = valid and not brain.arc_active
	return valid and brain.state == StormWispBrain.State.DRIFT


func _test_defeated_stays_still() -> bool:
	var brain := _brain()
	var down := _frame(Vector2(240, HOME_Y), Vector2(20, 14))
	down.defeated = true
	brain.step(down, DELTA)
	var valid := brain.state == StormWispBrain.State.DEFEATED
	brain.step(_frame(Vector2(240, HOME_Y), Vector2(20, 14)), DELTA)
	return valid and brain.state == StormWispBrain.State.DEFEATED and brain.velocity == Vector2.ZERO


func _brain() -> StormWispBrain:
	var brain := StormWispBrain.new()
	brain.drift_left = LEFT
	brain.drift_right = RIGHT
	brain.home_y = HOME_Y
	return brain


func _frame(position: Vector2, player_offset: Variant = null) -> StormWispBrain.Frame:
	var frame := StormWispBrain.Frame.new()
	frame.position = position
	if player_offset != null:
		frame.sees_player = true
		frame.player_offset = player_offset
	return frame


func _steps_until(brain: StormWispBrain, frame: StormWispBrain.Frame, state: int) -> int:
	var steps := 0
	while brain.state != state and steps < 200:
		brain.step(frame, DELTA)
		steps += 1
	return steps
