extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_12.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
const RoomEnemies := preload("res://tests/room_enemies.gd")
# Two screens wide, along the cliff tops from the gull ledges to the wreck graveyard.
const ROOM_SIZE := Vector2i(320, 144)
const TILE := 16
const WEST_ENTRY := Vector2(12, 64)
const EAST_ENTRY := Vector2(308, 64)
const EAST_END := Vector2i(19, 4)
# A grassy hollow two tiles down, and a mossy rock two tiles high standing in the way.
const HOLLOW := Rect2i(8, 6, 4, 1)
const ROCK_TOP := Vector2i(15, 2)
# Landmark cells: layer -> {cell: atlas coords}.
const LANDMARKS := {
	&"Terrain":
	{
		# the hollow's rims and floor
		Vector2i(7, 4): Vector2i(5, 13),
		Vector2i(12, 4): Vector2i(1, 13),
		Vector2i(9, 6): Vector2i(2, 13),
		# the mossy rock
		ROCK_TOP: Vector2i(3, 6),
		ROCK_TOP + Vector2i.DOWN: Vector2i(3, 7),
	},
	# a big mossy rock back from the edge, and a palm leaning over the far rim
	&"Rocks": {Vector2i(3, 0): Vector2i(6, 1)},
	&"Trees": {Vector2i(12, 0): Vector2i(14, 1)},
}


func get_tests() -> Array:
	return [
		["Cliff tops Room lays out two screens", _test_lays_out],
		["Cliff tops run east, down through a hollow and over a rock", _test_runs_east],
		["A mossy rock on the cliff tops is a jump high", _test_rock],
		["Cliff tops lead west to the gull ledges and east to the graveyard", _test_exits],
		["A Wraith haunts the cliff tops beside the mossy rock", _test_wraith],
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


# The way east drops into the hollow and jumps out of it; nothing on it is more than a jump.
func _test_runs_east() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	var valid := RoomReach.span_at(reached, EAST_END) != null
	for column in range(HOLLOW.position.x, HOLLOW.end.x):
		var floor_cell := Vector2i(column, HOLLOW.position.y)
		valid = valid and RoomReach.span_at(reached, floor_cell) != null
		valid = valid and terrain.get_cell_source_id(floor_cell + Vector2i.UP) == -1
	room.free()
	return valid


func _test_rock() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := terrain.get_cell_source_id(ROCK_TOP + Vector2i.UP) == -1
	valid = valid and terrain.get_cell_source_id(ROCK_TOP + Vector2i.DOWN * 2) != -1
	valid = valid and ROCK_TOP.y + RoomReach.jump_rows() >= EAST_END.y
	room.free()
	return valid


# Both edges are open Exits along the cliff top; neither is walled.
func _test_exits() -> bool:
	var room := _room()
	if room == null:
		return false
	var valid := room.get_node_or_null("Bounds") == null
	var west := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and west != null and west.position.x < 0.0
	valid = valid and west.get("room_id") == &"waking_coast_11" and west.get("entry_id") == &"east"
	var east := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and east != null and east.position.x > ROOM_SIZE.x
	valid = valid and east.get("room_id") == &"waking_coast_4" and east.get("entry_id") == &"west"
	var terrain := room.get_node("Terrain") as TileMapLayer
	for entry_name in ["west", "east"]:
		var entry := room.get_node_or_null("Entries/%s" % entry_name) as Marker2D
		valid = valid and entry != null
		if valid:
			var below := Vector2i(entry.position / TILE)
			valid = valid and terrain.get_cell_source_id(below) != -1
			valid = valid and terrain.get_cell_source_id(below + Vector2i.UP) == -1
	valid = valid and room.get_node("Entries/west").position == WEST_ENTRY
	valid = valid and room.get_node("Entries/east").position == EAST_ENTRY
	room.free()
	return valid


# It floats over the cliff top between the hollow and the rock, its haunt ending at the rock.
func _test_wraith() -> bool:
	var room := _room()
	if room == null:
		return false
	var wraith := room.get_node_or_null("Enemies/Wraith") as Node2D
	var valid := wraith != null
	if valid:
		var terrain := room.get_node("Terrain") as TileMapLayer
		valid = RoomEnemies.haunts_floor(terrain, wraith)
		var rock_face := ROCK_TOP.x * TILE
		valid = valid and wraith.get("haunt_left") >= (HOLLOW.end.x) * TILE
		valid = valid and wraith.get("haunt_right") <= rock_face
		valid = valid and wraith.get("haunt_right") >= rock_face - TILE
	room.free()
	return valid
