extends RefCounted

# The lower terraces: six screens, three by two, of the shrine keepers' medicine beds, climbing east
# behind broken stone walls, with a ruined relief of wardens carrying the Book on a terrace above,
# and east off a plank deck over the top bed into the canopy walk; and down through a hole in its
# floor into the Spore Beast's lair.

const ROOM_ID := &"low_canopy_jungle_2"
const ROOM_PATH := "res://scenes/rooms/low_canopy_jungle_2.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
const World := preload("res://scripts/core/world.gd")
const ROOM_SIZE := Vector2i(480, 288)
const TILE := 16
const SHEET := "res://assets/regions/low_canopy_jungle/tiles/low_canopy_jungle.png"
# Level with the harbour trail's end, a screen down.
const WEST_ENTRY := Vector2(12, 208)
# The lowest bed's floor, then each bed above it: its front, a column of stone wall from its top
# down to the bed below.
const LOW_BED_ROW := 15
const BEDS: Array[Vector3i] = [
	Vector3i(18, 13, 14), Vector3i(21, 11, 12), Vector3i(24, 9, 10), Vector3i(27, 7, 8)
]
# The sheet's stone: its mossy caps and its blocks.
const STONE := Rect2i(5, 0, 4, 2)
# The relief, two by two, standing on the high terrace.
const RELIEF := Rect2i(12, 4, 2, 2)
const RELIEF_TILES := Vector2i(8, 5)
# Up on the plank deck over the top bed, at the canopy walk's height.
const EAST_ENTRY := Vector2(468, 80)
# The hole in the floor over the lair, in the middle screen below, and the Entry on the step at its
# rim that the climb out of the lair arrives by.
const HOLE := Vector2i(14, 15)
const SOUTH_ENTRY := Vector2(216, 272)


func get_tests() -> Array:
	return [
		[
			"The lower terraces lay out six screens, three by two, holed over the lair",
			_test_six_screens
		],
		["The lower terraces' west Entry stands level with the trail's end", _test_west],
		["The medicine beds climb east behind stone walls, a jump at a time", _test_beds],
		["A ruined relief of wardens carrying the Book stands on a terrace", _test_relief],
		["The terraces open east off the deck, onto the canopy walk", _test_east],
		["A hole in the floor drops into the Spore Beast's lair", _test_hole],
	]


static func _room() -> Node2D:
	var packed_scene := load(ROOM_PATH) as PackedScene if ResourceLoader.exists(ROOM_PATH) else null
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node2D


func _test_six_screens() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := terrain.get_used_rect().end == ROOM_SIZE / TILE
	for column in range(ROOM_SIZE.x / TILE):
		var filled := terrain.get_cell_source_id(Vector2i(column, ROOM_SIZE.y / TILE - 1)) != -1
		valid = valid and filled == (column < HOLE.x or column > HOLE.y)
	room.free()
	return valid


func _test_west() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var entry := room.get_node_or_null("Entries/west") as Marker2D
	var valid := entry != null and entry.position == WEST_ENTRY
	var below := Vector2i(WEST_ENTRY / TILE)
	valid = valid and terrain.get_cell_source_id(below) != -1
	valid = valid and terrain.get_cell_source_id(below + Vector2i.UP) == -1
	var exit := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and exit != null and exit.position.x < 0.0
	valid = valid and int(exit.position.y / World.SCREEN_SIZE.y) == 1
	valid = valid and exit.get("room_id") == &"low_canopy_jungle_1"
	valid = valid and exit.get("entry_id") == &"east"
	room.free()
	return valid


# Each bed's top is reached from the Entry, and its front, facing the way up, is stone.
func _test_beds() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	var valid := true
	var last_top := LOW_BED_ROW
	for bed in BEDS:
		valid = valid and bed.y < last_top and last_top - bed.y <= RoomReach.jump_rows()
		last_top = bed.y
		valid = valid and RoomReach.span_at(reached, Vector2i(bed.x, bed.y)) != null
		for row in range(bed.y, bed.z + 1):
			valid = valid and _stone(terrain, Vector2i(bed.x, row))
		valid = valid and terrain.get_cell_source_id(Vector2i(bed.x - 1, bed.y)) == -1
	room.free()
	return valid


func _test_relief() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var ruins := room.get_node_or_null("Ruins") as TileMapLayer
	var valid := ruins != null
	for x in range(RELIEF.size.x):
		for y in range(RELIEF.size.y):
			var cell := RELIEF.position + Vector2i(x, y)
			valid = valid and ruins != null
			valid = valid and ruins.get_cell_atlas_coords(cell) == RELIEF_TILES + Vector2i(x, y)
			valid = valid and terrain.get_cell_source_id(cell) == -1
	var foot := Vector2i(RELIEF.position.x, RELIEF.end.y)
	valid = valid and _stone(terrain, foot)
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	valid = valid and RoomReach.span_at(reached, foot) != null
	room.free()
	return valid


# The deck runs over the top bed to the east edge: up onto it from the bed, and off it east.
func _test_east() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var entry := room.get_node_or_null("Entries/east") as Marker2D
	var valid := entry != null and entry.position == EAST_ENTRY
	valid = valid and room.get_node_or_null("Bounds/East") == null
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	valid = valid and RoomReach.span_at(reached, Vector2i(EAST_ENTRY / TILE)) != null
	var exit := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and exit != null and exit.position.x > ROOM_SIZE.x
	valid = valid and int(exit.position.y / World.SCREEN_SIZE.y) == 0
	valid = valid and exit.get("room_id") == &"low_canopy_jungle_3"
	valid = valid and exit.get("entry_id") == &"west"
	room.free()
	return valid


# The hole through the floor's every row, an Exit under it down into the lair, and the Entry at its
# rim on the floor, walked to from the west Entry.
func _test_hole() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for column in range(HOLE.x, HOLE.y + 1):
		for row in range(LOW_BED_ROW, ROOM_SIZE.y / TILE):
			valid = valid and terrain.get_cell_source_id(Vector2i(column, row)) == -1
	var exit := room.get_node_or_null("Exits/south") as Area2D
	valid = valid and exit != null and exit.position.y > ROOM_SIZE.y
	if valid:
		var column := int(exit.position.x / TILE)
		valid = column >= HOLE.x and column <= HOLE.y
		valid = valid and exit.get("room_id") == &"low_canopy_jungle_5"
		valid = valid and exit.get("entry_id") == &"north"
	var entry := room.get_node_or_null("Entries/south") as Marker2D
	valid = valid and entry != null and entry.position == SOUTH_ENTRY
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	valid = valid and RoomReach.span_at(reached, Vector2i(SOUTH_ENTRY / TILE)) != null
	room.free()
	return valid


static func _stone(terrain: TileMapLayer, cell: Vector2i) -> bool:
	var atlas := terrain.tile_set.get_source(terrain.get_cell_source_id(cell))
	return (
		atlas is TileSetAtlasSource
		and (atlas as TileSetAtlasSource).texture.resource_path == SHEET
		and STONE.has_point(terrain.get_cell_atlas_coords(cell))
	)
