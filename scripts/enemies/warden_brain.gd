extends RefCounted

# What the Nameless Warden does, one step at a time. It stands dormant until the Player comes
# near, then fights in turns: a wind-up, a move, a rest. The moves alternate, a shield bash
# toward the Player, then a slam that sends a shockwave along the floor. Below half Health it
# hurries: shorter wind-ups, and two slams in a row. Its Ward is up throughout; breaking it
# staggers the Warden, and the Ward returns when the Stagger ends.

enum State {
	DORMANT,
	WINDUP,
	BASH,
	SLAM,
	REST,
	STAGGERED,
	DEFEATED,
}


class Frame:
	var sees_player: bool = false
	# From the Warden to the Player.
	var player_offset: Vector2 = Vector2.ZERO
	# The share of its Health left.
	var health_share: float = 1.0
	# True on the step a Charged Attack breaks the Ward.
	var ward_broken: bool = false
	var defeated: bool = false


# How near the Player must come, across the floor, to wake it.
var wake_distance: float = 80.0
# The beat before its next wind-up, after waking or a Stagger.
var beat_time: float = 0.6
var windup_time: float = 1.0
var hurried_windup_time: float = 0.7
var bash_time: float = 0.5
var bash_speed: float = 120.0
# How long each slam holds the Warden down.
var slam_time: float = 0.3
var rest_time: float = 1.5
var stagger_time: float = 3.0
# Below this share of Health left, it hurries.
var hurry_below: float = 0.5

# Read-only for callers.
var state: State = State.DORMANT
var facing: float = -1.0
var velocity: Vector2 = Vector2.ZERO
var warded: bool = true
var bash_active: bool = false
# Whether touching it harms the Player.
var touch_harms: bool = false
# True on the step a slam lands, sending its shockwave.
var slammed: bool = false
var _time_left: float = 0.0
var _bash_next: bool = true
var _slams_left: int = 0


func is_awake() -> bool:
	return state != State.DORMANT


func step(frame: Frame, delta: float) -> void:
	slammed = false
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
		State.STAGGERED:
			if _time_left <= 0.0:
				_enter(State.REST, beat_time)
		State.REST:
			if _time_left <= 0.0:
				_face(frame)
				var hurried := frame.health_share < hurry_below
				_enter(State.WINDUP, hurried_windup_time if hurried else windup_time)
		State.WINDUP:
			if _time_left <= 0.0:
				_start_move(frame)
		State.BASH:
			if _time_left <= 0.0:
				_enter(State.REST, rest_time)
		State.SLAM:
			if _time_left <= 0.0:
				_slams_left -= 1
				if _slams_left > 0:
					_slam()
				else:
					_enter(State.REST, rest_time)


func _start_move(frame: Frame) -> void:
	if _bash_next:
		_enter(State.BASH, bash_time)
	else:
		_slams_left = 2 if frame.health_share < hurry_below else 1
		_slam()
	_bash_next = not _bash_next


func _slam() -> void:
	_enter(State.SLAM, slam_time)
	slammed = true


func _face(frame: Frame) -> void:
	if frame.player_offset.x != 0.0:
		facing = signf(frame.player_offset.x)


func _enter(next: State, time: float) -> void:
	state = next
	_time_left = time
	bash_active = next == State.BASH
	velocity = Vector2(facing * bash_speed, 0.0) if bash_active else Vector2.ZERO
	warded = next != State.STAGGERED and next != State.DEFEATED
	touch_harms = next != State.DORMANT and warded
