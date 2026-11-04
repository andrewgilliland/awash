extends RefCounted

signal state_changed(previous: State, next: State)
signal stepped
# The jump impulse was applied this step: a real jump, not walking off a ledge.
signal jumped

enum State {
	IDLE,
	WALK,
	JUMP,
	CHARGE,
	ATTACK,
}


class Frame:
	var direction: float = 0.0
	var jump_pressed: bool = false
	var melee_held: bool = false
	var on_floor: bool = true
	var attack_finished: bool = false
	var velocity: Vector2 = Vector2.ZERO
	# Non-zero on the frame a hit lands: the velocity the hit throws the Player at.
	var knockback: Vector2 = Vector2.ZERO


var move_speed: float = 80.0
var acceleration: float = 600.0
var friction: float = 800.0
var jump_velocity: float = -260.0
# How long a hit takes control away.
var stun_time: float = 0.3
# How long melee must be held, from the press, for a full Charge.
var charge_time: float = 0.5

var state: State = State.IDLE
var facing: float = -1.0
var is_moving: bool = false
var velocity: Vector2 = Vector2.ZERO
# Whether the current or last Attack was let go from a full Charge: the one that looses a Sword
# Beam.
var charged_attack: bool = false
# How long the Player has been in its current state; while state_changed is emitted, how
# long it was in the state it just left.
var time_in_state: float = 0.0
var _stun_left: float = 0.0
# How long melee has been held since it was pressed.
var _melee_held_for: float = 0.0
var _melee_was_held: bool = false


# Advances one physics frame. Emits state_changed at most once, after all transitions settle,
# then stepped.
func step(frame: Frame, delta: float) -> void:
	var previous_state := state
	velocity = frame.velocity

	if frame.knockback != Vector2.ZERO:
		velocity = frame.knockback
		_stun_left = stun_time
	if _stun_left > 0.0:
		# Tumbling: the hit's velocity carries the Player, a charge or attack is lost, and
		# input is ignored.
		_stun_left -= delta
		is_moving = false
		state = State.JUMP
		_melee_held_for = 0.0
		_melee_was_held = frame.melee_held
	else:
		_step_in_control(frame, delta)

	if state != previous_state:
		state_changed.emit(previous_state, state)
		time_in_state = 0.0
	else:
		time_in_state += delta
	stepped.emit()


func _step_in_control(frame: Frame, delta: float) -> void:
	is_moving = frame.direction != 0.0
	var on_floor := frame.on_floor

	var was_full := is_fully_charged()
	var pressed := frame.melee_held and not _melee_was_held
	_melee_was_held = frame.melee_held
	_melee_held_for = _melee_held_for + delta if frame.melee_held else 0.0

	if state == State.ATTACK and frame.attack_finished:
		# Melee held through the swing goes on into the Charge.
		if frame.melee_held:
			state = State.CHARGE
		else:
			state = State.IDLE if on_floor else State.JUMP

	if state != State.ATTACK and frame.jump_pressed and on_floor:
		velocity.y = jump_velocity
		jumped.emit()
		on_floor = false
		if state != State.CHARGE:
			state = State.JUMP

	if state == State.CHARGE and not frame.melee_held:
		# Let go: a full Charge swings a charged Attack; short of full, the Charge just ends.
		if was_full:
			charged_attack = true
			state = State.ATTACK
		else:
			state = State.IDLE
	elif pressed and state != State.ATTACK and state != State.CHARGE:
		# A press slashes at once.
		charged_attack = false
		state = State.ATTACK

	_update_horizontal_velocity(frame.direction, delta)
	_update_locomotion_state(frame, on_floor)


# Melee has been held long enough that letting go makes a charged Attack.
func is_fully_charged() -> bool:
	return state == State.CHARGE and _melee_held_for >= charge_time - 0.0001


func _update_horizontal_velocity(direction: float, delta: float) -> void:
	if state == State.ATTACK or direction == 0.0:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return

	velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * delta)
	if state != State.CHARGE:
		facing = signf(direction)


func _update_locomotion_state(frame: Frame, on_floor: bool) -> void:
	if state == State.ATTACK or (state == State.CHARGE and frame.melee_held):
		return

	if not on_floor:
		state = State.JUMP
	elif frame.direction != 0.0:
		state = State.WALK
	else:
		state = State.IDLE
