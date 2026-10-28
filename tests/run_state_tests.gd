extends RefCounted

const RunStateScript := preload("res://scripts/core/run_state.gd")


func get_tests() -> Array:
	return [
		["Run begins in the first Waking Coast Room", _test_begins_in_waking_coast],
		["Run enters a Room at an Entry", _test_enters_room_at_entry],
		["Run starts over in the first Waking Coast Room", _test_starts_over],
		["Run ignores an empty Room or Entry", _test_ignores_empty_ids],
	]


func _test_begins_in_waking_coast() -> bool:
	var run := RunStateScript.new()
	var valid := run.room_id == &"waking_coast_1" and run.entry_id == &"start"
	valid = valid and run.has_visited_room(&"waking_coast_1")
	valid = valid and not run.has_visited_room(&"room_2")
	run.free()
	return valid


func _test_enters_room_at_entry() -> bool:
	var run := RunStateScript.new()
	run.enter_room(&"room_2", &"west_door")
	var valid := run.room_id == &"room_2" and run.entry_id == &"west_door"
	valid = valid and run.has_visited_room(&"room_2") and run.has_visited_room(&"waking_coast_1")
	run.free()
	return valid


func _test_starts_over() -> bool:
	var run := RunStateScript.new()
	run.enter_room(&"room_2", &"west_door")
	run.start_run()
	var valid := run.room_id == &"waking_coast_1" and run.entry_id == &"start"
	valid = valid and run.has_visited_room(&"waking_coast_1")
	valid = valid and not run.has_visited_room(&"room_2")
	run.free()
	return valid


func _test_ignores_empty_ids() -> bool:
	var run := RunStateScript.new()
	run.enter_room(&"", &"west_door")
	run.enter_room(&"room_2", &"")
	var valid := run.room_id == &"waking_coast_1" and run.entry_id == &"start"
	valid = valid and not run.has_visited_room(&"") and not run.has_visited_room(&"room_2")
	run.free()
	return valid
