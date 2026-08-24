extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const PAUSE_MENU_SCENE_PATH := "res://scenes/ui/pause_menu.tscn"
const RUNTIME_STATE_SCRIPT_PATH := "res://scripts/core/runtime_state.gd"
var _failures: int = 0


func _init() -> void:
	_run_test("Player idle and walk frames load", _test_player_idle_and_walk_frames_load)
	_run_test("Player jump frames load", _test_player_jump_frames_load)
	_run_test("Player faces movement direction", _test_player_faces_movement_direction)
	_run_test("Player attack displays offset sword", _test_player_attack_displays_offset_sword)
	_run_test("Main scene loads", _test_main_scene_loads)
	_run_test("Pause menu scene loads", _test_pause_menu_scene_loads)
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


func _test_player_idle_and_walk_frames_load() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate() as CharacterBody2D
	if instance == null:
		return false

	root.add_child(instance)
	instance.call("_ready")
	var sprite := instance.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		instance.queue_free()
		return false

	var sprite_frames := sprite.sprite_frames
	var valid := sprite.animation == &"idle"
	valid = valid and sprite_frames.get_frame_count(&"idle") == 1
	valid = valid and sprite_frames.get_frame_count(&"walk") == 2
	valid = valid and _frame_region_is(sprite_frames, &"idle", 0, Rect2(0, 0, 16, 16))
	valid = valid and _frame_region_is(sprite_frames, &"walk", 0, Rect2(0, 0, 16, 16))
	valid = valid and _frame_region_is(sprite_frames, &"walk", 1, Rect2(16, 0, 16, 16))
	instance.queue_free()
	return valid


func _test_player_jump_frames_load() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate() as CharacterBody2D
	if instance == null:
		return false

	root.add_child(instance)
	instance.call("_ready")
	var sprite := instance.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var sprite_frames := sprite.sprite_frames

	var valid := sprite_frames.get_frame_count(&"jump") == 3
	valid = valid and not sprite_frames.get_animation_loop(&"jump")
	valid = valid and _frame_region_is(sprite_frames, &"jump", 0, Rect2(32, 0, 16, 16))
	valid = valid and _frame_region_is(sprite_frames, &"jump", 1, Rect2(48, 0, 16, 16))
	valid = valid and _frame_region_is(sprite_frames, &"jump", 2, Rect2(64, 0, 16, 16))
	instance.call("_set_state", 2)
	valid = valid and sprite.animation == &"jump" and sprite.is_playing()

	instance.queue_free()
	return valid


func _test_player_faces_movement_direction() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate() as CharacterBody2D
	if instance == null:
		return false

	root.add_child(instance)
	instance.call("_ready")
	var sprite := instance.get_node("AnimatedSprite2D") as AnimatedSprite2D

	instance.call("_update_facing", 1.0)
	var faces_right := sprite.flip_h

	instance.call("_update_facing", -1.0)
	var faces_left := not sprite.flip_h

	instance.queue_free()
	return faces_right and faces_left


func _test_player_attack_displays_offset_sword() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate() as CharacterBody2D
	if instance == null:
		return false

	root.add_child(instance)
	instance.call("_ready")
	var character_sprite := instance.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var sword_sprite := instance.get_node("SwordSprite") as AnimatedSprite2D
	var character_frames := character_sprite.sprite_frames
	var sword_frames := sword_sprite.sprite_frames

	var valid := character_frames.get_frame_count(&"attack") == 2
	valid = valid and sword_frames.get_frame_count(&"attack") == 2
	valid = valid and _frame_region_is(character_frames, &"attack", 0, Rect2(80, 0, 16, 16))
	valid = valid and _frame_region_is(character_frames, &"attack", 1, Rect2(96, 0, 16, 16))
	valid = valid and _frame_region_is(sword_frames, &"attack", 0, Rect2(0, 0, 16, 16))
	valid = valid and _frame_region_is(sword_frames, &"attack", 1, Rect2(16, 0, 16, 16))

	instance.call("_update_facing", 1.0)
	instance.call("_start_attack")
	valid = valid and character_sprite.animation == &"attack" and character_sprite.is_playing()
	valid = valid and sword_sprite.visible and sword_sprite.animation == &"attack"
	valid = valid and sword_sprite.is_playing() and sword_sprite.position == Vector2(12.0, -22.0)
	valid = valid and character_sprite.flip_h and sword_sprite.flip_h

	sword_sprite.frame = 1
	instance.call("_update_sword_position")
	valid = valid and sword_sprite.position == Vector2(16.0, -10.0)

	instance.call("_update_facing", -1.0)
	valid = valid and sword_sprite.position == Vector2(-16.0, -10.0)
	valid = valid and not character_sprite.flip_h and not sword_sprite.flip_h

	sword_sprite.frame = 0
	instance.call("_update_sword_position")
	valid = valid and sword_sprite.position == Vector2(-12.0, -22.0)

	instance.call("_on_character_animation_finished")
	valid = valid and not sword_sprite.visible and character_sprite.animation == &"jump"

	instance.queue_free()
	return valid


func _frame_region_is(
	sprite_frames: SpriteFrames,
	animation_name: StringName,
	frame_index: int,
	expected_region: Rect2
) -> bool:
	var frame_texture := sprite_frames.get_frame_texture(animation_name, frame_index)
	if frame_texture is not AtlasTexture:
		return false

	return (frame_texture as AtlasTexture).region == expected_region


func _test_main_scene_loads() -> bool:
	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate()
	if instance == null:
		return false

	instance.call("_ready")

	var has_player := instance.get_node_or_null("Player") != null
	var has_pause_menu := instance.get_node_or_null("CanvasLayer/PauseMenu") != null
	var has_world := _find_world_tile_layer(instance) != null
	instance.queue_free()
	return has_player and has_world and has_pause_menu


func _test_pause_menu_scene_loads() -> bool:
	var packed_scene := load(PAUSE_MENU_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate()
	if instance == null:
		return false

	var has_menu_panel := instance.get_node_or_null("CenterContainer/MenuPanel") != null
	var has_stats_button := (
		instance.get_node_or_null(
			"CenterContainer/MenuPanel/MarginContainer/VBoxContainer/MenuButtons/StatsButton"
		)
		!= null
	)
	var has_equipment_button := (
		instance.get_node_or_null(
			"CenterContainer/MenuPanel/MarginContainer/VBoxContainer/MenuButtons/EquipmentButton"
		)
		!= null
	)
	var has_map_button := (
		instance.get_node_or_null(
			"CenterContainer/MenuPanel/MarginContainer/VBoxContainer/MenuButtons/MapButton"
		)
		!= null
	)
	var has_content_root := (
		instance.get_node_or_null(
			"CenterContainer/MenuPanel/MarginContainer/VBoxContainer/ContentRoot"
		)
		!= null
	)
	var has_toggle_method := instance.has_method("toggle_pause")

	instance.queue_free()
	return (
		has_menu_panel
		and has_stats_button
		and has_equipment_button
		and has_map_button
		and has_content_root
		and has_toggle_method
	)


func _find_world_tile_layer(node: Node) -> TileMapLayer:
	for child in node.get_children():
		if child is TileMapLayer:
			return child as TileMapLayer

	return null


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
