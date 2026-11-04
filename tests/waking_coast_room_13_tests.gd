extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_13.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
# One screen wide and three tall: down from the graveyard's beach to the jungle trail.
const ROOM_SIZE := Vector2i(160, 432)
const SCREEN_HEIGHT := 144
const TILE := 16
const WORLD_LAYER := 1
# On the beach's last sand at the top, and on the sand at the foot.
const WEST_ENTRY := Vector2(12, 96)
const EAST_ENTRY := Vector2(148, 384)
const FOOT := Vector2i(9, 24)
const TOP := Vector2i(1, 6)
# The stair's landings: plank boards zigzagging down the open side, two rows apart.
const LANDINGS := [
	Vector2i(4, 8),
	Vector2i(7, 10),
	Vector2i(4, 12),
	Vector2i(7, 14),
	Vector2i(4, 16),
	Vector2i(7, 18),
	Vector2i(4, 20),
	Vector2i(7, 22),
]
# Landmark cells: layer -> {cell: atlas coords}.
const LANDMARKS := {
	&"Terrain":
	{
		# the beach's end over the drop, and a landing's board ends
		Vector2i(3, 6): Vector2i(5, 1),
		Vector2i(4, 8): Vector2i(6, 2),
		Vector2i(6, 8): Vector2i(11, 2),
	},
}


func get_tests() -> Array:
	return [
		["Broken stair Room lays out three screens tall", _test_lays_out],
		["Broken stair goes down to the trail and back up, a jump at a time", _test_both_ways],
		["Broken stair's landings are one-way boards", _test_landings_one_way],
		["Broken stair walls its east edge above the foot", _test_east_wall],
		["Broken stair leads west to the graveyard and east to the trail", _test_exits],
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


func _test_both_ways() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var down := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	var up := RoomReach.reachable(terrain, FOOT)
	var valid := RoomReach.span_at(down, FOOT) != null and RoomReach.span_at(up, TOP) != null
	for landing: Vector2i in LANDINGS:
		valid = valid and RoomReach.span_at(up, landing) != null
	room.free()
	return valid


func _test_landings_one_way() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for landing: Vector2i in LANDINGS:
		for column in range(landing.x, landing.x + 3):
			var data := terrain.get_cell_tile_data(Vector2i(column, landing.y))
			valid = valid and data != null and data.is_collision_polygon_one_way(0, 0)
	room.free()
	return valid


# Only the foot opens east, so a wall holds the Player in above it.
func _test_east_wall() -> bool:
	var room := _room()
	if room == null:
		return false
	var bounds := room.get_node_or_null("Bounds") as StaticBody2D
	var valid := bounds != null and bounds.collision_layer == WORLD_LAYER
	var wall := bounds.get_node_or_null("EastHigh") as CollisionShape2D if valid else null
	valid = valid and wall != null and wall.position.x > ROOM_SIZE.x
	valid = valid and _vertical_span(wall) == Vector2(0, SCREEN_HEIGHT * 2)
	room.free()
	return valid


func _test_exits() -> bool:
	var room := _room()
	if room == null:
		return false
	var west := room.get_node_or_null("Exits/west") as Area2D
	var valid := west != null and west.position.x < 0.0
	valid = valid and west.get("room_id") == &"waking_coast_4" and west.get("entry_id") == &"east"
	if valid:
		valid = _vertical_span(west.get_node("Edge")) == Vector2(0, SCREEN_HEIGHT)
	var east := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and east != null and east.position.x > ROOM_SIZE.x
	valid = valid and east.get("room_id") == &"waking_coast_6" and east.get("entry_id") == &"west"
	if valid:
		valid = _vertical_span(east.get_node("Edge")) == Vector2(SCREEN_HEIGHT * 2, ROOM_SIZE.y)
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
