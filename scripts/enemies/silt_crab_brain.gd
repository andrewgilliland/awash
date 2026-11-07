extends RefCounted

# The Silt Crab's rules, one frame of facts at a time: it clings to a ceiling until the Player
# passes under it, shakes silt down, drops on them, lies stunned where it lands, then scuttles
# after them. Struck while still up, it falls harmlessly.

enum State {
	CLINGING,
	SHAKING,
	FALLING,
	STUNNED,
	SCUTTLING,
	HURT,
	DEFEATED,
}


class Frame:
	var position: Vector2 = Vector2.ZERO
	var sees_player: bool = false
	# From the Silt Crab to the Player's feet.
	var player_offset: Vector2 = Vector2.ZERO
	# True on the frame a hit lands.
	var struck: bool = false
	var on_floor: bool = false
	var defeated: bool = false


# How close sideways a Player below must come before it shakes.
var notice: float = 24.0
var shake_time: float = 0.5
var gravity: float = 980.0
var fall_speed: float = 300.0
var stun_time: float = 1.0
var hurt_time: float = 0.3
var scuttle_speed: float = 40.0
# What its claws cost the Player: dropping on them, and touching them as it scuttles.
var drop_damage: int = 15
var touch_damage: int = 10

var state: State = State.CLINGING
var facing: float = 1.0
var velocity: Vector2 = Vector2.ZERO
# What its claws cost the Player now; 0 while harmless.
var claws_damage: int = 0
var silt_falling: bool = false
var _knocked: bool = false
var _time_left: float = 0.0


func step(frame: Frame, delta: float) -> void:
	if frame.defeated or state == State.DEFEATED:
		_enter(State.DEFEATED, 0.0)
		velocity = Vector2.ZERO
		return
	if frame.struck:
		if state == State.CLINGING or state == State.SHAKING:
			_knocked = true
			_enter(State.FALLING, 0.0)
		else:
			_enter(State.HURT, hurt_time)
	else:
		_time_left -= delta
		_think(frame)
	_move(frame, delta)


func _think(frame: Frame) -> void:
	match state:
		State.CLINGING:
			if _sees_under(frame):
				_enter(State.SHAKING, shake_time)
		State.SHAKING:
			if _time_left <= 0.0:
				_enter(State.FALLING, 0.0)
		State.FALLING:
			if frame.on_floor:
				_knocked = false
				_enter(State.STUNNED, stun_time)
		State.STUNNED, State.HURT:
			if _time_left <= 0.0:
				_enter(State.SCUTTLING, 0.0)
		State.SCUTTLING:
			if frame.sees_player and frame.player_offset.x != 0.0:
				facing = signf(frame.player_offset.x)


# A Player below it, within its notice sideways.
func _sees_under(frame: Frame) -> bool:
	var offset := frame.player_offset
	return frame.sees_player and offset.y > 0.0 and absf(offset.x) <= notice


# Up on the ceiling it keeps still; down, it falls until it lands, and scuttles only scuttling.
func _move(frame: Frame, delta: float) -> void:
	if state == State.CLINGING or state == State.SHAKING:
		velocity = Vector2.ZERO
		return
	velocity.x = facing * scuttle_speed if state == State.SCUTTLING else 0.0
	if frame.on_floor and state != State.FALLING:
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + gravity * delta, fall_speed)


func _enter(next: State, time: float) -> void:
	state = next
	_time_left = time
	silt_falling = next == State.SHAKING
	match next:
		State.FALLING:
			claws_damage = 0 if _knocked else drop_damage
		State.SCUTTLING:
			claws_damage = touch_damage
		_:
			claws_damage = 0
