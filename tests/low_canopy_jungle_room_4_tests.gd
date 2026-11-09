extends RefCounted

# The upper terraces: three screens up from the canopy walk to the shrine steps, beds and mossy
# ledges a jump apart, and high on its west side a chest on a shelf no single jump reaches: the
# jungle's gate for the Double Jump.

const ROOM_PATH := "res://scenes/rooms/low_canopy_jungle_4.tscn"
const Checks := preload("res://tests/jungle_room_checks.gd")
const RoomReach := preload("res://tests/room_reach.gd")
const ROOM_CELLS := Vector2i(10, 27)
const TILE := 16
# At the bottom, level with the canopy walk's deck; at the top, with the shrine steps.
const WEST_ENTRY := Vector2(12, 368)
const EAST_ENTRY := Vector2(148, 80)
# The shelf, its top row and columns, and its chest.
const SHELF := Vector3i(3, 0, 1)
const CHEST_ID := &"upper_terraces_chest"
# How many rows a jump and a second jump in the air would rise.
const DOUBLE_JUMP_ROWS := 4


func get_tests() -> Array:
	return [
		["The upper terraces lay out three screens, one above another", _test_three_screens],
		["The upper terraces' west Entry stands at its foot, from the canopy walk", _test_west],
		["The upper terraces' east Entry stands at its top, to the shrine steps", _test_east],
		["The upper terraces climb a jump at a time, and come back down", _test_climbs],
		["Its walls stand where it has no Exit", _test_walls],
		["A chest waits on a shelf a single jump can't reach, but a double one can", _test_shelf],
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
	var valid := Checks.entry_leads(room, &"west", WEST_ENTRY, &"low_canopy_jungle_3", &"east")
	room.free()
	return valid


func _test_east() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var valid := Checks.entry_leads(room, &"east", EAST_ENTRY, &"low_canopy_jungle_6", &"west")
	room.free()
	return valid


func _test_climbs() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var valid := Checks.reaches(room, WEST_ENTRY, EAST_ENTRY)
	valid = valid and Checks.reaches(room, EAST_ENTRY, WEST_ENTRY)
	room.free()
	return valid


# The west side walled above the bottom screen, the east below the top one.
func _test_walls() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var height := float(ROOM_CELLS.y * TILE)
	var west := room.get_node_or_null("Bounds/West") as CollisionShape2D
	var east := room.get_node_or_null("Bounds/East") as CollisionShape2D
	var valid := west != null and east != null
	if valid:
		var west_span := (west.shape as RectangleShape2D).size.y
		var east_span := (east.shape as RectangleShape2D).size.y
		valid = west.position.x < 0.0 and west.position.y - west_span / 2.0 <= 0.0
		valid = valid and west.position.y + west_span / 2.0 <= WEST_ENTRY.y - 2.0 * TILE
		valid = valid and east.position.x > ROOM_CELLS.x * TILE
		valid = valid and east.position.y + east_span / 2.0 >= height
		valid = valid and east.position.y - east_span / 2.0 >= EAST_ENTRY.y + 2.0 * TILE
	room.free()
	return valid


# No surface the Player reaches is a single jump below the shelf; one is within a double jump.
func _test_shelf() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	var valid := RoomReach.span_at(RoomReach.surfaces(terrain), Vector2i(SHELF.y, SHELF.x)) != null
	valid = valid and RoomReach.span_at(reached, Vector2i(SHELF.y, SHELF.x)) == null
	var within_double := false
	for span in reached:
		var gap := maxi(SHELF.y - span.z, span.y - SHELF.z) - 1
		within_double = (
			within_double or (gap <= RoomReach.JUMP_GAP and span.x - SHELF.x <= DOUBLE_JUMP_ROWS)
		)
	valid = valid and within_double
	var chest := room.get_node_or_null("HighChest") as Node2D
	valid = valid and chest != null and chest.get("cache_id") == CHEST_ID
	if valid:
		var foot := Vector2i(chest.position / TILE) + Vector2i.DOWN
		valid = foot.y == SHELF.x and foot.x >= SHELF.y and foot.x <= SHELF.z
	room.free()
	return valid
