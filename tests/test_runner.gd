extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const FIRST_ROOM_PATH := "res://scenes/rooms/waking_coast_1.tscn"
const START_SCREEN_PATH := "res://scenes/ui/start_screen.tscn"
const INPUT_SETUP_SCRIPT_PATH := "res://scripts/core/input_setup.gd"
const PlayerController := preload("res://scripts/player/player_controller.gd")
const PlayerControllerTests := preload("res://tests/player_controller_tests.gd")
const PlayerRigTests := preload("res://tests/player_rig_tests.gd")
const RunStateTests := preload("res://tests/run_state_tests.gd")
const PauseMenuTests := preload("res://tests/pause_menu_tests.gd")
const WakingCoastTilesetTests := preload("res://tests/waking_coast_tileset_tests.gd")
const WakingCoastRoomTests := preload("res://tests/waking_coast_room_tests.gd")
const WorldMapTests := preload("res://tests/world_map_tests.gd")
const WakingCoastRoom2Tests := preload("res://tests/waking_coast_room_2_tests.gd")
const RoomExitTests := preload("res://tests/room_exit_tests.gd")
const HealthTests := preload("res://tests/health_tests.gd")
const ScavengerBrainTests := preload("res://tests/scavenger_brain_tests.gd")
const CombatSceneTests := preload("res://tests/combat_scene_tests.gd")
const PlayerSoundsTests := preload("res://tests/player_sounds_tests.gd")
const PlayerSoundSceneTests := preload("res://tests/player_sound_scene_tests.gd")
const StartScreenTests := preload("res://tests/start_screen_tests.gd")
const ScavengerSoundsTests := preload("res://tests/scavenger_sounds_tests.gd")
const ScavengerSoundSceneTests := preload("res://tests/scavenger_sound_scene_tests.gd")
const STEP_DELTA := 0.1
var _failures: int = 0


func _init() -> void:
	var controller_tests := PlayerControllerTests.new()
	for test in controller_tests.get_tests():
		_run_test(test[0], test[1])
	var rig_tests := PlayerRigTests.new()
	for test in rig_tests.get_tests():
		_run_test(test[0], test[1])
	var run_state_tests := RunStateTests.new()
	for test in run_state_tests.get_tests():
		_run_test(test[0], test[1])
	var tileset_tests := WakingCoastTilesetTests.new()
	for test in tileset_tests.get_tests():
		_run_test(test[0], test[1])
	var room_tests := WakingCoastRoomTests.new()
	for test in room_tests.get_tests():
		_run_test(test[0], test[1])
	var world_map_tests := WorldMapTests.new()
	for test in world_map_tests.get_tests():
		_run_test(test[0], test[1])
	var room_2_tests := WakingCoastRoom2Tests.new()
	for test in room_2_tests.get_tests():
		_run_test(test[0], test[1])
	var room_exit_tests := RoomExitTests.new()
	for test in room_exit_tests.get_tests():
		_run_test(test[0], test[1])
	var health_tests := HealthTests.new()
	for test in health_tests.get_tests():
		_run_test(test[0], test[1])
	var scavenger_brain_tests := ScavengerBrainTests.new()
	for test in scavenger_brain_tests.get_tests():
		_run_test(test[0], test[1])
	var player_sounds_tests := PlayerSoundsTests.new()
	for test in player_sounds_tests.get_tests():
		_run_test(test[0], test[1])
	var scavenger_sounds_tests := ScavengerSoundsTests.new()
	for test in scavenger_sounds_tests.get_tests():
		_run_test(test[0], test[1])

	_run_test("Player scene wires the rig", _test_player_scene_wires_rig)
	_run_test("Player faces movement direction", _test_player_faces_movement_direction)
	_run_test("Player sprites follow the controller", _test_player_sprites_follow_controller)
	_run_test("Player body reads attack finished once", _test_player_reads_attack_finished_once)
	_run_test("Player sprite stands on its feet", _test_player_sprite_stands_on_feet)
	_run_test("Game starts at the start screen", _test_game_starts_at_start_screen)
	_run_test("First Room loads", _test_first_room_loads)
	_run_test("Player appears at the Run's Entry", _test_player_appears_at_entry)

	# Nodes join the tree only after the first frame; the Pause menu needs get_tree().
	await process_frame
	var pause_menu_tests := PauseMenuTests.new(root)
	for test in pause_menu_tests.get_tests():
		_run_test(test[0], test[1])
	var combat_scene_tests := CombatSceneTests.new(root)
	for test in combat_scene_tests.get_tests():
		_run_test(test[0], test[1])
	var player_sound_scene_tests := PlayerSoundSceneTests.new(root)
	for test in player_sound_scene_tests.get_tests():
		_run_test(test[0], test[1])
	var start_screen_tests := StartScreenTests.new(root)
	for test in start_screen_tests.get_tests():
		_run_test(test[0], test[1])
	var scavenger_sound_scene_tests := ScavengerSoundSceneTests.new(root)
	for test in scavenger_sound_scene_tests.get_tests():
		_run_test(test[0], test[1])

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


func _test_player_reads_attack_finished_once() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate() as CharacterBody2D
	if instance == null:
		return false

	# Autoloads do not run under --script, so register the input actions _read_frame reads.
	var input_setup := (load(INPUT_SETUP_SCRIPT_PATH) as GDScript).new() as Node
	input_setup.call("_register_inputs")
	input_setup.free()

	root.add_child(instance)
	instance.call("_ready")
	var character_sprite := instance.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var controller := instance.get("controller") as PlayerController

	_step_with(controller, {"melee_held": true})
	_step_with(controller, {})
	character_sprite.animation_finished.emit()
	var first := instance.call("_read_frame") as PlayerController.Frame
	var second := instance.call("_read_frame") as PlayerController.Frame

	instance.queue_free()
	return first.attack_finished and not second.attack_finished


# Steps the controller one frame with the given Frame fields; others keep their defaults.
func _step_with(controller: PlayerController, fields: Dictionary) -> void:
	var frame := PlayerController.Frame.new()
	frame.velocity = controller.velocity
	for field in fields:
		frame.set(field, fields[field])
	controller.step(frame, STEP_DELTA)


# The body frames draw the feet on their bottom row, so that row must meet the collision's base.
func _test_player_sprite_stands_on_feet() -> bool:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate() as CharacterBody2D
	root.add_child(instance)
	instance.call("_ready")
	var sprite := instance.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var collision := instance.get_node("CollisionShape2D") as CollisionShape2D
	var capsule := collision.shape as CapsuleShape2D
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var sprite_bottom := sprite.position.y + sprite.offset.y + texture.get_height()
	if sprite.centered:
		sprite_bottom -= texture.get_height() / 2.0
	var collision_bottom := collision.position.y + capsule.height / 2.0
	instance.queue_free()
	return is_equal_approx(sprite_bottom, collision_bottom)


func _test_game_starts_at_start_screen() -> bool:
	return ProjectSettings.get_setting("application/run/main_scene") == START_SCREEN_PATH


func _test_first_room_loads() -> bool:
	var packed_scene := load(FIRST_ROOM_PATH) as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate()
	if instance == null:
		return false

	instance.call("_ready")

	var has_player := instance.get_node_or_null("Player") != null
	var has_pause_menu := instance.get_node_or_null("CanvasLayer/PauseMenu") != null
	var has_world := instance.get_node_or_null("Terrain") is TileMapLayer
	instance.queue_free()
	return has_player and has_world and has_pause_menu


func _test_player_appears_at_entry() -> bool:
	var packed_scene := load(FIRST_ROOM_PATH) as PackedScene
	if packed_scene == null:
		return false

	var main_scene := packed_scene.instantiate() as Node2D
	var player := main_scene.get_node_or_null("Player") as CharacterBody2D
	var entry := main_scene.get_node_or_null("Entries/start") as Marker2D
	if player == null or entry == null:
		main_scene.free()
		return false

	# Moved off the Entry first, so only main.gd placing the Player can pass this.
	player.position = entry.position + Vector2(100.0, 100.0)
	root.add_child(main_scene)
	main_scene.call("_ready")
	var valid := player.global_position == entry.global_position
	main_scene.queue_free()
	return valid
