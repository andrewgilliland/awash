extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_5.tscn"
const RoomExitScript := preload("res://scripts/core/room_exit.gd")
const RoomReach := preload("res://tests/room_reach.gd")
# Two screens wide, under the salt cliffs' foot.
const ROOM_SIZE := Vector2i(320, 144)
const TILE := 16
const WORLD_LAYER := 1
# Dropping in from the hole under the salt cliffs' foot, through the opening in the roof.
const NORTH_ENTRY := Vector2(120, 16)
const PLAYER_HEIGHT := 20
const OPENING := Rect2i(6, 0, 5, 2)
# Up from the floor to the opening: plank landings a jump apart, the higher one under the opening.
const LANDINGS := [Vector2i(6, 4), Vector2i(8, 2)]
# At the east end of the floor, coming back from the undertow.
const EAST_ENTRY := Vector2(308, 96)
const EAST_FLOOR := Vector2i(19, 6)
const WEST_FLOOR := Vector2i(1, 6)
const SHELF := Vector2i(14, 4)
const CRATE := Vector2i(10, 3)
# Landmark cells from assets/regions/waking_coast/room_layouts/waking_coast_5.aseprite:
# layer -> {cell: atlas coords}.
const LANDMARKS := {
	&"Terrain":
	{
		# the earth roof, low at the west wall
		Vector2i(0, 4): Vector2i(5, 9),
		Vector2i(11, 1): Vector2i(1, 11),
		Vector2i(14, 1): Vector2i(2, 11),
		# the sandy floor and a pool the tide left
		Vector2i(0, 6): Vector2i(2, 1),
		Vector2i(7, 6): Vector2i(3, 1),
		Vector2i(8, 6): Vector2i(1, 1),
		Vector2i(10, 6): Vector2i(3, 1),
		# a shelf up out of the way, with the cave's crate
		Vector2i(13, 4): Vector2i(4, 4),
		Vector2i(15, 4): Vector2i(7, 4),
	},
	&"Props": {Vector2i(14, 3): CRATE},
}


func get_tests() -> Array:
	return [
		["Sea cave Room lays out two screens of cave", _test_lays_out_two_screens],
		["Sea cave's roof opens only under the salt cliffs' foot", _test_roofed],
		["Sea cave climbs up through its roof to the salt cliffs", _test_climbs_out],
		["Sea cave floor runs from its east end to its west wall", _test_floor_runs_west],
		["Sea cave shelf holds a crate a jump up", _test_shelf_holds_crate],
		["Sea cave leads east into the undertow", _test_leads_east],
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
	room.free()
	return valid


# The sea cave is reached only from the salt cliffs' foot: its roof runs whole along the top but
# for the opening under the hole, and its west end is walled.
func _test_roofed() -> bool:
	var room := _room()
	if room == null:
		return false
	var valid := room.get_node_or_null("Entries/shaft") == null
	valid = valid and room.get_node_or_null("Exits/west") == null
	var terrain := room.get_node("Terrain") as TileMapLayer
	for column in range(ROOM_SIZE.x / TILE):
		var open := column >= OPENING.position.x and column < OPENING.end.x
		valid = valid and (terrain.get_cell_source_id(Vector2i(column, 0)) == -1) == open
	for row in range(1, WEST_FLOOR.y):
		valid = valid and terrain.get_cell_source_id(Vector2i(0, row)) != -1
	for exit in _exits(room):
		valid = valid and exit.room_id != &"waking_coast_4"
	room.free()
	return valid


# Up from the floor, a landing at a time, to under the opening; a jump from there leaves north
# for the salt cliffs. Dropping in lands in the opening.
func _test_climbs_out() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, EAST_FLOOR)
	var valid := true
	for landing: Vector2i in LANDINGS:
		valid = valid and RoomReach.span_at(reached, landing) != null
		var data := terrain.get_cell_tile_data(landing)
		valid = valid and data != null and data.is_collision_polygon_one_way(0, 0)
	var top: Vector2i = LANDINGS[-1]
	valid = valid and top.x >= OPENING.position.x and top.x < OPENING.end.x
	valid = valid and top.y <= RoomReach.jump_rows()
	var exit := room.get_node_or_null("Exits/north") as Area2D
	valid = valid and exit != null and exit.position.y < 0.0
	valid = valid and exit.get("room_id") == &"waking_coast_3" and exit.get("entry_id") == &"cave"
	var entry := room.get_node_or_null("Entries/north") as Marker2D
	valid = valid and entry != null and entry.position == NORTH_ENTRY
	# Dropping in clear of the Exit, so the Player is not sent straight back up.
	if valid:
		var edge := (exit.get_node("Edge") as CollisionShape2D).shape as RectangleShape2D
		valid = exit.position.y + edge.size.y / 2.0 < NORTH_ENTRY.y - PLAYER_HEIGHT
	valid = valid and int(NORTH_ENTRY.x / TILE) in range(OPENING.position.x, OPENING.end.x)
	room.free()
	return valid


func _test_floor_runs_west() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, EAST_FLOOR)
	room.free()
	return RoomReach.span_at(reached, WEST_FLOOR) != null


func _test_shelf_holds_crate() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var props := room.get_node("Props") as TileMapLayer
	var reached := RoomReach.reachable(terrain, EAST_FLOOR)
	var valid := RoomReach.span_at(reached, SHELF) != null
	valid = valid and props.get_cell_atlas_coords(SHELF + Vector2i.UP) == CRATE
	room.free()
	return valid


# Past the floor's east end the tunnel runs on east into the undertow.
func _test_leads_east() -> bool:
	var room := _room()
	if room == null:
		return false
	var valid := room.get_node_or_null("Bounds") == null
	var exit := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and exit != null and exit.position.x > ROOM_SIZE.x
	valid = valid and exit.get("room_id") == &"waking_coast_9" and exit.get("entry_id") == &"west"
	var entry := room.get_node_or_null("Entries/east") as Marker2D
	valid = valid and entry != null and entry.position == EAST_ENTRY
	room.free()
	return valid


static func _exits(room: Node) -> Array:
	var exits: Array = []
	for node in room.find_children("*", "Area2D", true, false):
		if node.get_script() == RoomExitScript:
			exits.append(node)
	return exits
