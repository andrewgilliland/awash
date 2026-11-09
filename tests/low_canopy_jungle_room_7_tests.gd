extends RefCounted

# The root hollow: three screens down inside a giant hollow root off the Shrinekeeper Camp's east
# end, root ledges and earth zigzagging down to its foot, a Stalker perched on a shelf partway.
# Its way east to Smuggler Inlet waits for that Region to be planned.

const ROOM_ID := &"low_canopy_jungle_7"
const ROOM_PATH := "res://scenes/rooms/low_canopy_jungle_7.tscn"
const Checks := preload("res://tests/jungle_room_checks.gd")
const RoomEnemies := preload("res://tests/room_enemies.gd")
const World := preload("res://scripts/core/world.gd")
const DEN_BACKGROUND := "res://scenes/regions/low_canopy_jungle/den_background.tscn"
const ROOM_CELLS := Vector2i(10, 27)
const TILE := 16
# Level with the camp's floor; and the hollow's foot, three screens down.
const WEST_ENTRY := Vector2(12, 96)
const FOOT := Vector2(80, 384)
# Its Stalker's perch, on the shelf partway down.
const STALKER_PERCH := Vector2(136, 256)


func get_tests() -> Array:
	return [
		["The root hollow lays out three screens, one above another", _test_three_screens],
		["The root hollow's west Entry stands level with the camp's floor", _test_west],
		["Root ledges zigzag down to the hollow's foot, a jump apart back up", _test_climbs],
		["A Stalker perches on a shelf partway down", _test_stalker],
		["The hollow is walled where it has no Exit, and dark inside", _test_walls],
	]


func _test_three_screens() -> bool:
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
	var valid := Checks.entry_leads(room, &"west", WEST_ENTRY, &"shrinekeeper_camp_1", &"east")
	room.free()
	return valid


func _test_climbs() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var valid := Checks.reaches(room, WEST_ENTRY, FOOT) and Checks.reaches(room, FOOT, WEST_ENTRY)
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
	valid = valid and Checks.reaches(room, WEST_ENTRY, STALKER_PERCH)
	room.free()
	return valid


# The west side walled below the top screen, the east all the way down; no Exit east, and the
# jungle's dark den behind it.
func _test_walls() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var height := float(ROOM_CELLS.y * TILE)
	var west := room.get_node_or_null("Bounds/West") as CollisionShape2D
	var east := room.get_node_or_null("Bounds/East") as CollisionShape2D
	var valid := west != null and east != null and room.get_node_or_null("Exits/east") == null
	if valid:
		var west_span := (west.shape as RectangleShape2D).size.y
		var east_span := (east.shape as RectangleShape2D).size.y
		valid = west.position.y - west_span / 2.0 >= World.SCREEN_SIZE.y
		valid = valid and west.position.y + west_span / 2.0 >= height
		valid = valid and east_span >= height
	valid = valid and World.background(ROOM_ID) == DEN_BACKGROUND
	room.free()
	return valid
