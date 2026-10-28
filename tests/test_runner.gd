extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const PAUSE_MENU_SCENE_PATH := "res://scenes/ui/pause_menu.tscn"
const RUNTIME_STATE_SCRIPT_PATH := "res://scripts/core/runtime_state.gd"
const PlayerController := preload("res://scripts/player/player_controller.gd")
const PlayerControllerTests := preload("res://tests/player_controller_tests.gd")
const PlayerRigTests := preload("res://tests/player_rig_tests.gd")
const STEP_DELTA := 0.1
var _failures: int = 0


func _init() -> void:
	var controller_tests := PlayerControllerTests.new()
	for test in controller_tests.get_tests():
		_run_test(test[0], test[1])
	var rig_tests := PlayerRigTests.new()
	for test in rig_tests.get_tests():
		_run_test(test[0], test[1])

	_run_test("Player scene wires the rig", _test_player_scene_wires_rig)
	_run_test("Player faces movement direction", _test_player_faces_movement_direction)
	_run_test("Player sprites follow the controller", _test_player_sprites_follow_controller)
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


func _test_player_scene_wires_rig() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate() as CharacterBody2D
	if instance == null:
		return false

	root.add_child(instance)
	instance.call("_ready")
	var sprite := instance.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var sword_sprite := instance.get_node_or_null("SwordSprite") as AnimatedSprite2D
	if sprite == null or sword_sprite == null:
		instance.queue_free()
		return false

	var valid := sprite.sprite_frames != null and sword_sprite.sprite_frames != null
	valid = valid and sprite.animation == &"idle" and not sprite.flip_h
	valid = valid and not sword_sprite.visible
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
	var controller := instance.get("controller") as PlayerController

	_step_with(controller, {"direction": 1.0})
	var faces_right := sprite.flip_h

	_step_with(controller, {"direction": -1.0})
	var faces_left := not sprite.flip_h

	instance.queue_free()
	return faces_right and faces_left


func _test_player_sprites_follow_controller() -> bool:
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
	var controller := instance.get("controller") as PlayerController

	_step_with(controller, {"jump_pressed": true})
	var valid := character_sprite.animation == &"jump" and not sword_sprite.visible

	_step_with(controller, {"direction": 1.0})
	_step_with(controller, {"melee_held": true, "direction": 1.0})
	valid = valid and character_sprite.animation == &"walk"
	valid = valid and sword_sprite.visible and sword_sprite.animation == &"charge"

	_step_with(controller, {})
	valid = valid and character_sprite.animation == &"attack" and sword_sprite.visible
	valid = valid and character_sprite.flip_h and sword_sprite.flip_h

	character_sprite.animation_finished.emit()
	valid = valid and instance.get("_attack_finished") == true

	_step_with(controller, {"attack_finished": true})
	valid = valid and character_sprite.animation == &"idle" and not sword_sprite.visible

	instance.queue_free()
	return valid


# Steps the controller one frame with the given Frame fields; others keep their defaults.
func _step_with(controller: PlayerController, fields: Dictionary) -> void:
	var frame := PlayerController.Frame.new()
	frame.velocity = controller.velocity
	for field in fields:
		frame.set(field, fields[field])
	controller.step(frame, STEP_DELTA)


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
