extends RefCounted

const ROOM_PATH := "res://scenes/rooms/undertow_6.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
# One screen wide and two tall: a stair down from the pools, in the drowned temple.
const ROOM_SIZE := Vector2i(160, 288)
const SCREEN_HEIGHT := 144
const TILE := 16
const WORLD_LAYER := 1
const EAST_ENTRY := Vector2(148, 96)
const WEST_ENTRY := Vector2(12, 256)
# The landings, zigzagging two rows apart from the shelf by the way in down to the floor.
const LANDINGS := [
	Vector2i(7, 6), Vector2i(4, 8), Vector2i(7, 10), Vector2i(4, 12), Vector2i(7, 14)
]
# Landmark cells: layer -> {cell: atlas coords}.
const LANDMARKS := {
	# the temple's windowed wall behind the stair
	&"Temple": {Vector2i(2, 9): Vector2i(8, 13)},
	&"Terrain": {LANDINGS[1]: Vector2i(14, 12), Vector2i(0, 16): Vector2i(2, 1)},
}


func get_tests() -> Array:
	return [
		["Temple stair lays out two screens tall", _test_lays_out],
		["Temple stair goes down and back up, a jump at a time", _test_both_ways],
		["Temple stair's landings are one-way", _test_one_way],
		["Temple stair walls its top-west and foot-east edges", _test_walls],
		["Temple stair leads east to the pools and west to the lake", _test_exits],
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
	var down := RoomReach.reachable(terrain, Vector2i(EAST_ENTRY / TILE))
	var up := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	var valid := RoomReach.span_at(down, Vector2i(WEST_ENTRY / TILE)) != null
	valid = valid and RoomReach.span_at(up, Vector2i(EAST_ENTRY / TILE)) != null
	for landing: Vector2i in LANDINGS:
		valid = valid and RoomReach.span_at(up, landing) != null
	room.free()
	return valid


func _test_one_way() -> bool:
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


func _test_walls() -> bool:
	var room := _room()
	if room == null:
		return false
	var bounds := room.get_node_or_null("Bounds") as StaticBody2D
	var valid := bounds != null and bounds.collision_layer == WORLD_LAYER
	if valid:
		var west := bounds.get_node_or_null("WestTop") as CollisionShape2D
		var east := bounds.get_node_or_null("EastLow") as CollisionShape2D
		valid = west != null and east != null
		valid = valid and west.position.x < 0.0 and east.position.x > ROOM_SIZE.x
		valid = valid and _vertical_span(west) == Vector2(0, SCREEN_HEIGHT)
		valid = valid and _vertical_span(east) == Vector2(SCREEN_HEIGHT, ROOM_SIZE.y)
	room.free()
	return valid


func _test_exits() -> bool:
	var room := _room()
	if room == null:
		return false
	var east := room.get_node_or_null("Exits/east") as Area2D
	var valid := east != null and east.position.x > ROOM_SIZE.x
	valid = valid and east.get("room_id") == &"undertow_4" and east.get("entry_id") == &"west"
	var west := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and west != null and west.position.x < 0.0
	valid = valid and west.get("room_id") == &"undertow_7" and west.get("entry_id") == &"east"
	if valid:
		valid = _vertical_span(east.get_node("Edge")) == Vector2(0, SCREEN_HEIGHT)
		valid = valid and _vertical_span(west.get_node("Edge")) == Vector2(SCREEN_HEIGHT, 288)
	valid = valid and room.get_node("Entries/east").position == EAST_ENTRY
	valid = valid and room.get_node("Entries/west").position == WEST_ENTRY
	room.free()
	return valid


static func _vertical_span(shape_node: CollisionShape2D) -> Vector2:
	var rectangle := shape_node.shape as RectangleShape2D
	if rectangle == null:
		return Vector2(-1, -1)
	var owner_y := (shape_node.get_parent() as Node2D).position.y
	var top := owner_y + shape_node.position.y - rectangle.size.y / 2.0
	return Vector2(top, top + rectangle.size.y)
