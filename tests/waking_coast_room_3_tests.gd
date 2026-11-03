extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_3.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
# Two screens tall.
const ROOM_SIZE := Vector2i(160, 288)
const CELLS := Rect2i(0, 0, 10, 18)
const TILE := 16
const SCREEN_HEIGHT := 144
# On the beach, clear of the west Exit, at the height the palm shore's sand leaves off.
const WEST_ENTRY := Vector2(12, 240)
# On the cliff top, clear of the east Exit.
const EAST_ENTRY := Vector2(148, 64)
# Coming up out of the sea cave: on a step at the rim of the hole under the cliff's foot, a jump
# below the beach.
const CAVE_ENTRY := Vector2(104, 272)
const HOLE := Rect2i(7, 13, 3, 5)
const BEACH_END := Vector2i(5, 15)
const WORLD_LAYER := 1
# The cliff top the climb ends on, and the high ledge left for a double jump.
const CLIFF_TOP := Vector2i(8, 4)
const HIGH_LEDGE := Vector2i(5, 1)
# Landmark cells from assets/regions/waking_coast/room_layouts/waking_coast_3.aseprite:
# layer -> {cell: atlas coords}.
const LANDMARKS := {
	# A broken mast holds up the wreck decks on the west side of the climb.
	&"Wreck": {Vector2i(0, 6): Vector2i(12, 9), Vector2i(0, 14): Vector2i(12, 9)},
	# the jungle starting on the cliff top: a bush's crown and foot
	&"Jungle": {Vector2i(7, 1): Vector2i(5, 4), Vector2i(7, 3): Vector2i(5, 6)},
	&"Terrain":
	{
		# the beach, with a tidal pool
		Vector2i(0, 15): Vector2i(2, 1),
		Vector2i(1, 15): Vector2i(3, 1),
		Vector2i(2, 15): Vector2i(1, 1),
		Vector2i(3, 15): Vector2i(3, 1),
		Vector2i(4, 15): Vector2i(3, 1),
		# the sea cliff, its top two screens up the climb
		Vector2i(7, 4): Vector2i(1, 13),
		Vector2i(9, 4): Vector2i(3, 13),
		Vector2i(7, 12): Vector2i(1, 17),
		# driftwood logs on the cliff, wreck decks across from them
		Vector2i(3, 13): Vector2i(4, 4),
		Vector2i(5, 13): Vector2i(7, 4),
		Vector2i(1, 11): Vector2i(1, 6),
		Vector2i(3, 11): Vector2i(4, 6),
		Vector2i(4, 9): Vector2i(4, 4),
		Vector2i(1, 7): Vector2i(1, 6),
		Vector2i(4, 5): Vector2i(4, 4),
		Vector2i(4, 1): Vector2i(4, 4),
	},
	&"Props":
	{
		# a crate on the high ledge, Tidefen's bell on the cliff top
		Vector2i(5, 0): Vector2i(10, 3),
		Vector2i(8, 3): Vector2i(0, 0),
	},
}


func get_tests() -> Array:
	return [
		["Salt cliffs Room lays out two screens tall", _test_lays_out_two_screens_tall],
		["Salt cliffs climb one jump at a time to the top", _test_climb_reaches_top],
		["Salt cliffs high ledge waits for a double jump", _test_high_ledge_out_of_reach],
		["Salt cliffs west Entry stands on the beach", _test_west_entry_on_beach],
		["Salt cliffs lead east from the top and back west from the beach", _test_edges],
		["A Scavenger hunts the salt cliffs' tidal pool", _test_scavenger_in_pool],
		["A hole under the cliff's foot drops into the sea cave", _test_hole_to_cave],
		["Up out of the sea cave, a step climbs back to the beach", _test_step_to_beach],
	]


static func _room() -> Node2D:
	var packed_scene := load(ROOM_PATH) as PackedScene
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node2D


func _test_lays_out_two_screens_tall() -> bool:
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
	# The bottom row is filled but for the hole under the cliff's foot.
	var terrain := room.get_node("Terrain") as TileMapLayer
	for column in range(CELLS.size.x):
		var filled := terrain.get_cell_source_id(Vector2i(column, CELLS.end.y - 1)) != -1
		valid = valid and filled == (column < HOLE.position.x)
	room.free()
	return valid


func _test_climb_reaches_top() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	room.free()
	return RoomReach.span_at(reached, CLIFF_TOP) != null


func _test_high_ledge_out_of_reach() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	var valid := RoomReach.span_at(RoomReach.surfaces(terrain), HIGH_LEDGE) != null
	valid = valid and RoomReach.span_at(reached, HIGH_LEDGE) == null
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
		valid = terrain.get_cell_source_id(below) != -1
		valid = valid and terrain.get_cell_source_id(below + Vector2i.UP) == -1
	room.free()
	return valid


# The cliff top's east edge is the Exit on to the wreck graveyard; below it the cliff is solid
# rock. On the west, the bottom screen is the Exit back to the palm shore and the top screen is
# walled.
func _test_edges() -> bool:
	var room := _room()
	if room == null:
		return false
	var bounds := room.get_node_or_null("Bounds") as StaticBody2D
	var valid := bounds != null and bounds.collision_layer == WORLD_LAYER
	if valid:
		valid = bounds.get_node_or_null("East") == null
		var west := bounds.get_node_or_null("WestTop") as CollisionShape2D
		valid = valid and west != null and west.position.x < 0.0
		valid = valid and _vertical_span(west) == Vector2(0, SCREEN_HEIGHT)
	var exit := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and exit != null and exit.get("room_id") == &"waking_coast_10"
	valid = valid and exit.get("entry_id") == &"east"
	if valid:
		var edge := exit.get_node("Edge") as CollisionShape2D
		valid = exit.position.x < 0.0
		valid = valid and _vertical_span(edge) == Vector2(SCREEN_HEIGHT, ROOM_SIZE.y)
	var east_exit := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and east_exit != null and east_exit.position.x > ROOM_SIZE.x
	valid = valid and east_exit.get("room_id") == &"waking_coast_11"
	valid = valid and east_exit.get("entry_id") == &"west"
	if valid:
		var east_edge := east_exit.get_node("Edge") as CollisionShape2D
		valid = _vertical_span(east_edge) == Vector2(0, SCREEN_HEIGHT)
	var entry := room.get_node_or_null("Entries/east") as Marker2D
	valid = valid and entry != null and entry.position == EAST_ENTRY
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
	room.free()
	return valid


# Under the cliff's overhang the beach gives way: a hole to the bottom of the Room, an Exit under
# it down into the sea cave, and a wall on the east edge beside it.
func _test_hole_to_cave() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for row in range(HOLE.position.y, HOLE.end.y):
		for column in range(HOLE.position.x, HOLE.end.x):
			valid = valid and terrain.get_cell_source_id(Vector2i(column, row)) == -1
	var exit := room.get_node_or_null("Exits/hole") as Area2D
	valid = valid and exit != null and exit.position.y > ROOM_SIZE.y
	valid = valid and int(exit.position.x / TILE) in range(HOLE.position.x, HOLE.end.x)
	valid = valid and exit.get("room_id") == &"waking_coast_5" and exit.get("entry_id") == &"north"
	valid = valid and room.get_node_or_null("Exits/cave") == null
	var bounds := room.get_node_or_null("Bounds") as StaticBody2D
	var wall := bounds.get_node_or_null("EastLow") as CollisionShape2D if bounds else null
	valid = valid and wall != null and wall.position.x > ROOM_SIZE.x
	valid = valid and _vertical_span(wall) == Vector2(SCREEN_HEIGHT, ROOM_SIZE.y)
	room.free()
	return valid


# Coming up from the sea cave the Player stands on the step at the hole's rim, and the beach is a
# jump up from it.
func _test_step_to_beach() -> bool:
	var room := _room()
	if room == null:
		return false
	var entry := room.get_node_or_null("Entries/cave") as Marker2D
	var valid := entry != null and entry.position == CAVE_ENTRY
	if valid:
		var terrain := room.get_node("Terrain") as TileMapLayer
		var step := Vector2i(entry.position / TILE)
		valid = terrain.get_cell_source_id(step) != -1
		valid = valid and terrain.get_cell_source_id(step + Vector2i.UP) == -1
		var reached := RoomReach.reachable(terrain, step)
		valid = valid and RoomReach.span_at(reached, BEACH_END) != null
		valid = valid and RoomReach.span_at(reached, Vector2i(WEST_ENTRY / TILE)) != null
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
