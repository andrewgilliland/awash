extends RefCounted

# The Pirate's rules, one frame of facts at a time: it holds its post until the Player comes into
# its notice, then rushes them with its cutlass when they are close on its level, or lobs a bomb
# at them otherwise. It never chases; between attacks it walks back to its post. Positions are
# its feet and the Player's.

enum State {
	GUARD,
	TELL,
	RUSH,
	WINDED,
	WIND_UP,
	RELOAD,
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
	# Whether there is floor just ahead of its feet, the way it faces.
	var floor_ahead: bool = true
	var defeated: bool = false


# How near the Player must come: across, and above or below its feet.
var notice_across: float = 144.0
var notice_vertical: float = 96.0
# How near and how level the Player must be for a rush rather than a bomb.
var rush_reach: float = 64.0
var level: float = 16.0
var tell_time: float = 0.4
var rush_time: float = 0.35
var rush_speed: float = 160.0
var winded_time: float = 0.7
var wind_up_time: float = 0.4
var reload_time: float = 1.0
var hurt_time: float = 0.3
var walk_speed: float = 32.0
# How far from its post still counts as at it.
var post_slack: float = 0.5
var gravity: float = 980.0
var fall_speed: float = 300.0
# What its cutlass costs the Player in a rush.
var rush_damage: int = 10

var state: State = State.GUARD
var facing: float = -1.0
var velocity: Vector2 = Vector2.ZERO
# Where it stands guard: where it first stands.
var post: Vector2 = Vector2.ZERO
# What its cutlass costs the Player now; 0 while it is not rushing.
var cutlass_damage: int = 0
# True on the frame it lets a bomb go, aimed to land on throw_target.
var threw: bool = false
var throw_target: Vector2 = Vector2.ZERO
# True on the frame it first notices the Player since they were last out of its notice.
var noticed: bool = false
var _posted: bool = false
var _alert: bool = false
var _time_left: float = 0.0


func step(frame: Frame, delta: float) -> void:
	if not _posted:
		post = frame.position
		_posted = true
	threw = false
	noticed = false
	if frame.defeated or state == State.DEFEATED:
		_enter(State.DEFEATED, 0.0)
		velocity = Vector2.ZERO
		return
	var notices := _notices(frame)
	noticed = notices and not _alert
	_alert = notices
	# Mid-rush it rushes on; anywhere else a hit flinches it.
	if frame.struck and state != State.RUSH:
		_enter(State.HURT, hurt_time)
	else:
		_time_left -= delta
		_think(frame, notices)
	_move(frame, delta)


func _think(frame: Frame, notices: bool) -> void:
	match state:
		State.GUARD:
			if notices:
				_face(frame.player_position.x - frame.position.x)
				var offset := frame.player_position - frame.position
				if absf(offset.y) <= level and absf(offset.x) <= rush_reach:
					_enter(State.TELL, tell_time)
				else:
					_enter(State.WIND_UP, wind_up_time)
		State.TELL:
			if _due():
				_enter(State.RUSH, rush_time)
		State.RUSH:
			if _due():
				_enter(State.WINDED, winded_time)
		State.WIND_UP:
			if _due():
				threw = true
				throw_target = frame.player_position
				_enter(State.RELOAD, reload_time)
		State.WINDED, State.RELOAD, State.HURT:
			if _due():
				_enter(State.GUARD, 0.0)


# Whether the time in its state has run out, allowing for a sum of frame times falling a hair short.
func _due() -> bool:
	return _time_left <= 0.001


func _notices(frame: Frame) -> bool:
	var offset := frame.player_position - frame.position
	return (
		frame.sees_player and absf(offset.x) <= notice_across and absf(offset.y) <= notice_vertical
	)


func _face(dx: float) -> void:
	if dx != 0.0:
		facing = signf(dx)


# It rushes along its facing, and on guard walks back to its post; both stop at a ledge's edge.
func _move(frame: Frame, delta: float) -> void:
	velocity.x = 0.0
	if state == State.RUSH:
		velocity.x = rush_speed * facing
	elif state == State.GUARD:
		var home := post.x - frame.position.x
		if absf(home) > post_slack:
			_face(home)
			velocity.x = walk_speed * facing
	if not frame.floor_ahead:
		velocity.x = 0.0
	velocity.y = 0.0 if frame.on_floor else minf(velocity.y + gravity * delta, fall_speed)
	cutlass_damage = rush_damage if state == State.RUSH else 0


func _enter(next: State, time: float) -> void:
	state = next
	_time_left = time
	if next != State.RUSH:
		cutlass_damage = 0
