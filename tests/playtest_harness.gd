extends SceneTree

# What the playtests run on: running and reporting each one, sending input the way a key or
# button would, waiting on frames, and the moves the playtests share (walking, jumping,
# wading, entering and leaving Rooms, fighting the rune shore's Scavenger, reading dialogue).

const SCENARIO_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"jump",
	&"melee_attack",
	&"pause",
	&"ui_accept",
	&"interact",
	&"ui_left",
	&"ui_right",
	&"ui_up",
	&"ui_down",
]
const SETTLE_FRAME_LIMIT := 120
const TRANSITION_FRAME_LIMIT := 180
const WAKING_COAST_SAND_Y := 96.0
const RUNE_SHORE_PATH := "res://scenes/rooms/waking_coast_2.tscn"
# The sand at the rune shore's tidal pool's west edge, where its Scavenger can reach and be
# reached.
const POOL_EDGE := Vector2(122, 96)
const SCAVENGER_PATH := "Enemies/Scavenger"
const MAX_SWINGS := 8
# Collision margins rest the Player a fraction of a pixel off the sand; falling through is far more.
const ON_SAND_TOLERANCE := 0.5

var _failures: int = 0


func _run_playtest(name: String, playtest_callable: Callable) -> void:
	if not playtest_callable.is_valid():
		_fail("%s (its playtest cannot be called)" % name)
		return
	_report(name, playtest_callable.call())


# Plays one scenario on a fresh Room once the Player has landed, then resets input and pause.
func _run_room_scenario(name: String, room_path: String, scenario: Callable) -> void:
	if not scenario.is_valid():
		_fail("%s (its scenario cannot be called)" % name)
		return
	var packed_scene := load(room_path) as PackedScene
	if packed_scene == null:
		_fail("%s (cannot load %s)" % [name, room_path])
		return
	var main_scene := packed_scene.instantiate() as Node2D
	root.add_child(main_scene)
	var player := main_scene.get_node("Player") as CharacterBody2D
	var landed := await _frames_until(
		func() -> bool: return player.is_on_floor(), SETTLE_FRAME_LIMIT
	)
	var result: Variant = (await scenario.call(player)) if landed else false
	for action in SCENARIO_ACTIONS:
		Input.action_release(action)
	paused = false
	main_scene.free()
	await process_frame
	_report(name, result)


# Like _run_playtest, for playtests that wait on frames.
func _run_playtest_async(name: String, playtest: Callable) -> void:
	if not playtest.is_valid():
		_fail("%s (its playtest cannot be called)" % name)
		return
	var result: Variant = await playtest.call()
	for action in SCENARIO_ACTIONS:
		Input.action_release(action)
	_report(name, result)


# Only a true passes: a script error or a freed object hands back null, and that must fail.
func _report(name: String, result: Variant) -> void:
	if result is bool and result:
		print("PASS: %s" % name)
	else:
		_fail(name)


func _fail(description: String) -> void:
	_failures += 1
	push_error("FAIL: %s" % description)


# Starts a fresh Run in a Room at an Entry and waits for the Player to land.
func _enter_room(room_id: StringName, entry_id: StringName, path: String) -> CharacterBody2D:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return null
	run.call("start_run")
	run.call("enter_room", room_id, entry_id)
	change_scene_to_file(path)
	var landed := await _frames_until(
		func() -> bool: return _current_player() != null and _current_player().is_on_floor(),
		SETTLE_FRAME_LIMIT
	)
	return _current_player() if landed else null


# Walks through each point in turn, jumping toward it whenever a pool's edge stops the walk.
func _wade_to(player: CharacterBody2D, points: Array[float]) -> void:
	for x in points:
		await _walk_to_x(player, x)
		var distance := x - player.global_position.x
		if absf(distance) > 4.0:
			await _jump_toward(player, 1 if distance > 0.0 else -1)


func _walk_to_x(player: CharacterBody2D, x: float) -> void:
	for i in 240:
		var distance := x - player.global_position.x
		if absf(distance) < 2.0:
			break
		_release(&"move_left" if distance > 0.0 else &"move_right")
		_press(&"move_right" if distance > 0.0 else &"move_left")
		await _frames(1)
	_release(&"move_left")
	_release(&"move_right")
	await _frames(20)


# Jumps, holding a direction (or none), until the Player lands.
func _jump_toward(player: CharacterBody2D, direction: int) -> void:
	if direction != 0:
		_press(&"move_right" if direction > 0 else &"move_left")
	_press(&"jump")
	await _frames(4)
	await _frames_until(
		func() -> bool: return player.is_on_floor() and player.velocity.y >= 0.0, 120
	)
	_release(&"jump")
	_release(&"move_left")
	_release(&"move_right")
	await _frames(15)


func _dialogue_box() -> Control:
	if current_scene == null:
		return null
	return current_scene.get_node_or_null("CanvasLayer/DialogueBox") as Control


func _speaker() -> String:
	return (_dialogue_box().get_node("%Speaker") as Label).text


# Presses on through every line, as a player would; false if the box never closes.
func _read_through_dialogue() -> bool:
	for i in 60:
		if not _dialogue_box().visible:
			return true
		await _tap(&"ui_accept")
		await _frames(3)
	return not _dialogue_box().visible


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
# One quick swing of the sword, and long enough after for the Attack to play out.
func _swing() -> void:
	_press(&"melee_attack")
	await _frames(3)
	_release(&"melee_attack")
	await _frames(30)


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


# Swings at the Scavenger from the pool's edge until it is gone. Its lunges may knock the
# Player away, so each swing starts back at the edge, facing the pool.
func _strike_down_scavenger(player: CharacterBody2D, scavenger: Node) -> void:
	for swing in MAX_SWINGS:
		if not is_instance_valid(scavenger):
			return
		await _face_pool_from_edge(player)
		await _swing()


func _face_pool_from_edge(player: CharacterBody2D) -> void:
	_press(&"move_right")
	await _frames(1)
	_release(&"move_right")
	player.global_position = POOL_EDGE
	player.velocity = Vector2.ZERO
	await _frames(2)
