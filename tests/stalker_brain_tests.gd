extends RefCounted

# The Stalker's rules, played a frame at a time with its own arcs: positions follow its velocity,
# and it stands on a floor at its perch and at the mark.

const StalkerBrain := preload("res://scripts/enemies/stalker_brain.gd")
const DELTA := 1.0 / 60.0
const PERCH := Vector2(280, 80)
# A Player out on the bridge below and west of it, within its notice.
const ON_BRIDGE := Vector2(200, 112)
# Too far sideways, too high above, and too far below.
const OUT_OF_NOTICE: Array[Vector2] = [Vector2(150, 80), Vector2(250, 40), Vector2(250, 200)]
const LEAP_DAMAGE := 12
# How near its arc must bring it to where it aims.
const LANDS_WITHIN := 4.0


func get_tests() -> Array:
	return [
		["Stalker crouches on its perch, still and harmless, with no Player near", _test_perches],
		["Stalker marks where the Player stands, still and harmless", _test_marks],
		["The mark stays where it burst when the Player steps off it", _test_mark_stays],
		["After the mark the Stalker leaps up and out toward it", _test_leaps],
		["The Stalker's leap comes down on the mark", _test_lands_on_mark],
		["Its claws strike only as it comes down", _test_claws],
		["Landed, the Stalker recovers, harmless, then leaps back to its perch", _test_recovers],
		["Back on its perch the Stalker rests before it notices again", _test_rests],
		["A hit on its perch or as it marks makes it flinch, the mark gone", _test_hit_on_perch],
		["A hit as it recovers makes it flinch, then leap back", _test_hit_recovering],
		["A hit in the air costs it Health, but it flies on", _test_hit_in_air],
		["A defeated Stalker stays still and harmless", _test_defeated],
	]


# One frame of facts, the Stalker standing at a point.
static func _frame(at: Vector2, player: Variant, on_floor := true) -> StalkerBrain.Frame:
	var frame := StalkerBrain.Frame.new()
	frame.position = at
	frame.on_floor = on_floor
	if player != null:
		frame.sees_player = true
		frame.player_position = player
	return frame


# Plays frames for a time, moving it by its velocity. It stands on a floor only at the given
# points (its perch, the mark), landing on one it comes down onto. Returns where it ends up.
static func _play(
	brain: StalkerBrain, at: Vector2, player: Variant, seconds: float, floors: Array = []
) -> Vector2:
	for i in range(roundi(seconds / DELTA)):
		var on_floor := false
		for ground: Vector2 in floors:
			on_floor = on_floor or (absf(at.y - ground.y) < 0.5 and absf(at.x - ground.x) < 8.0)
		brain.step(_frame(at, player, on_floor), DELTA)
		var before := at
		at += brain.velocity * DELTA
		for ground: Vector2 in floors:
			var over := absf(at.x - ground.x) < 8.0
			if over and before.y <= ground.y + 0.01 and at.y > ground.y:
				at.y = ground.y
	return at


# Where it stands after marking the Player on the bridge and leaping onto the mark.
static func _landed(brain: StalkerBrain) -> Vector2:
	brain.step(_frame(PERCH, ON_BRIDGE), DELTA)
	var seconds := brain.mark_time + brain.leap_time + 0.1
	return _play(brain, PERCH, ON_BRIDGE, seconds, [PERCH, ON_BRIDGE])


func _test_perches() -> bool:
	var brain := StalkerBrain.new()
	var valid := true
	for player in [null] + OUT_OF_NOTICE:
		brain.step(_frame(PERCH, player), DELTA)
		valid = valid and brain.state == StalkerBrain.State.PERCHED
		valid = valid and brain.velocity == Vector2.ZERO and brain.claws_damage == 0
		valid = valid and not brain.roots_showing
	return valid


func _test_marks() -> bool:
	var brain := StalkerBrain.new()
	brain.step(_frame(PERCH, ON_BRIDGE), DELTA)
	var valid := brain.state == StalkerBrain.State.MARKING and brain.mark == ON_BRIDGE
	valid = valid and brain.roots_showing and brain.facing < 0.0
	valid = valid and brain.velocity == Vector2.ZERO and brain.claws_damage == 0
	_play(brain, PERCH, ON_BRIDGE, brain.mark_time - 2.0 * DELTA, [PERCH])
	return valid and brain.state == StalkerBrain.State.MARKING


func _test_mark_stays() -> bool:
	var brain := StalkerBrain.new()
	brain.step(_frame(PERCH, ON_BRIDGE), DELTA)
	_play(brain, PERCH, ON_BRIDGE + Vector2(-40, 0), brain.mark_time / 2.0, [PERCH])
	return brain.mark == ON_BRIDGE


func _test_leaps() -> bool:
	var brain := StalkerBrain.new()
	brain.step(_frame(PERCH, ON_BRIDGE), DELTA)
	_play(brain, PERCH, ON_BRIDGE, brain.mark_time, [PERCH])
	var valid := brain.state == StalkerBrain.State.LEAPING
	return valid and brain.velocity.x < 0.0 and brain.velocity.y < 0.0 and brain.roots_showing


func _test_lands_on_mark() -> bool:
	var valid := true
	for mark in [ON_BRIDGE, Vector2(360, 160), Vector2(240, 80)]:
		var brain := StalkerBrain.new()
		brain.step(_frame(PERCH, mark), DELTA)
		var seconds := brain.mark_time + brain.leap_time + 0.1
		var at := _play(brain, PERCH, mark, seconds, [PERCH, mark])
		valid = valid and at.distance_to(mark) <= LANDS_WITHIN
		valid = valid and brain.state == StalkerBrain.State.RECOVERING
	return valid


func _test_claws() -> bool:
	var brain := StalkerBrain.new()
	brain.step(_frame(PERCH, ON_BRIDGE), DELTA)
	var at := _play(brain, PERCH, ON_BRIDGE, brain.mark_time, [PERCH])
	var valid := true
	var seen_rising := false
	var seen_falling := false
	while brain.state == StalkerBrain.State.LEAPING:
		var rising := brain.velocity.y < 0.0
		seen_rising = seen_rising or rising
		seen_falling = seen_falling or not rising
		valid = valid and brain.claws_damage == (0 if rising else LEAP_DAMAGE)
		at = _play(brain, at, ON_BRIDGE, DELTA, [ON_BRIDGE])
	valid = valid and seen_rising and seen_falling
	return valid and brain.claws_damage == 0


func _test_recovers() -> bool:
	var brain := StalkerBrain.new()
	var at := _landed(brain)
	var valid := brain.state == StalkerBrain.State.RECOVERING and not brain.roots_showing
	valid = valid and brain.claws_damage == 0 and brain.velocity.x == 0.0
	at = _play(brain, at, ON_BRIDGE, brain.recover_time, [PERCH, ON_BRIDGE])
	valid = valid and brain.state == StalkerBrain.State.RETURNING
	valid = valid and brain.velocity.x > 0.0 and brain.claws_damage == 0
	at = _play(brain, at, ON_BRIDGE, brain.leap_time + 0.1, [PERCH, ON_BRIDGE])
	valid = valid and brain.state == StalkerBrain.State.PERCHED
	return valid and at.distance_to(PERCH) <= LANDS_WITHIN


func _test_rests() -> bool:
	var brain := StalkerBrain.new()
	brain.step(_frame(PERCH, ON_BRIDGE), DELTA)
	var seconds := brain.mark_time + 2.0 * brain.leap_time + brain.recover_time + 0.2
	var at := _play(brain, PERCH, ON_BRIDGE, seconds, [PERCH, ON_BRIDGE])
	var valid := brain.state == StalkerBrain.State.PERCHED
	at = _play(brain, at, ON_BRIDGE, brain.rest_time - 0.4, [PERCH])
	valid = valid and brain.state == StalkerBrain.State.PERCHED
	_play(brain, at, ON_BRIDGE, 0.4, [PERCH])
	return valid and brain.state == StalkerBrain.State.MARKING


func _test_hit_on_perch() -> bool:
	var valid := true
	for marking in [false, true]:
		var brain := StalkerBrain.new()
		brain.step(_frame(PERCH, ON_BRIDGE if marking else null), DELTA)
		var struck := _frame(PERCH, ON_BRIDGE if marking else null)
		struck.struck = true
		brain.step(struck, DELTA)
		valid = valid and brain.state == StalkerBrain.State.HURT and not brain.roots_showing
		_play(brain, PERCH, null, brain.hurt_time + DELTA, [PERCH])
		valid = valid and brain.state == StalkerBrain.State.PERCHED
	return valid


func _test_hit_recovering() -> bool:
	var brain := StalkerBrain.new()
	var at := _landed(brain)
	var struck := _frame(at, ON_BRIDGE)
	struck.struck = true
	brain.step(struck, DELTA)
	var valid := brain.state == StalkerBrain.State.HURT and brain.claws_damage == 0
	_play(brain, at, ON_BRIDGE, brain.hurt_time + DELTA, [PERCH, ON_BRIDGE])
	return valid and brain.state == StalkerBrain.State.RETURNING


func _test_hit_in_air() -> bool:
	var brain := StalkerBrain.new()
	brain.step(_frame(PERCH, ON_BRIDGE), DELTA)
	var at := _play(brain, PERCH, ON_BRIDGE, brain.mark_time + 0.1, [PERCH])
	var struck := _frame(at, ON_BRIDGE, false)
	struck.struck = true
	var velocity := brain.velocity
	brain.step(struck, DELTA)
	return brain.state == StalkerBrain.State.LEAPING and brain.velocity.x == velocity.x


func _test_defeated() -> bool:
	var brain := StalkerBrain.new()
	brain.step(_frame(PERCH, ON_BRIDGE), DELTA)
	_play(brain, PERCH, ON_BRIDGE, brain.mark_time + 0.2, [PERCH])
	var defeated := _frame(PERCH, ON_BRIDGE, false)
	defeated.defeated = true
	brain.step(defeated, DELTA)
	var valid := brain.state == StalkerBrain.State.DEFEATED and brain.claws_damage == 0
	valid = valid and brain.velocity == Vector2.ZERO and not brain.roots_showing
	brain.step(_frame(PERCH, ON_BRIDGE), DELTA)
	return valid and brain.state == StalkerBrain.State.DEFEATED
