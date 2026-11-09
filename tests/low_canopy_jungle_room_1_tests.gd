extends RefCounted

# The harbour trail: two screens off Tidefen's landing, up past a waterfall into the trees, to the
# foot of the lower terraces.

const ROOM_PATH := "res://scenes/rooms/low_canopy_jungle_1.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
const ROOM_SIZE := Vector2i(320, 144)
const TILE := 16
# On the shore, level with Tidefen's landing.
const WEST_ENTRY := Vector2(12, 112)
# On the bank at the trail's end, level with the lower terraces' floor.
const EAST_ENTRY := Vector2(308, 64)
# The pool at the waterfall's foot, and the waterfall pouring into it from the bank above.
const POOL := Vector2i(5, 7)
const POOL_ROW := 7
const FALL_COLUMN := 7
const WATERFALL: Array[Vector2i] = [Vector2i(6, 4), Vector2i(6, 5), Vector2i(6, 6)]


func get_tests() -> Array:
	return [
		["The harbour trail lays out two screens", _test_two_screens],
		["The harbour trail's west Entry stands on its shore, from Tidefen", _test_west],
		["The harbour trail's east Entry stands on its bank, to the terraces", _test_east],
		["The harbour trail climbs from the shore past the waterfall", _test_climbs],
		["The harbour trail walks back down to the shore", _test_walks_back],
		["A waterfall pours off the bank into the trail's pool", _test_waterfall],
	]


static func _room() -> Node2D:
	var packed_scene := load(ROOM_PATH) as PackedScene if ResourceLoader.exists(ROOM_PATH) else null
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node2D


func _test_two_screens() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := terrain.get_used_rect().end == ROOM_SIZE / TILE
	for column in range(ROOM_SIZE.x / TILE):
		valid = valid and terrain.get_cell_source_id(Vector2i(column, ROOM_SIZE.y / TILE - 1)) != -1
	room.free()
	return valid


func _test_west() -> bool:
	return _entry_on_ground(&"west", WEST_ENTRY, &"tidefen_village_1", &"east")


func _test_east() -> bool:
	return _entry_on_ground(&"east", EAST_ENTRY, &"low_canopy_jungle_2", &"west")


func _entry_on_ground(side: StringName, at: Vector2, to: StringName, entry_id: StringName) -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var entry := room.get_node_or_null(NodePath("Entries/%s" % side)) as Marker2D
	var valid := entry != null and entry.position == at
	var below := Vector2i(at / TILE)
	valid = valid and terrain.get_cell_source_id(below) != -1
	valid = valid and terrain.get_cell_source_id(below + Vector2i.UP) == -1
	var exit := room.get_node_or_null(NodePath("Exits/%s" % side)) as Area2D
	var outside := exit != null and (exit.position.x < 0.0 or exit.position.x > ROOM_SIZE.x)
	valid = valid and outside and exit.get("room_id") == to and exit.get("entry_id") == entry_id
	room.free()
	return valid


func _test_climbs() -> bool:
	return _reaches(WEST_ENTRY, EAST_ENTRY)


func _test_walks_back() -> bool:
	return _reaches(EAST_ENTRY, WEST_ENTRY)


func _reaches(from: Vector2, to: Vector2) -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(from / TILE))
	var valid := RoomReach.span_at(reached, Vector2i(to / TILE)) != null
	room.free()
	return valid


# Its lip level with the bank's top, falling down the bank's side to the water.
func _test_waterfall() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var falls := room.get_node_or_null("Falls") as TileMapLayer
	var valid := falls != null
	for column in range(POOL.x, POOL.y + 1):
		valid = valid and RoomReach.is_water(terrain, Vector2i(column, POOL_ROW))
	var top := POOL_ROW - WATERFALL.size()
	for i in range(WATERFALL.size()):
		var cell := Vector2i(FALL_COLUMN, top + i)
		valid = valid and falls != null and falls.get_cell_atlas_coords(cell) == WATERFALL[i]
		valid = valid and terrain.get_cell_source_id(cell) == -1
	valid = valid and terrain.get_cell_source_id(Vector2i(FALL_COLUMN + 1, top)) != -1
	valid = valid and terrain.get_cell_source_id(Vector2i(FALL_COLUMN + 1, top - 1)) == -1
	room.free()
	return valid
