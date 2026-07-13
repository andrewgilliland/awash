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
@export var animation_frame_size: Vector2i = Vector2i(128, 128)
@export var sprite_visual_offset: Vector2 = Vector2(0.0, -58.0)
@export var idle_animation_fps: float = 8.0
@export var run_animation_fps: float = 11.0
@export var air_animation_fps: float = 8.0
@export var attack_animation_fps: float = 14.0
@export var guard_animation_fps: float = 1.0
@export var guard_from_attack_frame_index: int = 0
@export var charge_from_attack_frame_index: int = 2
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
var _attack_phase_timer: float = 0.0
var _attack_hit_targets: Dictionary = {}
var _attack_base_position: Vector2 = Vector2.ZERO
var _ranged_cooldown_timer: float = 0.0
var _ranged_resource: float = 0.0
var _run_active: bool = false
var _run_tap_timer: float = 0.0
var _last_run_tap_direction: float = 0.0
var _state_machine = preload("res://scripts/player/player_state_machine.gd").new()

@onready var _body_visual: Polygon2D = $Body
@onready var _sprite_visual: AnimatedSprite2D = $AnimatedSprite2D
@onready var _attack_area: Area2D = $AttackArea
@onready var _attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	if not _state_machine.state_changed.is_connected(state_changed.emit):
		_state_machine.state_changed.connect(state_changed.emit)
	_current_health = max_health
	_ranged_resource = max_ranged_resource
	_attack_base_position = _attack_area.position
	_setup_sprite_visual()
	_configure_camera_behavior()
	_set_attack_hitbox_enabled(false)
	if not _attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		_attack_area.body_entered.connect(_on_attack_area_body_entered)
	if not _attack_area.area_entered.is_connected(_on_attack_area_area_entered):
		_attack_area.area_entered.connect(_on_attack_area_area_entered)


func _setup_sprite_visual() -> void:
	if _sprite_visual == null:
		return

	if PLAYER_SPRITE_SHEET == null:
		return

	_sprite_visual.position = sprite_visual_offset
	_sprite_visual.sprite_frames = _build_default_sprite_frames(
		_create_runtime_sprite_sheet_image()
	)
	_sprite_visual.animation = &"idle"
	_sprite_visual.play()

	if _body_visual != null:
		_body_visual.visible = false


func _create_runtime_sprite_sheet_image() -> Image:
	var image := PLAYER_SPRITE_SHEET.get_image()
	if image == null:
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)

	image.convert(Image.FORMAT_RGBA8)

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if _is_background_pixel(pixel):
				image.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, 0.0))

	return image


func _is_background_pixel(pixel: Color) -> bool:
	if pixel.a <= 0.0:
		return false

	return (
		absf(pixel.r - sprite_background_key_color.r) <= sprite_background_key_tolerance
		and absf(pixel.g - sprite_background_key_color.g) <= sprite_background_key_tolerance
		and absf(pixel.b - sprite_background_key_color.b) <= sprite_background_key_tolerance
	)


func _build_default_sprite_frames(image: Image) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	var sheet_rows := _extract_sheet_rows(image)

	_add_animation_regions(
		sprite_frames, &"idle", _get_row_regions(sheet_rows, 0), idle_animation_fps, true, image
	)
	_add_animation_regions(
		sprite_frames, &"walk", _get_row_regions(sheet_rows, 0), run_animation_fps, true, image
	)
	_add_animation_regions(
		sprite_frames, &"run", _get_row_regions(sheet_rows, 1), run_animation_fps, true, image
	)
	_add_animation_regions(
		sprite_frames,
		&"jump_up",
		_get_regions_by_indices(sheet_rows, 2, [1, 2]),
		air_animation_fps,
		true,
		image
	)
	_add_animation_regions(
		sprite_frames,
		&"jump_down",
		_get_regions_by_indices(sheet_rows, 2, [2, 3]),
		air_animation_fps,
		true,
		image
	)
	_add_animation_regions(
		sprite_frames,
		&"attack",
		_get_row_regions(sheet_rows, 3),
		attack_animation_fps,
		false,
		image
	)
	_copy_single_frame_animation(
		sprite_frames,
		&"guard",
		&"attack",
		guard_from_attack_frame_index,
		guard_animation_fps,
		false
	)
	_copy_single_frame_animation(
		sprite_frames,
		&"charge",
		&"attack",
		charge_from_attack_frame_index,
		guard_animation_fps,
		false
	)
	_add_animation_regions(
		sprite_frames,
		&"hurt",
		_get_regions_by_indices(sheet_rows, 5, [0, 1]),
		hurt_animation_fps,
		false,
		image
	)
	_add_animation_regions(
		sprite_frames,
		&"death",
		_get_regions_by_indices(sheet_rows, 5, [4, 5]),
		death_animation_fps,
		false,
		image
	)

	_ensure_animation_exists(sprite_frames, &"jump_up", &"idle")
	_ensure_animation_exists(sprite_frames, &"jump_down", &"jump_up")
	_ensure_animation_exists(sprite_frames, &"walk", &"idle")
	_ensure_animation_exists(sprite_frames, &"attack", &"idle")
	_ensure_animation_exists(sprite_frames, &"crouch", &"idle")
	_ensure_animation_exists(sprite_frames, &"guard", &"crouch")
	_ensure_animation_exists(sprite_frames, &"charge", &"guard")
	_ensure_animation_exists(sprite_frames, &"hurt", &"idle")
	_ensure_animation_exists(sprite_frames, &"death", &"hurt")

	return sprite_frames


func _extract_sheet_rows(image: Image) -> Array:
	var row_bands: Array = []
	var band_start := -1

	for y in range(image.get_height()):
		var occupied := false
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				occupied = true
				break

		if occupied and band_start < 0:
			band_start = y
		elif not occupied and band_start >= 0:
			row_bands.append(Vector2i(band_start, y - 1))
			band_start = -1

	if band_start >= 0:
		row_bands.append(Vector2i(band_start, image.get_height() - 1))

	var sheet_rows: Array = []
	for row_band in row_bands:
		sheet_rows.append(_extract_row_regions(image, row_band.x, row_band.y))

	return sheet_rows


func _extract_row_regions(image: Image, top: int, bottom: int) -> Array:
	var column_bands: Array = []
	var band_start := -1

	for x in range(image.get_width()):
		var occupied := false
		for y in range(top, bottom + 1):
			if image.get_pixel(x, y).a > 0.0:
				occupied = true
				break

		if occupied and band_start < 0:
			band_start = x
		elif not occupied and band_start >= 0:
			column_bands.append(Vector2i(band_start, x - 1))
			band_start = -1

	if band_start >= 0:
		column_bands.append(Vector2i(band_start, image.get_width() - 1))

	var regions: Array = []
	for column_band in column_bands:
		regions.append(_trim_region(image, column_band.x, column_band.y, top, bottom))

	return regions


func _trim_region(image: Image, left: int, right: int, top: int, bottom: int) -> Rect2i:
	var min_x := right
	var min_y := bottom
	var max_x := left
	var max_y := top

	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			if image.get_pixel(x, y).a <= 0.0:
				continue

			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	return Rect2i(min_x, min_y, (max_x - min_x) + 1, (max_y - min_y) + 1)


func _get_row_regions(sheet_rows: Array, row_index: int) -> Array:
	if row_index < 0 or row_index >= sheet_rows.size():
		return []

	return sheet_rows[row_index]


func _get_regions_by_indices(sheet_rows: Array, row_index: int, indices: Array) -> Array:
	var selected_regions: Array = []
	if row_index < 0 or row_index >= sheet_rows.size():
		return selected_regions

	var row_regions: Array = sheet_rows[row_index]
	for index in indices:
		if index >= 0 and index < row_regions.size():
			selected_regions.append(row_regions[index])

	return selected_regions


func _add_animation_regions(
	sprite_frames: SpriteFrames,
	animation_name: StringName,
	regions: Array,
	fps: float,
	looped: bool,
	image: Image
) -> void:
	if regions.is_empty():
		return

	if not sprite_frames.has_animation(animation_name):
		sprite_frames.add_animation(animation_name)

	sprite_frames.set_animation_speed(animation_name, maxf(0.1, fps))
	sprite_frames.set_animation_loop(animation_name, looped)

	for region in regions:
		sprite_frames.add_frame(animation_name, _create_aligned_frame_texture(image, region))


func _ensure_animation_exists(
	sprite_frames: SpriteFrames, animation_name: StringName, fallback_name: StringName
) -> void:
	if sprite_frames.has_animation(animation_name):
		return

	if not sprite_frames.has_animation(fallback_name):
		return

	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(
		animation_name, sprite_frames.get_animation_speed(fallback_name)
	)
	sprite_frames.set_animation_loop(
		animation_name, sprite_frames.get_animation_loop(fallback_name)
	)

	for frame_index in range(sprite_frames.get_frame_count(fallback_name)):
		sprite_frames.add_frame(
			animation_name,
			sprite_frames.get_frame_texture(fallback_name, frame_index),
			sprite_frames.get_frame_duration(fallback_name, frame_index)
		)


func _copy_single_frame_animation(
	sprite_frames: SpriteFrames,
	target_animation_name: StringName,
	source_animation_name: StringName,
	source_frame_index: int,
	fps: float,
	looped: bool
) -> void:
	if not sprite_frames.has_animation(source_animation_name):
		return

	var source_count := sprite_frames.get_frame_count(source_animation_name)
	if source_count <= 0:
		return

	if sprite_frames.has_animation(target_animation_name):
		sprite_frames.remove_animation(target_animation_name)

	sprite_frames.add_animation(target_animation_name)
	sprite_frames.set_animation_speed(target_animation_name, maxf(0.1, fps))
	sprite_frames.set_animation_loop(target_animation_name, looped)

	var clamped_index := clampi(source_frame_index, 0, source_count - 1)
	sprite_frames.add_frame(
		target_animation_name,
		sprite_frames.get_frame_texture(source_animation_name, clamped_index),
		sprite_frames.get_frame_duration(source_animation_name, clamped_index)
	)


func _create_aligned_frame_texture(image: Image, region: Rect2i) -> Texture2D:
	var frame_image := Image.create(
		animation_frame_size.x, animation_frame_size.y, false, Image.FORMAT_RGBA8
	)
	frame_image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var cropped_image := image.get_region(region)
	cropped_image.convert(Image.FORMAT_RGBA8)
	var destination := Vector2i(
		maxi(0, int((animation_frame_size.x - region.size.x) / 2)),
		maxi(0, animation_frame_size.y - region.size.y)
	)
	frame_image.blit_rect(cropped_image, Rect2i(Vector2i.ZERO, region.size), destination)

	return ImageTexture.create_from_image(frame_image)


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
		_handle_attack_press()
		if Input.is_action_just_pressed("ranged_attack"):
			_try_fire_projectile()
		_tick_attack_phase(delta)
		if Input.is_action_just_pressed("jump"):
			_jump_buffer_timer = jump_buffer_seconds
		_try_consume_buffered_jump()
		_apply_jump_release_gravity(delta)
		_update_facing()
		_update_camera_look_ahead(delta)

	move_and_slide()
	_update_state_from_motion()
	_update_visual_state(delta)


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


func _apply_vertical_movement(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time_seconds
		_air_jumps_used = 0
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
		velocity += get_gravity() * delta
		velocity.y = minf(velocity.y, max_fall_speed)

	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)


func _try_consume_buffered_jump() -> void:
	if _jump_buffer_timer <= 0.0:
		return

	if is_on_floor() or _coyote_timer > 0.0:
		_do_jump()
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		return

	if has_double_jump and _air_jumps_used < max_air_jumps and not is_on_floor():
		_air_jumps_used += 1
		_do_jump()
		_jump_buffer_timer = 0.0


func _do_jump() -> void:
	velocity.y = jump_velocity
	if _state != PlayerState.HURT and _state != PlayerState.DEAD and _state != PlayerState.ATTACK:
		_set_state(PlayerState.JUMP)


func _is_crouch_requested() -> bool:
	if crouch_action_name == StringName(""):
		return false

	if not InputMap.has_action(crouch_action_name):
		return false

	return Input.is_action_pressed(crouch_action_name)


func _is_guard_requested() -> bool:
	if guard_action_name != StringName("") and InputMap.has_action(guard_action_name):
		return Input.is_action_pressed(guard_action_name)

	if InputMap.has_action(&"interact"):
		return Input.is_action_pressed(&"interact")

	return false


func _register_run_tap(direction: float) -> void:
	if direction == 0.0:
		return

	if _run_tap_timer > 0.0 and _last_run_tap_direction == direction:
		_run_active = true
		_run_tap_timer = 0.0
		return

	_last_run_tap_direction = direction
	_run_tap_timer = run_double_tap_window_seconds


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

	var holding_charge := _state == PlayerState.CHARGE and is_on_floor()
	holding_charge = holding_charge and Input.is_action_pressed("melee_attack")
	holding_charge = holding_charge and not _is_guard_requested()
	if holding_charge:
		return

	if not is_on_floor():
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


func _set_state(next_state: PlayerState) -> void:
	if _state == next_state:
		return
	_state = next_state
	_state_machine.set_state_by_id(int(_state))


func _apply_jump_release_gravity(delta: float) -> void:
	if is_on_floor():
		return

	if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y += get_gravity().y * jump_release_gravity_multiplier * delta


func _update_facing() -> void:
	if absf(_input_direction) > 0.01:
		_facing_sign = signf(_input_direction)
	_update_attack_hitbox_orientation()


func _handle_attack_press() -> void:
	if _state == PlayerState.DEAD or _state == PlayerState.HURT or _state == PlayerState.GUARD:
		return

	if _attack_phase != AttackPhase.NONE:
		return

	if Input.is_action_pressed("melee_attack"):
		if is_on_floor():
			_set_state(PlayerState.CHARGE)
		return

	if _state == PlayerState.CHARGE:
		_begin_attack()


func _try_fire_projectile() -> void:
	var blocked_state := _state == PlayerState.DEAD or _state == PlayerState.HURT
	blocked_state = blocked_state or _state == PlayerState.GUARD or _state == PlayerState.CHARGE
	if blocked_state:
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

	projectile.global_position = global_position
	projectile.global_position += Vector2(
		projectile_spawn_offset.x * _facing_sign, projectile_spawn_offset.y
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


func _update_visual_state(_delta: float) -> void:
	if _sprite_visual != null and _sprite_visual.sprite_frames != null:
		var desired_animation := _get_desired_animation_name()
		var is_one_shot := (
			desired_animation == &"attack"
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
