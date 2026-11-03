extends RefCounted

const ROOM_PATH := "res://scenes/rooms/undertow_4.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
# Two screens wide: pools under the undertow tunnel, open to it through a hole in its floor.
const ROOM_SIZE := Vector2i(320, 144)
const TILE := 16
const WORLD_LAYER := 1
# Dropping in through the opening in the roof, under the tunnel's hole.
const NORTH_ENTRY := Vector2(112, 16)
const OPENING := Rect2i(5, 0, 4, 2)
const FLOOR := Vector2i(1, 6)
# Up from the floor to the opening: landings a jump apart, the higher under the opening and
# overlapping the lower, so each is a jump straight up.
const LANDINGS := [Vector2i(3, 4), Vector2i(5, 2)]
# The pools, each the coast's shallow from edge to edge.
const POOLS := [Rect2i(10, 6, 3, 1), Rect2i(15, 6, 3, 1)]
# Landmark cells: layer -> {cell: atlas coords}.
const LANDMARKS := {
	# coral on the sand between the pools, and a barrel sunk by the east wall
	&"Props": {Vector2i(13, 4): Vector2i(1, 12), Vector2i(18, 4): Vector2i(1, 7)},
	&"Terrain": {LANDINGS[0]: Vector2i(1, 7), Vector2i(4, 1): Vector2i(5, 13)},
}


func get_tests() -> Array:
	return [
		["Undertow pools lay out two screens", _test_lays_out],
		["Undertow pools hold two shallows on the sand", _test_pools],
		["Undertow pools climb up through their roof to the tunnel", _test_climbs_out],
		["Undertow pools lead north to the tunnel and east to the dead end", _test_north],
	]


static func _room() -> Node2D:
	if not ResourceLoader.exists(ROOM_PATH):
		return null
	return (load(ROOM_PATH) as PackedScene).instantiate() as Node2D


func _test_lays_out() -> bool:
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


func _test_pools() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for pool: Rect2i in POOLS:
		for column in range(pool.position.x, pool.end.x):
			valid = valid and RoomReach.is_water(terrain, Vector2i(column, pool.position.y))
		valid = valid and not RoomReach.is_water(terrain, pool.position + Vector2i.LEFT)
		valid = valid and not RoomReach.is_water(terrain, Vector2i(pool.end.x, pool.position.y))
	var reached := RoomReach.reachable(terrain, FLOOR)
	valid = valid and RoomReach.span_at(reached, Vector2i(ROOM_SIZE.x / TILE - 1, FLOOR.y)) != null
	room.free()
	return valid


# Up from the floor, a landing at a time, to under the opening; a jump from there leaves north for
# the tunnel. Dropping in lands in the opening.
func _test_climbs_out() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, FLOOR)
	var valid := true
	for landing: Vector2i in LANDINGS:
		valid = valid and RoomReach.span_at(reached, landing) != null
		var data := terrain.get_cell_tile_data(landing)
		valid = valid and data != null and data.is_collision_polygon_one_way(0, 0)
	for column in range(OPENING.position.x, OPENING.end.x):
		for row in range(OPENING.position.y, OPENING.end.y):
			valid = valid and terrain.get_cell_source_id(Vector2i(column, row)) == -1
	var top: Vector2i = LANDINGS[-1]
	valid = valid and top.x >= OPENING.position.x and top.x < OPENING.end.x
	valid = valid and top.y <= RoomReach.jump_rows()
	var entry := room.get_node_or_null("Entries/north") as Marker2D
	valid = valid and entry != null and entry.position == NORTH_ENTRY
	room.free()
	return valid


# The way on west waits for the stair down; until then that edge is walled.
func _test_north() -> bool:
	var room := _room()
	if room == null:
		return false
	var exit := room.get_node_or_null("Exits/north") as Area2D
	var valid := exit != null and exit.position.y < 0.0
	valid = valid and exit.get("room_id") == &"waking_coast_9" and exit.get("entry_id") == &"south"
	if valid:
		var edge := (exit.get_node("Edge") as CollisionShape2D).shape as RectangleShape2D
		valid = exit.position.y + edge.size.y / 2.0 < NORTH_ENTRY.y - 20.0
	var east := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and east != null and east.position.x > ROOM_SIZE.x
	valid = valid and east.get("room_id") == &"undertow_5" and east.get("entry_id") == &"west"
	var entry := room.get_node_or_null("Entries/east") as Marker2D
	valid = valid and entry != null and entry.position == Vector2(308, 96)
	var bounds := room.get_node_or_null("Bounds") as StaticBody2D
	valid = valid and bounds != null and bounds.collision_layer == WORLD_LAYER
	room.free()
	return valid
