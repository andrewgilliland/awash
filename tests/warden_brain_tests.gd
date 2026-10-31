extends RefCounted

const WardenBrain := preload("res://scripts/enemies/warden_brain.gd")
const DELTA := 0.05
const NEAR := Vector2(-60, 0)
const FAR := Vector2(-120, 0)


func get_tests() -> Array:
	return [
		["Warden stands dormant until the Player comes near", _test_dormant_until_near],
		["Warden winds up, bashes toward the Player, then rests", _test_bashes],
		["After a bash the Warden slams one shockwave, then rests", _test_slams_after_bash],
		["Below half Health the Warden winds up faster and slams twice", _test_hurries],
		["A broken Ward staggers the Warden until the Ward returns", _test_stagger],
		["A defeated Warden stays still and harmless", _test_defeated],
	]


func _test_dormant_until_near() -> bool:
	var brain := WardenBrain.new()
	brain.step(_frame(FAR), DELTA)
	var valid := brain.state == WardenBrain.State.DORMANT and not brain.is_awake()
	valid = valid and not brain.touch_harms and brain.velocity.x == 0.0
	brain.step(_frame(NEAR), DELTA)
	valid = valid and brain.is_awake() and brain.state == WardenBrain.State.REST
	return valid and brain.facing == -1.0 and brain.warded and brain.touch_harms


func _test_bashes() -> bool:
	var brain := _awake()
	var steps := _steps_until(brain, NEAR, WardenBrain.State.WINDUP)
	var valid := not brain.bash_active and brain.velocity.x == 0.0
	steps = _steps_until(brain, NEAR, WardenBrain.State.BASH)
	valid = valid and _near(steps * DELTA, brain.windup_time)
	valid = valid and brain.bash_active and brain.velocity.x == -brain.bash_speed
	steps = _steps_until(brain, NEAR, WardenBrain.State.REST)
	valid = valid and _near(steps * DELTA, brain.bash_time)
	return valid and not brain.bash_active and brain.velocity.x == 0.0


func _test_slams_after_bash() -> bool:
	var brain := _awake()
	_steps_until(brain, NEAR, WardenBrain.State.BASH)
	_steps_until(brain, NEAR, WardenBrain.State.REST)
	var steps := _steps_until(brain, NEAR, WardenBrain.State.WINDUP)
	var valid := _near(steps * DELTA, brain.rest_time)
	var slams := _slams_until(brain, NEAR, 1.0, WardenBrain.State.REST)
	valid = valid and slams == 1 and not brain.bash_active
	# Then it bashes again.
	steps = _steps_until(brain, NEAR, WardenBrain.State.BASH)
	return valid and _near(steps * DELTA, brain.rest_time + brain.windup_time)


func _test_hurries() -> bool:
	var brain := _awake()
	_steps_until(brain, NEAR, WardenBrain.State.WINDUP, 0.4)
	var steps := _steps_until(brain, NEAR, WardenBrain.State.BASH, 0.4)
	var valid := _near(steps * DELTA, brain.hurried_windup_time)
	_steps_until(brain, NEAR, WardenBrain.State.WINDUP, 0.4)
	return valid and _slams_until(brain, NEAR, 0.4, WardenBrain.State.REST) == 2


func _test_stagger() -> bool:
	var brain := _awake()
	_steps_until(brain, NEAR, WardenBrain.State.BASH)
	var broken := _frame(NEAR)
	broken.ward_broken = true
	brain.step(broken, DELTA)
	var valid := brain.state == WardenBrain.State.STAGGERED and not brain.warded
	valid = valid and not brain.touch_harms and not brain.bash_active
	valid = valid and brain.velocity.x == 0.0
	var steps := _steps_until(brain, NEAR, WardenBrain.State.REST)
	valid = valid and _near(steps * DELTA, brain.stagger_time)
	valid = valid and brain.warded and brain.touch_harms
	steps = _steps_until(brain, NEAR, WardenBrain.State.WINDUP)
	return valid and _near(steps * DELTA, brain.beat_time)


func _test_defeated() -> bool:
	var brain := _awake()
	_steps_until(brain, NEAR, WardenBrain.State.BASH)
	var down := _frame(NEAR)
	down.defeated = true
	brain.step(down, DELTA)
	var valid := brain.state == WardenBrain.State.DEFEATED and brain.velocity.x == 0.0
	valid = valid and not brain.touch_harms and not brain.bash_active and not brain.warded
	brain.step(_frame(NEAR), 10.0)
	return valid and brain.state == WardenBrain.State.DEFEATED


func _awake() -> WardenBrain:
	var brain := WardenBrain.new()
	brain.step(_frame(NEAR), DELTA)
	return brain


func _frame(offset: Vector2, health_share: float = 1.0) -> WardenBrain.Frame:
	var frame := WardenBrain.Frame.new()
	frame.sees_player = true
	frame.player_offset = offset
	frame.health_share = health_share
	return frame


# Steps until the brain enters the state, and returns how many steps that took. Gives up after
# ten seconds.
func _steps_until(
	brain: WardenBrain, offset: Vector2, state: WardenBrain.State, health_share: float = 1.0
) -> int:
	for steps in range(1, 201):
		brain.step(_frame(offset, health_share), DELTA)
		if brain.state == state:
			return steps
	return -1


# Steps until the brain enters the state, counting the shockwaves it sends on the way.
func _slams_until(
	brain: WardenBrain, offset: Vector2, health_share: float, state: WardenBrain.State
) -> int:
	var slams := 0
	for steps in 200:
		brain.step(_frame(offset, health_share), DELTA)
		slams += 1 if brain.slammed else 0
		if brain.state == state:
			return slams
	return -1


func _near(seconds: float, expected: float) -> bool:
	return absf(seconds - expected) <= DELTA * 1.5
