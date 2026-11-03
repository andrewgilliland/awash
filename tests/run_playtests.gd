extends "res://tests/fight_playtests.gd"

# The Run and its story with real input: a defeat keeps the Run, Health carries through an Exit,
# START begins a Run on Mara's intro, and Interact talks to her again.
# Part of the playtests tests/playtest_runner.gd runs: each file extends the one before it, from
# the harness on, so all of them share its helpers.

const START_SCREEN_PATH := "res://scenes/ui/start_screen.tscn"


# One Health left at the pool's edge: the next lunge defeats the Player. It falls where it lands
# and stops answering the controls, then wakes in the first Room with full Health, the Run kept.
func _playtest_defeat_keeps_run() -> bool:
	var player := await _enter_palm_shore()
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


# A hit taken in the palm shore is still taken after walking west into the first Room, and the
# Health bar there shows it.
func _playtest_health_carries() -> bool:
	var player := await _enter_palm_shore()
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


# From a Run left in the palm shore: the start screen's START begins a fresh Run.
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
