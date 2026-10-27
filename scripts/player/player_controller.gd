extends RefCounted

signal state_changed(previous: State, next: State)
signal stepped

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


var move_speed: float = 80.0
var acceleration: float = 600.0
var friction: float = 800.0
var jump_velocity: float = -260.0

var state: State = State.IDLE
var facing: float = -1.0
var is_moving: bool = false
var velocity: Vector2 = Vector2.ZERO


# Advances one physics frame. Emits state_changed at most once, after all transitions settle,
# then stepped.
func step(frame: Frame, delta: float) -> void:
	var previous_state := state
	velocity = frame.velocity
	is_moving = frame.direction != 0.0
	var on_floor := frame.on_floor

	if state == State.ATTACK and frame.attack_finished:
		state = State.IDLE if on_floor else State.JUMP

	if state != State.ATTACK and frame.jump_pressed and on_floor:
		velocity.y = jump_velocity
		on_floor = false
		state = State.JUMP

	if state != State.ATTACK:
		if frame.melee_held:
			state = State.CHARGE
		elif state == State.CHARGE:
			state = State.ATTACK

	_update_horizontal_velocity(frame.direction, delta)
	_update_locomotion_state(frame, on_floor)

	if state != previous_state:
		state_changed.emit(previous_state, state)
	stepped.emit()


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
