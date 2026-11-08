extends "res://tests/run_playtests.gd"

# The playtests: real Rooms, real input and physics. The harness they run on is in
# tests/playtest_harness.gd; the coast's walks, the fights and the Run's story are in
# tests/coast_playtests.gd, tests/fight_playtests.gd and tests/run_playtests.gd, each extending
# the one before it. This file runs them all, with the moves of the first Room and the Pause menu.

# The first Room's low shelf at the west wall, two steps down from the beach, under the surf.
const SHALLOWS_Y := 128.0
const WEST_WALK_FRAMES := 240
const PlayerController := preload("res://scripts/player/player_controller.gd")
const WardenPlaytests := preload("res://tests/warden_playtests.gd")
const CoastRoutePlaytests := preload("res://tests/coast_route_playtests.gd")
const UndertowPlaytests := preload("res://tests/undertow_playtests.gd")
const LurelightPlaytests := preload("res://tests/lurelight_playtests.gd")
const SiltCrabPlaytests := preload("res://tests/silt_crab_playtests.gd")
const BombPlaytests := preload("res://tests/bomb_playtests.gd")
const VillagerPlaytests := preload("res://tests/villager_playtests.gd")
const RestPlaytests := preload("res://tests/rest_playtests.gd")
const ShopPlaytests := preload("res://tests/shop_playtests.gd")
const SavingPlaytests := preload("res://tests/saving_playtests.gd")
const LakeEndPlaytests := preload("res://tests/lake_end_playtests.gd")


func _init() -> void:
	_run_playtest("First Room spawn stays deterministic", _playtest_first_room_spawn)

	# Scenarios play the real main scene with input events and physics frames. The tree,
	# autoloads and input map are live only after the first frame.
	await process_frame
	await _run_scenario("Player walks right", _scenario_walks_right)
	await _run_scenario("Player jumps and lands", _scenario_jumps_and_lands)
	await _run_scenario("A tap of jump hops lower than a held jump", _scenario_tap_hops_lower)
	await _run_scenario("Player attack plays out", _scenario_attack_plays_out)
	await _run_scenario("Pause freezes and resumes play", _scenario_pause_freezes_play)
	await _run_scenario("Left and right page the Pause menu", _scenario_pause_menu_pages)
	await _run_scenario("Player walks the Waking Coast sand", _scenario_walks_waking_coast_sand)
	await _run_scenario("Player stops at the west edge", _scenario_stops_at_west_edge)
	await _run_playtest_async("Player walks between the Waking Coast Rooms", _playtest_walks_rooms)
	await _run_playtest_async("Player climbs the salt cliffs to the top", _playtest_climbs_cliffs)
	var coast_route_playtests := CoastRoutePlaytests.new(self)
	for playtest in coast_route_playtests.get_playtests():
		await _run_playtest_async(playtest[0], playtest[1])
	await _run_playtest_async("Player hops the wreck decks to the stern", _playtest_hops_to_stern)
	await _run_playtest_async(
		"Player drops into the sea cave from the cliffs' foot and climbs back out",
		_playtest_cave_and_back
	)
	await _run_playtest_async(
		"Player walks the graveyard's beach to the broken stair and back",
		_playtest_beach_to_broken_stair
	)
	await _run_playtest_async(
		"Player climbs the jungle trail to its gate", _playtest_climbs_jungle_trail
	)
	await _run_playtest_async("Sword disperses the Storm Wisp", _playtest_sword_disperses_wisp)
	await _run_playtest_async("Storm Wisp's arc hurts the Player", _playtest_arc_hurts_player)
	await _run_playtest_async(
		"A charged Attack disperses the Storm Wisp in one blow", _playtest_charged_wisp
	)
	await _run_playtest_async(
		"Past the defeated Warden, Player walks on into Tidefen", _playtest_walks_to_tidefen
	)
	await _run_playtest_async("Player climbs onto Tidefen's walkway", _playtest_climbs_tidefen)
	await _run_playtest_async(
		"Player baits the Wraith's lash, then strikes its anchor", _playtest_strikes_wraith
	)
	await _run_playtest_async("Wraith's lash hurts the Player", _playtest_lash_hurts_player)
	var undertow_playtests := UndertowPlaytests.new(self)
	for playtest in undertow_playtests.get_playtests():
		await _run_playtest_async(playtest[0], playtest[1])
	var lurelight_playtests := LurelightPlaytests.new(self)
	for playtest in lurelight_playtests.get_playtests():
		await _run_playtest_async(playtest[0], playtest[1])
	var silt_crab_playtests := SiltCrabPlaytests.new(self)
	for playtest in silt_crab_playtests.get_playtests():
		await _run_playtest_async(playtest[0], playtest[1])
	var bomb_playtests := BombPlaytests.new(self)
	for playtest in bomb_playtests.get_playtests():
		await _run_playtest_async(playtest[0], playtest[1])
	var villager_playtests := VillagerPlaytests.new(self)
	for playtest in villager_playtests.get_playtests():
		await _run_playtest_async(playtest[0], playtest[1])
	var rest_playtests := RestPlaytests.new(self)
	for playtest in rest_playtests.get_playtests():
		await _run_playtest_async(playtest[0], playtest[1])
	var shop_playtests := ShopPlaytests.new(self)
	for playtest in shop_playtests.get_playtests():
		await _run_playtest_async(playtest[0], playtest[1])
	var saving_playtests := SavingPlaytests.new(self)
	for playtest in saving_playtests.get_playtests():
		await _run_playtest_async(playtest[0], playtest[1])
	var lake_end_playtests := LakeEndPlaytests.new(self)
	for playtest in lake_end_playtests.get_playtests():
		await _run_playtest_async(playtest[0], playtest[1])
	await _run_playtest_async(
		"Sword defeats the Scavenger and earns its Experience and Gold",
		_playtest_sword_defeats_scavenger
	)
	await _run_playtest_async("Scavenger's lunge hurts the Player", _playtest_lunge_hurts_player)
	await _run_playtest_async(
		"A defeated Scavenger leaves a Brinecap, eaten from the Inventory", _playtest_brinecap_drop
	)
	await _run_playtest_async(
		"Player defeat keeps the Run, back at the start", _playtest_defeat_keeps_run
	)
	await _run_playtest_async("Health carries through an Exit", _playtest_health_carries)
	await _run_playtest_async(
		"START begins a new Run in the first Room", _playtest_start_begins_run
	)
	await _run_playtest_async("A new game opens on Mara's intro", _playtest_new_game_intro)
	await _run_playtest_async("Interact talks to Mara again", _playtest_talk_to_mara)
	var warden_playtests := WardenPlaytests.new(self)
	for playtest in warden_playtests.get_playtests():
		await _run_playtest_async(playtest[0], playtest[1])

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


# A jump let go at once is a short hop, under a tile; held to the top it rises two tiles.
func _scenario_tap_hops_lower(player: CharacterBody2D) -> bool:
	var floor_y := player.global_position.y
	_press(&"jump")
	await _frames(1)
	_release(&"jump")
	var hop := await _peak_height(player, floor_y)
	_press(&"jump")
	var full := await _peak_height(player, floor_y)
	_release(&"jump")
	return hop > 4.0 and hop < 16.0 and full > 30.0


# How high above the floor the Player rises before landing again.
func _peak_height(player: CharacterBody2D, floor_y: float) -> float:
	var peak := 0.0
	for i in 120:
		await _frames(1)
		peak = maxf(peak, floor_y - player.global_position.y)
		if player.is_on_floor() and peak > 1.0:
			break
	await _frames(5)
	return peak


func _scenario_jumps_and_lands(player: CharacterBody2D) -> bool:
	var floor_y := player.global_position.y
	var controller := player.get("controller") as PlayerController
	var sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	# Held through the rise, for the whole jump.
	_press(&"jump")
	await _frames(10)
	_release(&"jump")
	var valid := player.global_position.y < floor_y - 10.0 and not player.is_on_floor()
	valid = valid and controller.state == PlayerController.State.JUMP
	valid = valid and sprite.animation == &"jump"

	var landed := await _frames_until(func() -> bool: return player.is_on_floor(), 120)
	await _frames(2)
	valid = valid and landed and controller.state == PlayerController.State.IDLE
	# It lands, then stands.
	valid = valid and sprite.animation == &"land"
	var stood := await _frames_until(func() -> bool: return sprite.animation == &"idle", 30)
	return valid and stood


func _scenario_attack_plays_out(player: CharacterBody2D) -> bool:
	var controller := player.get("controller") as PlayerController
	var body_sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var sword_sprite := player.get_node("SwordSprite") as AnimatedSprite2D
	# A quick tap: the press slashes at once.
	_press(&"melee_attack")
	await _frames(2)
	var valid := controller.state == PlayerController.State.ATTACK and sword_sprite.visible
	valid = valid and body_sprite.animation == &"attack" and sword_sprite.animation == &"attack"
	_release(&"melee_attack")

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


# Opens on Stats; right goes on to Inventory, and left twice comes round to Map.
func _scenario_pause_menu_pages(player: CharacterBody2D) -> bool:
	var content := player.get_parent().get_node(
		"CanvasLayer/PauseMenu/CenterContainer/MenuPanel/MarginContainer/VBoxContainer/ContentRoot"
	)
	var shown := func() -> Array:
		return content.get_children().filter(func(panel: Control) -> bool: return panel.visible)
	await _tap(&"pause")
	await _frames(2)
	var valid: bool = paused and shown.call() == [content.get_node("StatsPanel")]
	await _tap(&"ui_right")
	await _frames(2)
	valid = valid and shown.call() == [content.get_node("InventoryPanel")]
	await _tap(&"ui_left")
	await _tap(&"ui_left")
	await _frames(2)
	valid = valid and shown.call() == [content.get_node("MapPanel")]
	await _tap(&"pause")
	await _frames(2)
	return valid and not paused


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
	# Walking from where Vael wakes, across the beach and down the shore's two slopes into the
	# shallows, keeps to the ground all the way, then reaches the wall and stops there.
	_press(&"move_left")
	var airborne := 0
	for frame in WEST_WALK_FRAMES:
		await _frames(1)
		if not player.is_on_floor():
			airborne += 1
	_release(&"move_left")
	await _frames(2)
	var valid := airborne == 0 and player.is_on_floor() and player.global_position.x >= 0.0
	valid = valid and player.global_position.x < 12.0
	valid = valid and absf(player.global_position.y - SHALLOWS_Y) < ON_SAND_TOLERANCE
	return valid
