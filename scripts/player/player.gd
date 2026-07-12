extends CharacterBody2D

@export var move_speed: float = 145.0
@export var acceleration: float = 950.0
@export var friction: float = 1100.0
@export var jump_velocity: float = -315.0
@export var coyote_time_seconds: float = 0.12
@export var jump_buffer_seconds: float = 0.12
@export var has_double_jump: bool = false
@export var max_air_jumps: int = 1

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _air_jumps_used: int = 0


func _physics_process(delta: float) -> void:
	_apply_horizontal_movement(delta)
	_apply_vertical_movement(delta)
	_handle_jump_press()
	_try_consume_buffered_jump()
	move_and_slide()


func _apply_horizontal_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var target_speed := direction * move_speed

	if absf(target_speed) > 0.01:
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _apply_vertical_movement(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time_seconds
		_air_jumps_used = 0
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
		velocity += get_gravity() * delta

	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)


func _handle_jump_press() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_seconds


func _try_consume_buffered_jump() -> void:
	if _jump_buffer_timer <= 0.0:
		return

	if _can_ground_or_coyote_jump():
		_do_jump()
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		return

	if has_double_jump and _air_jumps_used < max_air_jumps and not is_on_floor():
		_air_jumps_used += 1
		_do_jump()
		_jump_buffer_timer = 0.0


func _can_ground_or_coyote_jump() -> bool:
	return is_on_floor() or _coyote_timer > 0.0


func _do_jump() -> void:
	velocity.y = jump_velocity
