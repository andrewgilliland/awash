extends RefCounted

const World := preload("res://scripts/core/world.gd")
const MapLayout := preload("res://scripts/ui/map_layout.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const VIEW_SIZE := Vector2(144, 54)
const COAST := Color("183931")
const REEF := Color("31254a")
# Made-up Rooms: a one-screen cove, then a two-screen cliff with a Boss on its second screen and a
# drop from it, and a planned reef in another Region past them.
const ROOMS := {
	&"cove":
	{
		cell = Vector2i(0, 0),
		size = Vector2i(1, 1),
		region = "Waking Coast",
		colour = COAST,
		exits = [{screen = Vector2i(0, 0), side = &"east"}],
		markers = {},
	},
	&"cliffs":
	{
		cell = Vector2i(1, 0),
		size = Vector2i(2, 1),
		region = "Waking Coast",
		colour = COAST,
		exits =
		[
			{screen = Vector2i(0, 0), side = &"west"},
			{screen = Vector2i(1, 0), side = &"south"},
		],
		markers = {&"boss": Vector2i(1, 0)},
	},
	&"reef":
	{
		cell = Vector2i(3, 0),
		size = Vector2i(1, 1),
		region = "Black Reef",
		colour = REEF,
		exits = [],
		markers = {},
		planned = true,
	},
}
const SCREEN_CENTRE := Vector2(80, 72)
# Where the cove and the cliffs sit on a Map centred on the cove.
const COVE := Rect2(62, 18, 20, 18)
const CLIFFS := Rect2(82, 18, 40, 18)


func get_tests() -> Array:
	return [
		["Map centres the current Room", _test_centres_current_room],
		["Map shows only visited Rooms", _test_shows_only_visited_rooms],
		["Map marks where the Player stands", _test_marks_player],
		["Map holds the Room every Run begins in", _test_holds_first_room],
		["Map fills each Room with its Region's colour", _test_region_colour],
		["Map walls each Room, with a gap at each Exit", _test_walls_with_exit_gaps],
		["Map draws faint lines between a Room's screens", _test_screen_lines],
		["Map marks a Boss or Rest point on its screen", _test_markers],
		["The whole World shows every Room, the planned ones in outline", _test_whole_world],
		["The whole World names each Region above its Rooms", _test_region_names],
	]


func _test_centres_current_room() -> bool:
	var layout := MapLayout.layout(ROOMS, &"cove", [&"cove"], SCREEN_CENTRE, VIEW_SIZE)
	return layout.current == COVE and layout.region == "Waking Coast"


func _test_shows_only_visited_rooms() -> bool:
	var alone := MapLayout.layout(ROOMS, &"cove", [&"cove"], SCREEN_CENTRE, VIEW_SIZE)
	var both := MapLayout.layout(ROOMS, &"cove", [&"cove", &"cliffs"], SCREEN_CENTRE, VIEW_SIZE)
	var valid: bool = _blocks(alone) == [COVE]
	valid = valid and _blocks(both).size() == 2 and CLIFFS in _blocks(both)
	return valid


func _test_marks_player() -> bool:
	var corner := MapLayout.layout(ROOMS, &"cove", [&"cove"], Vector2.ZERO, VIEW_SIZE)
	var centre := MapLayout.layout(ROOMS, &"cove", [&"cove"], SCREEN_CENTRE, VIEW_SIZE)
	# The middle of the two-screen cliffs, which the Map centres on.
	var far := MapLayout.layout(ROOMS, &"cliffs", [&"cliffs"], Vector2(160, 72), VIEW_SIZE)
	var valid: bool = corner.dot == Vector2(62, 18) and centre.dot == Vector2(72, 27)
	valid = valid and far.dot == Vector2(72, 27)
	return valid


func _test_holds_first_room() -> bool:
	return World.region_name(RunStateScript.FIRST_ROOM_ID) == "Waking Coast"


func _test_region_colour() -> bool:
	var layout := MapLayout.layout(ROOMS, &"cove", [&"cove", &"cliffs"], SCREEN_CENTRE, VIEW_SIZE)
	var valid: bool = true
	for room: Dictionary in layout.rooms:
		valid = valid and room.colour == COAST and room.current == (room.block == COVE)
	return valid


# The cove's east wall opens in its middle, where its Exit is; its other walls are whole. The
# cliffs open west on their first screen and down on their second.
func _test_walls_with_exit_gaps() -> bool:
	var layout := MapLayout.layout(ROOMS, &"cove", [&"cove", &"cliffs"], SCREEN_CENTRE, VIEW_SIZE)
	var cove := _room(layout, COVE)
	var cliffs := _room(layout, CLIFFS)
	var middle := COVE.get_center()
	var valid: bool = not _walled(cove, Vector2(COVE.end.x - 0.5, middle.y))
	valid = valid and _walled(cove, Vector2(COVE.end.x - 0.5, COVE.position.y + 1.5))
	valid = valid and _walled(cove, Vector2(COVE.position.x + 0.5, middle.y))
	valid = valid and _walled(cove, Vector2(middle.x, COVE.position.y + 0.5))
	valid = valid and _walled(cove, Vector2(middle.x, COVE.end.y - 0.5))
	valid = valid and not _walled(cliffs, Vector2(CLIFFS.position.x + 0.5, middle.y))
	valid = valid and not _walled(cliffs, Vector2(CLIFFS.position.x + 30, CLIFFS.end.y - 0.5))
	valid = valid and _walled(cliffs, Vector2(CLIFFS.position.x + 10, CLIFFS.end.y - 0.5))
	valid = valid and _walled(cliffs, Vector2(CLIFFS.end.x - 0.5, middle.y))
	# no wall between the cliffs' own two screens
	valid = valid and not _walled(cliffs, Vector2(CLIFFS.position.x + 20.5, middle.y))
	return valid


func _test_screen_lines() -> bool:
	var layout := MapLayout.layout(ROOMS, &"cliffs", [&"cliffs"], SCREEN_CENTRE, VIEW_SIZE)
	var cliffs: Dictionary = layout.rooms[0]
	var block: Rect2 = cliffs.block
	var cove := _room(MapLayout.layout(ROOMS, &"cove", [&"cove"], SCREEN_CENTRE, VIEW_SIZE), COVE)
	var lines: Array = cliffs.lines
	var valid: bool = lines.size() == 1 and cove.lines.is_empty()
	valid = valid and (lines[0] as Rect2).has_point(block.position + Vector2(20.5, 9))
	valid = valid and block.encloses(lines[0])
	return valid


func _test_markers() -> bool:
	var layout := MapLayout.layout(ROOMS, &"cliffs", [&"cliffs"], SCREEN_CENTRE, VIEW_SIZE)
	var cliffs: Dictionary = layout.rooms[0]
	var block: Rect2 = cliffs.block
	var second_screen := Rect2(block.position + Vector2(20, 0), MapLayout.CELL_SIZE)
	var markers: Array = cliffs.markers
	var valid: bool = markers.size() == 1 and markers[0].kind == &"boss"
	if valid:
		var at: Rect2 = markers[0].at
		valid = second_screen.encloses(at) and at.size == MapLayout.MARKER_SIZE
		valid = valid and (at.get_center() - second_screen.get_center()).length() <= 1.0
	return valid


func _test_whole_world() -> bool:
	var whole := MapLayout.whole(ROOMS)
	var valid: bool = whole.rooms.size() == ROOMS.size()
	var picture := Rect2(Vector2.ZERO, whole.size)
	for room: Dictionary in whole.rooms:
		valid = valid and picture.encloses(room.block) and not room.current
		valid = valid and room.planned == (room.colour == REEF)
	# laid out by their cells, side by side
	var blocks := _blocks(whole)
	blocks.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	valid = valid and blocks[1].position - blocks[0].position == Vector2(20, 0)
	valid = valid and blocks[2].position - blocks[1].position == Vector2(40, 0)
	return valid


func _test_region_names() -> bool:
	var whole := MapLayout.whole(ROOMS)
	var names := {}
	for label: Dictionary in whole.labels:
		names[label.text] = label.at
	var blocks := _blocks(whole)
	var valid: bool = names.size() == 2 and names.has("Waking Coast") and names.has("Black Reef")
	if valid:
		var coast: Vector2 = names["Waking Coast"]
		var reef: Vector2 = names["Black Reef"]
		var picture := Rect2(Vector2.ZERO, whole.size)
		valid = picture.has_point(coast) and picture.has_point(reef)
		# just above the Region's top-left Room
		valid = valid and coast.x == blocks.map(func(b: Rect2) -> float: return b.position.x).min()
		valid = valid and coast.y < blocks[0].position.y and reef.x > coast.x
	return valid


static func _blocks(layout: Dictionary) -> Array:
	return layout.rooms.map(func(room: Dictionary) -> Rect2: return room.block)


static func _room(layout: Dictionary, block: Rect2) -> Dictionary:
	for room: Dictionary in layout.rooms:
		if room.block == block:
			return room
	return {}


static func _walled(room: Dictionary, point: Vector2) -> bool:
	for wall: Rect2 in room.get("walls", []):
		if wall.has_point(point):
			return true
	return false
