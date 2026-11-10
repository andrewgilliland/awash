extends RefCounted

# What Rusk does, one step at a time. He stands dormant at his post until the Player comes into
# the arena, speaks, then drives his maul down and the roots rise. He fights in turns: a move,
# then a rest. A Player far off he charges until he meets a wall, and stands dazed; one close by
# he slams with his maul, shaking the floor. Below half Health he hurries: shorter tells, and a
# charge's wall leads into a slam and a second charge. Beaten, he kneels, speaks, and leaps away.

enum State {
	DORMANT,
	SPEAKING,
	SUMMONING,
	REST,
	TELL,
	CHARGE,
	DAZED,
	WIND_UP,
	SLAM,
	KNEEL,
	LEAP,
	GONE,
}

# The states he fights in, from the roots rising: hits land, and the Boss Health bar shows.
const FIGHTING: Array[State] = [
	State.SUMMONING, State.REST, State.TELL, State.CHARGE, State.DAZED, State.WIND_UP, State.SLAM
]


class Frame:
	var sees_player: bool = false
	# From Rusk to the Player.
	var player_offset: Vector2 = Vector2.ZERO
	# The share of his Health left.
	var health_share: float = 1.0
	# True once the Player has read what he says, speaking or kneeling.
	var words_read: bool = false
	# True on the step his charge meets a wall.
	var met_wall: bool = false
	var defeated: bool = false


# How near the Player must come, across, to wake him.
var wake_distance: float = 88.0
# Within this, across, he slams; beyond it he charges.
var slam_range: float = 48.0
var summon_time: float = 0.6
# The beat after the roots rise, before his first move.
var beat_time: float = 0.6
var tell_time: float = 0.6
var charge_speed: float = 180.0
# A charge that meets no wall ends after this.
var charge_limit: float = 2.0
var dazed_time: float = 1.2
var windup_time: float = 0.7
var slam_time: float = 0.3
var rest_time: float = 1.0
# Below this share of Health left, he hurries, and each tell and wind-up lasts hurried_time.
var hurry_below: float = 0.5
var hurried_time: float = 0.4
var leap_time: float = 0.8

# Read-only for callers.
var state: State = State.DORMANT
var facing: float = -1.0
var velocity: Vector2 = Vector2.ZERO
# Whether touching him harms the Player.
var touch_harms: bool = false
# Whether his plate turns aside quick hits on his front: while he charges.
var plated: bool = false
# Whether the maul's blow in front of him is live.
var maul_active: bool = false
# True on the step he drives his maul down and the roots rise.
var roots_called: bool = false
# True on the step his maul lands, shaking the floor.
var slammed: bool = false
# True on the step his charge meets a wall.
var crashed: bool = false
# True on the step he leaps away.
var leaped: bool = false
var _time_left: float = 0.0
# Hurried, a charge's wall leads into a slam, then into a second charge that ends dazed.
var _chain: int = 0


func is_fighting() -> bool:
	return state in FIGHTING


func charging() -> bool:
	return state == State.CHARGE


func step(frame: Frame, delta: float) -> void:
	roots_called = false
	slammed = false
	crashed = false
	leaped = false
	if frame.defeated and is_fighting():
		_enter(State.KNEEL, 0.0)
		return

	_time_left -= delta
	var hurried := frame.health_share < hurry_below
	match state:
		State.DORMANT:
			if frame.sees_player and absf(frame.player_offset.x) <= wake_distance:
				_face(frame)
				_enter(State.SPEAKING, 0.0)
		State.SPEAKING:
			if frame.words_read:
				roots_called = true
				_enter(State.SUMMONING, summon_time)
		State.SUMMONING:
			if _due():
				_enter(State.REST, beat_time)
		State.REST:
			if _due():
				_face(frame)
				if absf(frame.player_offset.x) <= slam_range:
					_enter(State.WIND_UP, hurried_time if hurried else windup_time)
				else:
					_enter(State.TELL, hurried_time if hurried else tell_time)
		State.TELL:
			if _due():
				_enter(State.CHARGE, charge_limit)
		State.CHARGE:
			_step_charge(frame, hurried)
		State.DAZED:
			if _due():
				_enter(State.REST, rest_time)
		State.WIND_UP:
			if _due():
				slammed = true
				_enter(State.SLAM, slam_time)
		State.SLAM:
			if _due():
				if _chain == 1:
					_chain = 2
					_face(frame)
					_enter(State.TELL, hurried_time)
				else:
					_enter(State.REST, rest_time)
		State.KNEEL:
			if frame.words_read:
				facing = 1.0
				leaped = true
				_enter(State.LEAP, leap_time)
		State.LEAP:
			if _due():
				_enter(State.GONE, 0.0)


func _step_charge(frame: Frame, hurried: bool) -> void:
	if frame.met_wall:
		crashed = true
		if hurried and _chain == 0:
			_chain = 1
			_face(frame)
			_enter(State.WIND_UP, hurried_time)
			return
		_chain = 0
		_enter(State.DAZED, dazed_time)
	elif _due():
		_chain = 0
		_enter(State.DAZED, dazed_time)


# Summed frame times can fall a hair short of the time they add up to.
func _due() -> bool:
	return _time_left <= 0.001


func _face(frame: Frame) -> void:
	if frame.player_offset.x != 0.0:
		facing = signf(frame.player_offset.x)


func _enter(next: State, time: float) -> void:
	state = next
	_time_left = time
	plated = next == State.CHARGE
	maul_active = next == State.SLAM
	velocity = Vector2(facing * charge_speed, 0.0) if plated else Vector2.ZERO
	touch_harms = is_fighting() and next != State.DAZED and next != State.SUMMONING
