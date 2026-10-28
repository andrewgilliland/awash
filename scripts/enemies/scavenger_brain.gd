extends RefCounted

enum State {
	PATROL,
	WINDUP,
	LUNGE,
	RECOVER,
	HURT,
	DEFEATED,
}


class Frame:
	var position: Vector2 = Vector2.ZERO
	var sees_player: bool = false
	# From the Scavenger to the Player.
	var player_offset: Vector2 = Vector2.ZERO
	# Non-zero on the frame a hit lands: the direction the hit pushes the Scavenger.
	var knocked_toward: float = 0.0
	var defeated: bool = false


# It walks between these, in Room x.
var patrol_left: float = 0.0
var patrol_right: float = 0.0
var patrol_speed: float = 20.0
# How close and how level the Player must be before it winds up.
var sight: Vector2 = Vector2(40.0, 20.0)
var windup_time: float = 0.45
var lunge_time: float = 0.2
var lunge_speed: float = 150.0
var recover_time: float = 0.6
var hurt_time: float = 0.35
var knockback_speed: float = 90.0
var knockback_friction: float = 300.0

var state: State = State.PATROL
var facing: float = 1.0
var velocity: Vector2 = Vector2.ZERO
var spear_active: bool = false
var _time_left: float = 0.0


func step(frame: Frame, delta: float) -> void:
	if frame.defeated or state == State.DEFEATED:
		_enter(State.DEFEATED, 0.0)
		velocity = Vector2.ZERO
		return
	if frame.knocked_toward != 0.0:
		_enter(State.HURT, hurt_time)
		velocity.x = frame.knocked_toward * knockback_speed
		facing = -frame.knocked_toward
		return

	_time_left -= delta
	match state:
		State.PATROL:
			_patrol(frame)
		State.WINDUP:
			velocity.x = 0.0
			if _time_left <= 0.0:
				_enter(State.LUNGE, lunge_time)
				velocity.x = facing * lunge_speed
		State.LUNGE:
			velocity.x = facing * lunge_speed
			if _time_left <= 0.0:
				_enter(State.RECOVER, recover_time)
				velocity.x = 0.0
		State.RECOVER:
			velocity.x = 0.0
			if _time_left <= 0.0:
				_enter(State.PATROL, 0.0)
		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
			if _time_left <= 0.0:
				_enter(State.PATROL, 0.0)


func _patrol(frame: Frame) -> void:
	var offset := frame.player_offset
	if frame.sees_player and absf(offset.x) <= sight.x and absf(offset.y) <= sight.y:
		facing = signf(offset.x) if offset.x != 0.0 else facing
		_enter(State.WINDUP, windup_time)
		velocity.x = 0.0
		return
	if frame.position.x >= patrol_right:
		facing = -1.0
	elif frame.position.x <= patrol_left:
		facing = 1.0
	velocity.x = facing * patrol_speed


func _enter(next: State, time: float) -> void:
	state = next
	_time_left = time
	spear_active = next == State.LUNGE
