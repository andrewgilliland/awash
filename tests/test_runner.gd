extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const BIOME_SCENE_PATH := "res://scenes/world/world_biome_01.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const RUNTIME_STATE_SCRIPT_PATH := "res://scripts/core/runtime_state.gd"
const PLAYER_STATE_ATTACK := 5
const PLAYER_STATE_RUN := 2
const PLAYER_STATE_GUARD := 7
const PLAYER_STATE_CHARGE := 8
const PLAYER_STATE_HURT := 9
const PLAYER_STATE_DEAD := 10
const ATTACK_PHASE_NONE := 0
const ATTACK_PHASE_STARTUP := 1
const ATTACK_PHASE_ACTIVE := 2
const ATTACK_PHASE_RECOVERY := 3
var _failures: int = 0


func _init() -> void:
	_run_test("Player scene loads", _test_player_scene_loads)
	_run_test("Main scene loads", _test_main_scene_loads)
	_run_test("Biome scene loads", _test_biome_scene_loads)
	_run_test("Biome room api sane", _test_biome_room_api_sane)
	_run_test("Player defaults sane", _test_player_default_values)
	_run_test("Player movement tuning sane", _test_player_movement_tuning_defaults)
	_run_test("Player run double tap activates run", _test_player_run_double_tap_activates_run)
	_run_test(
		"Player crouch and guard stop run input", _test_player_crouch_and_guard_stop_run_input
	)
	_run_test(
		"Player jump buffer and coyote timing stay wired", _test_player_jump_buffer_and_coyote
	)
	_run_test("Player coyote time allows jump", _test_player_coyote_time_allows_jump)
	_run_test("Player jump buffer fires on landing", _test_player_jump_buffer_fires_on_landing)
	_run_test(
		"Player crouch blocks run and guard blocks crouch",
		_test_player_crouch_blocks_run_and_guard_blocks_crouch
	)
	_run_test("Player melee attack windows advance correctly", _test_player_melee_attack_windows)
	_run_test("Player state machine relay stays wired", _test_player_state_machine_relay)
	_run_test("Player guard and charge sprites differ", _test_player_guard_charge_sprites_differ)
	_run_test("Player crouch sprite animates", _test_player_crouch_sprite_animates)
	_run_test("Player walk animation uses walk fps", _test_player_walk_animation_uses_walk_fps)
	_run_test("Player sprite visual is scaled down", _test_player_sprite_visual_is_scaled_down)
	_run_test(
		"Player attack animation uses larger frame size",
		_test_player_attack_animation_uses_larger_frame_size
	)
	_run_test(
		"Player guard and charge animations map correctly",
		_test_player_guard_charge_animation_mapping
	)
	_run_test("Player charge release starts attack", _test_player_charge_release_starts_attack)
	_run_test(
		"Player blocked states prevent ranged fire", _test_player_blocked_states_prevent_ranged
	)
	_run_test("Player ranged defaults sane", _test_player_ranged_defaults)
	_run_test("Player camera defaults sane", _test_player_camera_defaults)
	_run_test("Runtime state defaults sane", _test_runtime_state_defaults_sane)

	if _failures > 0:
		push_error("%d test(s) failed" % _failures)
		quit(1)
		return

	print("All tests passed")
	quit(0)


func _run_test(name: String, test_callable: Callable) -> void:
	var result = test_callable.call()
	if result:
		print("PASS: %s" % name)
	else:
		_failures += 1
		push_error("FAIL: %s" % name)


func _test_player_scene_loads() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate()
	if instance == null:
		return false

	var is_expected_type := instance is CharacterBody2D
	instance.queue_free()
	return is_expected_type


func _test_biome_scene_loads() -> bool:
	var packed_scene := load(BIOME_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate() as Node2D
	if instance == null:
		return false

	var has_background := instance.get_node_or_null("Tilemaps/BackgroundLayer") != null
	var has_ground := instance.get_node_or_null("Tilemaps/GroundLayer") != null
	var has_foreground := instance.get_node_or_null("Tilemaps/ForegroundLayer") != null
	var has_spawn := instance.get_node_or_null("Spawn") != null

	instance.queue_free()
	return has_background and has_ground and has_foreground and has_spawn


func _test_main_scene_loads() -> bool:
	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate()
	if instance == null:
		return false

	var has_player := instance.get_node_or_null("Player") != null
	var has_world := instance.get_node_or_null("WorldBiome01") != null
	instance.queue_free()
	return has_player and has_world


func _test_biome_room_api_sane() -> bool:
	var packed_scene := load(BIOME_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var biome := packed_scene.instantiate()
	if biome == null:
		return false

	var is_valid := true
	is_valid = is_valid and biome.has_method("get_room_count")
	is_valid = is_valid and biome.has_method("get_room_bounds")
	is_valid = is_valid and biome.has_method("get_adjacent_room_id")
	is_valid = is_valid and biome.has_method("get_room_spawn_position")

	if is_valid:
		var room_count := biome.call("get_room_count") as int
		var room_1_bounds := biome.call("get_room_bounds", &"room_1") as Rect2
		var room_2_id := biome.call("get_adjacent_room_id", &"room_1", 1) as StringName
		var room_1_spawn := biome.call("get_room_spawn_position", &"room_1", &"center") as Vector2

		is_valid = is_valid and room_count >= 1
		is_valid = is_valid and room_1_bounds.size.x > 0.0
		is_valid = is_valid and room_2_id != StringName("")
		is_valid = is_valid and room_1_spawn.y > 0.0

	biome.queue_free()
	return is_valid


func _test_player_default_values() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var is_valid := true
	is_valid = is_valid and player.has_method("_physics_process")
	is_valid = is_valid and player.get("move_speed") > 0.0
	is_valid = is_valid and player.get("jump_velocity") < 0.0
	is_valid = is_valid and player.get("has_double_jump") == false
	player.queue_free()
	return is_valid


func _test_player_ranged_defaults() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var is_valid := true
	is_valid = is_valid and player.get("projectile_scene") != null
	is_valid = is_valid and player.get("ranged_cooldown_seconds") > 0.0
	is_valid = is_valid and player.get("max_ranged_resource") >= 1.0
	is_valid = is_valid and player.get("ranged_cost") > 0.0
	is_valid = is_valid and player.get("ranged_regen_per_second") > 0.0
	player.queue_free()
	return is_valid


func _test_player_movement_tuning_defaults() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var run_threshold := player.get("run_state_speed_threshold") as float
	var walk_threshold := player.get("walk_state_speed_threshold") as float
	var jump_to_fall_threshold := player.get("jump_to_fall_velocity_threshold") as float
	var is_valid := true
	is_valid = is_valid and player.get("move_speed") >= 120.0
	is_valid = is_valid and player.get("acceleration") > player.get("move_speed")
	is_valid = is_valid and player.get("air_acceleration") > 0.0
	is_valid = is_valid and player.get("friction") >= player.get("acceleration")
	is_valid = is_valid and player.get("jump_release_gravity_multiplier") > 1.0
	is_valid = is_valid and player.get("crouch_action_name") == StringName("move_down")
	is_valid = is_valid and player.get("guard_action_name") == StringName("guard")
	is_valid = is_valid and player.get("walk_speed_multiplier") > 0.0
	is_valid = is_valid and player.get("walk_speed_multiplier") <= 1.0
	is_valid = is_valid and player.get("sprite_visual_scale") is Vector2
	is_valid = is_valid and (player.get("sprite_visual_scale") as Vector2).x < 1.0
	is_valid = is_valid and (player.get("sprite_visual_scale") as Vector2).y < 1.0
	is_valid = is_valid and player.get("attack_animation_frame_size") is Vector2i
	is_valid = (
		is_valid
		and (
			(player.get("attack_animation_frame_size") as Vector2i).x
			> player.get("animation_frame_size").x
		)
	)
	is_valid = (
		is_valid
		and (
			(player.get("attack_animation_frame_size") as Vector2i).y
			== player.get("animation_frame_size").y
		)
	)
	is_valid = is_valid and player.get("walk_animation_fps") > 0.0
	is_valid = is_valid and player.get("run_speed_multiplier") >= 1.0
	is_valid = is_valid and player.get("run_speed_multiplier") <= 1.5
	is_valid = is_valid and player.get("run_double_tap_window_seconds") > 0.0
	is_valid = is_valid and player.get("crouch_movement_multiplier") > 0.0
	is_valid = is_valid and player.get("crouch_movement_multiplier") < 1.0
	is_valid = is_valid and player.get("crouch_animation_fps") > 0.0
	is_valid = is_valid and player.get("guard_damage_multiplier") >= 0.0
	is_valid = is_valid and player.get("guard_damage_multiplier") <= 1.0
	is_valid = is_valid and player.get("guard_knockback_multiplier") >= 0.0
	is_valid = is_valid and player.get("guard_knockback_multiplier") <= 1.0
	is_valid = is_valid and walk_threshold > 0.0
	is_valid = is_valid and walk_threshold < run_threshold
	is_valid = is_valid and run_threshold > 0.0
	is_valid = is_valid and run_threshold < player.get("move_speed")
	is_valid = is_valid and jump_to_fall_threshold >= 0.0
	is_valid = is_valid and player.get("attack_movement_multiplier") > 0.0
	is_valid = is_valid and player.get("attack_movement_multiplier") <= 1.0
	player.queue_free()
	return is_valid


func _test_player_run_double_tap_activates_run() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var had_move_left := InputMap.has_action(&"move_left")
	var had_move_right := InputMap.has_action(&"move_right")
	if not had_move_left:
		InputMap.add_action(&"move_left")
	if not had_move_right:
		InputMap.add_action(&"move_right")

	player.set("_run_tap_timer", 0.0)
	player.set("_last_run_tap_direction", 0.0)
	player.call("_register_run_tap", 1.0)
	var after_first_tap := bool(player.get("_run_active"))
	player.set("_run_tap_timer", player.get("run_double_tap_window_seconds"))
	player.call("_register_run_tap", 1.0)
	var after_second_tap := bool(player.get("_run_active"))
	if not had_move_left:
		InputMap.erase_action(&"move_left")
	if not had_move_right:
		InputMap.erase_action(&"move_right")

	player.queue_free()
	return not after_first_tap and after_second_tap


func _test_player_crouch_and_guard_stop_run_input() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var had_crouch := InputMap.has_action(&"move_down")
	var had_guard := InputMap.has_action(&"guard")
	if not had_crouch:
		InputMap.add_action(&"move_down")
	if not had_guard:
		InputMap.add_action(&"guard")
	if not InputMap.has_action(&"move_left"):
		InputMap.add_action(&"move_left")
	if not InputMap.has_action(&"move_right"):
		InputMap.add_action(&"move_right")

	Input.action_release("move_down")
	Input.action_release("guard")
	Input.action_press("move_down")
	player.set("_run_active", true)
	player.call("_update_run_input_window", 0.0)
	var run_active_after_crouch := bool(player.get("_run_active"))

	Input.action_release("move_down")
	Input.action_press("guard")
	player.set("_run_active", true)
	player.call("_update_run_input_window", 0.0)
	var run_active_after_guard := bool(player.get("_run_active"))

	Input.action_release("guard")
	if not had_crouch:
		InputMap.erase_action(&"move_down")
	if not had_guard:
		InputMap.erase_action(&"guard")

	player.queue_free()
	return not run_active_after_crouch and not run_active_after_guard


func _test_player_jump_buffer_and_coyote() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var jump_buffer_seconds := float(player.get("jump_buffer_seconds"))
	var coyote_time_seconds := float(player.get("coyote_time_seconds"))
	var is_valid := jump_buffer_seconds > 0.0 and coyote_time_seconds > 0.0
	is_valid = is_valid and player.has_method("_try_consume_buffered_jump")
	is_valid = is_valid and player.has_method("_do_jump")

	player.queue_free()
	return is_valid


func _test_player_coyote_time_allows_jump() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	player.set("_state", 0)
	player.set("_coyote_timer", player.get("coyote_time_seconds"))
	player.set("_jump_buffer_timer", player.get("jump_buffer_seconds"))
	player.call("_try_consume_buffered_jump")

	var jump_velocity := float(player.get("jump_velocity"))
	var next_velocity_y := float(player.velocity.y)
	var helper: Object = player.get("_state_machine")
	var next_state := StringName(helper.call("get_state"))

	player.queue_free()
	return is_equal_approx(next_velocity_y, jump_velocity) and next_state == &"jump"


func _test_player_jump_buffer_fires_on_landing() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	player.set("_state", 0)
	player.set("_coyote_timer", 0.0)
	player.set("_jump_buffer_timer", player.get("jump_buffer_seconds"))

	player.call("_try_consume_buffered_jump", true)

	var jump_velocity := float(player.get("jump_velocity"))
	var next_velocity_y := float(player.velocity.y)
	var helper: Object = player.get("_state_machine")
	var next_state := StringName(helper.call("get_state"))
	var buffer_consumed := is_equal_approx(float(player.get("_jump_buffer_timer")), 0.0)

	player.queue_free()
	return (
		buffer_consumed
		and is_equal_approx(next_velocity_y, jump_velocity)
		and next_state == &"jump"
	)


func _test_player_crouch_blocks_run_and_guard_blocks_crouch() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var had_move_down := InputMap.has_action(&"move_down")
	var had_guard := InputMap.has_action(&"guard")
	if not had_move_down:
		InputMap.add_action(&"move_down")
	if not had_guard:
		InputMap.add_action(&"guard")

	Input.action_release("move_down")
	Input.action_release("guard")

	Input.action_press("move_down")
	player.set("_run_active", true)
	player.set("_state", 0)
	player.call("_update_state_from_motion", true)
	var crouch_state := int(player.get("_state"))
	var crouch_run_active := bool(player.get("_run_active"))

	Input.action_release("move_down")
	Input.action_press("guard")
	player.set("_run_active", true)
	player.set("_state", 0)
	player.call("_update_state_from_motion", true)
	var guard_state := int(player.get("_state"))
	var guard_run_active := bool(player.get("_run_active"))

	Input.action_release("guard")
	Input.action_press("move_down")
	Input.action_press("guard")
	player.set("_run_active", true)
	player.set("_state", 0)
	player.call("_update_state_from_motion", true)
	var both_state := int(player.get("_state"))

	Input.action_release("move_down")
	Input.action_release("guard")
	if not had_move_down:
		InputMap.erase_action(&"move_down")
	if not had_guard:
		InputMap.erase_action(&"guard")

	player.queue_free()
	return (
		crouch_state == 6
		and not crouch_run_active
		and guard_state == 7
		and not guard_run_active
		and both_state == 7
	)


func _test_player_melee_attack_windows() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var had_melee_attack := InputMap.has_action(&"melee_attack")
	if not had_melee_attack:
		InputMap.add_action(&"melee_attack")

	var attack_started_count := [0]
	var attack_ended_count := [0]
	player.attack_window_started.connect(func() -> void: attack_started_count[0] += 1)
	player.attack_window_ended.connect(func() -> void: attack_ended_count[0] += 1)

	Input.action_release("melee_attack")
	player.set("_state", PLAYER_STATE_CHARGE)
	player.set("_attack_phase", ATTACK_PHASE_NONE)
	player.call("_handle_attack_press")
	var combat: Object = player.get("_combat")
	combat.call("tick_attack_phase", player.get("melee_startup_seconds"))
	var active_phase := int(player.get("_attack_phase"))
	combat.call("tick_attack_phase", player.get("melee_active_seconds"))
	var recovery_phase := int(player.get("_attack_phase"))
	combat.call("tick_attack_phase", player.get("melee_recovery_seconds"))
	var finished_phase := int(player.get("_attack_phase"))

	if not had_melee_attack:
		InputMap.erase_action(&"melee_attack")

	player.queue_free()
	return (
		attack_started_count[0] == 1
		and attack_ended_count[0] == 1
		and active_phase == ATTACK_PHASE_ACTIVE
		and recovery_phase == ATTACK_PHASE_RECOVERY
		and finished_phase == ATTACK_PHASE_NONE
	)


func _test_player_state_machine_relay() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	get_root().add_child(player)
	player.call("_ready")

	var helper: Object = player.get("_state_machine")

	var relay_connected: bool = helper.state_changed.is_connected(player.state_changed.emit)
	var relay_states: Array[StringName] = [StringName(""), StringName("")]
	player.state_changed.connect(
		func(previous_state: StringName, next_state: StringName) -> void:
			relay_states[0] = previous_state
			relay_states[1] = next_state
	)

	helper.call("set_state_by_id", PLAYER_STATE_RUN)
	var helper_state := StringName(helper.call("get_state"))
	var relay_fired := relay_states[0] == &"idle" and relay_states[1] == &"run"

	player.queue_free()
	return relay_connected and helper_state == &"run" and relay_fired


func _test_player_guard_charge_sprites_differ() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var guard_index := int(player.get("guard_from_attack_frame_index"))
	var charge_index := int(player.get("charge_from_attack_frame_index"))
	var image := player.call("_create_runtime_sprite_sheet_image") as Image
	var sprite_frames := player.call("_build_default_sprite_frames", image) as SpriteFrames
	var is_valid := guard_index == 0
	is_valid = is_valid and charge_index == 5
	is_valid = is_valid and sprite_frames != null
	is_valid = is_valid and sprite_frames.has_animation(&"guard")
	is_valid = is_valid and sprite_frames.has_animation(&"charge")
	is_valid = is_valid and sprite_frames.get_frame_count(&"guard") > 0
	is_valid = is_valid and sprite_frames.get_frame_count(&"charge") > 0

	if is_valid:
		var guard_texture := sprite_frames.get_frame_texture(&"guard", 0)
		var charge_texture := sprite_frames.get_frame_texture(&"charge", 0)
		is_valid = is_valid and guard_texture != null and charge_texture != null
		is_valid = is_valid and guard_texture != charge_texture

	player.queue_free()
	return is_valid


func _test_player_crouch_sprite_animates() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var image := player.call("_create_runtime_sprite_sheet_image") as Image
	var sprite_frames := player.call("_build_default_sprite_frames", image) as SpriteFrames
	var is_valid := sprite_frames != null
	is_valid = is_valid and sprite_frames.has_animation(&"crouch")
	is_valid = is_valid and sprite_frames.get_frame_count(&"crouch") == 2
	is_valid = is_valid and not sprite_frames.get_animation_loop(&"crouch")

	if is_valid:
		var crouch_texture_0 := sprite_frames.get_frame_texture(&"crouch", 0)
		var crouch_texture_1 := sprite_frames.get_frame_texture(&"crouch", 1)
		is_valid = is_valid and crouch_texture_0 != null and crouch_texture_1 != null
		is_valid = is_valid and crouch_texture_0 != crouch_texture_1

	player.queue_free()
	return is_valid


func _test_player_walk_animation_uses_walk_fps() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var image := player.call("_create_runtime_sprite_sheet_image") as Image
	var sprite_frames := player.call("_build_default_sprite_frames", image) as SpriteFrames
	var expected_walk_fps := float(player.get("walk_animation_fps"))
	var is_valid := sprite_frames != null
	is_valid = is_valid and sprite_frames.has_animation(&"walk")
	is_valid = (
		is_valid and is_equal_approx(sprite_frames.get_animation_speed(&"walk"), expected_walk_fps)
	)

	player.queue_free()
	return is_valid


func _test_player_sprite_visual_is_scaled_down() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	player.call("_ready")

	var sprite_visual := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite_visual == null:
		player.queue_free()
		return false

	var expected_scale := player.get("sprite_visual_scale") as Vector2
	var is_valid := expected_scale.x < 1.0 and expected_scale.y < 1.0
	is_valid = is_valid and is_equal_approx(sprite_visual.scale.x, expected_scale.x)
	is_valid = is_valid and is_equal_approx(sprite_visual.scale.y, expected_scale.y)

	player.queue_free()
	return is_valid


func _test_player_attack_animation_uses_larger_frame_size() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var image := player.call("_create_runtime_sprite_sheet_image") as Image
	var sprite_frames := player.call("_build_default_sprite_frames", image) as SpriteFrames
	var expected_size := player.get("attack_animation_frame_size") as Vector2i
	var is_valid := sprite_frames != null
	is_valid = is_valid and sprite_frames.has_animation(&"attack")

	if is_valid:
		var attack_texture := sprite_frames.get_frame_texture(&"attack", 0)
		is_valid = is_valid and attack_texture != null
		is_valid = is_valid and is_equal_approx(attack_texture.get_size().x, expected_size.x)
		is_valid = is_valid and is_equal_approx(attack_texture.get_size().y, expected_size.y)

	player.queue_free()
	return is_valid


func _test_player_guard_charge_animation_mapping() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	player.set("_state", PLAYER_STATE_GUARD)
	var guard_animation := StringName(player.call("_get_desired_animation_name"))
	player.set("_state", PLAYER_STATE_CHARGE)
	var charge_animation := StringName(player.call("_get_desired_animation_name"))

	player.queue_free()
	return guard_animation == &"guard" and charge_animation == &"charge"


func _test_player_charge_release_starts_attack() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var had_melee_attack := InputMap.has_action(&"melee_attack")
	if not had_melee_attack:
		InputMap.add_action(&"melee_attack")

	Input.action_release("melee_attack")
	player.set("_state", PLAYER_STATE_CHARGE)
	player.set("_attack_phase", ATTACK_PHASE_NONE)
	player.call("_handle_attack_press")

	var next_state := int(player.get("_state"))
	var next_phase := int(player.get("_attack_phase"))

	if not had_melee_attack:
		InputMap.erase_action(&"melee_attack")

	player.queue_free()
	return next_state == PLAYER_STATE_ATTACK and next_phase == ATTACK_PHASE_STARTUP


func _test_player_blocked_states_prevent_ranged() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var blocked_states := [
		PLAYER_STATE_GUARD,
		PLAYER_STATE_CHARGE,
		PLAYER_STATE_HURT,
		PLAYER_STATE_DEAD,
	]
	var is_valid := true

	for blocked_state in blocked_states:
		player.set("_state", blocked_state)
		player.set("_ranged_resource", 2.0)
		player.set("_ranged_cooldown_timer", 0.0)
		player.call("_try_fire_projectile")
		is_valid = is_valid and is_equal_approx(player.get("_ranged_resource"), 2.0)
		is_valid = is_valid and is_equal_approx(player.get("_ranged_cooldown_timer"), 0.0)

	player.queue_free()
	return is_valid


func _test_player_camera_defaults() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var player := packed_scene.instantiate()
	if player == null:
		return false

	var room_bounds := player.get("camera_room_bounds") as Rect2
	var is_valid := true
	is_valid = is_valid and player.get("camera_drag_margin_horizontal") > 0.0
	is_valid = is_valid and player.get("camera_drag_margin_top") > 0.0
	is_valid = is_valid and player.get("camera_drag_margin_bottom") > 0.0
	is_valid = is_valid and player.get("camera_look_ahead_distance") >= 0.0
	is_valid = is_valid and player.get("camera_look_ahead_lerp_speed") > 0.0
	is_valid = is_valid and room_bounds.size.x > 0.0
	is_valid = is_valid and room_bounds.size.y > 0.0
	player.queue_free()
	return is_valid


func _test_runtime_state_defaults_sane() -> bool:
	var runtime_state_script := load(RUNTIME_STATE_SCRIPT_PATH) as GDScript
	if runtime_state_script == null:
		return false

	var runtime_state := runtime_state_script.new() as Node
	if runtime_state == null:
		return false

	var is_valid := true
	is_valid = is_valid and runtime_state.get("current_room_id") == StringName("room_1")
	is_valid = is_valid and runtime_state.call("has_visited_room", &"room_1")
	runtime_state.free()
	return is_valid
