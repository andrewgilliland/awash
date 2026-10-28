extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/rooms/waking_coast_1.tscn"
const WAKING_COAST_SAND_Y := 96.0
# Collision margins rest the Player a fraction of a pixel off the sand; falling through is far more.
const ON_SAND_TOLERANCE := 0.5
const PlayerController := preload("res://scripts/player/player_controller.gd")
const SCENARIO_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"jump", &"melee_attack", &"pause"
]
const SETTLE_FRAME_LIMIT := 120

var _failures: int = 0


func _init() -> void:
	_run_playtest("Main scene spawn stays deterministic", _playtest_main_scene_spawn)

	# Scenarios play the real main scene with input events and physics frames. The tree,
	# autoloads and input map are live only after the first frame.
	await process_frame
	await _run_scenario("Player walks right", _scenario_walks_right)
	await _run_scenario("Player jumps and lands", _scenario_jumps_and_lands)
	await _run_scenario("Player attack plays out", _scenario_attack_plays_out)
	await _run_scenario("Pause freezes and resumes play", _scenario_pause_freezes_play)
	await _run_scenario("Player walks the Waking Coast sand", _scenario_walks_waking_coast_sand)
	await _run_scenario("Player stops at the west edge", _scenario_stops_at_west_edge)

	if _failures > 0:
		push_error("%d playtest(s) failed" % _failures)
		quit(1)
		return

	print("All playtests passed")
	quit(0)


func _run_playtest(name: String, playtest_callable: Callable) -> void:
	var result = playtest_callable.call()
	if result:
		print("PASS: %s" % name)
	else:
		_failures += 1
		push_error("FAIL: %s" % name)


func _playtest_main_scene_spawn() -> bool:
	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var main_scene := packed_scene.instantiate() as Node2D
	if main_scene == null:
		return false

	main_scene.call("_ready")
	var player := main_scene.get_node_or_null("Player") as CharacterBody2D
	var entry := main_scene.get_node_or_null("Entries/start") as Marker2D
	var world_layer := main_scene.get_node_or_null("Terrain") as TileMapLayer
	var is_valid := player != null and entry != null and world_layer != null

	if is_valid:
		is_valid = is_valid and player.global_position == entry.global_position
		is_valid = is_valid and world_layer.tile_set != null
		is_valid = is_valid and world_layer.get_used_cells().size() > 0

	main_scene.free()
	return is_valid


# Plays one scenario on a fresh main scene once the Player has landed, then resets input and pause.
func _run_scenario(name: String, scenario: Callable) -> void:
	await _run_room_scenario(name, MAIN_SCENE_PATH, scenario)


# Plays one scenario on a fresh Room once the Player has landed, then resets input and pause.
func _run_room_scenario(name: String, room_path: String, scenario: Callable) -> void:
	var packed_scene := load(room_path) as PackedScene
	if packed_scene == null:
		_failures += 1
		push_error("FAIL: %s (cannot load %s)" % [name, room_path])
		return
	var main_scene := packed_scene.instantiate() as Node2D
	root.add_child(main_scene)
	var player := main_scene.get_node("Player") as CharacterBody2D
	var landed := await _frames_until(
		func() -> bool: return player.is_on_floor(), SETTLE_FRAME_LIMIT
	)
	var result: bool = landed and await scenario.call(player)
	for action in SCENARIO_ACTIONS:
		Input.action_release(action)
	paused = false
	main_scene.free()
	await process_frame

	if result:
		print("PASS: %s" % name)
	else:
		_failures += 1
		push_error("FAIL: %s" % name)


func _scenario_walks_right(player: CharacterBody2D) -> bool:
	var start := player.global_position
	_press(&"move_right")
	await _frames(30)
	var sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var controller := player.get("controller") as PlayerController
	var valid := player.global_position.x > start.x + 20.0
	valid = valid and controller.state == PlayerController.State.WALK
	valid = valid and sprite.flip_h and sprite.animation == &"walk" and sprite.is_playing()
	return valid


func _scenario_jumps_and_lands(player: CharacterBody2D) -> bool:
	var floor_y := player.global_position.y
	var controller := player.get("controller") as PlayerController
	var sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_press(&"jump")
	await _frames(1)
	_release(&"jump")
	await _frames(10)
	var valid := player.global_position.y < floor_y - 10.0 and not player.is_on_floor()
	valid = valid and controller.state == PlayerController.State.JUMP
	valid = valid and sprite.animation == &"jump"

	var landed := await _frames_until(func() -> bool: return player.is_on_floor(), 120)
	await _frames(2)
	valid = valid and landed and controller.state == PlayerController.State.IDLE
	valid = valid and sprite.animation == &"idle"
	return valid


func _scenario_attack_plays_out(player: CharacterBody2D) -> bool:
	var controller := player.get("controller") as PlayerController
	var body_sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var sword_sprite := player.get_node("SwordSprite") as AnimatedSprite2D
	_press(&"melee_attack")
	await _frames(5)
	var valid := controller.state == PlayerController.State.CHARGE and sword_sprite.visible
	_release(&"melee_attack")
	await _frames(2)
	valid = valid and controller.state == PlayerController.State.ATTACK
	valid = valid and body_sprite.animation == &"attack" and sword_sprite.animation == &"attack"

	# Only the attack animation reaching its last frame ends the Attack state.
	var idle := func() -> bool: return controller.state == PlayerController.State.IDLE
	valid = valid and await _frames_until(idle, 60)
	valid = valid and body_sprite.animation == &"idle" and not sword_sprite.visible
	return valid


func _scenario_pause_freezes_play(player: CharacterBody2D) -> bool:
	var menu_panel := player.get_parent().get_node(
		"CanvasLayer/PauseMenu/CenterContainer/MenuPanel"
	)
	_press(&"move_right")
	await _frames(10)
	await _tap(&"pause")
	var paused_x := player.global_position.x
	await _frames(20)
	var valid := paused and (menu_panel as Control).visible
	valid = valid and player.global_position.x == paused_x

	await _tap(&"pause")
	await _frames(10)
	valid = valid and not paused and not (menu_panel as Control).visible
	valid = valid and player.global_position.x > paused_x
	return valid


func _scenario_walks_waking_coast_sand(player: CharacterBody2D) -> bool:
	var valid := _is_on_sand(player)
	var start_x := player.global_position.x
	_press(&"move_right")
	await _frames(30)
	_release(&"move_right")
	await _frames(2)
	valid = valid and player.is_on_floor() and player.global_position.x > start_x + 20.0
	valid = valid and _is_on_sand(player)
	return valid


# Walking off the screen's west edge would drop the Player out of the world.
func _scenario_stops_at_west_edge(player: CharacterBody2D) -> bool:
	_press(&"move_left")
	await _frames(40)
	_release(&"move_left")
	await _frames(2)
	var valid := player.is_on_floor() and player.global_position.x >= 0.0
	valid = valid and _is_on_sand(player)
	return valid


func _is_on_sand(player: CharacterBody2D) -> bool:
	return absf(player.global_position.y - WAKING_COAST_SAND_Y) < ON_SAND_TOLERANCE


# Presses and releases an action across one frame, like a quick key tap.
func _tap(action: StringName) -> void:
	_press(action)
	await _frames(1)
	_release(action)


func _press(action: StringName) -> void:
	_send(action, true)


func _release(action: StringName) -> void:
	_send(action, false)


# The same path a key or button takes: an action event through Input to the game's handlers.
func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


# Advances physics frames until the condition holds; false if it never does within the limit.
func _frames_until(condition: Callable, limit: int) -> bool:
	for i in limit:
		await physics_frame
		if condition.call():
			return true
	return false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
