extends Control

const HOME_PANEL := "HomePanel"

# Each menu button's Panel, paired by name in _ready: <Name>Button opens <Name>Panel.
var _panels: Dictionary = {}
var _opener: Button

@onready var _backdrop: ColorRect = $Backdrop
@onready var _menu_panel: Control = $CenterContainer/MenuPanel
@onready var _menu_buttons: Container = %MenuButtons
@onready var _content_root: Control = %ContentRoot
@onready var _resume_button: Button = %ResumeButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _panels.is_empty():
		_pair_panels()
		_resume_button.pressed.connect(_on_resume_button_pressed)
		_quit_button.pressed.connect(_on_quit_button_pressed)
	_apply_pause_state(get_tree().paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	_apply_pause_state(not get_tree().paused)


# A button without a matching Panel, or a Panel without a BackButton, is reported and disabled.
func _pair_panels() -> void:
	for button in _menu_buttons.get_children():
		if button is not Button:
			continue

		var panel_name := button.name.trim_suffix("Button") + "Panel"
		var panel := _content_root.get_node_or_null(panel_name) as Control
		var back_button := panel.get_node_or_null("BackButton") as Button if panel != null else null
		if back_button == null:
			push_error("Pause menu: '%s' has no %s with a BackButton." % [button.name, panel_name])
			button.disabled = true
			continue

		_panels[button] = panel
		button.pressed.connect(_open_panel.bind(button))
		back_button.pressed.connect(_show_home)


func _apply_pause_state(is_paused: bool) -> void:
	get_tree().paused = is_paused
	_backdrop.visible = is_paused
	_menu_panel.visible = is_paused
	if is_paused:
		_opener = null
		_show_home()


func _open_panel(button: Button) -> void:
	_opener = button
	_show_only(_panels[button])
	(_panels[button].get_node("BackButton") as Button).grab_focus()


# Shows Home and focuses the button that opened the last Panel, or the first one on pause.
func _show_home() -> void:
	_show_only(_content_root.get_node(HOME_PANEL))
	var focus_target := _opener if _opener != null else _first_menu_button()
	if focus_target != null:
		focus_target.grab_focus()


func _show_only(shown_panel: Control) -> void:
	for panel in _content_root.get_children():
		(panel as Control).visible = panel == shown_panel


func _first_menu_button() -> Button:
	for button in _menu_buttons.get_children():
		if button is Button and not button.disabled:
			return button
	return null


func _on_resume_button_pressed() -> void:
	if get_tree().paused:
		_apply_pause_state(false)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
