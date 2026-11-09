extends RefCounted

# The Stalker's rules, one frame of facts at a time: it crouches on its perch until the Player
# comes near below it, marks where they stand with roots, leaps onto the mark, recovers there,
# then leaps back to its perch and rests. Positions are its feet and the Player's.

enum State {
	PERCHED,
	MARKING,
	LEAPING,
	RECOVERING,
	RETURNING,
	HURT,
	DEFEATED,
}


class Frame:
	var position: Vector2 = Vector2.ZERO
	var sees_player: bool = false
	var player_position: Vector2 = Vector2.ZERO
	# True on the frame a hit lands.
	var struck: bool = false
	var on_floor: bool = false
	var defeated: bool = false


# How near the Player must come: sideways, above its feet, and below them.
var notice_across: float = 112.0
var notice_above: float = 16.0
var notice_below: float = 96.0
var mark_time: float = 0.6
# How long each leap takes, there and back.
var leap_time: float = 0.7
var recover_time: float = 0.8
var rest_time: float = 1.2
var hurt_time: float = 0.3
var gravity: float = 980.0
var fall_speed: float = 300.0
# What landing on the Player costs them.
var leap_damage: int = 12
# How long a leap must have flown before a floor under it is a landing, not where it left.
var lift_off_time: float = 0.1

var state: State = State.PERCHED
var facing: float = -1.0
var velocity: Vector2 = Vector2.ZERO
# Where it leaps from and back to: where it first stands.
var perch: Vector2 = Vector2.ZERO
# Where the roots burst, under the Player.
var mark: Vector2 = Vector2.ZERO
# What its claws cost the Player now; 0 while harmless.
var claws_damage: int = 0
var roots_showing: bool = false
var _perched_yet: bool = false
var _time_left: float = 0.0
var _airborne: float = 0.0
# Where it goes once a flinch is over: back to its perch, or on resting there.
var _after_hurt: State = State.PERCHED


func step(frame: Frame, delta: float) -> void:
	if not _perched_yet:
		perch = frame.position
		_perched_yet = true
	if frame.defeated or state == State.DEFEATED:
		_enter(State.DEFEATED, 0.0)
		velocity = Vector2.ZERO
		return
	# Struck in the air it flies on; anywhere else it flinches.
	if frame.struck and state != State.LEAPING and state != State.RETURNING:
		if state != State.HURT:
			_after_hurt = State.RETURNING if state == State.RECOVERING else State.PERCHED
		_enter(State.HURT, hurt_time)
	else:
		_time_left -= delta
		_think(frame, delta)
	_move(frame, delta)


func _think(frame: Frame, delta: float) -> void:
	match state:
		State.PERCHED:
			if _time_left <= 0.0 and _notices(frame):
				mark = frame.player_position
				_face(mark.x - frame.position.x)
				_enter(State.MARKING, mark_time)
		State.MARKING:
			if _time_left <= 0.0:
				_leap(State.LEAPING, frame.position, mark, delta)
		State.LEAPING:
			_airborne += delta
			if _landed(frame):
				_enter(State.RECOVERING, recover_time)
		State.RECOVERING:
			if _time_left <= 0.0:
				_leap(State.RETURNING, frame.position, perch, delta)
		State.RETURNING:
			_airborne += delta
			if _landed(frame):
				_enter(State.PERCHED, rest_time)
		State.HURT:
			if _time_left <= 0.0:
				if _after_hurt == State.RETURNING:
					_leap(State.RETURNING, frame.position, perch, delta)
				else:
					_enter(State.PERCHED, 0.0)


func _notices(frame: Frame) -> bool:
	var offset := frame.player_position - frame.position
	return (
		frame.sees_player
		and absf(offset.x) <= notice_across
		and offset.y >= -notice_above
		and offset.y <= notice_below
	)


func _landed(frame: Frame) -> bool:
	return frame.on_floor and velocity.y >= 0.0 and _airborne > lift_off_time


# Sets off on an arc from one point to come down on another in a leap's time. Gravity is added
# from the next frame on, before each move, so the launch makes up the half frame it costs.
func _leap(next: State, from: Vector2, to: Vector2, delta: float) -> void:
	_enter(next, 0.0)
	_airborne = 0.0
	_face(to.x - from.x)
	var rise := (to.y - from.y) / leap_time - 0.5 * gravity * leap_time + 0.5 * gravity * delta
	velocity = Vector2((to.x - from.x) / leap_time, rise)


func _face(dx: float) -> void:
	if dx != 0.0:
		facing = signf(dx)


# In a leap it flies its arc; otherwise it keeps its place sideways and falls if unsupported.
func _move(frame: Frame, delta: float) -> void:
	if state == State.LEAPING or state == State.RETURNING:
		if _airborne > 0.0:
			velocity.y += gravity * delta
	else:
		velocity.x = 0.0
		velocity.y = 0.0 if frame.on_floor else minf(velocity.y + gravity * delta, fall_speed)
	claws_damage = leap_damage if state == State.LEAPING and velocity.y > 0.0 else 0


func _enter(next: State, time: float) -> void:
	state = next
	_time_left = time
	roots_showing = next == State.MARKING or next == State.LEAPING
	if next != State.LEAPING and next != State.RETURNING:
		claws_damage = 0
