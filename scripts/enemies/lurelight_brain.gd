extends RefCounted

enum State {
	HIDDEN,
	DIM,
	SNAP,
	STRANDED,
	HURT,
	SUNK,
	DEFEATED,
}


class Frame:
	# Its place at the water's surface.
	var position: Vector2 = Vector2.ZERO
	var sees_player: bool = false
	# From the Lurelight to the Player's feet.
	var player_offset: Vector2 = Vector2.ZERO
	# True on the frame a hit lands.
	var struck: bool = false
	var defeated: bool = false


# Its pool's edges, in Room x; its body keeps half its width inside them.
var pool_left: float = 0.0
var pool_right: float = 0.0
var half_width: float = 8.0
var drift_speed: float = 16.0
# How far away, sideways and up or down, it notices the Player and drifts toward it.
var sight: Vector2 = Vector2(48, 40)
# How close sideways, and how far above or below its surface, the Player must be before it dims:
# within its jaws' reach.
var reach: Vector2 = Vector2(16, 24)
var dim_time: float = 0.6
var snap_time: float = 0.25
var stranded_time: float = 1.0
var hurt_time: float = 0.35
# How long its lure stays dark once it has sunk, before it lights again.
var dark_time: float = 1.2

var state: State = State.HIDDEN
var facing: float = 1.0
var velocity: Vector2 = Vector2.ZERO
var lure_lit: bool = true
var jaws_active: bool = false
# Lying stranded at the surface, and only now can it be struck.
var exposed: bool = false
var _time_left: float = 0.0


func step(frame: Frame, delta: float) -> void:
	velocity = Vector2.ZERO
	if frame.defeated or state == State.DEFEATED:
		_enter(State.DEFEATED, 0.0)
		return
	if frame.struck:
		_enter(State.HURT, hurt_time)
		return

	_time_left -= delta
	match state:
		State.HIDDEN:
			_lurk(frame, delta)
		State.DIM:
			if _time_left <= 0.0:
				_enter(State.SNAP, snap_time)
		State.SNAP:
			if _time_left <= 0.0:
				_enter(State.STRANDED, stranded_time)
		State.STRANDED, State.HURT:
			if _time_left <= 0.0:
				_enter(State.SUNK, dark_time)
		State.SUNK:
			if _time_left <= 0.0:
				_enter(State.HIDDEN, 0.0)


# Drifts toward a Player in sight, inside its pool, and dims once the Player is in its reach.
func _lurk(frame: Frame, delta: float) -> void:
	var offset := frame.player_offset
	if not frame.sees_player or absf(offset.x) > sight.x or absf(offset.y) > sight.y:
		return
	if offset.x != 0.0:
		facing = signf(offset.x)
	if absf(offset.x) <= reach.x and absf(offset.y) <= reach.y:
		_enter(State.DIM, dim_time)
		return
	if (
		(facing < 0.0 and frame.position.x <= pool_left + half_width)
		or (facing > 0.0 and frame.position.x >= pool_right - half_width)
	):
		return
	velocity.x = facing * minf(drift_speed, absf(offset.x) / delta)


func _enter(next: State, time: float) -> void:
	state = next
	_time_left = time
	lure_lit = next == State.HIDDEN
	jaws_active = next == State.SNAP
	exposed = next == State.STRANDED
