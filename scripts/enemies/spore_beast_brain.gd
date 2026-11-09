extends RefCounted

# The Spore Beast's rules, one frame of facts at a time: it stands until the Player comes near,
# then lumbers after them. Every hit vents a cloud of spores around it, and it stands puffed a
# moment before lumbering on; it never flinches. Its hide hurts to touch while it lives.

enum State {
	IDLE,
	LUMBERING,
	VENTING,
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


# How near the Player must come: sideways, and up or down.
var notice_across: float = 160.0
var notice_height: float = 48.0
var speed: float = 24.0
var vent_time: float = 0.4
var gravity: float = 980.0
var fall_speed: float = 300.0
# What touching it costs the Player.
var touch: int = 10

var state: State = State.IDLE
var facing: float = -1.0
var velocity: Vector2 = Vector2.ZERO
# What its hide costs the Player now; 0 once defeated.
var touch_damage: int = 10
# True only on the frame a cloud of spores bursts from it.
var vented: bool = false
var _time_left: float = 0.0


func step(frame: Frame, delta: float) -> void:
	vented = false
	if frame.defeated or state == State.DEFEATED:
		# Its last cloud bursts as it falls.
		vented = state != State.DEFEATED
		state = State.DEFEATED
		velocity = Vector2.ZERO
		touch_damage = 0
		return
	touch_damage = touch
	if frame.struck:
		vented = true
		state = State.VENTING
		_time_left = vent_time
	else:
		_time_left -= delta
		_think(frame)
	velocity.x = facing * speed if state == State.LUMBERING else 0.0
	velocity.y = 0.0 if frame.on_floor else minf(velocity.y + gravity * delta, fall_speed)


func _think(frame: Frame) -> void:
	var near := _notices(frame)
	match state:
		State.IDLE:
			if near:
				state = State.LUMBERING
		State.LUMBERING:
			if not near:
				state = State.IDLE
		State.VENTING:
			if _time_left <= 0.0:
				state = State.LUMBERING if near else State.IDLE
	if near and state == State.LUMBERING:
		var dx := frame.player_position.x - frame.position.x
		if dx != 0.0:
			facing = signf(dx)


func _notices(frame: Frame) -> bool:
	var offset := frame.player_position - frame.position
	return frame.sees_player and absf(offset.x) <= notice_across and absf(offset.y) <= notice_height
