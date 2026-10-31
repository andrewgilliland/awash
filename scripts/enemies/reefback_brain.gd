extends RefCounted

# What the Reefback does, one step at a time. It stands dormant until the Player comes near, then
# fights in turns: a rest, stomping toward the Player; a Tell, planted and facing them; then an
# attack. From afar it charges on its knuckles, leaps to where the Player stood, or throws a
# chunk of reef; up close it swipes or pounds the floor; never the same attack twice in a row.
# The first time its Health is half gone, it beats its chest instead, bringing rubble down, and
# hurries from then on. Its Ward is up throughout; breaking it staggers the Reefback, and the Ward
# returns when the Stagger ends.

enum State {
	DORMANT,
	REST,
	TELL,
	CHARGE,
	SWIPE,
	POUND,
	LEAP,
	LAND,
	THROW,
	CHEST_BEAT,
	STAGGERED,
	DEFEATED,
}
enum Move {
	CHARGE,
	SWIPE,
	POUND,
	LEAP,
	THROW,
}

const FAR_MOVES: Array[Move] = [Move.CHARGE, Move.LEAP, Move.THROW]
const NEAR_MOVES: Array[Move] = [Move.SWIPE, Move.POUND]
const MOVE_STATES := {
	Move.CHARGE: State.CHARGE,
	Move.SWIPE: State.SWIPE,
	Move.POUND: State.POUND,
	Move.LEAP: State.LEAP,
	Move.THROW: State.THROW,
}


class Frame:
	var sees_player: bool = false
	# From the Reefback to the Player.
	var player_offset: Vector2 = Vector2.ZERO
	# The share of its Health left.
	var health_share: float = 1.0
	# True on the step a Charged Attack breaks the Ward.
	var ward_broken: bool = false
	var defeated: bool = false


# How near the Player must come, across the floor, to wake it; nearer than near_distance counts
# as up close; nearer than keep_distance it stops stomping closer.
var wake_distance: float = 80.0
var near_distance: float = 40.0
var keep_distance: float = 24.0
var walk_speed: float = 20.0
# The beat before its first Tell, and after a Stagger; the rest after each attack.
var beat_time: float = 0.6
var rest_time: float = 1.0
var tell_time: float = 0.8
var hurried_tell_time: float = 0.55
var charge_time: float = 0.75
var charge_speed: float = 120.0
var swipe_time: float = 0.35
var swipe_speed: float = 90.0
var pound_time: float = 0.5
var leap_time: float = 0.8
var land_time: float = 0.4
var throw_time: float = 0.9
var chest_beat_time: float = 1.4
var stagger_time: float = 3.0
# Below this share of Health left it beats its chest, then walks and charges this much faster.
var hurry_below: float = 0.5
var hurry: float = 4.0 / 3.0
# Picks one attack from those it may make; tests swap it for a fixed choice.
var choose: Callable = func(options: Array) -> Move: return options[randi() % options.size()]

# Read-only for callers.
var state: State = State.DORMANT
# The attack being told or made.
var move: Move = Move.CHARGE
var facing: float = -1.0
var velocity: Vector2 = Vector2.ZERO
var warded: bool = true
# Whether touching it harms the Player; whether that touch is a charge's; whether its swipe is
# live; whether it is in the air.
var touch_harms: bool = false
var charging: bool = false
var swipe_active: bool = false
var airborne: bool = false
# Whether it has beaten its chest, and hurries.
var hurried: bool = false
# True on the step each happens: a pound strikes, a leap lands, a chunk is thrown, the chest-beat
# starts. A throw aims throw_offset across from it; a leap lands leap_offset across.
var pounded: bool = false
var landed: bool = false
var threw: bool = false
var beat: bool = false
var throw_offset: float = 0.0
var leap_offset: float = 0.0
var _time_left: float = 0.0
var _duration: float = 0.0
var _last_move: int = -1


func is_awake() -> bool:
	return state != State.DORMANT


# How far through its current state it is, from 0 to 1; what a body's animation follows.
func progress() -> float:
	return clampf(1.0 - _time_left / _duration, 0.0, 1.0) if _duration > 0.0 else 0.0


func step(frame: Frame, delta: float) -> void:
	pounded = false
	landed = false
	threw = false
	beat = false
	if frame.defeated or state == State.DEFEATED:
		_enter(State.DEFEATED, 0.0)
		return
	if frame.ward_broken and warded and is_awake():
		_enter(State.STAGGERED, stagger_time)
		return

	_time_left -= delta
	match state:
		State.DORMANT:
			if frame.sees_player and absf(frame.player_offset.x) <= wake_distance:
				_face(frame)
				_enter(State.REST, beat_time)
		State.REST:
			_stomp(frame)
			if _time_left <= 0.0:
				_decide(frame)
		State.TELL:
			if _time_left <= 0.0:
				_attack(frame)
		State.LEAP:
			if _time_left <= 0.0:
				_enter(State.LAND, land_time)
				landed = true
		State.STAGGERED:
			if _time_left <= 0.0:
				_enter(State.REST, beat_time)
		_:
			if _time_left <= 0.0:
				_enter(State.REST, rest_time)


# After a rest: the chest-beat, the first time half its Health is gone; otherwise a Tell for an
# attack chosen by how far off the Player is, never the last one again.
func _decide(frame: Frame) -> void:
	_face(frame)
	if not hurried and frame.health_share < hurry_below:
		_enter(State.CHEST_BEAT, chest_beat_time)
		hurried = true
		beat = true
		return
	var near := absf(frame.player_offset.x) < near_distance
	var options: Array = (NEAR_MOVES if near else FAR_MOVES).filter(
		func(option: Move) -> bool: return option != _last_move
	)
	move = choose.call(options)
	_last_move = move
	_enter(State.TELL, hurried_tell_time if hurried else tell_time)


func _attack(frame: Frame) -> void:
	_face(frame)
	match move:
		Move.CHARGE:
			_enter(State.CHARGE, charge_time)
			velocity.x = facing * charge_speed * (hurry if hurried else 1.0)
		Move.SWIPE:
			_enter(State.SWIPE, swipe_time)
			velocity.x = facing * swipe_speed
		Move.POUND:
			_enter(State.POUND, pound_time)
			pounded = true
		Move.LEAP:
			_enter(State.LEAP, leap_time)
			leap_offset = frame.player_offset.x
			velocity.x = leap_offset / leap_time
		Move.THROW:
			_enter(State.THROW, throw_time)
			throw_offset = frame.player_offset.x
			threw = true


# Toward a Player out of reach, step by heavy step; close by, it stands its ground.
func _stomp(frame: Frame) -> void:
	if frame.sees_player and absf(frame.player_offset.x) > keep_distance:
		_face(frame)
		velocity.x = facing * walk_speed * (hurry if hurried else 1.0)
	else:
		velocity.x = 0.0


func _face(frame: Frame) -> void:
	if frame.player_offset.x != 0.0:
		facing = signf(frame.player_offset.x)


func _enter(next: State, time: float) -> void:
	state = next
	_time_left = time
	_duration = time
	velocity = Vector2.ZERO
	warded = next != State.STAGGERED and next != State.DEFEATED
	charging = next == State.CHARGE
	swipe_active = next == State.SWIPE
	airborne = next == State.LEAP
	touch_harms = next != State.DORMANT and warded and not airborne
