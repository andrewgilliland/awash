extends RefCounted

const LurelightBrain := preload("res://scripts/enemies/lurelight_brain.gd")
const DELTA := 0.05
# The first pool under the undertow tunnel, and its surface, in pixels.
const LEFT := 160.0
const RIGHT := 208.0
const SURFACE_Y := 96.0
const MIDDLE := Vector2(184, SURFACE_Y)
# A Player wading the pool beside it, in its Snap's reach.
const NEAR := Vector2(12, 10)
# Out of sight.
const FAR := Vector2(100, 10)


func get_tests() -> Array:
	return [
		["Lurelight waits hidden, its lure lit, with no Player in sight", _test_waits_hidden],
		["Lurelight drifts toward a Player in sight, inside its pool", _test_drifts_toward_player],
		["Lurelight dims when the Player comes in its Snap's reach", _test_dims_in_reach],
		["Lurelight snaps after dimming, then lies stranded", _test_snaps_then_strands],
		["A Lurelight that dims always snaps, even at a Player gone", _test_dim_follows_through],
		["Lurelight sinks after stranding and stays dark a while", _test_sinks_and_waits],
		["A hit sends the stranded Lurelight under at once", _test_hit_sinks],
		["A defeated Lurelight stays still", _test_defeated_stays_still],
	]


func _test_waits_hidden() -> bool:
	var brain := _brain()
	var valid := true
	for player_offset in [null, FAR]:
		brain.step(_frame(MIDDLE, player_offset), DELTA)
		valid = valid and brain.state == LurelightBrain.State.HIDDEN
		valid = valid and brain.velocity == Vector2.ZERO and brain.lure_lit
		valid = valid and not brain.jaws_active and not brain.exposed
	return valid


func _test_drifts_toward_player() -> bool:
	var brain := _brain()
	brain.step(_frame(MIDDLE, Vector2(-40, 10)), DELTA)
	var valid := brain.velocity.x == -brain.drift_speed and brain.facing == -1.0
	brain = _brain()
	brain.step(_frame(MIDDLE, Vector2(40, -20)), DELTA)
	valid = valid and brain.velocity.x == brain.drift_speed and brain.facing == 1.0
	# A Player out past its pool's edge draws it only as far as the edge.
	brain = _brain()
	brain.step(_frame(Vector2(LEFT + brain.half_width, SURFACE_Y), Vector2(-40, 0)), DELTA)
	valid = valid and brain.velocity.x == 0.0
	# Too high above the water to notice.
	brain = _brain()
	brain.step(_frame(MIDDLE, Vector2(40, -50)), DELTA)
	return valid and brain.velocity.x == 0.0 and brain.state == LurelightBrain.State.HIDDEN


func _test_dims_in_reach() -> bool:
	var valid := true
	# Wading beside it, on the bank at its edge, or in the air within the jaws' height.
	for offset in [Vector2(-NEAR.x, NEAR.y), Vector2(16, 0), Vector2(8, -20)]:
		var brain := _brain()
		brain.step(_frame(MIDDLE, offset), DELTA)
		valid = valid and brain.state == LurelightBrain.State.DIM
		valid = valid and brain.facing == signf(offset.x) and brain.velocity == Vector2.ZERO
		valid = valid and not brain.lure_lit and not brain.jaws_active and not brain.exposed
	# Too far to the side, or over the jaws' reach.
	for offset in [Vector2(24, 0), Vector2(4, -30)]:
		var brain := _brain()
		brain.step(_frame(MIDDLE, offset), DELTA)
		valid = valid and brain.state == LurelightBrain.State.HIDDEN
	return valid


func _test_snaps_then_strands() -> bool:
	var brain := _brain()
	var near := _frame(MIDDLE, NEAR)
	brain.step(near, DELTA)
	var steps := _steps_until(brain, near, LurelightBrain.State.SNAP)
	var valid := steps * DELTA >= brain.dim_time - DELTA
	valid = valid and brain.jaws_active and not brain.exposed and not brain.lure_lit
	steps = _steps_until(brain, near, LurelightBrain.State.STRANDED)
	valid = valid and steps * DELTA >= brain.snap_time - DELTA
	valid = valid and brain.exposed and not brain.jaws_active
	return valid and brain.velocity == Vector2.ZERO


func _test_dim_follows_through() -> bool:
	var brain := _brain()
	brain.step(_frame(MIDDLE, NEAR), DELTA)
	var gone := _frame(MIDDLE)
	var steps := _steps_until(brain, gone, LurelightBrain.State.SNAP)
	steps += _steps_until(brain, gone, LurelightBrain.State.STRANDED)
	return brain.state == LurelightBrain.State.STRANDED and steps < 200


func _test_sinks_and_waits() -> bool:
	var brain := _brain()
	var near := _frame(MIDDLE, NEAR)
	brain.step(near, DELTA)
	_steps_until(brain, near, LurelightBrain.State.STRANDED)
	var steps := _steps_until(brain, near, LurelightBrain.State.SUNK)
	var valid := steps * DELTA >= brain.stranded_time - DELTA
	valid = valid and not brain.exposed and not brain.jaws_active and not brain.lure_lit
	steps = _steps_until(brain, near, LurelightBrain.State.HIDDEN)
	valid = valid and steps * DELTA >= brain.dark_time - DELTA and brain.lure_lit
	return valid


func _test_hit_sinks() -> bool:
	var brain := _brain()
	var near := _frame(MIDDLE, NEAR)
	brain.step(near, DELTA)
	_steps_until(brain, near, LurelightBrain.State.STRANDED)
	var hit := _frame(MIDDLE, NEAR)
	hit.struck = true
	brain.step(hit, DELTA)
	var valid := brain.state == LurelightBrain.State.HURT
	valid = valid and not brain.exposed and not brain.jaws_active and not brain.lure_lit
	var steps := _steps_until(brain, near, LurelightBrain.State.SUNK)
	valid = valid and steps * DELTA >= brain.hurt_time - DELTA
	steps = _steps_until(brain, near, LurelightBrain.State.HIDDEN)
	return valid and steps * DELTA >= brain.dark_time - DELTA


func _test_defeated_stays_still() -> bool:
	var brain := _brain()
	var down := _frame(MIDDLE, NEAR)
	down.defeated = true
	brain.step(down, DELTA)
	var valid := brain.state == LurelightBrain.State.DEFEATED
	brain.step(_frame(MIDDLE, NEAR), DELTA)
	valid = valid and brain.state == LurelightBrain.State.DEFEATED
	valid = valid and brain.velocity == Vector2.ZERO and not brain.lure_lit
	return valid and not brain.exposed and not brain.jaws_active


func _brain() -> LurelightBrain:
	var brain := LurelightBrain.new()
	brain.pool_left = LEFT
	brain.pool_right = RIGHT
	return brain


func _frame(position: Vector2, player_offset: Variant = null) -> LurelightBrain.Frame:
	var frame := LurelightBrain.Frame.new()
	frame.position = position
	if player_offset != null:
		frame.sees_player = true
		frame.player_offset = player_offset
	return frame


func _steps_until(brain: LurelightBrain, frame: LurelightBrain.Frame, state: int) -> int:
	var steps := 0
	while brain.state != state and steps < 200:
		brain.step(frame, DELTA)
		steps += 1
	return steps
