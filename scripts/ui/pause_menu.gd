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
# round the rest, from the last back to the first; down leads through the shown Panel's rows to
# Resume, and up from Resume back the same way.
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
		var body := panel.get_node_or_null("Body")
		if body != null and body.has_signal(&"focus_rows_changed"):
			body.connect(&"focus_rows_changed", _on_focus_rows_changed.bind(button))
		paired.append(button)

	for index in paired.size():
		var button := paired[index]
		button.focus_neighbor_left = button.get_path_to(paired[index - 1])
		button.focus_neighbor_right = button.get_path_to(paired[(index + 1) % paired.size()])
		_link_down_from(button)


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
	_link_down_from(button)


# Down from a menu button runs through its Panel's rows, if it has any, then to Resume; up runs
# back the same way.
func _link_down_from(button: Button) -> void:
	var above: Control = button
	for row in _focus_rows(button):
		above.focus_neighbor_bottom = above.get_path_to(row)
		row.focus_neighbor_top = row.get_path_to(above)
		row.focus_neighbor_left = row.get_path_to(row)
		row.focus_neighbor_right = row.get_path_to(row)
		above = row
	above.focus_neighbor_bottom = above.get_path_to(_resume_button)
	_resume_button.focus_neighbor_top = _resume_button.get_path_to(above)


func _focus_rows(button: Button) -> Array:
	var body := (_panels[button] as Control).get_node_or_null("Body")
	return body.call("focus_rows") if body != null and body.has_method("focus_rows") else []


# A shown Panel's rows changed: relink them, and if the focused row went, focus its button.
func _on_focus_rows_changed(button: Button) -> void:
	if not (_panels[button] as Control).visible:
		return
	_link_down_from(button)
	if get_viewport().gui_get_focus_owner() == null:
		button.grab_focus()


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
