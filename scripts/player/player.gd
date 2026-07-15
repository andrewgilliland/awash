extends CharacterBody2D

signal attack_window_started
signal attack_window_ended
signal melee_hit_confirmed(target: Node)
signal feedback_event_requested(event_name: String)
signal state_changed(previous_state: StringName, next_state: StringName)

enum PlayerState {
	IDLE,
	WALK,
	RUN,
	JUMP,
	FALL,
	ATTACK,
	CROUCH,
	GUARD,
	CHARGE,
	HURT,
	DEAD,
}

enum AttackPhase {
	NONE,
	STARTUP,
	ACTIVE,
	RECOVERY,
}

const PLAYER_SPRITE_SHEET := preload("res://assets/sprites/player_1.png")
const PLAYER_SPRITE_FACTORY_SCRIPT := preload("res://scripts/player/player_sprite_factory.gd")
const PLAYER_COMBAT_SCRIPT := preload("res://scripts/player/player_combat.gd")

@export var move_speed: float = 160.0
@export var acceleration: float = 1200.0
@export var air_acceleration: float = 800.0
@export var friction: float = 1400.0
@export var jump_velocity: float = -330.0
@export var max_fall_speed: float = 560.0
@export var jump_release_gravity_multiplier: float = 1.9
@export var coyote_time_seconds: float = 0.14
@export var jump_buffer_seconds: float = 0.14
@export var crouch_action_name: StringName = &"move_down"
@export var guard_action_name: StringName = &"guard"
@export var walk_speed_multiplier: float = 0.62
@export var run_speed_multiplier: float = 1.0
@export var run_double_tap_window_seconds: float = 0.22
@export var walk_state_speed_threshold: float = 6.0
@export var run_state_speed_threshold: float = 20.0
@export var jump_to_fall_velocity_threshold: float = 18.0
@export var crouch_movement_multiplier: float = 0.28
@export var crouch_animation_fps: float = 10.0
@export var guard_damage_multiplier: float = 0.35
@export var guard_knockback_multiplier: float = 0.25
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
@export var attack_movement_multiplier: float = 0.45
@export var melee_damage: int = 1
@export var melee_knockback: Vector2 = Vector2(120.0, -45.0)
@export var projectile_scene: PackedScene
@export var projectile_spawn_offset: Vector2 = Vector2(18.0, -58.0)
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
@export var animation_frame_size: Vector2i = Vector2i(128, 128)
@export var attack_animation_frame_size: Vector2i = Vector2i(192, 128)
@export var sprite_visual_offset: Vector2 = Vector2(0.0, -58.0)
@export var sprite_visual_scale: Vector2 = Vector2(0.75, 0.75)
@export var idle_animation_fps: float = 8.0
@export var walk_animation_fps: float = 8.0
@export var run_animation_fps: float = 11.0
@export var air_animation_fps: float = 8.0
@export var attack_animation_fps: float = 14.0
@export var guard_animation_fps: float = 1.0
@export var guard_from_attack_frame_index: int = 0
@export var charge_from_attack_frame_index: int = 5
@export var hurt_animation_fps: float = 10.0
@export var death_animation_fps: float = 7.0
@export var sprite_background_key_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.0, 1.0, 0.01) var sprite_background_key_tolerance: float = 0.03

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
var _attack_base_position: Vector2 = Vector2.ZERO
var _ranged_cooldown_timer: float = 0.0
var _ranged_resource: float = 0.0
var _run_active: bool = false
var _run_tap_timer: float = 0.0
var _last_run_tap_direction: float = 0.0
var _state_machine = preload("res://scripts/player/player_state_machine.gd").new()
var _sprite_factory = PLAYER_SPRITE_FACTORY_SCRIPT.new()
var _combat = PLAYER_COMBAT_SCRIPT.new()

@onready var _body_visual: Polygon2D = $Body
@onready var _sprite_visual: AnimatedSprite2D = $AnimatedSprite2D
@onready var _attack_area: Area2D = $AttackArea
@onready var _attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var _camera: Camera2D = $Camera2D


# Initializes runtime state and connects required signals.
func _ready() -> void:
	if not _state_machine.state_changed.is_connected(state_changed.emit):
		_state_machine.state_changed.connect(state_changed.emit)
	_current_health = max_health
	_ranged_resource = max_ranged_resource
	_attack_base_position = _attack_area.position
	_ensure_combat_setup()
	_setup_sprite_visual()
	_configure_camera_behavior()
	_combat.set_attack_hitbox_enabled(false)
	if not _attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		_attack_area.body_entered.connect(_on_attack_area_body_entered)
	if not _attack_area.area_entered.is_connected(_on_attack_area_area_entered):
		_attack_area.area_entered.connect(_on_attack_area_area_entered)


# Sets up sprite visual.
func _setup_sprite_visual() -> void:
	if _sprite_visual == null:
		return

	if PLAYER_SPRITE_SHEET == null:
		return

	_sprite_visual.position = sprite_visual_offset
	_sprite_visual.scale = sprite_visual_scale
	_sprite_visual.sprite_frames = _sprite_factory.build_default_sprite_frames(
		_sprite_factory_config()
	)
	_sprite_visual.animation = &"idle"
	_sprite_visual.play()

	if _body_visual != null:
		_body_visual.visible = false


# Creates runtime sprite sheet image.
func _create_runtime_sprite_sheet_image() -> Image:
	return _sprite_factory.create_runtime_sprite_sheet_image(
		PLAYER_SPRITE_SHEET, sprite_background_key_color, sprite_background_key_tolerance
	)


# Builds default sprite frames.
func _build_default_sprite_frames(image: Image) -> SpriteFrames:
	return _sprite_factory.build_default_sprite_frames_from_image(image, _sprite_factory_config())


# Returns sprite-frame factory settings from current player tuning exports.
func _sprite_factory_config() -> Dictionary:
	return {
		"sprite_sheet": PLAYER_SPRITE_SHEET,
		"animation_frame_size": animation_frame_size,
		"attack_animation_frame_size": attack_animation_frame_size,
		"sprite_background_key_color": sprite_background_key_color,
		"sprite_background_key_tolerance": sprite_background_key_tolerance,
		"sprite_visual_scale": sprite_visual_scale,
		"idle_animation_fps": idle_animation_fps,
		"walk_animation_fps": walk_animation_fps,
		"run_animation_fps": run_animation_fps,
		"air_animation_fps": air_animation_fps,
		"attack_animation_fps": attack_animation_fps,
		"crouch_animation_fps": crouch_animation_fps,
		"guard_animation_fps": guard_animation_fps,
		"guard_from_attack_frame_index": guard_from_attack_frame_index,
		"charge_from_attack_frame_index": charge_from_attack_frame_index,
		"hurt_animation_fps": hurt_animation_fps,
		"death_animation_fps": death_animation_fps,
	}


# Returns combat state-name mappings to PlayerState enum values.
func _combat_state_values() -> Dictionary:
	return {
		&"idle": PlayerState.IDLE,
		&"walk": PlayerState.WALK,
		&"run": PlayerState.RUN,
		&"jump": PlayerState.JUMP,
		&"fall": PlayerState.FALL,
		&"attack": PlayerState.ATTACK,
		&"crouch": PlayerState.CROUCH,
		&"guard": PlayerState.GUARD,
		&"charge": PlayerState.CHARGE,
		&"hurt": PlayerState.HURT,
		&"dead": PlayerState.DEAD,
	}


# Returns combat phase-name mappings to AttackPhase enum values.
func _combat_phase_values() -> Dictionary:
	return {
		&"none": AttackPhase.NONE,
		&"startup": AttackPhase.STARTUP,
		&"active": AttackPhase.ACTIVE,
		&"recovery": AttackPhase.RECOVERY,
	}


# Ensures combat setup.
func _ensure_combat_setup() -> void:
	if _combat._player != null:
		return

	_combat.setup(self, _attack_area, _attack_shape, _combat_state_values(), _combat_phase_values())


# Returns desired animation name.
func _get_desired_animation_name() -> StringName:
	var animation_name: StringName = &"idle"

	match _state:
		PlayerState.WALK:
			animation_name = &"walk"
		PlayerState.RUN:
			animation_name = &"run"
		PlayerState.JUMP:
			animation_name = &"jump_up"
		PlayerState.FALL:
			animation_name = &"jump_down"
		PlayerState.ATTACK:
			animation_name = &"attack"
		PlayerState.CROUCH:
			animation_name = &"crouch"
		PlayerState.GUARD:
			animation_name = &"guard"
		PlayerState.CHARGE:
			animation_name = &"charge"
		PlayerState.HURT:
			animation_name = &"hurt"
		PlayerState.DEAD:
			animation_name = &"death"

	return animation_name


# Runs per-frame physics updates for movement, combat, and visuals.
func _physics_process(delta: float) -> void:
	_tick_state_timers(delta)
	_update_run_input_window(delta)

	if _state == PlayerState.DEAD:
		_process_dead_state(delta)
	else:
		match _state:
			PlayerState.HURT:
				_process_hurt_state(delta)
			PlayerState.ATTACK:
				_apply_horizontal_movement(delta * attack_movement_multiplier)
			PlayerState.GUARD, PlayerState.CHARGE:
				_run_active = false
				velocity.x = move_toward(velocity.x, 0.0, friction * 1.4 * delta)
			PlayerState.CROUCH:
				_apply_horizontal_movement(delta * crouch_movement_multiplier)
			_:
				_apply_horizontal_movement(delta)

		_apply_vertical_movement(delta)
		_combat.handle_attack_press()
		if Input.is_action_just_pressed("ranged_attack"):
			_combat.try_fire_projectile()
		_combat.tick_attack_phase(delta)
		if Input.is_action_just_pressed("jump"):
			_jump_buffer_timer = jump_buffer_seconds
		_try_consume_buffered_jump()
		_apply_jump_release_gravity(delta)
		_update_facing()
		_update_camera_look_ahead(delta)

	move_and_slide()
	_update_state_from_motion()
	_update_visual_state(delta)


# Applies horizontal movement.
func _apply_horizontal_movement(delta: float) -> void:
	_input_direction = Input.get_axis("move_left", "move_right")
	var movement_multiplier := 1.0
	if is_on_floor() and _is_crouch_requested() and not _is_guard_requested():
		movement_multiplier = crouch_movement_multiplier

	var speed_multiplier := walk_speed_multiplier
	if _run_active:
		speed_multiplier = run_speed_multiplier

	var target_speed := _input_direction * move_speed * speed_multiplier * movement_multiplier

	var acceleration_value := acceleration if is_on_floor() else air_acceleration

	if absf(target_speed) > 0.01:
		velocity.x = move_toward(velocity.x, target_speed, acceleration_value * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


# Applies vertical movement.
func _apply_vertical_movement(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time_seconds
		_air_jumps_used = 0
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
		velocity += get_gravity() * delta
		velocity.y = minf(velocity.y, max_fall_speed)

	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)


# Attempts to consume buffered jump.
func _try_consume_buffered_jump(is_grounded: bool = false) -> void:
	if _jump_buffer_timer <= 0.0:
		return

	var grounded := is_grounded or is_on_floor()
	if grounded or _coyote_timer > 0.0:
		_do_jump()
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		return

	if has_double_jump and _air_jumps_used < max_air_jumps and not grounded:
		_air_jumps_used += 1
		_do_jump()
		_jump_buffer_timer = 0.0


# Applies jump velocity and transitions to jump state when allowed.
func _do_jump() -> void:
	velocity.y = jump_velocity
	if _state != PlayerState.HURT and _state != PlayerState.DEAD and _state != PlayerState.ATTACK:
		_set_state(PlayerState.JUMP)


# Returns whether crouch requested is true.
func _is_crouch_requested() -> bool:
	if crouch_action_name == StringName(""):
		return false

	if not InputMap.has_action(crouch_action_name):
		return false

	return Input.is_action_pressed(crouch_action_name)


# Returns whether guard requested is true.
func _is_guard_requested() -> bool:
	if guard_action_name != StringName("") and InputMap.has_action(guard_action_name):
		return Input.is_action_pressed(guard_action_name)

	if InputMap.has_action(&"interact"):
		return Input.is_action_pressed(&"interact")

	return false


# Registers run tap.
func _register_run_tap(direction: float) -> void:
	if direction == 0.0:
		return

	if _run_tap_timer > 0.0 and _last_run_tap_direction == direction:
		_run_active = true
		_run_tap_timer = 0.0
		return

	_last_run_tap_direction = direction
	_run_tap_timer = run_double_tap_window_seconds


# Updates run input window.
func _update_run_input_window(delta: float) -> void:
	if Input.is_action_just_pressed("move_left"):
		_register_run_tap(-1.0)
	if Input.is_action_just_pressed("move_right"):
		_register_run_tap(1.0)

	_run_tap_timer = maxf(0.0, _run_tap_timer - delta)
	if _run_tap_timer <= 0.0 and not _run_active:
		_last_run_tap_direction = 0.0

	var directional_input := Input.get_axis("move_left", "move_right")
	if absf(directional_input) <= 0.01:
		_run_active = false
		return

	var input_sign := signf(directional_input)
	if _run_active and input_sign != _last_run_tap_direction:
		_run_active = false

	if _is_crouch_requested() or _is_guard_requested():
		_run_active = false


# Applies incoming damage, guard modifiers, knockback, and death transitions.
func take_damage(amount: int = 1, knockback: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0:
		return

	if _state == PlayerState.DEAD or _invulnerable_timer > 0.0:
		return

	var applied_amount := amount
	var applied_knockback := knockback
	if _state == PlayerState.GUARD and is_on_floor():
		applied_amount = int(ceil(float(amount) * guard_damage_multiplier))
		applied_knockback = knockback * guard_knockback_multiplier
		if applied_amount <= 0:
			emit_signal("feedback_event_requested", "guard_block")
			return

	_current_health = maxi(0, _current_health - applied_amount)
	_invulnerable_timer = invulnerable_seconds

	if applied_knockback != Vector2.ZERO:
		velocity = applied_knockback

	if _current_health <= 0:
		_enter_death_state()
		return

	_hurt_timer = hurt_lock_seconds
	_set_state(PlayerState.HURT)


# Starts death-state lock timing, cancels attacks, and transitions to dead state.
func _enter_death_state() -> void:
	_death_timer = death_lock_seconds
	_combat.end_attack()
	_set_state(PlayerState.DEAD)


# Advances state timers over delta time.
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


# Processes hurt state.
func _process_hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * 0.65 * delta)
	_combat.end_attack()


# Processes dead state.
func _process_dead_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
		velocity.y = minf(velocity.y, max_fall_speed)


# Updates state from motion.
func _update_state_from_motion(is_grounded: bool = false) -> void:
	if _state == PlayerState.DEAD:
		return

	if _state == PlayerState.ATTACK and _attack_phase != AttackPhase.NONE:
		return

	if _state == PlayerState.HURT and _hurt_timer > 0.0:
		return

	var holding_charge := _state == PlayerState.CHARGE and is_on_floor()
	holding_charge = holding_charge and Input.is_action_pressed("melee_attack")
	holding_charge = holding_charge and not _is_guard_requested()
	if holding_charge:
		return

	var grounded := is_grounded or is_on_floor()
	if not grounded:
		if velocity.y <= -jump_to_fall_velocity_threshold:
			_set_state(PlayerState.JUMP)
		else:
			_set_state(PlayerState.FALL)
		return

	if _is_guard_requested() or _is_crouch_requested():
		_run_active = false
		_set_state(PlayerState.GUARD if _is_guard_requested() else PlayerState.CROUCH)
		return

	var horizontal_speed := absf(velocity.x)
	if _run_active and horizontal_speed >= run_state_speed_threshold:
		_set_state(PlayerState.RUN)
	elif horizontal_speed >= walk_state_speed_threshold:
		_set_state(PlayerState.WALK)
	elif absf(_input_direction) > 0.2 and horizontal_speed > 1.0:
		_set_state(PlayerState.WALK)
	else:
		_set_state(PlayerState.IDLE)


# Sets state.
func _set_state(next_state: PlayerState) -> void:
	if _state == next_state:
		return
	_state = next_state
	_state_machine.set_state_by_id(int(_state))


# Emits attack window started.
func _emit_attack_window_started() -> void:
	emit_signal("attack_window_started")


# Emits attack window ended.
func _emit_attack_window_ended() -> void:
	emit_signal("attack_window_ended")


# Emits melee hit confirmed.
func _emit_melee_hit_confirmed(target: Node) -> void:
	emit_signal("melee_hit_confirmed", target)


# Applies jump release gravity.
func _apply_jump_release_gravity(delta: float) -> void:
	if is_on_floor():
		return

	if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y += get_gravity().y * jump_release_gravity_multiplier * delta


# Handles attack press.
func _handle_attack_press() -> void:
	_ensure_combat_setup()
	_combat.handle_attack_press()


# Attempts to fire projectile.
func _try_fire_projectile() -> void:
	_ensure_combat_setup()
	_combat.try_fire_projectile()


# Updates facing.
func _update_facing() -> void:
	if absf(_input_direction) > 0.01:
		_facing_sign = signf(_input_direction)
	_combat.update_attack_hitbox_orientation()


# Returns ranged resource.
func get_ranged_resource() -> float:
	return _ranged_resource


# Returns ranged cooldown remaining.
func get_ranged_cooldown_remaining() -> float:
	return _ranged_cooldown_timer


# Sets camera room bounds.
func set_camera_room_bounds(bounds: Rect2) -> void:
	camera_room_bounds = bounds
	_apply_camera_room_clamps()


# Configures camera drag margins and reapplies room clamp limits.
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


# Applies camera room clamps.
func _apply_camera_room_clamps() -> void:
	if _camera == null:
		return

	var min_point := camera_room_bounds.position
	var max_point := camera_room_bounds.position + camera_room_bounds.size
	_camera.limit_left = int(round(min_point.x))
	_camera.limit_top = int(round(min_point.y))
	_camera.limit_right = int(round(max_point.x))
	_camera.limit_bottom = int(round(max_point.y))


# Updates camera look ahead.
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


# Handles attack area body entered.
func _on_attack_area_body_entered(body: Node2D) -> void:
	_combat.on_attack_area_body_entered(body)


# Handles attack area area entered.
func _on_attack_area_area_entered(area: Area2D) -> void:
	_combat.on_attack_area_area_entered(area)


# Updates visual state.
func _update_visual_state(_delta: float) -> void:
	if _sprite_visual != null and _sprite_visual.sprite_frames != null:
		var desired_animation := _get_desired_animation_name()
		var is_one_shot := (
			desired_animation == &"attack"
			or desired_animation == &"crouch"
			or desired_animation == &"hurt"
			or desired_animation == &"death"
		)

		if _sprite_visual.animation != desired_animation:
			_sprite_visual.play(desired_animation)
		elif not _sprite_visual.is_playing() and not is_one_shot:
			_sprite_visual.play(desired_animation)

		_sprite_visual.flip_h = _facing_sign < 0.0
		return

	if _body_visual != null:
		_body_visual.visible = true
