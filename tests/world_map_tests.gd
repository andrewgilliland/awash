extends RefCounted

const WorldMap := preload("res://scripts/core/world_map.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const VIEW_SIZE := Vector2(144, 54)
# Two made-up Rooms side by side: a one-screen cove, then a two-screen cliff.
const ROOMS := {
	&"cove": {cell = Vector2i(0, 0), size = Vector2i(1, 1), region = "Waking Coast"},
	&"cliffs": {cell = Vector2i(1, 0), size = Vector2i(2, 1), region = "Waking Coast"},
}
const SCREEN_CENTRE := Vector2(80, 72)


func get_tests() -> Array:
	return [
		["Map centres the current Room", _test_centres_current_room],
		["Map shows only visited Rooms", _test_shows_only_visited_rooms],
		["Map marks where the Player stands", _test_marks_player],
		["Map holds the Room every Run begins in", _test_holds_first_room],
	]


func _test_centres_current_room() -> bool:
	var layout := WorldMap.layout(ROOMS, &"cove", [&"cove"], SCREEN_CENTRE, VIEW_SIZE)
	return layout.current == Rect2(62, 18, 20, 18) and layout.region == "Waking Coast"


func _test_shows_only_visited_rooms() -> bool:
	var alone := WorldMap.layout(ROOMS, &"cove", [&"cove"], SCREEN_CENTRE, VIEW_SIZE)
	var both := WorldMap.layout(ROOMS, &"cove", [&"cove", &"cliffs"], SCREEN_CENTRE, VIEW_SIZE)
	var valid: bool = alone.blocks == [Rect2(62, 18, 20, 18)]
	valid = valid and both.blocks.size() == 2 and Rect2(82, 18, 40, 18) in both.blocks
	return valid


func _test_marks_player() -> bool:
	var corner := WorldMap.layout(ROOMS, &"cove", [&"cove"], Vector2.ZERO, VIEW_SIZE)
	var centre := WorldMap.layout(ROOMS, &"cove", [&"cove"], SCREEN_CENTRE, VIEW_SIZE)
	# The middle of the two-screen cliffs, which the Map centres on.
	var far := WorldMap.layout(ROOMS, &"cliffs", [&"cliffs"], Vector2(160, 72), VIEW_SIZE)
	var valid: bool = corner.dot == Vector2(62, 18) and centre.dot == Vector2(72, 27)
	valid = valid and far.dot == Vector2(72, 27)
	return valid


func _test_holds_first_room() -> bool:
	var room: Dictionary = WorldMap.ROOMS.get(RunStateScript.FIRST_ROOM_ID, {})
	return room.get("region", "") == "Waking Coast"
