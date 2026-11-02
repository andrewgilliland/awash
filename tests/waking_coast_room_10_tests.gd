extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_10.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
# Two screens wide, between the palm shore and the salt cliffs, level with both beaches.
const ROOM_SIZE := Vector2i(320, 144)
const TILE := 16
const WEST_ENTRY := Vector2(12, 96)
const EAST_ENTRY := Vector2(308, 96)
const EAST_END := Vector2i(19, 6)
# The stepping stone in the widest pool: low enough to hop from the water.
const ROCK := Vector2i(10, 5)
const POOLS := [Vector2i(3, 6), Vector2i(8, 6), Vector2i(15, 6)]
const POOL_WIDTHS := [3, 5, 2]
# Landmark cells: layer -> {cell: atlas coords}.
const LANDMARKS := {
	# a palm at the west end, and a mossy boulder up the beach toward the cliffs
	&"Trees": {Vector2i(0, 2): Vector2i(11, 1), Vector2i(1, 5): Vector2i(12, 4)},
	&"Rocks": {Vector2i(14, 2): Vector2i(10, 1), Vector2i(16, 5): Vector2i(12, 4)},
	&"Terrain":
	{
		# the stepping stone in the widest pool
		ROCK: Vector2i(2, 5),
	},
}


func get_tests() -> Array:
	return [
		["Tide pools Room lays out two screens", _test_lays_out_two_screens],
		["Three tide pools, each its own width, break the sand", _test_pools],
		["Tide pools beach runs east, wading the pools", _test_runs_east],
		["A stepping stone stands in the widest pool, a hop up", _test_rock],
		["Tide pools lead west to the palm shore and east to the salt cliffs", _test_exits],
	]


static func _room() -> Node2D:
	var packed_scene := load(ROOM_PATH) as PackedScene if ResourceLoader.exists(ROOM_PATH) else null
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


# Each pool is the pack's water from edge to edge, sand either side.
func _test_pools() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for index in POOLS.size():
		var start: Vector2i = POOLS[index]
		var width: int = POOL_WIDTHS[index]
		for column in range(start.x, start.x + width):
			valid = valid and RoomReach.is_water(terrain, Vector2i(column, start.y))
		valid = valid and not RoomReach.is_water(terrain, start + Vector2i.LEFT)
		valid = valid and not RoomReach.is_water(terrain, start + Vector2i(width, 0))
	room.free()
	return valid


func _test_runs_east() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	room.free()
	return RoomReach.span_at(reached, EAST_END) != null


# The stepping stone's top is a hop up out of the water.
func _test_rock() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	var valid := RoomReach.span_at(reached, ROCK) != null
	valid = valid and RoomReach.is_water(terrain, ROCK + Vector2i.DOWN)
	room.free()
	return valid


# Both edges are open Exits, level with the sand either side; neither is walled.
func _test_exits() -> bool:
	var room := _room()
	if room == null:
		return false
	var valid := room.get_node_or_null("Bounds") == null
	var west := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and west != null and west.position.x < 0.0
	valid = valid and west.get("room_id") == &"waking_coast_2" and west.get("entry_id") == &"east"
	var east := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and east != null and east.position.x > ROOM_SIZE.x
	valid = valid and east.get("room_id") == &"waking_coast_3" and east.get("entry_id") == &"west"
	for entry_name in ["west", "east"]:
		var entry := room.get_node_or_null("Entries/%s" % entry_name) as Marker2D
		valid = valid and entry != null
		if valid:
			var terrain := room.get_node("Terrain") as TileMapLayer
			var below := Vector2i(entry.position / TILE)
			valid = valid and terrain.get_cell_source_id(below) != -1
			valid = valid and terrain.get_cell_source_id(below + Vector2i.UP) == -1
	valid = valid and room.get_node("Entries/west").position == WEST_ENTRY
	valid = valid and room.get_node("Entries/east").position == EAST_ENTRY
	room.free()
	return valid
