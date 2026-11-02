extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_6.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
# Two screens wide.
const ROOM_SIZE := Vector2i(320, 144)
const CELLS := Rect2i(0, 0, 20, 9)
const TILE := 16
# On the sand, clear of the west Exit, at the height of the graveyard's beach.
const WEST_ENTRY := Vector2(12, 96)
# On the heights by the gate, clear of the east Exit.
const EAST_ENTRY := Vector2(308, 48)
const WORLD_LAYER := 1
# The heights the trail climbs to, at the gate by the east edge.
const EAST_END := Vector2i(19, 3)
# The jungle's plants, two tiles tall: a sapling and a fern, top -> foot.
const PLANTS := {Vector2i(3, 22): Vector2i(3, 23), Vector2i(6, 22): Vector2i(6, 23)}
# Landmark cells from assets/regions/waking_coast/room_layouts/waking_coast_6.aseprite:
# layer -> {cell: atlas coords}.
const LANDMARKS := {
	# a palm on the beach before the trail: crown middle and base
	&"Trees": {Vector2i(2, 2): Vector2i(1, 18), Vector2i(2, 5): Vector2i(1, 19)},
	# the jungle thickening behind the trail: a wide bush's crown and roots
	&"Jungle": {Vector2i(8, 1): Vector2i(0, 25), Vector2i(8, 3): Vector2i(0, 27)},
	&"Terrain":
	{
		# the beach the trail leaves from
		Vector2i(0, 6): Vector2i(1, 11),
		Vector2i(3, 6): Vector2i(1, 11),
		# the trail, a step at a time up onto the heights
		Vector2i(4, 5): Vector2i(0, 13),
		Vector2i(7, 5): Vector2i(1, 13),
		Vector2i(8, 4): Vector2i(0, 13),
		Vector2i(12, 3): Vector2i(0, 13),
		Vector2i(19, 3): Vector2i(1, 13),
		# the earth under it
		Vector2i(10, 6): Vector2i(1, 14),
		Vector2i(15, 5): Vector2i(3, 14),
	},
	&"Props":
	{
		# saplings and ferns along the trail, and a pair at the gate
		Vector2i(6, 3): Vector2i(3, 22),
		Vector2i(10, 2): Vector2i(6, 22),
		Vector2i(16, 1): Vector2i(3, 22),
		Vector2i(18, 1): Vector2i(6, 22),
	},
}


func get_tests() -> Array:
	return [
		["Jungle trail Room lays out two screens", _test_lays_out_two_screens],
		["Jungle trail west Entry stands on the beach", _test_west_entry_on_beach],
		["Jungle trail climbs east a step at a time", _test_climbs_east],
		["Jungle plants line the trail", _test_plants_line_trail],
		["Jungle trail leads east to the Warden's gate", _test_leads_east],
	]


static func _room() -> Node2D:
	var packed_scene := load(ROOM_PATH) as PackedScene
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node2D


func _test_lays_out_two_screens() -> bool:
	var room := _room()
	if room == null:
		return false
	var valid := true
	for layer_name in LANDMARKS:
		var layer := room.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		if layer == null:
			room.free()
			return false
		var cells: Dictionary = LANDMARKS[layer_name]
		for cell in cells:
			valid = valid and layer.get_cell_atlas_coords(cell) == cells[cell]
	var terrain := room.get_node("Terrain") as TileMapLayer
	for column in range(CELLS.size.x):
		valid = valid and terrain.get_cell_source_id(Vector2i(column, CELLS.end.y - 1)) == 0
	room.free()
	return valid


func _test_west_entry_on_beach() -> bool:
	var room := _room()
	if room == null:
		return false
	var entry := room.get_node_or_null("Entries/west") as Marker2D
	var valid := entry != null and entry.position == WEST_ENTRY
	if valid:
		var terrain := room.get_node("Terrain") as TileMapLayer
		var below := Vector2i(entry.position / TILE)
		valid = terrain.get_cell_source_id(below) == 0
		valid = valid and terrain.get_cell_source_id(below + Vector2i.UP) == -1
	var exit := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and exit != null and exit.position.x < 0.0
	valid = valid and exit.get("room_id") == &"waking_coast_4" and exit.get("entry_id") == &"east"
	room.free()
	return valid


# Each step of the trail is one tile up from the last, so the climb never needs more than a
# small jump, and it reaches the heights at the east edge.
func _test_climbs_east() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	var valid := RoomReach.span_at(reached, EAST_END) != null
	var previous := _surface_row(terrain, 0)
	for column in range(1, CELLS.size.x):
		var surface := _surface_row(terrain, column)
		valid = valid and previous - surface <= 1
		previous = surface
	room.free()
	return valid


# The row of a column's topmost Terrain tile.
static func _surface_row(terrain: TileMapLayer, column: int) -> int:
	var row := 0
	while row < CELLS.end.y and terrain.get_cell_source_id(Vector2i(column, row)) == -1:
		row += 1
	return row


# Each plant is two tiles tall, its foot standing on the trail's surface.
func _test_plants_line_trail() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var props := room.get_node("Props") as TileMapLayer
	var plants := 0
	var valid := true
	for cell in props.get_used_cells():
		var top := props.get_cell_atlas_coords(cell)
		if top not in PLANTS:
			continue
		plants += 1
		var base := cell + Vector2i.DOWN
		valid = valid and props.get_cell_atlas_coords(base) == PLANTS[top]
		valid = valid and terrain.get_cell_source_id(base) == -1
		valid = valid and terrain.get_cell_source_id(base + Vector2i.DOWN) == 0
	room.free()
	return valid and plants == LANDMARKS[&"Props"].size()


# The heights run on east through the rune gate to the Warden's gate.
func _test_leads_east() -> bool:
	var room := _room()
	if room == null:
		return false
	var valid := room.get_node_or_null("Bounds") == null
	var exit := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and exit != null and exit.position.x > ROOM_SIZE.x
	valid = valid and exit.get("room_id") == &"waking_coast_7" and exit.get("entry_id") == &"west"
	var entry := room.get_node_or_null("Entries/east") as Marker2D
	valid = valid and entry != null and entry.position == EAST_ENTRY
	room.free()
	return valid
