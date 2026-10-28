extends Node2D

const RunStateScript := preload("res://scripts/core/run_state.gd")
const WorldMap := preload("res://scripts/core/world_map.gd")
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
@onready var _start_button: Button = $UI/Menu/StartButton
@onready var _quit_button: Button = $UI/Menu/QuitButton
@onready var _move_sound: AudioStreamPlayer = $Sounds/Move
@onready var _start_sound: AudioStreamPlayer = $Sounds/Start
@onready var _music: AudioStreamPlayer = $Music


func _ready() -> void:
	_menu.visible = false
	_prompt.visible = true
	_start_button.pressed.connect(_on_start_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	for button in [_start_button, _quit_button]:
		button.focus_entered.connect(_move_sound.play)
	get_tree().create_timer(MUSIC_DELAY).timeout.connect(_start_music)


func _process(delta: float) -> void:
	if not _prompt.visible:
		return
	_blink_time += delta
	_prompt.self_modulate.a = 1.0 if fmod(_blink_time, BLINK_TIME * 2.0) < BLINK_TIME else 0.0


func _unhandled_input(event: InputEvent) -> void:
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


func _open_menu() -> void:
	_prompt.visible = false
	_menu.visible = true
	_start_button.grab_focus()


# A new Run, in the first Room at its start Entry.
func _on_start_pressed() -> void:
	if _starting:
		return
	_starting = true
	_start_sound.play()
	create_tween().tween_property(_music, ^"volume_db", MUSIC_FADED_DB, START_PAUSE)
	var run := get_node_or_null("/root/RunState") as RunStateScript
	if run != null:
		run.start_run()
	await get_tree().create_timer(START_PAUSE).timeout
	var first_room: Dictionary = WorldMap.ROOMS[RunStateScript.FIRST_ROOM_ID]
	get_tree().change_scene_to_file(first_room.scene)


func _on_quit_pressed() -> void:
	get_tree().quit()
