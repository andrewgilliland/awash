extends "res://tests/coast_playtests.gd"

# Fights with real input: the Storm Wisp, the Wraith and the Scavenger, each struck down and each
# landing its hit, and the Brinecap a defeated one leaves.
# Part of the playtests tests/playtest_runner.gd runs: each file extends the one before it, from
# the harness on, so all of them share its helpers.

# Where to stand by the Storm Wisp: outside its arc but near enough to set it crackling, and
# close enough for the sword to reach it.
const WISP_WATCH_DISTANCE := 24.0
const WISP_STRIKE_DISTANCE := 14.0
const WISP_ARC_DISTANCE := 8.0
# Well out of the sword's reach, and of the Wisp's notice.
const WISP_CLEAR_DISTANCE := 60.0
const UNDERTOW_PATH := "res://scenes/rooms/waking_coast_9.tscn"
const WRAITH_PATH := "Enemies/Wraith"
const UNDERTOW_FLOOR_Y := 96.0
# Where to stand by the Wraith: near enough to draw out its lash, clear of the lash while it
# wails, and in sword reach of its anchor.
const WRAITH_BAIT_DISTANCE := 18.0
const WRAITH_CLEAR_DISTANCE := 40.0
const WRAITH_STRIKE_DISTANCE := 14.0
const BRINECAP_PATH := "res://scenes/items/brinecap.tscn"
# What any enemy hit costs the Player.
const ONE_HIT := 10
# What the Storm Wisp's arc and the Wraith's lash cost: stronger hits than the spear's.
const ARC_HIT := 15
const LASH_HIT := 15


# Waits out the Storm Wisp's crackle and arc just beyond its reach, then steps in while it rests
# and swings, until it is gone.
func _playtest_sword_disperses_wisp() -> bool:
	var player := await _enter_room(&"waking_coast_6", &"east", JUNGLE_TRAIL_PATH)
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
		await _swing()
	valid = valid and await _frames_until(func() -> bool: return not is_instance_valid(wisp), 90)
	await _leave_scene()
	return valid


# Stands inside the Storm Wisp's reach until its arc lands.
func _playtest_arc_hurts_player() -> bool:
	var player := await _enter_room(&"waking_coast_6", &"east", JUNGLE_TRAIL_PATH)
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
	var valid: bool = hurt and health.current == health.maximum - ARC_HIT
	await _leave_scene()
	return valid


# Presses melee well out of reach, so the slash meets nothing, and charges just beyond the Wisp's
# reach through its crackle and arc; then steps in while it rests and lets go: one Sword Beam.
func _playtest_charged_wisp() -> bool:
	var player := await _enter_room(&"waking_coast_6", &"east", JUNGLE_TRAIL_PATH)
	var wisp := (
		current_scene.get_node_or_null(STORM_WISP_PATH) as Node2D if player != null else null
	)
	if wisp == null:
		await _leave_scene()
		return false
	var brain = wisp.get("brain")
	var wisp_health = wisp.get("health")
	await _stand_by_wisp(player, wisp, WISP_CLEAR_DISTANCE)
	_press(&"melee_attack")
	await _frames(20)
	await _stand_by_wisp(player, wisp, WISP_WATCH_DISTANCE)
	var rested := await _frames_until(func() -> bool: return brain.state == brain.State.REST, 180)
	var controller = player.get("controller")
	var valid: bool = rested and controller.is_fully_charged()
	valid = valid and wisp_health.current == wisp_health.maximum
	var side := signf(player.global_position.x - wisp.global_position.x)
	player.global_position.x = wisp.global_position.x + side * WISP_STRIKE_DISTANCE
	await _frames(2)
	_release(&"melee_attack")
	valid = valid and await _frames_until(func() -> bool: return not is_instance_valid(wisp), 90)
	await _leave_scene()
	return valid


# Steps in to draw out the Wraith's lash, backs away while it wails, and steps back in to
# strike its anchor while it shows, until it is gone, untouched.
func _playtest_strikes_wraith() -> bool:
	var player := await _enter_room(&"waking_coast_9", &"west", UNDERTOW_PATH)
	var wraith := current_scene.get_node_or_null(WRAITH_PATH) as Node2D if player != null else null
	if wraith == null:
		await _leave_scene()
		return false
	var brain = wraith.get("brain")
	var health = player.get("health")
	for swing in MAX_SWINGS:
		if not is_instance_valid(wraith):
			break
		await _stand_by_wraith(player, wraith, WRAITH_BAIT_DISTANCE)
		await _frames_until(
			func() -> bool:
				return not is_instance_valid(wraith) or brain.state == brain.State.MANIFEST,
			180
		)
		if not is_instance_valid(wraith):
			break
		await _stand_by_wraith(player, wraith, WRAITH_CLEAR_DISTANCE)
		await _frames_until(func() -> bool: return brain.state == brain.State.EXPOSED, 120)
		await _stand_by_wraith(player, wraith, WRAITH_STRIKE_DISTANCE)
		await _swing()
	var valid := await _frames_until(func() -> bool: return not is_instance_valid(wraith), 90)
	valid = valid and health.current == health.maximum
	await _leave_scene()
	return valid


# Stands inside the Wraith's reach until its lash lands.
func _playtest_lash_hurts_player() -> bool:
	var player := await _enter_room(&"waking_coast_9", &"west", UNDERTOW_PATH)
	var wraith := current_scene.get_node_or_null(WRAITH_PATH) as Node2D if player != null else null
	if wraith == null:
		await _leave_scene()
		return false
	await _stand_by_wraith(player, wraith, WRAITH_BAIT_DISTANCE)
	var health = player.get("health")
	var hurt := await _frames_until(func() -> bool: return health.current < health.maximum, 180)
	await _frames(6)
	var valid: bool = hurt and health.current == health.maximum - LASH_HIT
	await _leave_scene()
	return valid


# Puts the Player on the floor a distance from the Wraith, on the side with more room in its
# haunt, facing it.
func _stand_by_wraith(player: CharacterBody2D, wraith: Node2D, distance: float) -> void:
	var side := 1.0 if wraith.global_position.x < 488.0 else -1.0
	var toward := &"move_left" if side > 0.0 else &"move_right"
	_press(toward)
	await _frames(1)
	_release(toward)
	player.global_position = Vector2(wraith.global_position.x + side * distance, UNDERTOW_FLOOR_Y)
	player.velocity = Vector2.ZERO
	await _frames(2)


# Puts the Player on the heights a distance to the Wisp's open side, facing it.
func _stand_by_wisp(player: CharacterBody2D, wisp: Node2D, distance: float) -> void:
	# Stand on the side away from the east edge, so the Player never steps into its Exit.
	var side := -1.0 if wisp.global_position.x > 256.0 else 1.0
	var toward := &"move_right" if side < 0.0 else &"move_left"
	_press(toward)
	await _frames(1)
	_release(toward)
	# A slash may have dispersed it in that frame.
	if not is_instance_valid(wisp):
		return
	player.global_position = Vector2(
		wisp.global_position.x + side * distance, JUNGLE_TRAIL_HEIGHTS_Y
	)
	player.velocity = Vector2.ZERO
	await _frames(2)


# Strikes the Scavenger down from the pool's edge; its Experience goes to the Player and into the
# Run.
func _playtest_sword_defeats_scavenger() -> bool:
	var player := await _enter_palm_shore()
	var scavenger := current_scene.get_node_or_null(SCAVENGER_PATH) if player != null else null
	var valid := scavenger != null
	var worth: int = scavenger.get("EXPERIENCE") if valid else 0
	var gold_worth: int = scavenger.get("GOLD") if valid else 0
	var run := root.get_node("RunState")
	var before: int = run.get("player_experience")
	var gold_before: int = run.get("player_gold")
	if valid:
		await _strike_down_scavenger(player, scavenger)
	valid = (
		valid and await _frames_until(func() -> bool: return not is_instance_valid(scavenger), 90)
	)
	valid = valid and worth > 0 and run.get("player_experience") == before + worth
	valid = valid and player.get("level").experience == before + worth
	valid = valid and gold_worth > 0 and run.get("player_gold") == gold_before + gold_worth
	await _leave_scene()
	return valid


# Stands still at the pool's edge until the Scavenger's lunge lands.
func _playtest_lunge_hurts_player() -> bool:
	var player := await _enter_palm_shore()
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


# With the Room's roll fixed to drop: strikes the Scavenger down, walks onto the Brinecap it
# leaves, then, hurt, pauses and chooses it in the Inventory to eat it back to 10 more Health.
func _playtest_brinecap_drop() -> bool:
	var player := await _enter_palm_shore()
	var scavenger := current_scene.get_node_or_null(SCAVENGER_PATH) if player != null else null
	var valid := scavenger != null
	if valid:
		current_scene.set("drop_roll", func() -> float: return 0.0)
	if valid:
		await _strike_down_scavenger(player, scavenger)
	var find_brinecap := func() -> Node2D:
		for node in current_scene.get_children():
			if node.scene_file_path == BRINECAP_PATH:
				return node
		return null
	valid = (
		valid
		and await _frames_until(
			func() -> bool:
				var brinecap: Node2D = find_brinecap.call()
				return brinecap != null and (brinecap as CharacterBody2D).is_on_floor(),
			120
		)
	)
	var supplies = player.get("supplies") if valid else null
	if valid:
		await _walk_to_x(player, (find_brinecap.call() as Node2D).global_position.x)
		valid = await _frames_until(func() -> bool: return supplies.count(&"brinecap") == 1, 60)
	valid = valid and find_brinecap.call() == null
	var health = player.get("health")
	if valid:
		health.hurt(20, 0.0)
		var hurt: int = health.current
		for action in [&"pause", &"ui_right", &"ui_down", &"ui_accept", &"pause"]:
			await _tap(action)
			await _frames(2)
		valid = health.current == hurt + 10 and supplies.count(&"brinecap") == 0
		valid = valid and not paused
	await _leave_scene()
	return valid
