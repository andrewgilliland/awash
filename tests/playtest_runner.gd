extends "res://tests/playtest_harness.gd"

# The playtests: real Rooms, real input and physics. The harness they run on is in
# tests/playtest_harness.gd.

const FIRST_ROOM_PATH := "res://scenes/rooms/waking_coast_1.tscn"
const START_SCREEN_PATH := "res://scenes/ui/start_screen.tscn"
const RUNE_SHORE_PATH := "res://scenes/rooms/waking_coast_2.tscn"
const SALT_CLIFFS_PATH := "res://scenes/rooms/waking_coast_3.tscn"
const WRECK_GRAVEYARD_PATH := "res://scenes/rooms/waking_coast_4.tscn"
# Up the wreck decks from the beach: [direction, launch x, height landed on]. The first deck
# (x 112-160), the mast's (x 160-192), the taller hull's (x 208-256), then the stern's.
const WRECK_DECKS := [[1, 92.0, 64.0], [1, 140.0, 48.0], [1, 180.0, 48.0], [1, 240.0, 16.0]]
const STERN_X := Vector2(256, 304)
const SEA_CAVE_PATH := "res://scenes/rooms/waking_coast_5.tscn"
const RUNE_ROAD_PATH := "res://scenes/rooms/waking_coast_6.tscn"
# Up the rune road's steps to the gate, jumping each one when the walk stops at it.
const RUNE_ROAD_EAST: Array[float] = [56.0, 104.0, 168.0, 232.0, 300.0]
const RUNE_ROAD_HEIGHTS_Y := 48.0
const STORM_WISP_PATH := "Enemies/StormWisp"
# Where to stand by the Storm Wisp: outside its arc but near enough to set it crackling, and
# close enough for the sword to reach it.
const WISP_WATCH_DISTANCE := 24.0
const WISP_STRIKE_DISTANCE := 14.0
const WISP_ARC_DISTANCE := 8.0
const WARDENS_GATE_PATH := "res://scenes/rooms/waking_coast_7.tscn"
const TIDEFEN_PATH := "res://scenes/rooms/waking_coast_8.tscn"
const UNDERTOW_PATH := "res://scenes/rooms/waking_coast_9.tscn"
const TIDEFEN_SAND_Y := 112.0
# Up onto Tidefen's walkway: straight up onto the ledge from under it, then on to the walkway.
const TIDEFEN_CLIMB := [[0, 40.0, 80.0], [1, 56.0, 64.0]]
const TIDEFEN_STALL_X := 250.0
# West along the undertow from the well's shaft: through three pools and over two rocks.
const UNDERTOW_WEST: Array[float] = [470.0, 400.0, 280.0, 200.0, 90.0, 20.0]
# Walking the graveyard's beach east to the sinkhole, and the cave's floor west to the tunnel:
# points to walk to, jumping out of a pool when the walk falls short.
const GRAVEYARD_BEACH_EAST: Array[float] = [88.0, 150.0, 186.0, 250.0, 296.0]
const SEA_CAVE_WEST: Array[float] = [170.0, 120.0, 40.0]
# The cliffs' tunnel Entry, at the foot of the climb.
const SALT_CLIFFS_CAVE_ENTRY := Vector2(148, 240)
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
const PlayerController := preload("res://scripts/player/player_controller.gd")
# The sand at the tidal pool's west edge, where the Scavenger can reach and be reached.
const POOL_EDGE := Vector2(122, 96)
const SCAVENGER_PATH := "Enemies/Scavenger"
const MAX_SWINGS := 8
# What any enemy hit costs the Player.
const ONE_HIT := 10


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
	await _run_playtest_async(
		"Player walks up the shore to the salt cliffs", _playtest_walks_to_cliffs
	)
	await _run_playtest_async("Player climbs the salt cliffs to the top", _playtest_climbs_cliffs)
	await _run_playtest_async(
		"Player walks from the cliff top to the wreck graveyard", _playtest_walks_to_graveyard
	)
	await _run_playtest_async("Player hops the wreck decks to the stern", _playtest_hops_to_stern)
	await _run_playtest_async(
		"Player drops into the sea cave and loops back to the cliffs", _playtest_cave_loop
	)
	await _run_playtest_async(
		"Player jumps the sinkhole onto the rune road and back", _playtest_jumps_to_rune_road
	)
	await _run_playtest_async("Player climbs the rune road to its gate", _playtest_climbs_rune_road)
	await _run_playtest_async("Sword disperses the Storm Wisp", _playtest_sword_disperses_wisp)
	await _run_playtest_async("Storm Wisp's arc hurts the Player", _playtest_arc_hurts_player)
	await _run_playtest_async(
		"Player walks through the Warden's gate into Tidefen", _playtest_walks_to_tidefen
	)
	await _run_playtest_async("Player climbs onto Tidefen's walkway", _playtest_climbs_tidefen)
	await _run_playtest_async(
		"Tidefen's well drops home through the undertow", _playtest_drops_home
	)
	await _run_playtest_async("Sword defeats the Scavenger", _playtest_sword_defeats_scavenger)
	await _run_playtest_async("Scavenger's lunge hurts the Player", _playtest_lunge_hurts_player)
	await _run_playtest_async(
		"Player defeat keeps the Run, back at the start", _playtest_defeat_keeps_run
	)
	await _run_playtest_async("Health carries through an Exit", _playtest_health_carries)
	await _run_playtest_async(
		"START begins a new Run in the first Room", _playtest_start_begins_run
	)
	await _run_playtest_async("A new game opens on Mara's intro", _playtest_new_game_intro)
	await _run_playtest_async("Interact talks to Mara again", _playtest_talk_to_mara)

	if _failures > 0:
		push_error("%d playtest(s) failed" % _failures)
		quit(1)
		return

	print("All playtests passed")
	quit(0)


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
	await _frames(100)
	_release(&"move_left")
	await _frames(2)
	# Walking from the middle of the beach reaches the wall, and stops there.
	var valid := player.is_on_floor() and player.global_position.x >= 0.0
	valid = valid and player.global_position.x < 12.0
	valid = valid and _is_on_sand(player)
	return valid


# Plays the real game flow: the Run starts on the first Room's cliff top, walks off its east
# edge into the rune shore, then back west. Exits swap the current scene, as in the game.
func _playtest_walks_rooms() -> bool:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return false
	run.call("start_run")
	run.call("enter_room", &"waking_coast_1", &"east")
	change_scene_to_file(FIRST_ROOM_PATH)

	var music := root.get_node_or_null("Music")
	var theme_path := "res://assets/audio/music/waking_coast_theme.wav"
	var theme_playing := func() -> bool:
		var current = music.call("current") if music != null else null
		return current != null and current.resource_path == theme_path
	await _frames_until(
		func() -> bool: return _current_player() != null and _current_player().is_on_floor(),
		SETTLE_FRAME_LIMIT
	)
	var starts_before: int = music.get("tracks_started") if music != null else -1
	var valid := await _walk_until_scene(&"move_right", RUNE_SHORE_PATH)
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
	valid = valid and player != null and player.global_position.x > 120.0

	run.call("start_run")
	if current_scene != null:
		current_scene.free()
	await process_frame
	return valid


# From the rune shore's east end into the salt cliffs' beach, then back.
func _playtest_walks_to_cliffs() -> bool:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return false
	run.call("start_run")
	run.call("enter_room", &"waking_coast_2", &"east")
	change_scene_to_file(RUNE_SHORE_PATH)
	await _frames_until(
		func() -> bool: return _current_player() != null and _current_player().is_on_floor(),
		SETTLE_FRAME_LIMIT
	)
	var valid := await _walk_until_scene(&"move_right", SALT_CLIFFS_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_3"
	var player := _current_player()
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and player != null and absf(player.global_position.y - SALT_CLIFFS_BEACH_Y) < 1.0

	valid = valid and await _walk_until_scene(&"move_left", RUNE_SHORE_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_2"
	player = _current_player()
	valid = valid and player != null and player.global_position.x > 280.0
	await _leave_scene()
	return valid


# From the salt cliffs' top on to the wreck graveyard's cliff, then back.
func _playtest_walks_to_graveyard() -> bool:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return false
	run.call("start_run")
	run.call("enter_room", &"waking_coast_3", &"east")
	change_scene_to_file(SALT_CLIFFS_PATH)
	await _frames_until(
		func() -> bool: return _current_player() != null and _current_player().is_on_floor(),
		SETTLE_FRAME_LIMIT
	)
	var valid := await _walk_until_scene(&"move_right", WRECK_GRAVEYARD_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_4"
	var player := _current_player()
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and player != null and absf(player.global_position.y - CLIFF_TOP_Y) < 1.0

	valid = valid and await _walk_until_scene(&"move_left", SALT_CLIFFS_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_3"
	player = _current_player()
	valid = valid and player != null and player.global_position.x > 120.0
	valid = valid and player != null and absf(player.global_position.y - SALT_CLIFFS_TOP_Y) < 1.0
	await _leave_scene()
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


# The loop with real input and physics: east along the graveyard's beach, down the sinkhole,
# west through the sea cave and out of the tunnel at the salt cliffs' foot. The Scavenger is
# taken out first: this checks the route, not the fight.
func _playtest_cave_loop() -> bool:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return false
	run.call("start_run")
	run.call("enter_room", &"waking_coast_4", &"west")
	change_scene_to_file(WRECK_GRAVEYARD_PATH)
	var landed := await _frames_until(
		func() -> bool: return _current_player() != null and _current_player().is_on_floor(),
		SETTLE_FRAME_LIMIT
	)
	if not landed:
		await _leave_scene()
		return false
	current_scene.get_node(SCAVENGER_PATH).free()
	await _wade_to(_current_player(), GRAVEYARD_BEACH_EAST)
	var valid := await _walk_until_scene(&"move_right", SEA_CAVE_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_5"
	var player := _current_player()
	valid = valid and player != null and player.is_on_floor() and player.global_position.x > 300.0
	if not valid:
		await _leave_scene()
		return false
	await _wade_to(player, SEA_CAVE_WEST)
	valid = await _walk_until_scene(&"move_left", SALT_CLIFFS_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_3"
	player = _current_player()
	valid = valid and player != null
	valid = valid and player.global_position.distance_to(SALT_CLIFFS_CAVE_ENTRY) < 1.0
	await _leave_scene()
	return valid


# From the graveyard's east end, a running jump over the sinkhole lands on the rune road;
# walking back west lands short of the sinkhole.
func _playtest_jumps_to_rune_road() -> bool:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return false
	run.call("start_run")
	run.call("enter_room", &"waking_coast_4", &"east")
	change_scene_to_file(WRECK_GRAVEYARD_PATH)
	var landed := await _frames_until(
		func() -> bool: return _current_player() != null and _current_player().is_on_floor(),
		SETTLE_FRAME_LIMIT
	)
	if not landed:
		await _leave_scene()
		return false
	current_scene.get_node(SCAVENGER_PATH).free()
	_press(&"move_right")
	await _frames(2)
	_press(&"jump")
	var arrived := await _frames_until(
		func() -> bool:
			return current_scene != null and current_scene.scene_file_path == RUNE_ROAD_PATH,
		TRANSITION_FRAME_LIMIT
	)
	_release(&"jump")
	_release(&"move_right")
	var valid: bool = arrived and run.get("room_id") == &"waking_coast_6"
	await _frames_until(
		func() -> bool: return _current_player() != null and _current_player().is_on_floor(),
		SETTLE_FRAME_LIMIT
	)
	var player := _current_player()
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and absf(player.global_position.y - WAKING_COAST_SAND_Y) < 1.0

	valid = valid and await _walk_until_scene(&"move_left", WRECK_GRAVEYARD_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_4"
	player = _current_player()
	valid = valid and player != null and player.is_on_floor()
	valid = valid and absf(player.global_position.y - WAKING_COAST_SAND_Y) < 1.0
	await _leave_scene()
	return valid


# Up the road from the beach, a step at a time, to the heights by the rune gate. The Storm Wisp
# over the heights is taken out first: this checks the route, not the fight.
func _playtest_climbs_rune_road() -> bool:
	var player := await _enter_room(&"waking_coast_6", &"west", RUNE_ROAD_PATH)
	if player == null:
		await _leave_scene()
		return false
	current_scene.get_node(STORM_WISP_PATH).free()
	await _wade_to(player, RUNE_ROAD_EAST)
	var valid := player.is_on_floor() and player.global_position.x > 290.0
	valid = valid and absf(player.global_position.y - RUNE_ROAD_HEIGHTS_Y) < 1.0
	await _leave_scene()
	return valid


# From the rune road's heights east through the Warden's gate, down into its arena and on into
# Tidefen.
func _playtest_walks_to_tidefen() -> bool:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return false
	run.call("start_run")
	run.call("enter_room", &"waking_coast_6", &"east")
	change_scene_to_file(RUNE_ROAD_PATH)
	var valid := await _walk_until_scene(&"move_right", WARDENS_GATE_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_7"
	valid = valid and await _walk_until_scene(&"move_right", TIDEFEN_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_8"
	var player := _current_player()
	valid = valid and player != null and player.global_position.x < 40.0
	valid = valid and absf(player.global_position.y - TIDEFEN_SAND_Y) < 1.0
	await _leave_scene()
	return valid


# From Tidefen's sand up onto the ledge, then the walkway, and along it to the shop's stall.
func _playtest_climbs_tidefen() -> bool:
	var player := await _enter_room(&"waking_coast_8", &"west", TIDEFEN_PATH)
	if player == null:
		await _leave_scene()
		return false
	var valid := true
	for step in TIDEFEN_CLIMB:
		await _walk_to_x(player, step[1])
		await _jump_toward(player, step[0])
		valid = valid and player.is_on_floor() and absf(player.global_position.y - step[2]) < 1.0
	await _walk_to_x(player, TIDEFEN_STALL_X)
	valid = valid and absf(player.global_position.x - TIDEFEN_STALL_X) < 4.0
	valid = valid and absf(player.global_position.y - TIDEFEN_CLIMB[-1][2]) < 1.0
	await _leave_scene()
	return valid


# The way home with real input: wade into Tidefen's well, run the undertow west, through the
# sea cave and out at the salt cliffs' foot. The undertow's Scavenger is taken out first.
func _playtest_drops_home() -> bool:
	var player := await _enter_room(&"waking_coast_8", &"west", TIDEFEN_PATH)
	if player == null:
		await _leave_scene()
		return false
	var run := root.get_node("RunState")
	var valid := await _walk_until_scene(&"move_right", UNDERTOW_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_9"
	player = _current_player()
	valid = valid and player != null and player.is_on_floor() and player.global_position.x > 620.0
	if not valid:
		await _leave_scene()
		return false
	current_scene.get_node(SCAVENGER_PATH).free()
	await _wade_to(player, UNDERTOW_WEST)
	valid = await _walk_until_scene(&"move_left", SEA_CAVE_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_5"
	player = _current_player()
	valid = valid and player != null
	if not valid:
		await _leave_scene()
		return false
	await _wade_to(player, SEA_CAVE_WEST)
	valid = await _walk_until_scene(&"move_left", SALT_CLIFFS_PATH)
	valid = valid and run.get("room_id") == &"waking_coast_3"
	player = _current_player()
	valid = valid and player != null
	valid = valid and player.global_position.distance_to(SALT_CLIFFS_CAVE_ENTRY) < 1.0
	await _leave_scene()
	return valid


# Waits out the Storm Wisp's crackle and arc just beyond its reach, then steps in while it rests
# and swings, until it is gone.
func _playtest_sword_disperses_wisp() -> bool:
	var player := await _enter_room(&"waking_coast_6", &"east", RUNE_ROAD_PATH)
	var wisp := current_scene.get_node_or_null(STORM_WISP_PATH) if player != null else null
	var valid := wisp != null
	var brain = wisp.get("brain") if valid else null
	for swing in MAX_SWINGS:
		if not valid or not is_instance_valid(wisp):
			break
		await _stand_by_wisp(player, wisp, WISP_WATCH_DISTANCE)
		await _frames_until(
			func() -> bool: return not is_instance_valid(wisp) or brain.state == brain.State.REST,
			180
		)
		if not is_instance_valid(wisp):
			break
		await _stand_by_wisp(player, wisp, WISP_STRIKE_DISTANCE)
		_press(&"melee_attack")
		await _frames(3)
		_release(&"melee_attack")
		await _frames(30)
	valid = valid and await _frames_until(func() -> bool: return not is_instance_valid(wisp), 90)
	await _leave_scene()
	return valid


# Stands inside the Storm Wisp's reach until its arc lands.
func _playtest_arc_hurts_player() -> bool:
	var player := await _enter_room(&"waking_coast_6", &"east", RUNE_ROAD_PATH)
	var wisp := (
		current_scene.get_node_or_null(STORM_WISP_PATH) as Node2D if player != null else null
	)
	if wisp == null:
		await _leave_scene()
		return false
	await _stand_by_wisp(player, wisp, WISP_ARC_DISTANCE)
	var health = player.get("health")
	var hurt := await _frames_until(func() -> bool: return health.current < health.maximum, 180)
	await _frames(6)
	var valid: bool = hurt and health.current == health.maximum - ONE_HIT
	await _leave_scene()
	return valid


# Puts the Player on the heights a distance to the Wisp's open side, facing it.
func _stand_by_wisp(player: CharacterBody2D, wisp: Node2D, distance: float) -> void:
	# Stand on the side away from the east edge, so the Player never steps into its Exit.
	var side := -1.0 if wisp.global_position.x > 256.0 else 1.0
	var toward := &"move_right" if side < 0.0 else &"move_left"
	_press(toward)
	await _frames(1)
	_release(toward)
	player.global_position = Vector2(wisp.global_position.x + side * distance, RUNE_ROAD_HEIGHTS_Y)
	player.velocity = Vector2.ZERO
	await _frames(2)


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
	var valid: bool = hurt and health.current == health.maximum - ONE_HIT
	valid = valid and player.global_position.x < POOL_EDGE.x
	await _leave_scene()
	return valid


# One Health left at the pool's edge: the next lunge defeats the Player. It falls where it lands
# and stops answering the controls, then wakes in the first Room with full Health, the Run kept.
func _playtest_defeat_keeps_run() -> bool:
	var player := await _enter_rune_shore()
	if player == null:
		await _leave_scene()
		return false
	var run := root.get_node("RunState")
	await _face_pool_from_edge(player)
	player.get("health").current = 1
	var down := await _frames_until(func() -> bool: return player.call("is_defeated"), 240)
	# Let the hit's knockback play out, then the controls should do nothing.
	await _frames_until(
		func() -> bool: return player.is_on_floor() and is_zero_approx(player.velocity.x), 90
	)
	var body := player.get_node("AnimatedSprite2D") as Node2D
	var valid: bool = down and not is_zero_approx(body.rotation)
	var x := player.global_position.x
	_press(&"move_left")
	await _frames(12)
	_release(&"move_left")
	valid = valid and absf(player.global_position.x - x) < 1.0
	var restarted := await _frames_until(
		func() -> bool:
			return current_scene != null and current_scene.scene_file_path == FIRST_ROOM_PATH,
		240
	)
	valid = valid and restarted and run.get("room_id") == &"waking_coast_1"
	valid = valid and run.get("entry_id") == &"start"
	valid = valid and run.call("has_visited_room", &"waking_coast_2")
	await _frames(30)
	var health = _current_player().get("health")
	valid = valid and health.current == health.maximum
	# Only a new game from START opens on the intro.
	var box := _dialogue_box()
	valid = valid and box != null and not box.visible and not run.get("intro_pending")
	await _leave_scene()
	return valid


# A hit taken in the rune shore is still taken after walking west into the first Room, and the
# Health bar there shows it.
func _playtest_health_carries() -> bool:
	var player := await _enter_rune_shore()
	if player == null:
		await _leave_scene()
		return false
	var blow := Area2D.new()
	current_scene.add_child(blow)
	blow.global_position = player.global_position + Vector2(10, 0)
	player.call("_on_hurtbox_hit", blow)
	blow.queue_free()
	var valid := await _walk_until_scene(&"move_left", FIRST_ROOM_PATH)
	var health = _current_player().get("health")
	valid = valid and health.current == health.maximum - ONE_HIT
	await _frames(2)
	var bar := current_scene.get_node("CanvasLayer/HealthBar")
	var fill: float = bar.call("fill_fraction")
	valid = valid and is_equal_approx(fill, float(health.current) / health.maximum)
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


# A new game from START: Vael wakes by the wreck, Mara comes over, they talk, and control
# comes back.
func _playtest_new_game_intro() -> bool:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return false
	change_scene_to_file(START_SCREEN_PATH)
	await _frames(20)
	await _tap(&"ui_accept")
	await _frames(2)
	await _tap(&"ui_accept")
	var arrived := await _frames_until(
		func() -> bool:
			return current_scene != null and current_scene.scene_file_path == FIRST_ROOM_PATH,
		TRANSITION_FRAME_LIMIT
	)
	var opened := await _frames_until(
		func() -> bool: return _dialogue_box() != null and _dialogue_box().visible, 360
	)
	var player := _current_player()
	var mara := current_scene.get_node_or_null("Mara") as Node2D if arrived else null
	var valid := arrived and opened and player != null and mara != null
	if not valid:
		await _leave_scene()
		return false
	valid = player.get("controls_locked") and _speaker() == "MARA"
	valid = valid and absf(mara.global_position.x - player.global_position.x) < 32.0
	valid = valid and await _read_through_dialogue()
	await _frames(3)
	valid = valid and not player.get("controls_locked") and not run.get("intro_pending")
	# Mara has handed Blacktide over: it no longer stands in the sand.
	var sword := current_scene.get_node_or_null("Blacktide") as CanvasItem
	valid = valid and sword != null and not sword.visible
	# Control is back: the Player walks.
	var x := player.global_position.x
	_press(&"move_right")
	await _frames(15)
	_release(&"move_right")
	valid = valid and player.global_position.x > x + 5.0
	await _leave_scene()
	return valid


# Without the intro, Mara still stands by the start Entry; Interact talks to her again.
func _playtest_talk_to_mara() -> bool:
	var run := root.get_node_or_null("RunState")
	if run == null:
		return false
	run.call("start_run")
	change_scene_to_file(FIRST_ROOM_PATH)
	var landed := await _frames_until(
		func() -> bool: return _current_player() != null and _current_player().is_on_floor(),
		SETTLE_FRAME_LIMIT
	)
	var valid := landed and _dialogue_box() != null and not _dialogue_box().visible
	await _tap(&"interact")
	await _frames(2)
	valid = valid and _dialogue_box().visible and _speaker() == "MARA"
	valid = valid and _current_player().get("controls_locked")
	valid = valid and await _read_through_dialogue()
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
