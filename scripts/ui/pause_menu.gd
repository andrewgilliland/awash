extends Control

@onready var _backdrop: ColorRect = $Backdrop
@onready var _menu_panel: Control = $CenterContainer/MenuPanel
@onready
var _resume_button: Button = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/ResumeButton
@onready
var _quit_button: Button = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_signals()
	_apply_pause_state(get_tree().paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	_apply_pause_state(not get_tree().paused)


func _connect_signals() -> void:
	if not _resume_button.pressed.is_connected(_on_resume_button_pressed):
		_resume_button.pressed.connect(_on_resume_button_pressed)
	if not _quit_button.pressed.is_connected(_on_quit_button_pressed):
		_quit_button.pressed.connect(_on_quit_button_pressed)


func _apply_pause_state(is_paused: bool) -> void:
	get_tree().paused = is_paused
	_backdrop.visible = is_paused
	_menu_panel.visible = is_paused
	if is_paused:
		_resume_button.grab_focus()


func _on_resume_button_pressed() -> void:
	if get_tree().paused:
		_apply_pause_state(false)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
