extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const BIOME_SCENE_PATH := "res://scenes/world/world_biome_01.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const RUNTIME_STATE_SCRIPT_PATH := "res://scripts/core/runtime_state.gd"
var _failures: int = 0


func _init() -> void:
	_run_test("Player scene loads", _test_player_scene_loads)
	_run_test("Main scene loads", _test_main_scene_loads)
	_run_test("Biome scene loads", _test_biome_scene_loads)
	_run_test("Biome room api sane", _test_biome_room_api_sane)
	_run_test("Player defaults sane", _test_player_default_values)
	_run_test("Player movement tuning sane", _test_player_movement_tuning_defaults)
	_run_test("Player guard and charge sprites differ", _test_player_guard_charge_sprites_differ)
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
	is_valid = is_valid and player.get("run_speed_multiplier") >= 1.0
	is_valid = is_valid and player.get("run_speed_multiplier") <= 1.5
	is_valid = is_valid and player.get("run_double_tap_window_seconds") > 0.0
	is_valid = is_valid and player.get("crouch_movement_multiplier") > 0.0
	is_valid = is_valid and player.get("crouch_movement_multiplier") < 1.0
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
	is_valid = is_valid and charge_index == 2
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
	return is_valid
