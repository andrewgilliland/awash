extends RefCounted

const PirateBrain := preload("res://scripts/enemies/pirate_brain.gd")
const DELTA := 1.0 / 60.0
const AT := Vector2(112, 384)
# A Player on its floor, close and farther off; on a ledge above it; out of its notice.
const CLOSE := Vector2(72, 384)
const FAR := Vector2(12, 384)
const ABOVE := Vector2(90, 352)
const OUT_OF_NOTICE: Array[Vector2] = [Vector2(300, 384), Vector2(112, 250)]
const RUSH_SPEED := 160.0
const WALK_SPEED := 32.0
const CUTLASS_DAMAGE := 10


func get_tests() -> Array:
	return [
		["Pirate stands on guard, still, with no Player in its notice", _test_guard],
		["Pirate tells, rushes with its cutlass live, then stands winded", _test_rush],
		["Pirate's rush stops short at a ledge's edge", _test_rush_stops_at_edge],
		["Pirate lobs a bomb at a Player farther off, where they stand, then reloads", _test_bomb],
		["Pirate throws, not rushes, at a Player above it", _test_bomb_above],
		["Pirate walks back to its post, and stops there", _test_walks_back],
		["Pirate whistles once as it notices, again only after losing the Player", _test_whistle],
		["A hit flinches it and loses the attack it was making", _test_flinch],
		["A hit mid-rush costs it nothing of the rush", _test_rush_committed],
		["Defeated, it stands still and harmless", _test_defeated],
	]


static func _frame(player: Variant, at := AT, struck := false) -> PirateBrain.Frame:
	var frame := PirateBrain.Frame.new()
	frame.position = at
	frame.on_floor = true
	frame.floor_ahead = true
	frame.struck = struck
	if player != null:
		frame.sees_player = true
		frame.player_position = player
	return frame


static func _run(brain: PirateBrain, player: Variant, seconds: float) -> void:
	for i in range(roundi(seconds / DELTA)):
		brain.step(_frame(player), DELTA)


func _test_guard() -> bool:
	var brain := PirateBrain.new()
	var valid := true
	for player in [null] + OUT_OF_NOTICE:
		_run(brain, player, 0.5)
		valid = valid and brain.state == PirateBrain.State.GUARD
		valid = valid and brain.velocity == Vector2.ZERO and brain.cutlass_damage == 0
		valid = valid and not brain.threw
	return valid


func _test_rush() -> bool:
	var brain := PirateBrain.new()
	brain.step(_frame(CLOSE), DELTA)
	var valid := brain.state == PirateBrain.State.TELL and brain.facing < 0.0
	valid = valid and brain.velocity.x == 0.0 and brain.cutlass_damage == 0
	_run(brain, CLOSE, 0.4)
	valid = valid and brain.state == PirateBrain.State.RUSH
	valid = valid and is_equal_approx(brain.velocity.x, -RUSH_SPEED)
	valid = valid and brain.cutlass_damage == CUTLASS_DAMAGE
	_run(brain, CLOSE, 0.35)
	valid = valid and brain.state == PirateBrain.State.WINDED
	valid = valid and brain.velocity.x == 0.0 and brain.cutlass_damage == 0
	_run(brain, CLOSE, 0.65)
	valid = valid and brain.state == PirateBrain.State.WINDED
	_run(brain, CLOSE, 0.1)
	return valid and brain.state == PirateBrain.State.TELL


func _test_rush_stops_at_edge() -> bool:
	var brain := PirateBrain.new()
	_run(brain, CLOSE, 0.42)
	var valid := brain.state == PirateBrain.State.RUSH and brain.velocity.x < 0.0
	var frame := _frame(CLOSE)
	frame.floor_ahead = false
	brain.step(frame, DELTA)
	return valid and brain.state == PirateBrain.State.RUSH and brain.velocity.x == 0.0


func _test_bomb() -> bool:
	var brain := PirateBrain.new()
	brain.step(_frame(FAR), DELTA)
	var valid := brain.state == PirateBrain.State.WIND_UP and brain.facing < 0.0
	_run(brain, FAR, 0.38)
	valid = valid and brain.state == PirateBrain.State.WIND_UP and not brain.threw
	# The Player has moved by the time it lets go: it aims where they stand then.
	var moved := FAR + Vector2(10, 0)
	var threw := false
	for i in range(4):
		brain.step(_frame(moved), DELTA)
		if brain.threw:
			threw = true
			valid = valid and brain.throw_target == moved
	valid = valid and threw and brain.state == PirateBrain.State.RELOAD
	brain.step(_frame(moved), DELTA)
	valid = valid and not brain.threw
	_run(brain, moved, 0.9)
	valid = valid and brain.state == PirateBrain.State.RELOAD
	_run(brain, moved, 0.1)
	return valid and brain.state == PirateBrain.State.WIND_UP


func _test_bomb_above() -> bool:
	var brain := PirateBrain.new()
	brain.step(_frame(ABOVE), DELTA)
	return brain.state == PirateBrain.State.WIND_UP


# Struck back from its post, it walks home at its pace and stops on the spot.
func _test_walks_back() -> bool:
	var brain := PirateBrain.new()
	brain.step(_frame(null), DELTA)
	var away := AT + Vector2(-20, 0)
	brain.step(_frame(null, away), DELTA)
	var valid := brain.state == PirateBrain.State.GUARD
	valid = valid and is_equal_approx(brain.velocity.x, WALK_SPEED) and brain.facing > 0.0
	brain.step(_frame(null, AT + Vector2(-0.2, 0)), DELTA)
	valid = valid and brain.velocity.x == 0.0
	brain.step(_frame(null, AT), DELTA)
	return valid and brain.velocity.x == 0.0


func _test_whistle() -> bool:
	var brain := PirateBrain.new()
	brain.step(_frame(null), DELTA)
	var valid := not brain.noticed
	brain.step(_frame(FAR), DELTA)
	valid = valid and brain.noticed
	var again := false
	for i in range(120):
		brain.step(_frame(FAR), DELTA)
		again = again or brain.noticed
	valid = valid and not again
	_run(brain, OUT_OF_NOTICE[0], 1.5)
	brain.step(_frame(FAR), DELTA)
	return valid and brain.noticed


func _test_flinch() -> bool:
	var valid := true
	# Its tell, wind-up, winded and reloading, each struck partway through.
	var cases := [
		[CLOSE, 0.2, PirateBrain.State.TELL],
		[FAR, 0.2, PirateBrain.State.WIND_UP],
		[CLOSE, 0.95, PirateBrain.State.WINDED],
		[FAR, 0.8, PirateBrain.State.RELOAD],
		[OUT_OF_NOTICE[0], 0.2, PirateBrain.State.GUARD],
	]
	for case in cases:
		var brain := PirateBrain.new()
		_run(brain, case[0], case[1])
		valid = valid and brain.state == case[2]
		brain.step(_frame(case[0], AT, true), DELTA)
		valid = valid and brain.state == PirateBrain.State.HURT
		valid = valid and brain.cutlass_damage == 0 and brain.velocity.x == 0.0
		var threw := false
		for i in range(roundi(0.28 / DELTA)):
			brain.step(_frame(case[0]), DELTA)
			threw = threw or brain.threw
		valid = valid and brain.state == PirateBrain.State.HURT and not threw
		_run(brain, OUT_OF_NOTICE[0], 0.05)
		valid = valid and brain.state == PirateBrain.State.GUARD
	return valid


func _test_rush_committed() -> bool:
	var brain := PirateBrain.new()
	_run(brain, CLOSE, 0.5)
	var valid := brain.state == PirateBrain.State.RUSH
	brain.step(_frame(CLOSE, AT, true), DELTA)
	valid = valid and brain.state == PirateBrain.State.RUSH
	return valid and brain.cutlass_damage == CUTLASS_DAMAGE and brain.velocity.x < 0.0


func _test_defeated() -> bool:
	var brain := PirateBrain.new()
	_run(brain, CLOSE, 0.5)
	var frame := _frame(CLOSE)
	frame.defeated = true
	brain.step(frame, DELTA)
	var valid := brain.state == PirateBrain.State.DEFEATED
	valid = valid and brain.velocity == Vector2.ZERO and brain.cutlass_damage == 0
	_run(brain, FAR, 1.0)
	return valid and brain.state == PirateBrain.State.DEFEATED and not brain.threw
