extends RefCounted

enum State {
	DRIFT,
	MANIFEST,
	LASH,
	EXPOSED,
	HURT,
	DEFEATED,
}


class Frame:
	var position: Vector2 = Vector2.ZERO
	var sees_player: bool = false
	# From the Wraith to the Player.
	var player_offset: Vector2 = Vector2.ZERO
	# Non-zero on the frame a hit lands: the direction the hit pushes the Wraith.
	var knocked_toward: float = 0.0
	var defeated: bool = false


# It drifts between these, in Room x, at its home height, bobbing.
var haunt_left: float = 0.0
var haunt_right: float = 0.0
var home_y: float = 0.0
var drift_speed: float = 12.0
var chase_speed: float = 22.0
# How far away sideways it notices the Player and drifts toward it.
var sight: float = 80.0
var bob_height: float = 2.0
var bob_time: float = 2.0
# How quickly it eases back to its bobbing height.
var hover_pull: float = 6.0
# How close the Player must come, sideways and up or down, before it manifests.
var reach: Vector2 = Vector2(24, 24)
var manifest_time: float = 0.5
var lash_time: float = 0.25
var exposed_time: float = 1.0
var hurt_time: float = 0.35
# How long it stays phased after exposing or being hurt before it can manifest again.
var rephase_time: float = 1.0
var knockback_speed: float = 60.0
var knockback_friction: float = 172.0

var state: State = State.DRIFT
var facing: float = 1.0
var velocity: Vector2 = Vector2.ZERO
# Solid from manifesting until it phases again; see-through otherwise.
var solid: bool = false
var lash_active: bool = false
# Its rune anchor shows, and only now can it be struck.
var exposed: bool = false
var _time_left: float = 0.0
var _rephase_left: float = 0.0
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
	_rephase_left -= delta
	match state:
		State.DRIFT:
			_drift(frame)
		State.MANIFEST:
			velocity = Vector2.ZERO
			if _time_left <= 0.0:
				_enter(State.LASH, lash_time)
		State.LASH:
			velocity = Vector2.ZERO
			if _time_left <= 0.0:
				_enter(State.EXPOSED, exposed_time)
		State.EXPOSED:
			velocity = Vector2.ZERO
			if _time_left <= 0.0:
				_phase()
		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
			velocity.y = _hover(frame)
			if _time_left <= 0.0:
				_phase()


func _drift(frame: Frame) -> void:
	var offset := frame.player_offset
	if (
		frame.sees_player
		and _rephase_left <= 0.0
		and absf(offset.x) <= reach.x
		and absf(offset.y) <= reach.y
	):
		if offset.x != 0.0:
			facing = signf(offset.x)
		_enter(State.MANIFEST, manifest_time)
		velocity = Vector2.ZERO
		return
	var speed := drift_speed
	if frame.sees_player and absf(offset.x) <= sight and offset.x != 0.0:
		facing = signf(offset.x)
		speed = chase_speed
		# It follows only as far as its haunt's edge.
		if (
			(facing < 0.0 and frame.position.x <= haunt_left)
			or (facing > 0.0 and frame.position.x >= haunt_right)
		):
			speed = 0.0
	elif frame.position.x >= haunt_right:
		facing = -1.0
	elif frame.position.x <= haunt_left:
		facing = 1.0
	velocity = Vector2(facing * speed, _hover(frame))


# Upward or downward speed easing it toward its bobbing height.
func _hover(frame: Frame) -> float:
	var target := home_y + bob_height * sin(TAU * _clock / bob_time)
	return (target - frame.position.y) * hover_pull


func _phase() -> void:
	_enter(State.DRIFT, 0.0)
	_rephase_left = rephase_time


func _enter(next: State, time: float) -> void:
	state = next
	_time_left = time
	solid = next in [State.MANIFEST, State.LASH, State.EXPOSED]
	lash_active = next == State.LASH
	exposed = next == State.EXPOSED
