extends RefCounted

# The shrine steps: two screens of worn stone steps climbing east under the canopy to the
# Shrinekeeper Camp's gate, swung open onto the camp.

const ROOM_PATH := "res://scenes/rooms/low_canopy_jungle_6.tscn"
const Checks := preload("res://tests/jungle_room_checks.gd")
const ROOM_CELLS := Vector2i(20, 9)
const TILE := 16
const SHEET := "res://assets/regions/low_canopy_jungle/tiles/low_canopy_jungle.png"
# Level with the upper terraces' top.
const WEST_ENTRY := Vector2(12, 80)
# The steps up, each its first column and top row, every one stone.
const STEPS: Array[Vector2i] = [Vector2i(5, 4), Vector2i(10, 3)]
const STONE := Rect2i(5, 0, 4, 2)
# The gate swung open against its post, a tile wide and three tall, on the top step at the east
# end; and the Entry past it, from the camp.
const GATE := Rect2i(17, 0, 1, 3)
const GATE_TILES := Vector2i(9, 8)
const GATE_FOOT := Vector2(264, 48)
const EAST_ENTRY := Vector2(308, 48)


func get_tests() -> Array:
	return [
		["The shrine steps lay out two screens", _test_two_screens],
		["The shrine steps' west Entry stands level with the terraces' top", _test_west],
		["Worn stone steps climb east to the camp's gate", _test_steps],
		["The camp's gate stands open at the east end, onto the camp", _test_gate],
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
	var valid := Checks.entry_leads(room, &"west", WEST_ENTRY, &"low_canopy_jungle_4", &"east")
	room.free()
	return valid


func _test_steps() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	var last_top := int(WEST_ENTRY.y / TILE)
	for step in STEPS:
		valid = valid and step.y < last_top
		last_top = step.y
		var atlas := terrain.tile_set.get_source(terrain.get_cell_source_id(step))
		valid = valid and atlas is TileSetAtlasSource
		valid = valid and (atlas as TileSetAtlasSource).texture.resource_path == SHEET
		valid = valid and STONE.has_point(terrain.get_cell_atlas_coords(step))
		valid = valid and terrain.get_cell_source_id(step + Vector2i.LEFT) == -1
	valid = valid and Checks.reaches(room, WEST_ENTRY, GATE_FOOT)
	valid = valid and Checks.reaches(room, GATE_FOOT, WEST_ENTRY)
	room.free()
	return valid


# The gate drawn open on the top step, and the way on past it into the camp.
func _test_gate() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var gate := room.get_node_or_null("Gate") as TileMapLayer
	var valid := gate != null
	for y in range(GATE.size.y):
		var cell := GATE.position + Vector2i(0, y)
		valid = (
			valid
			and gate != null
			and gate.get_cell_atlas_coords(cell) == GATE_TILES + Vector2i(0, y)
		)
	valid = valid and terrain.get_cell_source_id(Vector2i(GATE.position.x, GATE.end.y)) != -1
	valid = valid and room.get_node_or_null("Bounds/East") == null
	valid = valid and room.get_node_or_null("GateSign") == null
	valid = valid and Checks.entry_leads(room, &"east", EAST_ENTRY, &"shrinekeeper_camp_1", &"west")
	valid = valid and Checks.reaches(room, WEST_ENTRY, EAST_ENTRY)
	room.free()
	return valid
