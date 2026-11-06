extends Node2D

const RunStateScript := preload("res://scripts/core/run_state.gd")
const World := preload("res://scripts/core/world.gd")
const BLINK_TIME := 0.5
# Long enough for the start chime to finish before the first Room loads.
const START_PAUSE := 0.35
# How quiet the theme fades to under the start chime, and from when it starts.
const MUSIC_FADED_DB := -40.0
# The theme waits a moment after the screen appears, then fades in.
const MUSIC_DELAY := 0.25
const MUSIC_FADE_IN := 0.8
# Any of these opens the menu from the PRESS START prompt.
const OPEN_ACTIONS: Array[StringName] = [&"ui_accept", &"pause", &"jump"]

var _blink_time: float = 0.0
var _starting: bool = false

@onready var _prompt: Label = $UI/PressStart
@onready var _menu: Control = $UI/Menu
@onready var _continue_button: Button = $UI/Menu/ContinueButton
@onready var _start_button: Button = $UI/Menu/StartButton
@onready var _quit_button: Button = $UI/Menu/QuitButton
@onready var _confirm: Control = $UI/Confirm
@onready var _yes_button: Button = %YesButton
@onready var _no_button: Button = %NoButton
@onready var _move_sound: AudioStreamPlayer = $Sounds/Move
@onready var _start_sound: AudioStreamPlayer = $Sounds/Start
@onready var _music: AudioStreamPlayer = $Music


func _ready() -> void:
	_menu.visible = false
	_confirm.visible = false
	_prompt.visible = true
	_continue_button.pressed.connect(_on_continue_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_yes_button.pressed.connect(_start_new_run)
	_no_button.pressed.connect(_on_no_pressed)
	for button in [_continue_button, _start_button, _quit_button, _yes_button, _no_button]:
		button.focus_entered.connect(_move_sound.play)
	get_tree().create_timer(MUSIC_DELAY).timeout.connect(_start_music)


func _process(delta: float) -> void:
	if not _prompt.visible:
		return
	_blink_time += delta
	_prompt.self_modulate.a = 1.0 if fmod(_blink_time, BLINK_TIME * 2.0) < BLINK_TIME else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if _confirm.visible:
		if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
			_on_no_pressed()
			get_viewport().set_input_as_handled()
		return
	if _menu.visible:
		return
	for action in OPEN_ACTIONS:
		if event.is_action_pressed(action) and not event.is_echo():
			_open_menu()
			get_viewport().set_input_as_handled()
			return


func _start_music() -> void:
	if _starting or _music.playing:
		return
	var full_volume := _music.volume_db
	_music.volume_db = MUSIC_FADED_DB
	_music.play()
	create_tween().tween_property(_music, ^"volume_db", full_volume, MUSIC_FADE_IN)


# Opens on CONTINUE when there is a Saved Run to take up, and on START when there is not.
func _open_menu() -> void:
	_prompt.visible = false
	_menu.visible = true
	_continue_button.visible = _has_saved_run()
	(_continue_button if _continue_button.visible else _start_button).grab_focus()


func _has_saved_run() -> bool:
	var run := _run()
	return run != null and run.has_saved_run()


# A new Run, though over a Saved Run only once the player says YES to losing it.
func _on_start_pressed() -> void:
	if _starting:
		return
	if _has_saved_run():
		_menu.visible = false
		_confirm.visible = true
		_no_button.grab_focus()
		return
	_start_new_run()


func _on_no_pressed() -> void:
	_confirm.visible = false
	_menu.visible = true
	_start_button.grab_focus()


# A new Run, in the first Room at its start Entry, opening on the intro.
func _start_new_run() -> void:
	if _starting:
		return
	var run := _run()
	if run != null:
		run.start_run()
		run.intro_pending = true
	_leave_for(RunStateScript.FIRST_ROOM_ID)


# The Saved Run, taken up where it was saved.
func _on_continue_pressed() -> void:
	if _starting:
		return
	var run := _run()
	if run != null and run.continue_saved_run():
		_leave_for(run.room_id)


# Plays the start chime over the fading theme, then loads the Room.
func _leave_for(room_id: StringName) -> void:
	_starting = true
	_start_sound.play()
	create_tween().tween_property(_music, ^"volume_db", MUSIC_FADED_DB, START_PAUSE)
	await get_tree().create_timer(START_PAUSE).timeout
	get_tree().change_scene_to_file(World.scene(room_id))


func _run() -> RunStateScript:
	return get_node_or_null("/root/RunState") as RunStateScript if is_inside_tree() else null


func _on_quit_pressed() -> void:
	get_tree().quit()
