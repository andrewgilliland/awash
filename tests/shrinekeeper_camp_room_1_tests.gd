extends RefCounted

# The Shrinekeeper Camp: the Low Canopy Jungle's Safe spoke, up in the canopy past the shrine
# steps. Down from its gate, a restored shrine with its bell, the Rest point, then mossy canvas
# shelters and herb racks, where the SHRINEKEEPER keeps the Shop, and on east into the root hollow.

const ROOM_ID := &"shrinekeeper_camp_1"
const ROOM_PATH := "res://scenes/rooms/shrinekeeper_camp_1.tscn"
const Checks := preload("res://tests/jungle_room_checks.gd")
const World := preload("res://scripts/core/world.gd")
const KEEPER_PATH := "res://scenes/npcs/trader.tscn"
const KEEPER_SHEET := "res://assets/npcs/shrinekeeper/shrinekeeper.png"
const ROOM_CELLS := Vector2i(20, 9)
const TILE := 16
# Level with the shrine steps' top.
const WEST_ENTRY := Vector2(12, 48)
# The camp's floor, a few steps down from the gate.
const FLOOR_ROW := 6
# The shrine, three tiles square, and its bell hung in its arch.
const SHRINE := Rect2i(7, 3, 3, 3)
const SHRINE_TILES := Vector2i(0, 8)
const BELL_CELL := Vector2i(8, 4)
const BELL_TILE := Vector2i(3, 8)
# The shelters and the herb racks: their top-left cells, and their tiles'.
const SHELTERS: Array[Vector2i] = [Vector2i(11, 4)]
const SHELTER_TILE := Vector2i(4, 8)
const RACKS: Array[Vector2i] = [Vector2i(15, 4), Vector2i(17, 4)]
const RACK_TILE := Vector2i(7, 8)
# On the floor at the east end.
const EAST_ENTRY := Vector2(308, 96)


func get_tests() -> Array:
	return [
		["The camp lays out two screens", _test_two_screens],
		["The camp's west Entry stands at its gate, from the shrine steps", _test_west],
		["Steps lead down from the gate to the camp's floor, and back up", _test_steps],
		["The restored shrine stands on the floor, its bell hung in its arch", _test_shrine],
		["The shrine's bell is the camp's Rest point", _test_rest_point],
		["Shelters and herb racks stand on the camp's floor", _test_shelters],
		["The SHRINEKEEPER keeps the camp's Shop among the shelters", _test_keeper],
		["The camp opens east off its floor into the root hollow", _test_east],
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
	var valid := Checks.entry_leads(room, &"west", WEST_ENTRY, &"low_canopy_jungle_6", &"east")
	room.free()
	return valid


func _test_steps() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var on_floor := Vector2(SHRINE.position.x * TILE + 8, FLOOR_ROW * TILE)
	var valid := Checks.reaches(room, WEST_ENTRY, on_floor)
	valid = valid and Checks.reaches(room, on_floor, WEST_ENTRY)
	room.free()
	return valid


func _test_shrine() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var camp := room.get_node_or_null("Camp") as TileMapLayer
	var props := room.get_node("Props") as TileMapLayer
	var valid := camp != null
	for x in range(SHRINE.size.x):
		for y in range(SHRINE.size.y):
			var cell := SHRINE.position + Vector2i(x, y)
			valid = valid and camp != null
			valid = valid and camp.get_cell_atlas_coords(cell) == SHRINE_TILES + Vector2i(x, y)
			valid = valid and terrain.get_cell_source_id(cell) == -1
		valid = (
			valid and terrain.get_cell_source_id(Vector2i(SHRINE.position.x + x, FLOOR_ROW)) != -1
		)
	valid = valid and props.get_cell_atlas_coords(BELL_CELL) == BELL_TILE
	room.free()
	return valid


# Rung at its foot: a Rest bell there, the Entry a defeat wakes the Player at beside it, both on the
# floor, and the Map marks the Rest point on the bell's screen.
func _test_rest_point() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var bell := room.get_node_or_null("RestBell") as Node2D
	var entry := room.get_node_or_null("Entries/bell") as Marker2D
	var floor_y := float(FLOOR_ROW * TILE)
	var valid := bell != null and entry != null
	if valid:
		valid = int(bell.position.x / TILE) == BELL_CELL.x and bell.position.y == floor_y
		valid = (
			valid and entry.position.y == floor_y and absf(entry.position.x - bell.position.x) < 16
		)
	var screen := Vector2i(Vector2(BELL_CELL * TILE) / World.SCREEN_SIZE)
	valid = valid and World.markers(ROOM_ID) == {&"rest": screen}
	room.free()
	return valid


func _test_shelters() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var camp := room.get_node_or_null("Camp") as TileMapLayer
	var valid := camp != null
	for spot: Array in [
		[SHELTERS, SHELTER_TILE, Vector2i(3, 2)], [RACKS, RACK_TILE, Vector2i(2, 2)]
	]:
		for at: Vector2i in spot[0]:
			var size: Vector2i = spot[2]
			for x in range(size.x):
				var foot := at + Vector2i(x, size.y - 1)
				valid = valid and camp != null
				valid = (
					valid and camp.get_cell_atlas_coords(foot) == spot[1] + Vector2i(x, size.y - 1)
				)
				valid = valid and terrain.get_cell_source_id(foot + Vector2i.DOWN) != -1
	room.free()
	return valid


func _test_keeper() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var keeper := room.get_node_or_null("Shrinekeeper") as Node2D
	var valid := keeper != null and keeper.scene_file_path == KEEPER_PATH
	if valid:
		valid = (
			keeper.get("speaker") == "SHRINEKEEPER" and keeper.get("stock_name") == &"CAMP_STOCK"
		)
		var sheet := keeper.get("sheet") as Texture2D
		valid = valid and sheet != null and sheet.resource_path == KEEPER_SHEET
		valid = valid and sheet.get_size() == Vector2(32, 16)
		valid = valid and keeper.position.x >= World.SCREEN_SIZE.x
		var under := Vector2i(keeper.position / TILE)
		valid = valid and terrain.get_cell_source_id(under) != -1
		valid = valid and terrain.get_cell_source_id(under + Vector2i.UP) == -1
	room.free()
	return valid


func _test_east() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var valid := room.get_node_or_null("Bounds/East") == null
	valid = valid and Checks.entry_leads(room, &"east", EAST_ENTRY, &"low_canopy_jungle_7", &"west")
	valid = valid and Checks.reaches(room, WEST_ENTRY, EAST_ENTRY)
	room.free()
	return valid
