extends RefCounted

enum State {
	DRIFT,
	CRACKLE,
	ARC,
	REST,
	HURT,
	DEFEATED,
}


class Frame:
	var position: Vector2 = Vector2.ZERO
	var sees_player: bool = false
	# From the Wisp to the Player.
	var player_offset: Vector2 = Vector2.ZERO
	# Non-zero on the frame a hit lands: the direction the hit pushes the Wisp.
	var knocked_toward: float = 0.0
	var defeated: bool = false


# It drifts between these, in Room x, at its home height, bobbing on the wind.
var drift_left: float = 0.0
var drift_right: float = 0.0
var home_y: float = 0.0
var drift_speed: float = 16.0
var bob_height: float = 4.0
var bob_time: float = 1.6
# How quickly it eases back to its bobbing height.
var hover_pull: float = 6.0
# How close the Player must come before it gathers a charge.
var sight: float = 32.0
var crackle_time: float = 0.7
var arc_time: float = 0.3
var rest_time: float = 0.9
var hurt_time: float = 0.35
var knockback_speed: float = 70.0
var knockback_friction: float = 240.0

var state: State = State.DRIFT
var facing: float = 1.0
var velocity: Vector2 = Vector2.ZERO
var arc_active: bool = false
var _time_left: float = 0.0
var _clock: float = 0.0


func step(frame: Frame, delta: float) -> void:
	if frame.defeated or state == State.DEFEATED:
		_enter(State.DEFEATED, 0.0)
		velocity = Vector2.ZERO
		return
	if frame.knocked_toward != 0.0:
		_enter(State.HURT, hurt_time)
		velocity = Vector2(frame.knocked_toward * knockback_speed, 0.0)
		return

	_clock += delta
	_time_left -= delta
	match state:
		State.DRIFT:
			_drift(frame)
		State.CRACKLE:
			velocity = Vector2.ZERO
			if _time_left <= 0.0:
				_enter(State.ARC, arc_time)
		State.ARC:
			velocity = Vector2.ZERO
			if _time_left <= 0.0:
				_enter(State.REST, rest_time)
		State.REST:
			velocity = Vector2(0.0, _hover(frame))
			if _time_left <= 0.0:
				_enter(State.DRIFT, 0.0)
		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
			velocity.y = _hover(frame)
			if _time_left <= 0.0:
				_enter(State.DRIFT, 0.0)


func _drift(frame: Frame) -> void:
	if frame.sees_player and frame.player_offset.length() <= sight:
		_enter(State.CRACKLE, crackle_time)
		velocity = Vector2.ZERO
		return
	if frame.position.x >= drift_right:
		facing = -1.0
	elif frame.position.x <= drift_left:
		facing = 1.0
	velocity = Vector2(facing * drift_speed, _hover(frame))


# Upward or downward speed easing it toward its bobbing height.
func _hover(frame: Frame) -> float:
	var target := home_y + bob_height * sin(TAU * _clock / bob_time)
	return (target - frame.position.y) * hover_pull


func _enter(next: State, time: float) -> void:
	state = next
	_time_left = time
	arc_active = next == State.ARC
