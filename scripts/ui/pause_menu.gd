extends Control

# Each menu button's Panel, paired by name in _ready: <Name>Panel shows once <Name>Button takes
# focus, until another menu button does.
var _panels: Dictionary = {}

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


# A button without a matching Panel is reported, disabled and passed over. Left and right run
# round the rest, from the last back to the first; down leads to Resume, and up from Resume back
# to the button whose Panel is shown.
func _pair_panels() -> void:
	var paired: Array[Button] = []
	for button in _menu_buttons.get_children():
		if button is not Button:
			continue

		var panel_name := button.name.trim_suffix("Button") + "Panel"
		var panel := _content_root.get_node_or_null(panel_name) as Control
		if panel == null:
			push_error("Pause menu: '%s' has no %s." % [button.name, panel_name])
			button.disabled = true
			button.focus_mode = Control.FOCUS_NONE
			continue

		_panels[button] = panel
		button.focus_entered.connect(_on_menu_button_focused.bind(button))
		paired.append(button)

	for index in paired.size():
		var button := paired[index]
		button.focus_neighbor_left = button.get_path_to(paired[index - 1])
		button.focus_neighbor_right = button.get_path_to(paired[(index + 1) % paired.size()])
		button.focus_neighbor_bottom = button.get_path_to(_resume_button)


# Pausing opens on the first Panel.
func _apply_pause_state(is_paused: bool) -> void:
	get_tree().paused = is_paused
	_backdrop.visible = is_paused
	_menu_panel.visible = is_paused
	var first := _first_menu_button()
	if is_paused and first != null:
		_on_menu_button_focused(first)
		first.grab_focus()


func _on_menu_button_focused(button: Button) -> void:
	_show_only(_panels[button])
	_resume_button.focus_neighbor_top = _resume_button.get_path_to(button)


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
