extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_11.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
# One screen wide and two tall: up from the salt cliffs' top to the cliff tops.
const ROOM_SIZE := Vector2i(160, 288)
const SCREEN_HEIGHT := 144
const TILE := 16
const WORLD_LAYER := 1
# On the ground the salt cliffs' top runs on to, and on the cliff top above it.
const WEST_ENTRY := Vector2(12, 208)
const EAST_ENTRY := Vector2(148, 64)
const CLIFF_TOP := Vector2i(8, 4)
# Weathered planks wedged into the air up the cliff face, each a jump above the last.
const PLANKS := [Vector2i(1, 11), Vector2i(4, 9), Vector2i(1, 7), Vector2i(3, 5)]
const PLANK_TILES := [Vector2i(4, 4), Vector2i(5, 4), Vector2i(7, 4)]
# Landmark cells: layer -> {cell: atlas coords}.
const LANDMARKS := {
	&"Terrain":
	{
		# the cliff's top-left corner and its face, over the ground below
		Vector2i(6, 4): Vector2i(1, 13),
		Vector2i(6, 8): Vector2i(1, 14),
		Vector2i(0, 13): Vector2i(2, 13),
	},
}


func get_tests() -> Array:
	return [
		["Gull ledges Room lays out two screens tall", _test_lays_out],
		["Gull ledges climb one jump at a time to the cliff tops", _test_climbs],
		["Gull ledges' planks are one-way ledges", _test_planks_one_way],
		["Gull ledges wall the top screen's west edge", _test_west_wall],
		["Gull ledges lead west to the salt cliffs and east to the cliff tops", _test_exits],
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


# From the ground, each plank is a jump up, and the last one a jump to the cliff top; every
# rise is at most a single jump.
func _test_climbs() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	var valid := RoomReach.span_at(reached, CLIFF_TOP) != null
	for plank: Vector2i in PLANKS:
		valid = valid and RoomReach.span_at(reached, plank) != null
	room.free()
	return valid


func _test_planks_one_way() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for plank: Vector2i in PLANKS:
		valid = valid and terrain.get_cell_atlas_coords(plank) in PLANK_TILES
		var data := terrain.get_cell_tile_data(plank)
		valid = valid and data != null and data.is_collision_polygon_one_way(0, 0)
	room.free()
	return valid


# The top screen has no Exit west, so a wall holds the Player in.
func _test_west_wall() -> bool:
	var room := _room()
	if room == null:
		return false
	var bounds := room.get_node_or_null("Bounds") as StaticBody2D
	var valid := bounds != null and bounds.collision_layer == WORLD_LAYER
	var wall := bounds.get_node_or_null("WestTop") as CollisionShape2D if valid else null
	valid = valid and wall != null and wall.position.x < 0.0
	valid = valid and _vertical_span(wall) == Vector2(0, SCREEN_HEIGHT)
	room.free()
	return valid


func _test_exits() -> bool:
	var room := _room()
	if room == null:
		return false
	var west := room.get_node_or_null("Exits/west") as Area2D
	var valid := west != null and west.position.x < 0.0
	valid = valid and west.get("room_id") == &"waking_coast_3" and west.get("entry_id") == &"east"
	if valid:
		valid = _vertical_span(west.get_node("Edge")) == Vector2(SCREEN_HEIGHT, ROOM_SIZE.y)
	var east := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and east != null and east.position.x > ROOM_SIZE.x
	valid = valid and east.get("room_id") == &"waking_coast_12" and east.get("entry_id") == &"west"
	if valid:
		valid = _vertical_span(east.get_node("Edge")) == Vector2(0, SCREEN_HEIGHT)
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


# The top and bottom of a rectangle collision shape, in the Room's space.
static func _vertical_span(shape_node: CollisionShape2D) -> Vector2:
	var rectangle := shape_node.shape as RectangleShape2D
	if rectangle == null:
		return Vector2(-1, -1)
	var owner_y := (shape_node.get_parent() as Node2D).position.y
	var top := owner_y + shape_node.position.y - rectangle.size.y / 2.0
	return Vector2(top, top + rectangle.size.y)
