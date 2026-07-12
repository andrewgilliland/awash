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
	_add_action_if_missing("melee_attack")
	_add_action_if_missing("ranged_attack")
	_add_action_if_missing("interact")
	_add_action_if_missing("pause")
	_add_action_if_missing("map")

	_add_key("move_left", Key.LEFT)
	_add_key("move_left", Key.A)
	_add_key("move_right", Key.RIGHT)
	_add_key("move_right", Key.D)
	_add_key("move_up", Key.UP)
	_add_key("move_up", Key.W)
	_add_key("move_down", Key.DOWN)
	_add_key("move_down", Key.S)
	_add_key("jump", Key.SPACE)
	_add_key("jump", Key.C)
	_add_key("melee_attack", Key.X)
	_add_key("ranged_attack", Key.V)
	_add_key("interact", Key.E)
	_add_key("pause", Key.ESCAPE)
	_add_key("map", Key.TAB)

	# Xbox/PlayStation style defaults.
	_add_button("jump", 0)
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
