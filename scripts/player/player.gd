extends CharacterBody2D

@export var move_speed: float = 145.0
@export var acceleration: float = 950.0
@export var air_acceleration: float = 720.0
@export var friction: float = 1100.0
@export var jump_velocity: float = -315.0
@export var max_fall_speed: float = 520.0
@export var jump_release_gravity_multiplier: float = 1.6
@export var coyote_time_seconds: float = 0.12
@export var jump_buffer_seconds: float = 0.12
@export var has_double_jump: bool = false
@export var max_air_jumps: int = 1

var _input_direction: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _air_jumps_used: int = 0
var _facing_sign: float = 1.0

@onready var _body_visual: Polygon2D = $Body


func _physics_process(delta: float) -> void:
	_apply_horizontal_movement(delta)
	_apply_vertical_movement(delta)
	_handle_jump_press()
	_try_consume_buffered_jump()
	_apply_jump_release_gravity(delta)
	_update_facing()
	move_and_slide()
	_update_visual_state(delta)


func _apply_horizontal_movement(delta: float) -> void:
	_input_direction = Input.get_axis("move_left", "move_right")
	var target_speed := _input_direction * move_speed
	var acceleration_value := acceleration if is_on_floor() else air_acceleration

	if absf(target_speed) > 0.01:
		velocity.x = move_toward(velocity.x, target_speed, acceleration_value * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _apply_vertical_movement(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time_seconds
		_air_jumps_used = 0
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
		velocity += get_gravity() * delta
		velocity.y = minf(velocity.y, max_fall_speed)

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


func _apply_jump_release_gravity(delta: float) -> void:
	if is_on_floor():
		return

	if velocity.y < 0.0 and Input.is_action_just_released("jump"):
		velocity.y += get_gravity().y * jump_release_gravity_multiplier * delta


func _update_facing() -> void:
	if absf(_input_direction) > 0.01:
		_facing_sign = signf(_input_direction)


func _update_visual_state(delta: float) -> void:
	if _body_visual == null:
		return

	var target_scale := Vector2(1.0, 1.0)
	var target_rotation := 0.0
	var target_color := Color(0.164706, 0.741176, 0.756863, 1.0)

	if not is_on_floor():
		if velocity.y < 0.0:
			target_scale = Vector2(0.92, 1.08)
			target_color = Color(0.258824, 0.792157, 0.835294, 1.0)
		else:
			target_scale = Vector2(1.08, 0.92)
			target_color = Color(0.113725, 0.631373, 0.662745, 1.0)
	elif absf(velocity.x) > 8.0:
		target_rotation = deg_to_rad(6.0) * _facing_sign
		target_color = Color(0.227451, 0.831373, 0.847059, 1.0)

	_body_visual.scale = _body_visual.scale.lerp(target_scale, 12.0 * delta)
	_body_visual.rotation = lerpf(_body_visual.rotation, target_rotation, 12.0 * delta)
	_body_visual.color = _body_visual.color.lerp(target_color, 10.0 * delta)
