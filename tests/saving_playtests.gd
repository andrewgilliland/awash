extends RefCounted

# The Saved Run, played by tests/playtest_runner.gd with its harness: the real Rooms, start
# screen and Pause menu, with real input.

const TIDEFEN_PATH := "res://scenes/rooms/tidefen_village_1.tscn"
const FIRST_ROOM_PATH := "res://scenes/rooms/waking_coast_1.tscn"
const START_SCREEN_PATH := "res://scenes/ui/start_screen.tscn"
const GOLD := 17

# The runner: its input, frame and Room helpers.
var _harness: SceneTree


func _init(harness: SceneTree) -> void:
	_harness = harness


func get_playtests() -> Array:
	return [
		["Player quits in Tidefen and CONTINUEs there", _quit_and_continue],
		["START over a Saved Run asks; NO goes back, YES begins anew", _start_over],
	]


# In Tidefen with some Gold, the Player quits through the Pause menu (its quit swapped so the run
# goes on). The game starts afresh at the start screen, where CONTINUE, first on the menu, puts
# them back in Tidefen at the Entry they came in by, Gold and all.
func _quit_and_continue() -> bool:
	var player: CharacterBody2D = await _harness.call(
		"_enter_room", &"tidefen_village_1", &"west", TIDEFEN_PATH
	)
	if player == null:
		await _harness.call("_leave_scene")
		return false
	player.call("gain_gold", GOLD)
	var menu := _harness.current_scene.get_node("CanvasLayer/PauseMenu")
	menu.set("quit_game", func() -> void: pass)
	await _harness.call("_tap", &"pause")
	await _harness.call("_frames", 2)
	(menu.get_node("%QuitButton") as Button).emit_signal(&"pressed")
	# The game would have ended here, paused; the run goes on, so play does too.
	_harness.paused = false
	await _harness.call("_leave_scene")
	var screen := await _start_screen()
	var valid := (screen.get_node("UI/Menu/ContinueButton") as Button).has_focus()
	await _harness.call("_tap", &"ui_accept")
	var player_back: CharacterBody2D = await _arrive_in(TIDEFEN_PATH)
	valid = valid and player_back != null
	if valid:
		valid = player_back.get("gold") == GOLD
		var entry := _harness.current_scene.get_node("Entries/west") as Node2D
		valid = valid and absf(player_back.global_position.x - entry.global_position.x) < 4.0
	await _harness.call("_leave_scene")
	return valid


# With a Saved Run, START asks before starting over it. NO goes back to the menu; YES begins a
# new Run in the first Room, on Mara's intro.
func _start_over() -> bool:
	var run := _harness.root.get_node("RunState")
	run.call("enter_room", &"tidefen_village_1", &"west")
	run.call("save")
	var screen := await _start_screen()
	await _harness.call("_tap", &"ui_down")
	await _harness.call("_tap", &"ui_accept")
	await _harness.call("_frames", 2)
	var confirm := screen.get_node("UI/Confirm") as Control
	var no := confirm.get_node("%NoButton") as Button
	var valid := confirm.visible and no.has_focus()
	await _harness.call("_tap", &"ui_accept")
	await _harness.call("_frames", 2)
	var start := screen.get_node("UI/Menu/StartButton") as Button
	valid = valid and not confirm.visible and start.has_focus()
	await _harness.call("_tap", &"ui_accept")
	await _harness.call("_frames", 2)
	await _harness.call("_tap", &"ui_left")
	await _harness.call("_tap", &"ui_accept")
	valid = valid and await _arrive_in(FIRST_ROOM_PATH) != null
	var opened: bool = await _harness.call(
		"_frames_until", func() -> bool: return _harness.call("_dialogue_box").visible, 360
	)
	valid = valid and opened and _harness.call("_speaker") == "MARA"
	await _harness.call("_leave_scene")
	return valid


# A fresh launch: a new RunState's Run, at the start screen with its menu open.
func _start_screen() -> Node:
	_harness.root.get_node("RunState").call("start_run")
	_harness.change_scene_to_file(START_SCREEN_PATH)
	await _harness.call("_frames", 20)
	await _harness.call("_tap", &"ui_accept")
	await _harness.call("_frames", 2)
	return _harness.current_scene


func _arrive_in(path: String) -> CharacterBody2D:
	var arrived: bool = await _harness.call(
		"_frames_until",
		func() -> bool:
			var scene := _harness.current_scene
			return scene != null and scene.scene_file_path == path,
		_harness.get("TRANSITION_FRAME_LIMIT")
	)
	if not arrived:
		return null
	await _harness.call(
		"_frames_until",
		func() -> bool:
			var player: CharacterBody2D = _harness.call("_current_player")
			return player != null and player.is_on_floor(),
		_harness.get("SETTLE_FRAME_LIMIT")
	)
	return _harness.call("_current_player")
