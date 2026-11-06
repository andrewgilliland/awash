extends RefCounted

# The start screen and the Saved Run: CONTINUE takes it up, and START asks before starting over
# it.

const START_SCREEN := preload("res://scenes/ui/start_screen.tscn")

# Needs a root that is already in the tree: focus only works inside it.
var _root: Window
var _run: Node


func _init(root: Window) -> void:
	_root = root
	_run = root.get_node("RunState")


func get_tests() -> Array:
	return [
		["CONTINUE shows, first, only when there is a Saved Run", _test_continue_shows],
		["CONTINUE takes up the Saved Run, with no intro", _test_continue_resumes],
		["START over a Saved Run asks first, and NO goes back", _test_start_asks],
		["While it asks, pause does nothing and cancel goes back", _test_asking_input],
		["YES starts a new Run, with the intro", _test_yes_starts_over],
	]


func _test_continue_shows() -> bool:
	_clear_saved_run()
	var screen := _opened_screen()
	var valid := not _button(screen, "Continue").visible and _button(screen, "Start").has_focus()
	screen.free()
	_save_run()
	screen = _opened_screen()
	valid = valid and _button(screen, "Continue").visible
	valid = valid and _button(screen, "Continue").has_focus()
	valid = valid and _button(screen, "Continue").get_index() < _button(screen, "Start").get_index()
	screen.free()
	_clear_saved_run()
	return valid


func _test_continue_resumes() -> bool:
	_save_run()
	var screen := _opened_screen()
	_button(screen, "Continue").emit_signal(&"pressed")
	var valid: bool = _run.get("player_gold") == 12 and _run.get("room_id") == &"tidefen_village_1"
	valid = valid and not _run.get("intro_pending")
	screen.free()
	_clear_saved_run()
	return valid


func _test_start_asks() -> bool:
	_save_run()
	var screen := _opened_screen()
	_button(screen, "Start").emit_signal(&"pressed")
	var confirm := screen.get_node_or_null("UI/Confirm") as Control
	var valid := confirm != null and confirm.visible and not _menu(screen).visible
	if valid:
		var no := confirm.get_node("%NoButton") as Button
		valid = no.has_focus() and (confirm.get_node("%YesButton") as Button).visible
		valid = valid and not screen.get("_starting")
		no.emit_signal(&"pressed")
		valid = valid and not confirm.visible and _menu(screen).visible
		valid = valid and _button(screen, "Start").has_focus()
		valid = valid and _run.call("has_saved_run") and not _run.get("intro_pending")
	screen.free()
	_clear_saved_run()
	return valid


func _test_asking_input() -> bool:
	_save_run()
	var screen := _opened_screen()
	_button(screen, "Start").emit_signal(&"pressed")
	var confirm := screen.get_node("UI/Confirm") as Control
	screen.call("_unhandled_input", _action(&"pause"))
	var valid := confirm.visible and not _menu(screen).visible
	screen.call("_unhandled_input", _action(&"ui_cancel"))
	valid = valid and not confirm.visible and _button(screen, "Start").has_focus()
	screen.free()
	_clear_saved_run()
	return valid


func _test_yes_starts_over() -> bool:
	_save_run()
	var screen := _opened_screen()
	_button(screen, "Start").emit_signal(&"pressed")
	(screen.get_node("UI/Confirm/Choices/YesButton") as Button).emit_signal(&"pressed")
	var valid: bool = _run.get("intro_pending") and _run.get("player_gold") == 0
	valid = valid and _run.get("room_id") == &"waking_coast_1" and screen.get("_starting")
	screen.free()
	_clear_saved_run()
	return valid


# A Saved Run some way in, with 12 Gold; the Run itself goes back to a fresh one.
func _save_run() -> void:
	_run.call("start_run")
	_run.call("enter_room", &"tidefen_village_1", &"west")
	_run.set("player_gold", 12)
	_run.call("save")
	_run.call("start_run")


func _clear_saved_run() -> void:
	DirAccess.remove_absolute(_run.get("save_path"))
	_run.call("start_run")


# The start screen, past PRESS START with its menu open.
func _opened_screen() -> Node:
	var screen := START_SCREEN.instantiate()
	_root.add_child(screen)
	screen.call("_unhandled_input", _action(&"ui_accept"))
	return screen


func _menu(screen: Node) -> Control:
	return screen.get_node("UI/Menu") as Control


func _button(screen: Node, name: String) -> Button:
	return screen.get_node("UI/Menu/%sButton" % name) as Button


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
