extends RefCounted

const ReefbackBrain := preload("res://scripts/enemies/reefback_brain.gd")
const DELTA := 0.05
const FAR := Vector2(-80, 0)
const NEAR := Vector2(-30, 0)
const CLOSE := Vector2(-16, 0)
const AWAY := Vector2(-200, 0)


func get_tests() -> Array:
	return [
		["Reefback stands dormant until the Player comes near", _test_dormant_until_near],
		["Between attacks the Reefback stomps toward the Player", _test_stomps],
		["From afar it charges, leaps or throws; up close, swipes or pounds", _test_picks_by_range],
		["It never makes the same attack twice in a row", _test_never_repeats],
		["Each attack is shown first by a Tell, facing the Player", _test_tells],
		["A knuckle charge gallops at the Player, hitting hard, then rests", _test_charge],
		["A lunge swipe lunges forward with its swipe live", _test_swipe],
		["A ground pound sends its shockwaves once", _test_pound],
		["A leap carries it to where the Player stood, then it lands", _test_leap],
		["A reef throw is thrown once, at where the Player stands", _test_throw],
		["At half Health it beats its chest once, then hurries", _test_chest_beat],
		["A broken Ward staggers the Reefback until the Ward returns", _test_stagger],
		["A defeated Reefback stays still and harmless", _test_defeated],
	]


func _test_dormant_until_near() -> bool:
	var brain := ReefbackBrain.new()
	brain.step(_frame(AWAY), DELTA)
	var valid := brain.state == ReefbackBrain.State.DORMANT and not brain.is_awake()
	valid = valid and not brain.touch_harms and brain.velocity.x == 0.0
	brain.step(_frame(FAR), DELTA)
	valid = valid and brain.is_awake() and brain.state == ReefbackBrain.State.REST
	return valid and brain.facing == -1.0 and brain.warded and brain.touch_harms


func _test_stomps() -> bool:
	var brain := _awake()
	brain.step(_frame(FAR), DELTA)
	var valid := brain.velocity.x == -brain.walk_speed and brain.facing == -1.0
	brain.step(_frame(CLOSE), DELTA)
	valid = valid and brain.velocity.x == 0.0
	brain.step(_frame(-FAR), DELTA)
	valid = valid and brain.velocity.x == brain.walk_speed and brain.facing == 1.0
	# It plants its feet for a Tell.
	_steps_until(brain, FAR, ReefbackBrain.State.TELL)
	return valid and brain.velocity.x == 0.0


func _test_picks_by_range() -> bool:
	var offered: Array = []
	var far := _awake(
		func(options: Array) -> ReefbackBrain.Move:
			offered.append(options.duplicate())
			return options[0]
	)
	_steps_until(far, FAR, ReefbackBrain.State.TELL)
	var valid := (
		offered.size() == 1
		and _same(
			offered[0],
			[ReefbackBrain.Move.CHARGE, ReefbackBrain.Move.LEAP, ReefbackBrain.Move.THROW]
		)
	)
	valid = valid and far.move == ReefbackBrain.Move.CHARGE
	offered.clear()
	var near := _awake(
		func(options: Array) -> ReefbackBrain.Move:
			offered.append(options.duplicate())
			return options[0]
	)
	_steps_until(near, NEAR, ReefbackBrain.State.TELL, NEAR)
	valid = (
		valid
		and offered.size() == 1
		and _same(offered[0], [ReefbackBrain.Move.SWIPE, ReefbackBrain.Move.POUND])
	)
	return valid and near.move == ReefbackBrain.Move.SWIPE


func _test_never_repeats() -> bool:
	var offered: Array = []
	var brain := _awake(
		func(options: Array) -> ReefbackBrain.Move:
			offered.append(options.duplicate())
			return options[0]
	)
	_steps_until(brain, NEAR, ReefbackBrain.State.TELL, NEAR)
	_steps_until(brain, NEAR, ReefbackBrain.State.REST, NEAR)
	_steps_until(brain, NEAR, ReefbackBrain.State.TELL, NEAR)
	var valid := offered.size() == 2 and _same(offered[1], [ReefbackBrain.Move.POUND])
	return valid and brain.move == ReefbackBrain.Move.POUND


func _test_tells() -> bool:
	var brain := _awake(_first)
	var steps := _steps_until(brain, FAR, ReefbackBrain.State.TELL)
	var valid := brain.facing == -1.0 and brain.velocity.x == 0.0 and brain.warded
	steps = _steps_until(brain, FAR, ReefbackBrain.State.CHARGE)
	return valid and _near(steps * DELTA, brain.tell_time)


func _test_charge() -> bool:
	var brain := _awake(_first)
	_steps_until(brain, FAR, ReefbackBrain.State.CHARGE)
	var valid := brain.charging and brain.velocity.x == -brain.charge_speed and brain.touch_harms
	var steps := _steps_until(brain, FAR, ReefbackBrain.State.REST)
	valid = valid and _near(steps * DELTA, brain.charge_time)
	return valid and not brain.charging and brain.velocity.x == 0.0


func _test_swipe() -> bool:
	var brain := _awake(_first)
	_steps_until(brain, NEAR, ReefbackBrain.State.SWIPE, NEAR)
	var valid := brain.swipe_active and brain.velocity.x == -brain.swipe_speed
	var steps := _steps_until(brain, NEAR, ReefbackBrain.State.REST, NEAR)
	valid = valid and _near(steps * DELTA, brain.swipe_time)
	return valid and not brain.swipe_active and brain.velocity.x == 0.0


func _test_pound() -> bool:
	var brain := _awake(
		func(_options: Array) -> ReefbackBrain.Move: return ReefbackBrain.Move.POUND
	)
	_steps_until(brain, NEAR, ReefbackBrain.State.TELL, NEAR)
	var pounds := _count_until(brain, NEAR, ReefbackBrain.State.REST, "pounded")
	return pounds == 1 and brain.velocity.x == 0.0


func _test_leap() -> bool:
	var brain := _awake(func(_options: Array) -> ReefbackBrain.Move: return ReefbackBrain.Move.LEAP)
	_steps_until(brain, FAR, ReefbackBrain.State.LEAP)
	var valid := brain.airborne and not brain.touch_harms
	# It flies to where the Player stood as its Tell ended, whatever the Player does next.
	valid = valid and is_equal_approx(brain.velocity.x * brain.leap_time, FAR.x)
	brain.step(_frame(-FAR), DELTA)
	valid = valid and is_equal_approx(brain.velocity.x * brain.leap_time, FAR.x)
	var landings := _count_until(brain, FAR, ReefbackBrain.State.LAND, "landed")
	valid = valid and landings == 1 and not brain.airborne and brain.velocity.x == 0.0
	var steps := _steps_until(brain, FAR, ReefbackBrain.State.REST)
	return valid and _near(steps * DELTA, brain.land_time)


func _test_throw() -> bool:
	var brain := _awake(
		func(_options: Array) -> ReefbackBrain.Move: return ReefbackBrain.Move.THROW
	)
	_steps_until(brain, FAR, ReefbackBrain.State.TELL)
	var throws := 0
	var offset := 0.0
	for i in 200:
		brain.step(_frame(FAR), DELTA)
		if brain.threw:
			throws += 1
			offset = brain.throw_offset
		if brain.state == ReefbackBrain.State.REST:
			break
	return throws == 1 and offset == FAR.x and brain.velocity.x == 0.0


func _test_chest_beat() -> bool:
	var brain := _awake(_first)
	var valid := not brain.hurried
	var beats := _count_until(brain, FAR, ReefbackBrain.State.CHEST_BEAT, "beat", 0.4)
	valid = valid and beats == 1 and brain.velocity.x == 0.0
	var steps := _steps_until(brain, FAR, ReefbackBrain.State.REST, FAR, 0.4)
	valid = valid and _near(steps * DELTA, brain.chest_beat_time) and brain.hurried
	# Hurried: a shorter Tell, a faster stomp and charge, and no second chest-beat.
	brain.step(_frame(FAR, 0.3), DELTA)
	valid = valid and is_equal_approx(brain.velocity.x, -brain.walk_speed * brain.hurry)
	steps = _steps_until(brain, FAR, ReefbackBrain.State.CHARGE, FAR, 0.3)
	valid = valid and brain.velocity.x == -brain.charge_speed * brain.hurry
	_steps_until(brain, FAR, ReefbackBrain.State.TELL, FAR, 0.3)
	steps = _steps_until(brain, FAR, ReefbackBrain.State.LEAP, FAR, 0.3)
	return valid and _near(steps * DELTA, brain.hurried_tell_time)


func _test_stagger() -> bool:
	var brain := _awake(_first)
	_steps_until(brain, FAR, ReefbackBrain.State.CHARGE)
	var broken := _frame(FAR)
	broken.ward_broken = true
	brain.step(broken, DELTA)
	var valid := brain.state == ReefbackBrain.State.STAGGERED and not brain.warded
	valid = valid and not brain.touch_harms and not brain.charging and brain.velocity.x == 0.0
	var steps := _steps_until(brain, CLOSE, ReefbackBrain.State.REST, CLOSE)
	valid = valid and _near(steps * DELTA, brain.stagger_time) and brain.warded
	steps = _steps_until(brain, CLOSE, ReefbackBrain.State.TELL, CLOSE)
	return valid and _near(steps * DELTA, brain.beat_time)


func _test_defeated() -> bool:
	var brain := _awake(_first)
	_steps_until(brain, FAR, ReefbackBrain.State.CHARGE)
	var down := _frame(FAR)
	down.defeated = true
	brain.step(down, DELTA)
	var valid := brain.state == ReefbackBrain.State.DEFEATED and brain.velocity.x == 0.0
	valid = valid and not brain.touch_harms and not brain.charging and not brain.warded
	brain.step(_frame(FAR), 10.0)
	return valid and brain.state == ReefbackBrain.State.DEFEATED


# A Reefback just woken by a Player far off, choosing its attacks with the given picker.
func _awake(choose: Callable = _first) -> ReefbackBrain:
	var brain := ReefbackBrain.new()
	brain.choose = choose
	brain.step(_frame(FAR), DELTA)
	return brain


func _first(options: Array) -> ReefbackBrain.Move:
	return options[0]


func _frame(offset: Vector2, health_share: float = 1.0) -> ReefbackBrain.Frame:
	var frame := ReefbackBrain.Frame.new()
	frame.sees_player = true
	frame.player_offset = offset
	frame.health_share = health_share
	return frame


# Steps, with the Player at `first` on the first step and `offset` after, until the brain enters
# the state; returns how many steps that took. Gives up after ten seconds.
func _steps_until(
	brain: ReefbackBrain,
	first: Vector2,
	state: ReefbackBrain.State,
	offset: Vector2 = Vector2.INF,
	health_share: float = 1.0
) -> int:
	var rest := first if offset == Vector2.INF else offset
	for steps in range(1, 201):
		brain.step(_frame(first if steps == 1 else rest, health_share), DELTA)
		if brain.state == state:
			return steps
	return -1


# Steps until the brain enters the state, counting the steps on which the named event fired.
func _count_until(
	brain: ReefbackBrain,
	offset: Vector2,
	state: ReefbackBrain.State,
	event: String,
	health_share: float = 1.0
) -> int:
	var count := 0
	for steps in 200:
		brain.step(_frame(offset, health_share), DELTA)
		count += 1 if brain.get(event) else 0
		if brain.state == state:
			return count
	return -1


func _same(a: Array, b: Array) -> bool:
	var x := a.duplicate()
	var y := b.duplicate()
	x.sort()
	y.sort()
	return x == y


func _near(seconds: float, expected: float) -> bool:
	return absf(seconds - expected) <= DELTA * 1.5
