extends RefCounted

# The canopy walk: two screens between two treehouse decks, joined by a rope bridge broken in its
# middle, over a forest floor a fall climbs back up from.

const ROOM_PATH := "res://scenes/rooms/low_canopy_jungle_3.tscn"
const Checks := preload("res://tests/jungle_room_checks.gd")
const RoomEnemies := preload("res://tests/room_enemies.gd")
# Where its Stalker crouches, clear of the Entries.
const STALKER_PERCH := Vector2(280, 80)
const ROOM_CELLS := Vector2i(20, 9)
# On each deck, at the height of the terraces' deck west of it.
const WEST_ENTRY := Vector2(12, 80)
const EAST_ENTRY := Vector2(308, 80)
# The bridge's two halves, and the gap between them.
const BRIDGE_ROW := 5
const BRIDGE_HALVES: Array[Vector2i] = [Vector2i(5, 8), Vector2i(11, 14)]
const BRIDGE_PLANK := Vector2i(6, 3)
const RAIL_ROW := 4
# Down on the forest floor, under the gap.
const FLOOR := Vector2(160, 128)


func get_tests() -> Array:
	return [
		["The canopy walk lays out two screens", _test_two_screens],
		["The canopy walk's west Entry stands on its deck, from the terraces", _test_west],
		["The canopy walk's east Entry stands on its deck, to the upper terraces", _test_east],
		["A rope bridge, broken in its middle, crosses between the decks", _test_bridge],
		["A fall from the bridge climbs back up to either deck", _test_climbs_back],
		["A Stalker perches on the east deck, over the bridge's far half", _test_stalker],
	]


func _test_two_screens() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := terrain.get_used_rect().end == ROOM_CELLS
	for column in range(ROOM_CELLS.x):
		valid = valid and terrain.get_cell_source_id(Vector2i(column, ROOM_CELLS.y - 1)) != -1
	room.free()
	return valid


func _test_west() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var valid := Checks.entry_leads(room, &"west", WEST_ENTRY, &"low_canopy_jungle_2", &"east")
	room.free()
	return valid


func _test_east() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var valid := Checks.entry_leads(room, &"east", EAST_ENTRY, &"low_canopy_jungle_4", &"west")
	room.free()
	return valid


# Its planks from deck to deck but for the gap, a rail of rope over each half, and a jump across
# the gap either way.
func _test_bridge() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var rails := room.get_node_or_null("Rails") as TileMapLayer
	var valid := rails != null
	for column in range(BRIDGE_HALVES[0].x, BRIDGE_HALVES[1].y + 1):
		var cell := Vector2i(column, BRIDGE_ROW)
		var on_bridge := column <= BRIDGE_HALVES[0].y or column >= BRIDGE_HALVES[1].x
		var plank := terrain.get_cell_atlas_coords(cell) == BRIDGE_PLANK
		valid = valid and plank == on_bridge
		valid = valid and on_bridge == (terrain.get_cell_source_id(cell) != -1)
		var railed := rails != null and rails.get_cell_source_id(Vector2i(column, RAIL_ROW)) != -1
		valid = valid and railed == on_bridge
	valid = valid and Checks.reaches(room, WEST_ENTRY, EAST_ENTRY)
	valid = valid and Checks.reaches(room, EAST_ENTRY, WEST_ENTRY)
	room.free()
	return valid


func _test_climbs_back() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var valid := Checks.reaches(room, FLOOR, WEST_ENTRY) and Checks.reaches(room, FLOOR, EAST_ENTRY)
	room.free()
	return valid


func _test_stalker() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var stalkers: Array = []
	if room.has_node("Enemies"):
		stalkers = room.get_node("Enemies").get_children()
	var valid := stalkers.size() == 1
	if valid:
		var stalker := stalkers[0] as Node2D
		valid = stalker.position == STALKER_PERCH and RoomEnemies.perches(terrain, stalker)
	room.free()
	return valid
