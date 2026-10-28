extends SceneTree

const FIRST_ROOM_PATH := "res://scenes/rooms/waking_coast_1.tscn"
const START_SCREEN_PATH := "res://scenes/ui/start_screen.tscn"
const RUNE_SHORE_PATH := "res://scenes/rooms/waking_coast_2.tscn"
const CLIFF_TOP_Y := 64.0
const TRANSITION_FRAME_LIMIT := 180
const WAKING_COAST_SAND_Y := 96.0
# Collision margins rest the Player a fraction of a pixel off the sand; falling through is far more.
const ON_SAND_TOLERANCE := 0.5
const PlayerController := preload("res://scripts/player/player_controller.gd")
const SCENARIO_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"jump", &"melee_attack", &"pause", &"ui_accept"
]
const SETTLE_FRAME_LIMIT := 120
# The sand at the tidal pool's west edge, where the Scavenger can reach and be reached.
const POOL_EDGE := Vector2(122, 96)
const SCAVENGER_PATH := "Enemies/Scavenger"
const MAX_SWINGS := 8

var _failures: int = 0


func _init() -> void:
	_run_playtest("First Room spawn stays deterministic", _playtest_first_room_spawn)

	# Scenarios play the real main scene with input events and physics frames. The tree,
	# autoloads and input map are live only after the first frame.
	await process_frame
	await _run_scenario("Player walks right", _scenario_walks_right)
	await _run_scenario("Player jumps and lands", _scenario_jumps_and_lands)
	await _run_scenario("Player attack plays out", _scenario_attack_plays_out)
	await _run_scenario("Pause freezes and resumes play", _scenario_pause_freezes_play)
	await _run_scenario("Player walks the Waking Coast sand", _scenario_walks_waking_coast_sand)
	await _run_scenario("Player stops at the west edge", _scenario_stops_at_west_edge)
	await _run_playtest_async("Player walks between the Waking Coast Rooms", _playtest_walks_rooms)
	await _run_playtest_async("Sword defeats the Scavenger", _playtest_sword_defeats_scavenger)
	await _run_playtest_async("Scavenger's lunge hurts the Player", _playtest_lunge_hurts_player)
	await _run_playtest_async("Player defeat starts the Run over", _playtest_defeat_starts_over)
	await _run_playtest_async(
		"START begins a new Run in the first Room", _playtest_start_begins_run
	)

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


func _playtest_first_room_spawn() -> bool:
	var packed_scene := load(FIRST_ROOM_PATH) as PackedScene
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
	await _run_room_scenario(name, FIRST_ROOM_PATH, scenario)


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


# Like _run_playtest, for playtests that wait on frames.
func _run_playtest_async(name: String, playtest: Callable) -> void:
	var result: bool = await playtest.call()
	for action in SCENARIO_ACTIONS:
		Input.action_release(action)
	if result:
		print("PASS: %s" % name)
	else:
		_failures += 1
		push_error("FAIL: %s" % name)


# Plays the real game flow: the Run starts on the first Room's cliff top, walks off its east
# edge into the rune shore, then back west. Exits swap the current scene, as in the game.
func _playtest_walks_rooms() -> bool:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return false
	run.call("start_run")
	run.call("enter_room", &"waking_coast_1", &"east")
	change_scene_to_file(FIRST_ROOM_PATH)

	var valid := await _walk_until_scene(&"move_right", RUNE_SHORE_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_2"
	var player := _current_player()
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and player != null and absf(player.global_position.y - CLIFF_TOP_Y) < 1.0

	valid = valid and await _walk_until_scene(&"move_left", FIRST_ROOM_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_1"
	player = _current_player()
	valid = valid and player != null and player.global_position.x > 120.0

	run.call("start_run")
	if current_scene != null:
		current_scene.free()
	await process_frame
	return valid


# Swings at the Scavenger from the pool's edge until it is gone. Its lunges may knock the
# Player away, so each swing starts back at the edge, facing the pool.
func _playtest_sword_defeats_scavenger() -> bool:
	var player := await _enter_rune_shore()
	var scavenger := current_scene.get_node_or_null(SCAVENGER_PATH) if player != null else null
	var valid := scavenger != null
	for swing in MAX_SWINGS:
		if not valid or not is_instance_valid(scavenger):
			break
		await _face_pool_from_edge(player)
		_press(&"melee_attack")
		await _frames(3)
		_release(&"melee_attack")
		await _frames(30)
	valid = (
		valid and await _frames_until(func() -> bool: return not is_instance_valid(scavenger), 90)
	)
	await _leave_scene()
	return valid


# Stands still at the pool's edge until the Scavenger's lunge lands.
func _playtest_lunge_hurts_player() -> bool:
	var player := await _enter_rune_shore()
	if player == null:
		await _leave_scene()
		return false
	await _face_pool_from_edge(player)
	var health = player.get("health")
	var hurt := await _frames_until(func() -> bool: return health.current < health.maximum, 180)
	await _frames(6)
	var valid: bool = hurt and health.current == health.maximum - 1
	valid = valid and player.global_position.x < POOL_EDGE.x
	await _leave_scene()
	return valid


# One Health left at the pool's edge: the next lunge ends the Run, which starts over.
func _playtest_defeat_starts_over() -> bool:
	var player := await _enter_rune_shore()
	if player == null:
		await _leave_scene()
		return false
	var run := root.get_node("RunState")
	await _face_pool_from_edge(player)
	player.get("health").current = 1
	var restarted := await _frames_until(
		func() -> bool:
			return current_scene != null and current_scene.scene_file_path == FIRST_ROOM_PATH,
		240
	)
	var valid: bool = restarted and run.get("room_id") == &"waking_coast_1"
	valid = valid and run.get("entry_id") == &"start"
	valid = valid and not run.call("has_visited_room", &"waking_coast_2")
	await _leave_scene()
	return valid


# From a Run left in the rune shore: the start screen's START begins a fresh Run.
func _playtest_start_begins_run() -> bool:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return false
	run.call("enter_room", &"waking_coast_2", &"west")
	change_scene_to_file(START_SCREEN_PATH)
	# Long enough for the theme to start and fade in.
	await _frames(80)
	var valid := current_scene != null and current_scene.scene_file_path == START_SCREEN_PATH
	# One press opens the menu on START; a second presses it.
	await _tap(&"ui_accept")
	await _frames(2)
	var music := current_scene.get_node_or_null("Music") as AudioStreamPlayer
	valid = valid and music != null and music.playing
	var full_volume := music.volume_db if music != null else 0.0
	await _tap(&"ui_accept")
	# The theme fades under the start chime before the first Room loads.
	await _frames(8)
	valid = valid and music != null and music.volume_db < full_volume - 3.0
	var arrived := await _frames_until(
		func() -> bool:
			return current_scene != null and current_scene.scene_file_path == FIRST_ROOM_PATH,
		TRANSITION_FRAME_LIMIT
	)
	valid = valid and arrived and run.get("room_id") == &"waking_coast_1"
	valid = valid and run.get("entry_id") == &"start"
	valid = valid and not run.call("has_visited_room", &"waking_coast_2")
	var player := _current_player()
	var entry := current_scene.get_node_or_null("Entries/start") as Marker2D if arrived else null
	valid = valid and player != null and entry != null
	valid = valid and player.global_position.distance_to(entry.global_position) < 1.0
	await _leave_scene()
	return valid


func _enter_rune_shore() -> CharacterBody2D:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return null
	run.call("start_run")
	run.call("enter_room", &"waking_coast_2", &"west")
	change_scene_to_file(RUNE_SHORE_PATH)
	var landed := await _frames_until(
		func() -> bool: return _current_player() != null and _current_player().is_on_floor(),
		SETTLE_FRAME_LIMIT
	)
	return _current_player() if landed else null


func _face_pool_from_edge(player: CharacterBody2D) -> void:
	_press(&"move_right")
	await _frames(1)
	_release(&"move_right")
	player.global_position = POOL_EDGE
	player.velocity = Vector2.ZERO
	await _frames(2)


func _leave_scene() -> void:
	for action in SCENARIO_ACTIONS:
		Input.action_release(action)
	var run := root.get_node_or_null("RunState")
	if run != null:
		run.call("start_run")
	if current_scene != null:
		current_scene.free()
	await process_frame


# Lands in the current Room, then holds a direction until the scene becomes the given Room.
func _walk_until_scene(action: StringName, scene_path: String) -> bool:
	var landed := await _frames_until(
		func() -> bool: return _current_player() != null and _current_player().is_on_floor(),
		SETTLE_FRAME_LIMIT
	)
	_press(action)
	var arrived := await _frames_until(
		func() -> bool:
			return current_scene != null and current_scene.scene_file_path == scene_path,
		TRANSITION_FRAME_LIMIT
	)
	_release(action)
	await _frames_until(
		func() -> bool: return _current_player() != null and _current_player().is_on_floor(),
		SETTLE_FRAME_LIMIT
	)
	return landed and arrived


func _current_player() -> CharacterBody2D:
	if current_scene == null:
		return null
	return current_scene.get_node_or_null("Player") as CharacterBody2D


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
