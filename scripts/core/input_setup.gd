extends Node


# Keyboard + gamepad bootstrap so the project works immediately on first open.
func _ready() -> void:
	_register_inputs()


func _register_inputs() -> void:
	_add_action_if_missing("move_left")
	_add_action_if_missing("move_right")
	_add_action_if_missing("move_up")
	_add_action_if_missing("move_down")
	_add_action_if_missing("jump")
	_add_action_if_missing("guard")
	_add_action_if_missing("melee_attack")
	_add_action_if_missing("ranged_attack")
	_add_action_if_missing("interact")
	_add_action_if_missing("pause")
	_add_action_if_missing("map")

	_add_key("move_left", Key.KEY_LEFT)
	_add_key("move_left", Key.KEY_A)
	_add_key("move_right", Key.KEY_RIGHT)
	_add_key("move_right", Key.KEY_D)
	_add_key("move_up", Key.KEY_UP)
	_add_key("move_up", Key.KEY_W)
	_add_key("move_down", Key.KEY_DOWN)
	_add_key("move_down", Key.KEY_S)
	_add_key("jump", Key.KEY_SPACE)
	_add_key("guard", Key.KEY_C)
	_add_key("melee_attack", Key.KEY_X)
	_add_key("ranged_attack", Key.KEY_V)
	_add_key("interact", Key.KEY_E)
	_add_key("pause", Key.KEY_ESCAPE)
	_add_key("map", Key.KEY_TAB)

	# Xbox/PlayStation style defaults.
	_add_button("jump", 0)
	_add_button("guard", 4)
	_add_button("melee_attack", 2)
	_add_button("ranged_attack", 1)
	_add_button("interact", 3)
	_add_button("pause", 7)
	_add_button("map", 6)

	_add_axis("move_left", 0, -1.0)
	_add_axis("move_right", 0, 1.0)
	_add_axis("move_up", 1, -1.0)
	_add_axis("move_down", 1, 1.0)


func _add_action_if_missing(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)


func _add_key(action_name: StringName, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)


func _add_button(action_name: StringName, button_index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)


func _add_axis(action_name: StringName, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)
