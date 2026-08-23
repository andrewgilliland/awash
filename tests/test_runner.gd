extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const PAUSE_MENU_SCENE_PATH := "res://scenes/ui/pause_menu.tscn"
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
