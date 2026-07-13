extends RefCounted

signal state_changed(previous_state: StringName, next_state: StringName)

var _current_state: StringName = &"idle"
var _state_names: Array[StringName] = [
	&"idle",
	&"walk",
	&"run",
	&"jump",
	&"fall",
	&"attack",
	&"crouch",
	&"guard",
	&"charge",
	&"hurt",
	&"dead"
]


func get_state() -> StringName:
	return _current_state


func set_state(next_state: StringName) -> void:
	if next_state == StringName("") or next_state == _current_state:
		return

	var previous_state := _current_state
	_current_state = next_state
	emit_signal("state_changed", previous_state, _current_state)


func set_state_by_id(state_id: int) -> void:
	if state_id < 0 or state_id >= _state_names.size():
		set_state(&"idle")
		return

	set_state(_state_names[state_id])
