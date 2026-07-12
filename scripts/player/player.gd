extends CharacterBody2D

signal attack_window_started
signal attack_window_ended
signal melee_hit_confirmed(target: Node)
signal feedback_event_requested(event_name: String)

enum PlayerState {
	IDLE,
	RUN,
	JUMP,
	FALL,
	ATTACK,
	HURT,
	DEAD,
}

enum AttackPhase {
	NONE,
	STARTUP,
	ACTIVE,
	RECOVERY,
}

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
@export var max_health: int = 3
@export var hurt_lock_seconds: float = 0.2
@export var invulnerable_seconds: float = 0.7
@export var death_lock_seconds: float = 0.9
@export var reload_scene_on_death: bool = false
@export var melee_startup_seconds: float = 0.06
@export var melee_active_seconds: float = 0.08
@export var melee_recovery_seconds: float = 0.16
@export var melee_damage: int = 1
@export var melee_knockback: Vector2 = Vector2(120.0, -45.0)
@export var projectile_scene: PackedScene
@export var projectile_spawn_offset: Vector2 = Vector2(18.0, -10.0)
@export var projectile_speed: float = 420.0
@export var projectile_lifetime_seconds: float = 1.1
@export var projectile_damage: int = 1
@export var projectile_knockback: Vector2 = Vector2(95.0, -25.0)
@export var ranged_cooldown_seconds: float = 0.32
@export var max_ranged_resource: float = 3.0
@export var ranged_cost: float = 1.0
@export var ranged_regen_per_second: float = 1.25
@export var camera_drag_margin_horizontal: float = 0.14
@export var camera_drag_margin_top: float = 0.2
@export var camera_drag_margin_bottom: float = 0.28
@export var camera_look_ahead_distance: float = 36.0
@export var camera_look_ahead_vertical: float = 20.0
@export var camera_look_ahead_lerp_speed: float = 8.0
@export var camera_room_bounds: Rect2 = Rect2(-232.0, 0.0, 2048.0, 270.0)

var _input_direction: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _air_jumps_used: int = 0
var _facing_sign: float = 1.0
var _current_health: int = 0
var _state: PlayerState = PlayerState.IDLE
var _hurt_timer: float = 0.0
var _invulnerable_timer: float = 0.0
var _death_timer: float = 0.0
var _attack_phase: AttackPhase = AttackPhase.NONE
var _attack_phase_timer: float = 0.0
var _attack_hit_targets: Dictionary = {}
var _attack_base_position: Vector2 = Vector2.ZERO
var _ranged_cooldown_timer: float = 0.0
var _ranged_resource: float = 0.0

@onready var _body_visual: Polygon2D = $Body
@onready var _attack_area: Area2D = $AttackArea
@onready var _attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_current_health = max_health
	_ranged_resource = max_ranged_resource
	_attack_base_position = _attack_area.position
	_configure_camera_behavior()
	_set_attack_hitbox_enabled(false)
	if not _attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		_attack_area.body_entered.connect(_on_attack_area_body_entered)
	if not _attack_area.area_entered.is_connected(_on_attack_area_area_entered):
		_attack_area.area_entered.connect(_on_attack_area_area_entered)


func _physics_process(delta: float) -> void:
	_tick_state_timers(delta)

	if _state == PlayerState.DEAD:
		_process_dead_state(delta)
	else:
		if _state == PlayerState.HURT:
			_process_hurt_state(delta)
		elif _state == PlayerState.ATTACK:
			_process_attack_state(delta)
		else:
			_apply_horizontal_movement(delta)

		_apply_vertical_movement(delta)
		_handle_attack_press()
		_handle_ranged_press()
		_tick_attack_phase(delta)
		_handle_jump_press()
		_try_consume_buffered_jump()
		_apply_jump_release_gravity(delta)
		_update_facing()
		_update_camera_look_ahead(delta)

	move_and_slide()
	_update_state_from_motion()
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
	if _state != PlayerState.HURT and _state != PlayerState.DEAD and _state != PlayerState.ATTACK:
		_set_state(PlayerState.JUMP)


func take_damage(amount: int = 1, knockback: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0:
		return

	if _state == PlayerState.DEAD or _invulnerable_timer > 0.0:
		return

	_current_health = maxi(0, _current_health - amount)
	_invulnerable_timer = invulnerable_seconds

	if knockback != Vector2.ZERO:
		velocity = knockback

	if _current_health <= 0:
		_enter_death_state()
		return

	_hurt_timer = hurt_lock_seconds
	_set_state(PlayerState.HURT)


func _enter_death_state() -> void:
	_death_timer = death_lock_seconds
	_end_attack()
	_set_state(PlayerState.DEAD)


func _tick_state_timers(delta: float) -> void:
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_invulnerable_timer = maxf(0.0, _invulnerable_timer - delta)
	_death_timer = maxf(0.0, _death_timer - delta)
	_ranged_cooldown_timer = maxf(0.0, _ranged_cooldown_timer - delta)

	if max_ranged_resource > 0.0:
		_ranged_resource = minf(
			max_ranged_resource, _ranged_resource + ranged_regen_per_second * delta
		)
	else:
		_ranged_resource = 0.0

	if _state == PlayerState.HURT and _hurt_timer <= 0.0:
		_update_state_from_motion()

	if _state == PlayerState.DEAD and _death_timer <= 0.0 and reload_scene_on_death:
		get_tree().reload_current_scene()


func _process_hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * 0.65 * delta)
	_end_attack()


func _process_attack_state(delta: float) -> void:
	_apply_horizontal_movement(delta * 0.35)


func _process_dead_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
		velocity.y = minf(velocity.y, max_fall_speed)


func _update_state_from_motion() -> void:
	if _state == PlayerState.DEAD:
		return

	if _state == PlayerState.ATTACK and _attack_phase != AttackPhase.NONE:
		return

	if _state == PlayerState.HURT and _hurt_timer > 0.0:
		return

	if not is_on_floor():
		if velocity.y < 0.0:
			_set_state(PlayerState.JUMP)
		else:
			_set_state(PlayerState.FALL)
		return

	if absf(velocity.x) > 8.0:
		_set_state(PlayerState.RUN)
	else:
		_set_state(PlayerState.IDLE)


func _set_state(next_state: PlayerState) -> void:
	if _state == next_state:
		return
	_state = next_state


func _apply_jump_release_gravity(delta: float) -> void:
	if is_on_floor():
		return

	if velocity.y < 0.0 and Input.is_action_just_released("jump"):
		velocity.y += get_gravity().y * jump_release_gravity_multiplier * delta


func _update_facing() -> void:
	if absf(_input_direction) > 0.01:
		_facing_sign = signf(_input_direction)
	_update_attack_hitbox_orientation()


func _handle_attack_press() -> void:
	if not Input.is_action_just_pressed("melee_attack"):
		return

	if _state == PlayerState.DEAD or _state == PlayerState.HURT:
		return

	if _attack_phase != AttackPhase.NONE:
		return

	_begin_attack()


func _handle_ranged_press() -> void:
	if not Input.is_action_just_pressed("ranged_attack"):
		return

	_try_fire_projectile()


func _try_fire_projectile() -> void:
	if _state == PlayerState.DEAD or _state == PlayerState.HURT:
		return

	if projectile_scene == null:
		return

	if _ranged_cooldown_timer > 0.0:
		emit_signal("feedback_event_requested", "ranged_cooldown_blocked")
		return

	if _ranged_resource < ranged_cost:
		emit_signal("feedback_event_requested", "ranged_resource_empty")
		return

	var projectile := projectile_scene.instantiate() as Node2D
	if projectile == null:
		return

	var scene_root := get_tree().current_scene
	if scene_root == null:
		projectile.queue_free()
		return

	projectile.global_position = (
		global_position
		+ Vector2(projectile_spawn_offset.x * _facing_sign, projectile_spawn_offset.y)
	)

	if projectile.has_method("initialize"):
		projectile.call("initialize", _facing_sign, self)

	_try_set_projectile_property(projectile, "speed", projectile_speed)
	_try_set_projectile_property(projectile, "lifetime_seconds", projectile_lifetime_seconds)
	_try_set_projectile_property(projectile, "damage", projectile_damage)
	_try_set_projectile_property(projectile, "knockback", projectile_knockback)

	scene_root.add_child(projectile)

	_ranged_resource = maxf(0.0, _ranged_resource - ranged_cost)
	_ranged_cooldown_timer = ranged_cooldown_seconds
	emit_signal("feedback_event_requested", "ranged_fire")


func _try_set_projectile_property(
	projectile: Object, property_name: StringName, value: Variant
) -> void:
	for property_data in projectile.get_property_list():
		if property_data.has("name") and property_data["name"] == property_name:
			projectile.set(property_name, value)
			return


func get_ranged_resource() -> float:
	return _ranged_resource


func get_ranged_cooldown_remaining() -> float:
	return _ranged_cooldown_timer


func set_camera_room_bounds(bounds: Rect2) -> void:
	camera_room_bounds = bounds
	_apply_camera_room_clamps()


func _configure_camera_behavior() -> void:
	if _camera == null:
		return

	_camera.drag_horizontal_enabled = true
	_camera.drag_vertical_enabled = true
	_camera.drag_left_margin = camera_drag_margin_horizontal
	_camera.drag_right_margin = camera_drag_margin_horizontal
	_camera.drag_top_margin = camera_drag_margin_top
	_camera.drag_bottom_margin = camera_drag_margin_bottom
	_apply_camera_room_clamps()


func _apply_camera_room_clamps() -> void:
	if _camera == null:
		return

	var min_point := camera_room_bounds.position
	var max_point := camera_room_bounds.position + camera_room_bounds.size
	_camera.limit_left = int(round(min_point.x))
	_camera.limit_top = int(round(min_point.y))
	_camera.limit_right = int(round(max_point.x))
	_camera.limit_bottom = int(round(max_point.y))


func _update_camera_look_ahead(delta: float) -> void:
	if _camera == null:
		return

	var horizontal_target := 0.0
	if absf(_input_direction) > 0.01:
		horizontal_target = _facing_sign * camera_look_ahead_distance
	elif absf(velocity.x) > 20.0:
		horizontal_target = signf(velocity.x) * (camera_look_ahead_distance * 0.5)

	var vertical_target := 0.0
	if velocity.y > 45.0:
		vertical_target = camera_look_ahead_vertical
	elif velocity.y < -45.0:
		vertical_target = -camera_look_ahead_vertical * 0.45

	_camera.offset.x = lerpf(
		_camera.offset.x, horizontal_target, camera_look_ahead_lerp_speed * delta
	)
	_camera.offset.y = lerpf(
		_camera.offset.y, vertical_target, camera_look_ahead_lerp_speed * delta
	)


func _begin_attack() -> void:
	_set_state(PlayerState.ATTACK)
	_attack_phase = AttackPhase.STARTUP
	_attack_phase_timer = melee_startup_seconds
	_attack_hit_targets.clear()
	_set_attack_hitbox_enabled(false)
	emit_signal("feedback_event_requested", "melee_startup")


func _tick_attack_phase(delta: float) -> void:
	if _attack_phase == AttackPhase.NONE:
		return

	_attack_phase_timer = maxf(0.0, _attack_phase_timer - delta)
	if _attack_phase_timer > 0.0:
		return

	if _attack_phase == AttackPhase.STARTUP:
		_attack_phase = AttackPhase.ACTIVE
		_attack_phase_timer = melee_active_seconds
		_attack_hit_targets.clear()
		_set_attack_hitbox_enabled(true)
		emit_signal("attack_window_started")
		emit_signal("feedback_event_requested", "melee_active")
		return

	if _attack_phase == AttackPhase.ACTIVE:
		_attack_phase = AttackPhase.RECOVERY
		_attack_phase_timer = melee_recovery_seconds
		_set_attack_hitbox_enabled(false)
		emit_signal("attack_window_ended")
		emit_signal("feedback_event_requested", "melee_recovery")
		return

	_end_attack()


func _end_attack() -> void:
	_attack_phase = AttackPhase.NONE
	_attack_phase_timer = 0.0
	_attack_hit_targets.clear()
	_set_attack_hitbox_enabled(false)
	if _state == PlayerState.ATTACK:
		_update_state_from_motion()


func _set_attack_hitbox_enabled(enabled: bool) -> void:
	if _attack_shape != null:
		_attack_shape.disabled = not enabled
	if _attack_area != null:
		_attack_area.monitoring = enabled


func _update_attack_hitbox_orientation() -> void:
	if _attack_area == null:
		return

	var direction := 1.0 if _facing_sign >= 0.0 else -1.0
	_attack_area.position = Vector2(_attack_base_position.x * direction, _attack_base_position.y)


func _on_attack_area_body_entered(body: Node2D) -> void:
	_register_melee_hit(body)


func _on_attack_area_area_entered(area: Area2D) -> void:
	if area == null:
		return

	if area.get_parent() != null:
		_register_melee_hit(area.get_parent())


func _register_melee_hit(target: Node) -> void:
	if target == null:
		return

	if _attack_phase != AttackPhase.ACTIVE:
		return

	if _attack_hit_targets.has(target):
		return

	_attack_hit_targets[target] = true

	if target.has_method("take_damage"):
		var knockback := Vector2(melee_knockback.x * _facing_sign, melee_knockback.y)
		target.call("take_damage", melee_damage, knockback)

	emit_signal("melee_hit_confirmed", target)
	emit_signal("feedback_event_requested", "melee_hit_confirm")


func _update_visual_state(delta: float) -> void:
	if _body_visual == null:
		return

	var target_scale := Vector2(1.0, 1.0)
	var target_rotation := 0.0
	var target_color := Color(0.164706, 0.741176, 0.756863, 1.0)

	if _state == PlayerState.DEAD:
		target_scale = Vector2(1.06, 0.88)
		target_rotation = deg_to_rad(90.0)
		target_color = Color(0.45, 0.45, 0.45, 1.0)
	elif _state == PlayerState.HURT:
		target_scale = Vector2(1.08, 0.9)
		target_color = Color(0.96, 0.45, 0.45, 1.0)
	elif _state == PlayerState.JUMP:
		target_scale = Vector2(0.92, 1.08)
		target_color = Color(0.258824, 0.792157, 0.835294, 1.0)
	elif _state == PlayerState.FALL:
		target_scale = Vector2(1.08, 0.92)
		target_color = Color(0.113725, 0.631373, 0.662745, 1.0)
	elif _state == PlayerState.ATTACK:
		target_scale = Vector2(1.06, 0.94)
		target_rotation = deg_to_rad(3.0) * _facing_sign
		target_color = Color(0.956863, 0.807843, 0.337255, 1.0)
	elif _state == PlayerState.RUN:
		target_rotation = deg_to_rad(6.0) * _facing_sign
		target_color = Color(0.227451, 0.831373, 0.847059, 1.0)

	_body_visual.scale = _body_visual.scale.lerp(target_scale, 12.0 * delta)
	_body_visual.rotation = lerpf(_body_visual.rotation, target_rotation, 12.0 * delta)
	_body_visual.color = _body_visual.color.lerp(target_color, 10.0 * delta)
