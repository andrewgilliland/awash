extends "res://tests/playtest_harness.gd"

# The Waking Coast's walks with real input: Room to Room, up the cliffs and the wreck decks, into
# the sea cave and out, on to Tidefen and up its walkway.
# Part of the playtests tests/playtest_runner.gd runs: each file extends the one before it, from
# the harness on, so all of them share its helpers.

const FIRST_ROOM_PATH := "res://scenes/rooms/waking_coast_1.tscn"
const SALT_CLIFFS_PATH := "res://scenes/rooms/waking_coast_3.tscn"
const WRECK_GRAVEYARD_PATH := "res://scenes/rooms/waking_coast_4.tscn"
# Up the wreck decks from the beach: [direction, launch x, height landed on]. The first deck
# (x 112-160), the mast's (x 160-192), the taller hull's (x 208-256), then the stern's.
const WRECK_DECKS := [[1, 92.0, 64.0], [1, 140.0, 48.0], [1, 180.0, 48.0], [1, 240.0, 16.0]]
const STERN_X := Vector2(256, 304)
const SEA_CAVE_PATH := "res://scenes/rooms/waking_coast_5.tscn"
const JUNGLE_TRAIL_PATH := "res://scenes/rooms/waking_coast_6.tscn"
const BROKEN_STAIR_PATH := "res://scenes/rooms/waking_coast_13.tscn"
# Up the jungle trail's steps to the gate, jumping each one when the walk stops at it.
const JUNGLE_TRAIL_EAST: Array[float] = [56.0, 104.0, 168.0, 232.0, 300.0]
const JUNGLE_TRAIL_HEIGHTS_Y := 48.0
const STORM_WISP_PATH := "Enemies/StormWisp"
const WARDENS_GATE_PATH := "res://scenes/rooms/waking_coast_7.tscn"
const TIDEFEN_PATH := "res://scenes/rooms/tidefen_village_1.tscn"
const TIDEFEN_SAND_Y := 112.0
# Up onto Tidefen's walkway: straight up onto the ledge from under it, then on to the walkway.
const TIDEFEN_CLIMB := [[0, 40.0, 80.0], [1, 56.0, 64.0]]
const TIDEFEN_WALKWAY_EAST_X := 270.0
# Walking the graveyard's beach east to its end, and the cave's floor east to its end and back
# west to the tunnel: points to walk to, jumping out of a pool when the walk falls short.
const GRAVEYARD_BEACH_EAST: Array[float] = [88.0, 150.0, 186.0, 250.0, 296.0]
const SEA_CAVE_EAST: Array[float] = [170.0, 280.0]
# Where the sea cave's walk east stops: against the rock across the Shortcut, short of its Exit.
const SEA_CAVE_ROCK_X := 288.0
const ROOM_EDGE_X := 330.0
const SEA_CAVE_WEST: Array[float] = [170.0, 124.0]
# Up out of the sea cave: onto its two landings, a jump straight up at a time, then a jump up
# through the opening into the salt cliffs, onto the step at the hole's rim, and a hop onto the
# beach: [direction, launch x, height landed on].
const SEA_CAVE_CLIMB := [[0, 124.0, 64.0], [0, 136.0, 32.0]]
const SEA_CAVE_LEAVE_X := 152.0
const SALT_CLIFFS_CAVE_ENTRY := Vector2(104, 272)
# The salt cliffs' beach, two screens down, and the cliff top the climb ends on.
const SALT_CLIFFS_BEACH_Y := 240.0
const SALT_CLIFFS_TOP_Y := 64.0
# The climb, a jump at a time: [direction, launch x, height landed on]. Stone ledges hang on
# the cliff (x 64-112) and wreck decks across from them (x 16-64).
const SALT_CLIFFS_CLIMB := [
	[0, 88.0, 208.0],
	[-1, 72.0, 176.0],
	[1, 56.0, 144.0],
	[-1, 72.0, 112.0],
	[1, 56.0, 80.0],
	[1, 100.0, SALT_CLIFFS_TOP_Y],
]
const CLIFF_TOP_Y := 64.0


# Plays the real game flow: the Run starts on the first Room's cliff top, walks off its east
# edge into the palm shore, then back west. Exits swap the current scene, as in the game.
func _playtest_walks_rooms() -> bool:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return false
	run.call("start_run")
	run.call("enter_room", &"waking_coast_1", &"east")
	change_scene_to_file(FIRST_ROOM_PATH)

	var music := root.get_node_or_null("Music")
	var theme_path := "res://assets/regions/waking_coast/music/theme.wav"
	var theme_playing := func() -> bool:
		var current = music.call("current") if music != null else null
		return current != null and current.resource_path == theme_path
	await _frames_until(
		func() -> bool: return _current_player() != null and _current_player().is_on_floor(),
		SETTLE_FRAME_LIMIT
	)
	var starts_before: int = music.get("tracks_started") if music != null else -1
	var valid := await _walk_until_scene(&"move_right", PALM_SHORE_PATH)
	# The coast theme plays on through the Exit rather than starting over.
	var starts_after: int = music.get("tracks_started") if music != null else -2
	valid = valid and theme_playing.call() and starts_after == starts_before
	valid = valid and run.get("room_id") == &"waking_coast_2"
	var player := _current_player()
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and player != null and absf(player.global_position.y - CLIFF_TOP_Y) < 1.0

	valid = valid and await _walk_until_scene(&"move_left", FIRST_ROOM_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_1"
	player = _current_player()
	valid = valid and player != null and player.global_position.x > 280.0

	run.call("start_run")
	if current_scene != null:
		current_scene.free()
	await process_frame
	return valid


# Down from the cliff to the sand, then deck to deck up to the stern's crate, with real input
# and physics. The Scavenger is taken out first: this checks the route, not the fight.
func _playtest_hops_to_stern() -> bool:
	var player := await _enter_room(&"waking_coast_4", &"west", WRECK_GRAVEYARD_PATH)
	if player == null:
		await _leave_scene()
		return false
	current_scene.get_node(SCAVENGER_PATH).free()
	await _walk_to_x(player, WRECK_DECKS[0][1])
	var valid := absf(player.global_position.y - WAKING_COAST_SAND_Y) < 1.0
	for step in WRECK_DECKS:
		if not valid:
			break
		await _walk_to_x(player, step[1])
		await _jump_toward(player, step[0])
		valid = player.is_on_floor() and absf(player.global_position.y - step[2]) < 1.0
	var x := player.global_position.x
	valid = valid and x > STERN_X.x and x < STERN_X.y
	await _leave_scene()
	return valid


# With real input and physics: east along the salt cliffs' beach, down the hole under the cliff's
# foot into the sea cave, along its floor until the rock across the Shortcut stops the Player
# short of the Exit, then back, up its landings and out through the opening onto the step at the
# hole's rim, and back onto the beach. The cliffs' Scavenger is taken out first: this checks the
# route, not the fight.
func _playtest_cave_and_back() -> bool:
	var player := await _enter_room(&"waking_coast_3", &"west", SALT_CLIFFS_PATH)
	if player == null:
		await _leave_scene()
		return false
	var run := root.get_node("RunState")
	current_scene.get_node(SCAVENGER_PATH).free()
	await _wade_to(player, [80.0])
	var valid := await _walk_until_scene(&"move_right", SEA_CAVE_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_5"
	player = _current_player()
	if not valid or player == null:
		await _leave_scene()
		return false
	await _frames_until(func() -> bool: return player.is_on_floor(), SETTLE_FRAME_LIMIT)
	await _wade_to(player, SEA_CAVE_EAST)
	valid = player.is_on_floor() and player.global_position.x > 270.0
	await _walk_to_x(player, ROOM_EDGE_X)
	valid = valid and player.global_position.x < SEA_CAVE_ROCK_X
	valid = valid and current_scene.scene_file_path == SEA_CAVE_PATH
	valid = valid and await _climb_out_of_cave(player)
	await _leave_scene()
	return valid


# From the sea cave's floor, west to under the opening, up the landings and out into the salt
# cliffs; then from the step at the hole's rim onto the beach.
func _climb_out_of_cave(player: CharacterBody2D) -> bool:
	var run := root.get_node("RunState")
	await _wade_to(player, SEA_CAVE_WEST)
	var valid := true
	for step in SEA_CAVE_CLIMB:
		await _walk_to_x(player, step[1])
		await _jump_toward(player, step[0])
		valid = valid and player.is_on_floor() and absf(player.global_position.y - step[2]) < 1.0
	await _walk_to_x(player, SEA_CAVE_LEAVE_X)
	_press(&"jump")
	valid = (
		valid
		and await _frames_until(
			func() -> bool:
				return current_scene != null and current_scene.scene_file_path == SALT_CLIFFS_PATH,
			TRANSITION_FRAME_LIMIT
		)
	)
	_release(&"jump")
	valid = valid and run.get("room_id") == &"waking_coast_3"
	await _frames_until(
		func() -> bool: return _current_player() != null and _current_player().is_on_floor(),
		SETTLE_FRAME_LIMIT
	)
	player = _current_player()
	valid = valid and player != null
	valid = valid and player.global_position.distance_to(SALT_CLIFFS_CAVE_ENTRY) < 1.0
	if valid:
		await _jump_toward(player, -1)
		valid = player.is_on_floor()
		valid = valid and absf(player.global_position.y - SALT_CLIFFS_BEACH_Y) < 1.0
	return valid


# Along the graveyard's beach, wading its pools, and straight on east to the top of the broken
# stair; walking back west lands on the graveyard's sand. The Scavenger is taken out first: this
# checks the route, not the fight.
func _playtest_beach_to_broken_stair() -> bool:
	var player := await _enter_room(&"waking_coast_4", &"west", WRECK_GRAVEYARD_PATH)
	if player == null:
		await _leave_scene()
		return false
	var run := root.get_node("RunState")
	current_scene.get_node(SCAVENGER_PATH).free()
	await _wade_to(player, GRAVEYARD_BEACH_EAST)
	var valid := await _walk_until_scene(&"move_right", BROKEN_STAIR_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_13"
	player = _current_player()
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and absf(player.global_position.y - WAKING_COAST_SAND_Y) < 1.0
	valid = valid and await _walk_until_scene(&"move_left", WRECK_GRAVEYARD_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_4"
	player = _current_player()
	valid = valid and player != null and player.is_on_floor()
	valid = valid and absf(player.global_position.y - WAKING_COAST_SAND_Y) < 1.0
	await _leave_scene()
	return valid


# Up the trail from the beach, a step at a time, to the heights by the rune gate. The Storm Wisp
# over the heights is taken out first: this checks the route, not the fight.
func _playtest_climbs_jungle_trail() -> bool:
	var player := await _enter_room(&"waking_coast_6", &"west", JUNGLE_TRAIL_PATH)
	if player == null:
		await _leave_scene()
		return false
	current_scene.get_node(STORM_WISP_PATH).free()
	await _wade_to(player, JUNGLE_TRAIL_EAST)
	var valid := player.is_on_floor() and player.global_position.x > 290.0
	valid = valid and absf(player.global_position.y - JUNGLE_TRAIL_HEIGHTS_Y) < 1.0
	await _leave_scene()
	return valid


# From the jungle trail's heights east through the Warden's gate, down into its arena and on into
# Tidefen, the Warden already defeated this Run.
func _playtest_walks_to_tidefen() -> bool:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return false
	run.call("start_run")
	run.call("defeat_boss", &"nameless_warden")
	run.call("enter_room", &"waking_coast_6", &"east")
	change_scene_to_file(JUNGLE_TRAIL_PATH)
	var valid := await _walk_until_scene(&"move_right", WARDENS_GATE_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_7"
	valid = valid and await _walk_until_scene(&"move_right", TIDEFEN_PATH)
	valid = valid and run.get("room_id") == &"tidefen_village_1"
	var player := _current_player()
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and absf(player.global_position.y - TIDEFEN_SAND_Y) < 1.0
	await _leave_scene()
	return valid


# From Tidefen's sand up onto the ledge, then the walkway, and along it to its east end.
func _playtest_climbs_tidefen() -> bool:
	var player := await _enter_room(&"tidefen_village_1", &"west", TIDEFEN_PATH)
	if player == null:
		await _leave_scene()
		return false
	var valid := true
	for step in TIDEFEN_CLIMB:
		await _walk_to_x(player, step[1])
		await _jump_toward(player, step[0])
		valid = valid and player.is_on_floor() and absf(player.global_position.y - step[2]) < 1.0
	await _walk_to_x(player, TIDEFEN_WALKWAY_EAST_X)
	valid = valid and absf(player.global_position.x - TIDEFEN_WALKWAY_EAST_X) < 4.0
	valid = valid and absf(player.global_position.y - TIDEFEN_CLIMB[-1][2]) < 1.0
	await _leave_scene()
	return valid


# Jumps the tidal pool, then climbs ledge to ledge to the cliff top, with real input and physics.
# The pool's Scavenger is taken out first: this checks the route, not the fight.
func _playtest_climbs_cliffs() -> bool:
	var player := await _enter_room(&"waking_coast_3", &"west", SALT_CLIFFS_PATH)
	if player == null:
		await _leave_scene()
		return false
	current_scene.get_node(SCAVENGER_PATH).free()
	# The pool sits below the sand: jump it, or jump back out of it.
	await _walk_to_x(player, 20.0)
	await _jump_toward(player, 1)
	if player.global_position.y > SALT_CLIFFS_BEACH_Y + 1.0:
		await _jump_toward(player, 1)
	# Landing on the beach, or already up on the lowest ledge, which hangs over the pool's far
	# edge; the first step jumps straight up onto that ledge either way.
	var valid := player.is_on_floor() and player.global_position.y < SALT_CLIFFS_BEACH_Y + 1.0
	for step in SALT_CLIFFS_CLIMB:
		if not valid:
			break
		await _walk_to_x(player, step[1])
		await _jump_toward(player, step[0])
		valid = player.is_on_floor() and absf(player.global_position.y - step[2]) < 1.0
	valid = valid and player.global_position.x > 112.0
	await _leave_scene()
	return valid
