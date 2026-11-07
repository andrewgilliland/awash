extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const FIRST_ROOM_PATH := "res://scenes/rooms/waking_coast_1.tscn"
const START_SCREEN_PATH := "res://scenes/ui/start_screen.tscn"
const INPUT_SETUP_SCRIPT_PATH := "res://scripts/core/input_setup.gd"
const PlayerController := preload("res://scripts/player/player_controller.gd")
const STEP_DELTA := 0.1

# The test files, each giving get_tests(), in the order they run: first those that need nothing
# of the tree.
const SUITES: Array[String] = [
	"res://tests/asset_path_tests.gd",
	"res://tests/player_controller_tests.gd",
	"res://tests/player_melee_tests.gd",
	"res://tests/player_rig_tests.gd",
	"res://tests/run_state_tests.gd",
	"res://tests/main_path_pacing_tests.gd",
	"res://tests/saved_run_tests.gd",
	"res://tests/region_tile_sheets_tests.gd",
	"res://tests/tropical_island_tileset_tests.gd",
	"res://tests/waking_coast_room_tests.gd",
	"res://tests/map_layout_tests.gd",
	"res://tests/draw_world_tests.gd",
	"res://tests/world_plan_tests.gd",
	"res://tests/world_data_tests.gd",
	"res://tests/waking_coast_room_2_tests.gd",
	"res://tests/waking_coast_room_3_tests.gd",
	"res://tests/waking_coast_room_4_tests.gd",
	"res://tests/waking_coast_room_5_tests.gd",
	"res://tests/waking_coast_room_6_tests.gd",
	"res://tests/waking_coast_room_7_tests.gd",
	"res://tests/tidefen_village_room_1_tests.gd",
	"res://tests/tidefen_villager_tests.gd",
	"res://tests/waking_coast_room_9_tests.gd",
	"res://tests/waking_coast_room_10_tests.gd",
	"res://tests/waking_coast_room_11_tests.gd",
	"res://tests/waking_coast_room_12_tests.gd",
	"res://tests/waking_coast_room_13_tests.gd",
	"res://tests/undertow_region_tests.gd",
	"res://tests/tidefen_region_tests.gd",
	"res://tests/undertow_room_1_tests.gd",
	"res://tests/undertow_room_2_tests.gd",
	"res://tests/undertow_room_3_tests.gd",
	"res://tests/undertow_room_4_tests.gd",
	"res://tests/undertow_room_5_tests.gd",
	"res://tests/undertow_room_6_tests.gd",
	"res://tests/undertow_room_7_tests.gd",
	"res://tests/room_exit_tests.gd",
	"res://tests/health_tests.gd",
	"res://tests/level_tests.gd",
	"res://tests/supplies_tests.gd",
	"res://tests/equipment_tests.gd",
	"res://tests/sub_weapons_tests.gd",
	"res://tests/description_tests.gd",
	"res://tests/scavenger_brain_tests.gd",
	"res://tests/dialogue_tests.gd",
	"res://tests/player_sounds_tests.gd",
	"res://tests/scavenger_sounds_tests.gd",
	"res://tests/storm_wisp_brain_tests.gd",
	"res://tests/storm_wisp_sounds_tests.gd",
	"res://tests/wraith_brain_tests.gd",
	"res://tests/warden_brain_tests.gd",
	"res://tests/wraith_sounds_tests.gd",
	"res://tests/lurelight_brain_tests.gd",
	"res://tests/lurelight_sounds_tests.gd",
]

# Then, once nodes can join the tree, those built with its root.
const TREE_SUITES: Array[String] = [
	"res://tests/pause_menu_tests.gd",
	"res://tests/map_zoom_tests.gd",
	"res://tests/combat_scene_tests.gd",
	"res://tests/combat_feel_tests.gd",
	"res://tests/hit_feel_wiring_tests.gd",
	"res://tests/sword_beam_tests.gd",
	"res://tests/bomb_tests.gd",
	"res://tests/player_sound_scene_tests.gd",
	"res://tests/start_screen_tests.gd",
	"res://tests/start_screen_save_tests.gd",
	"res://tests/music_tests.gd",
	"res://tests/intro_tests.gd",
	"res://tests/dialogue_box_placement_tests.gd",
	"res://tests/interaction_tests.gd",
	"res://tests/villager_tests.gd",
	"res://tests/scavenger_sound_scene_tests.gd",
	"res://tests/storm_wisp_scene_tests.gd",
	"res://tests/wraith_scene_tests.gd",
	"res://tests/lurelight_scene_tests.gd",
	"res://tests/health_bar_tests.gd",
	"res://tests/sub_weapon_count_tests.gd",
	"res://tests/gold_tests.gd",
	"res://tests/shop_tests.gd",
	"res://tests/shop_panel_tests.gd",
	"res://tests/player_growth_tests.gd",
	"res://tests/enemy_experience_tests.gd",
	"res://tests/player_supplies_tests.gd",
	"res://tests/inventory_tests.gd",
	"res://tests/player_armor_tests.gd",
	"res://tests/player_weapon_tests.gd",
	"res://tests/player_bomb_tests.gd",
	"res://tests/equipment_panel_tests.gd",
	"res://tests/nameless_warden_tests.gd",
	"res://tests/wardens_gate_tests.gd",
	"res://tests/shortcut_wall_tests.gd",
	"res://tests/breakable_wall_tests.gd",
	"res://tests/cache_tests.gd",
	"res://tests/sign_tests.gd",
	"res://tests/rest_bell_tests.gd",
	"res://tests/saving_tests.gd",
	"res://tests/boss_bar_tests.gd",
]

# Last, those that check every Room in the World, built with the tree's root.
const WORLD_SUITES: Array[String] = [
	"res://tests/every_room_tests.gd",
	"res://tests/region_background_tests.gd",
]
var _failures: int = 0


func _init() -> void:
	_run_suites(SUITES)

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
	_run_suites(TREE_SUITES, root)

	_run_suites(WORLD_SUITES, root)

	if _failures > 0:
		push_error("%d test(s) failed" % _failures)
		quit(1)
		return

	print("All tests passed")
	quit(0)


# Runs every test each file gives, built with the tree's root when it is given one. A file that
# does not load counts as a failure, so a suite that stops parsing can never pass by running
# nothing.
func _run_suites(paths: Array[String], tree_root: Window = null) -> void:
	for path in paths:
		var suite := _load_suite(path, tree_root)
		if suite == null:
			_failures += 1
			push_error("FAIL: suite %s did not load; its tests did not run" % path)
			continue
		for test: Array in suite.call("get_tests"):
			_run_test(test[0], test[1])


# The suite at the path, or null when it does not parse, cannot be built or gives no tests. Its
# own function, so an error building it ends only this call and not the run of the rest.
func _load_suite(path: String, tree_root: Window) -> Object:
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		return null
	var suite: Object = script.new(tree_root) if tree_root != null else script.new()
	if suite == null or not suite.has_method("get_tests"):
		return null
	return suite


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
	# A press slashes at once.
	_step_with(controller, {"melee_held": true, "direction": 1.0})
	valid = valid and character_sprite.animation == &"attack" and sword_sprite.visible
	valid = valid and sword_sprite.animation == &"attack"
	valid = valid and character_sprite.flip_h and sword_sprite.flip_h

	character_sprite.animation_finished.emit()
	valid = valid and instance.get("_attack_finished") == true

	# Held through the slash, it goes on into the Charge.
	_step_with(controller, {"melee_held": true, "direction": 1.0, "attack_finished": true})
	valid = valid and character_sprite.animation == &"walk"
	valid = valid and sword_sprite.visible and sword_sprite.animation == &"charge"

	# Let go short of full, the Charge just ends.
	_step_with(controller, {})
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
