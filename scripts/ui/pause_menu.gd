extends Control

@onready var _backdrop: ColorRect = $Backdrop
@onready var _menu_panel: Control = $CenterContainer/MenuPanel
@onready var _menu_root: VBoxContainer = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer
@onready var _menu_buttons: HBoxContainer = _menu_root.get_node("MenuButtons") as HBoxContainer
@onready var _content_root: Control = _menu_root.get_node("ContentRoot") as Control
@onready var _stats_button: Button = _menu_buttons.get_node("StatsButton") as Button
@onready var _equipment_button: Button = _menu_buttons.get_node("EquipmentButton") as Button
@onready var _map_button: Button = _menu_buttons.get_node("MapButton") as Button
@onready var _home_panel: Control = _content_root.get_node("HomePanel") as Control
@onready var _stats_panel: Control = _content_root.get_node("StatsPanel") as Control
@onready var _equipment_panel: Control = _content_root.get_node("EquipmentPanel") as Control
@onready var _map_panel: Control = _content_root.get_node("MapPanel") as Control
@onready var _stats_back_button: Button = _stats_panel.get_node("BackButton") as Button
@onready var _equipment_back_button: Button = _equipment_panel.get_node("BackButton") as Button
@onready var _map_back_button: Button = _map_panel.get_node("BackButton") as Button
@onready var _resume_button: Button = _menu_root.get_node("ResumeButton") as Button
@onready var _quit_button: Button = _menu_root.get_node("QuitButton") as Button


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
	if not _stats_button.pressed.is_connected(_on_stats_button_pressed):
		_stats_button.pressed.connect(_on_stats_button_pressed)
	if not _equipment_button.pressed.is_connected(_on_equipment_button_pressed):
		_equipment_button.pressed.connect(_on_equipment_button_pressed)
	if not _map_button.pressed.is_connected(_on_map_button_pressed):
		_map_button.pressed.connect(_on_map_button_pressed)
	if not _stats_back_button.pressed.is_connected(_on_back_pressed):
		_stats_back_button.pressed.connect(_on_back_pressed)
	if not _equipment_back_button.pressed.is_connected(_on_back_pressed):
		_equipment_back_button.pressed.connect(_on_back_pressed)
	if not _map_back_button.pressed.is_connected(_on_back_pressed):
		_map_back_button.pressed.connect(_on_back_pressed)
	if not _resume_button.pressed.is_connected(_on_resume_button_pressed):
		_resume_button.pressed.connect(_on_resume_button_pressed)
	if not _quit_button.pressed.is_connected(_on_quit_button_pressed):
		_quit_button.pressed.connect(_on_quit_button_pressed)


func _apply_pause_state(is_paused: bool) -> void:
	get_tree().paused = is_paused
	_backdrop.visible = is_paused
	_menu_panel.visible = is_paused
	if is_paused:
		_show_home()
		_stats_button.grab_focus()


func _show_home() -> void:
	_home_panel.visible = true
	_stats_panel.visible = false
	_equipment_panel.visible = false
	_map_panel.visible = false


func _show_panel(panel_name: StringName) -> void:
	_home_panel.visible = false
	_stats_panel.visible = panel_name == &"stats"
	_equipment_panel.visible = panel_name == &"equipment"
	_map_panel.visible = panel_name == &"map"


func _on_stats_button_pressed() -> void:
	_show_panel(&"stats")
	_stats_back_button.grab_focus()


func _on_equipment_button_pressed() -> void:
	_show_panel(&"equipment")
	_equipment_back_button.grab_focus()


func _on_map_button_pressed() -> void:
	_show_panel(&"map")
	_map_back_button.grab_focus()


func _on_back_pressed() -> void:
	_show_home()
	_stats_button.grab_focus()


func _on_resume_button_pressed() -> void:
	if get_tree().paused:
		_apply_pause_state(false)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
