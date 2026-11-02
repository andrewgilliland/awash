extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_4.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
# Two screens wide.
const ROOM_SIZE := Vector2i(320, 144)
const CELLS := Rect2i(0, 0, 20, 9)
const TILE := 16
# On the cliff top, clear of the west Exit, at the height the salt cliffs' top leaves off.
const WEST_ENTRY := Vector2(12, 64)
# On the sand just short of the sinkhole, coming back from the jungle trail.
const EAST_ENTRY := Vector2(296, 96)
# The east edge: a wall from just under a standing Player's feet down, and the Exit from the
# top down to just above a standing Player's head (it is 20 pixels tall).
const EAST_WALL_TOP := 88
const EAST_EXIT_BOTTOM := 72
const WORLD_LAYER := 1
const DECKS := [Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6)]
# The beach's east end, where the sand gives way into the sea cave, and the stern
# compartment's deck with its crate.
const EAST_END := Vector2i(18, 6)
const SINKHOLE_COLUMN := 19
const STERN_DECK := Vector2i(17, 1)
const STERN_CRATE := Vector2i(18, 0)
const CRATE := Vector2i(10, 3)
# Landmark cells from assets/regions/waking_coast/room_layouts/waking_coast_4.aseprite:
# layer -> {cell: atlas coords}.
const LANDMARKS := {
	# a jungle tree on the cliff top, where the jungle starts: crown and roots
	&"Jungle": {Vector2i(0, 0): Vector2i(7, 1), Vector2i(0, 3): Vector2i(7, 4)},
	&"Wreck":
	{
		# a low hull, a broken mast, a taller hull, and the stern standing on end
		Vector2i(7, 5): Vector2i(2, 2),
		Vector2i(8, 0): Vector2i(12, 9),
		Vector2i(11, 4): Vector2i(12, 9),
		Vector2i(14, 4): Vector2i(3, 2),
		Vector2i(16, 2): Vector2i(2, 2),
		Vector2i(18, 5): Vector2i(4, 2),
	},
	&"Terrain":
	{
		# the cliff the salt cliffs' top runs on to, and a ledge down from it
		Vector2i(0, 4): Vector2i(3, 13),
		Vector2i(2, 4): Vector2i(5, 13),
		Vector2i(3, 5): Vector2i(4, 4),
		# two tidal pools between wet edges, with a sand bar between them
		Vector2i(6, 6): Vector2i(2, 1),
		Vector2i(8, 6): Vector2i(2, 1),
		Vector2i(10, 6): Vector2i(3, 1),
		Vector2i(11, 6): Vector2i(4, 1),
		Vector2i(14, 6): Vector2i(2, 1),
		Vector2i(16, 6): Vector2i(3, 1),
		# decks on the wrecks, up to the stern
		Vector2i(7, 4): Vector2i(1, 6),
		Vector2i(10, 3): Vector2i(1, 6),
		Vector2i(15, 3): Vector2i(4, 6),
		Vector2i(16, 1): Vector2i(1, 6),
	},
	&"Props": {STERN_CRATE: CRATE},
}


func get_tests() -> Array:
	return [
		["Wreck graveyard Room lays out two screens", _test_lays_out_two_screens],
		["Wreck graveyard west Entry stands on the cliff", _test_west_entry_on_cliff],
		["Wreck graveyard leads east over the sinkhole", _test_leads_east],
		["Wreck graveyard beach runs east without the decks", _test_beach_runs_east],
		["Wreck decks lead up to the stern's crate", _test_decks_reach_stern],
		["A Scavenger wades the wreck graveyard's second pool", _test_scavenger_in_pool],
		["A sinkhole at the beach's east end drops into the sea cave", _test_sinkhole],
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
		var filled := terrain.get_cell_source_id(Vector2i(column, CELLS.end.y - 1)) != -1
		valid = valid and filled == (column != SINKHOLE_COLUMN)
	room.free()
	return valid


func _test_west_entry_on_cliff() -> bool:
	var room := _room()
	if room == null:
		return false
	var entry := room.get_node_or_null("Entries/west") as Marker2D
	var valid := entry != null and entry.position == WEST_ENTRY
	if valid:
		var terrain := room.get_node("Terrain") as TileMapLayer
		var below := Vector2i(entry.position / TILE)
		valid = terrain.get_cell_source_id(below) != -1
		valid = valid and terrain.get_cell_source_id(below + Vector2i.UP) == -1
	room.free()
	return valid


# A jump over the sinkhole carries on east onto the jungle trail. Below the sand's height the east
# edge stays walled, and the Exit sits only above a standing Player's head, so walking off the
# sand falls into the sinkhole rather than out east. The west edge is the Exit back to the salt
# cliffs' top. Coming back, the Player lands short of the sinkhole.
func _test_leads_east() -> bool:
	var room := _room()
	if room == null:
		return false
	var bounds := room.get_node_or_null("Bounds") as StaticBody2D
	var valid := bounds != null and bounds.collision_layer == WORLD_LAYER
	var wall := bounds.get_node_or_null("EastLow") as CollisionShape2D if valid else null
	valid = valid and wall != null and wall.position.x > ROOM_SIZE.x - TILE
	valid = valid and _vertical_span(wall) == Vector2(EAST_WALL_TOP, ROOM_SIZE.y)
	var east_exit := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and east_exit != null and east_exit.position.x > ROOM_SIZE.x
	if valid:
		var edge := east_exit.get_node("Edge") as CollisionShape2D
		valid = _vertical_span(edge) == Vector2(0, EAST_EXIT_BOTTOM)
	valid = valid and east_exit.get("room_id") == &"waking_coast_6"
	valid = valid and east_exit.get("entry_id") == &"west"
	var entry := room.get_node_or_null("Entries/east") as Marker2D
	valid = valid and entry != null and entry.position == EAST_ENTRY
	if valid:
		var terrain := room.get_node("Terrain") as TileMapLayer
		var below := Vector2i(entry.position / TILE)
		valid = terrain.get_cell_source_id(below) != -1 and below.x < SINKHOLE_COLUMN
	var exit := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and exit != null and exit.position.x < 0.0
	valid = valid and exit.get("room_id") == &"waking_coast_3" and exit.get("entry_id") == &"east"
	room.free()
	return valid


# The main way east is the beach, wading the pools: it needs none of the decks.
func _test_beach_runs_east() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE), DECKS)
	room.free()
	return RoomReach.span_at(reached, EAST_END) != null


# The stern is off the main way: only the decks, a jump at a time, lead up to its crate.
func _test_decks_reach_stern() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var props := room.get_node("Props") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	var valid := RoomReach.span_at(reached, STERN_DECK) != null
	valid = valid and terrain.get_cell_atlas_coords(STERN_DECK) in DECKS
	valid = valid and props.get_cell_atlas_coords(STERN_CRATE) == CRATE
	valid = valid and STERN_CRATE + Vector2i.DOWN in [STERN_DECK, STERN_DECK + Vector2i.RIGHT]
	room.free()
	return valid


func _test_scavenger_in_pool() -> bool:
	var room := _room()
	if room == null:
		return false
	var scavenger := room.get_node_or_null("Enemies/Scavenger") as Node2D
	var valid := scavenger != null
	if valid:
		var terrain := room.get_node("Terrain") as TileMapLayer
		var row := int(scavenger.position.y / TILE)
		for x in [scavenger.get("patrol_left"), scavenger.get("patrol_right")]:
			var cell := Vector2i(int(x / TILE), row)
			valid = valid and RoomReach.is_water(terrain, cell)
		valid = valid and scavenger.position.x > ROOM_SIZE.x / 2.0
	room.free()
	return valid


# The sand at the east end gives way: a hole to the bottom of the Room, and an Exit under it
# down into the sea cave's shaft.
func _test_sinkhole() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for row in range(6, CELLS.end.y):
		valid = valid and terrain.get_cell_source_id(Vector2i(SINKHOLE_COLUMN, row)) == -1
	var exit := room.get_node_or_null("Exits/sinkhole") as Area2D
	valid = valid and exit != null and exit.position.y > ROOM_SIZE.y
	valid = valid and int(exit.position.x / TILE) == SINKHOLE_COLUMN
	valid = valid and exit.get("room_id") == &"waking_coast_5" and exit.get("entry_id") == &"shaft"
	room.free()
	return valid


# The top and bottom of a rectangle collision shape, in the Room's space.
static func _vertical_span(shape_node: CollisionShape2D) -> Vector2:
	var rectangle := shape_node.shape as RectangleShape2D
	if rectangle == null:
		return Vector2(-1, -1)
	var owner_y := (shape_node.get_parent() as Node2D).position.y
	var top := owner_y + shape_node.position.y - rectangle.size.y / 2.0
	return Vector2(top, top + rectangle.size.y)
