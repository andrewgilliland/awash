extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
var _failures: int = 0


func _init() -> void:
	_run_test("Player scene loads", _test_player_scene_loads)
	_run_test("Player defaults sane", _test_player_default_values)
	_run_test("Player ranged defaults sane", _test_player_ranged_defaults)
	_run_test("Player camera defaults sane", _test_player_camera_defaults)

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
