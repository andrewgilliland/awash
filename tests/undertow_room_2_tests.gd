extends RefCounted

const ROOM_PATH := "res://scenes/rooms/undertow_2.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
const RoomEnemies := preload("res://tests/room_enemies.gd")
# Two screens wide and two tall: a hall of the drowned temple, from the passage at its top-west
# down to the tunnel at its foot.
const ROOM_SIZE := Vector2i(320, 288)
const SCREEN_HEIGHT := 144
const TILE := 16
const WORLD_LAYER := 1
const WEST_ENTRY := Vector2(12, 96)
const EAST_ENTRY := Vector2(308, 240)
# The temple's stone slabs, zigzagging up from the hall's floor to the west ledge.
const SLABS := [Vector2i(12, 13), Vector2i(9, 11), Vector2i(12, 9), Vector2i(8, 7)]
# Landmark cells: layer -> {cell: atlas coords}.
const LANDMARKS := {
	# a standing pillar on its plinth, and a doorway round the way west
	&"Temple": {Vector2i(15, 9): Vector2i(2, 1), Vector2i(14, 14): Vector2i(1, 6)},
	&"Doorway": {Vector2i(0, 3): Vector2i(1, 16)},
	&"Terrain": {SLABS[0]: Vector2i(14, 12), Vector2i(7, 6): Vector2i(5, 1)},
}


func get_tests() -> Array:
	return [
		["Temple hall lays out two screens square", _test_lays_out],
		["Temple hall climbs from the tunnel to the passage, a jump at a time", _test_climbs],
		["Temple hall's slabs are one-way", _test_slabs_one_way],
		["Temple hall walls its east edge above the tunnel", _test_east_wall],
		["Temple hall leads west to the passage and east to the tunnel", _test_exits],
		["A Wraith haunts the temple hall's lower floor", _test_wraith],
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


func _test_climbs() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(EAST_ENTRY / TILE))
	var valid := RoomReach.span_at(reached, Vector2i(WEST_ENTRY / TILE)) != null
	for slab: Vector2i in SLABS:
		valid = valid and RoomReach.span_at(reached, slab) != null
	room.free()
	return valid


func _test_slabs_one_way() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for slab: Vector2i in SLABS:
		for column in range(slab.x, slab.x + 3):
			var data := terrain.get_cell_tile_data(Vector2i(column, slab.y))
			valid = valid and data != null and data.is_collision_polygon_one_way(0, 0)
	room.free()
	return valid


func _test_east_wall() -> bool:
	var room := _room()
	if room == null:
		return false
	var bounds := room.get_node_or_null("Bounds") as StaticBody2D
	var valid := bounds != null and bounds.collision_layer == WORLD_LAYER
	var wall := bounds.get_node_or_null("EastTop") as CollisionShape2D if valid else null
	valid = valid and wall != null and wall.position.x > ROOM_SIZE.x
	valid = valid and _vertical_span(wall) == Vector2(0, SCREEN_HEIGHT)
	room.free()
	return valid


func _test_exits() -> bool:
	var room := _room()
	if room == null:
		return false
	var west := room.get_node_or_null("Exits/west") as Area2D
	var valid := west != null and west.position.x < 0.0
	valid = valid and west.get("room_id") == &"undertow_3" and west.get("entry_id") == &"east"
	if valid:
		valid = _vertical_span(west.get_node("Edge")) == Vector2(0, SCREEN_HEIGHT)
	var east := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and east != null and east.position.x > ROOM_SIZE.x
	valid = valid and east.get("room_id") == &"waking_coast_9" and east.get("entry_id") == &"west"
	if valid:
		valid = _vertical_span(east.get_node("Edge")) == Vector2(SCREEN_HEIGHT, ROOM_SIZE.y)
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


static func _vertical_span(shape_node: CollisionShape2D) -> Vector2:
	var rectangle := shape_node.shape as RectangleShape2D
	if rectangle == null:
		return Vector2(-1, -1)
	var owner_y := (shape_node.get_parent() as Node2D).position.y
	var top := owner_y + shape_node.position.y - rectangle.size.y / 2.0
	return Vector2(top, top + rectangle.size.y)


# It floats over the lower floor among the fallen columns, the floor the tunnel opens on.
func _test_wraith() -> bool:
	var room := _room()
	if room == null:
		return false
	var wraith := room.get_node_or_null("Enemies/Wraith") as Node2D
	var valid := wraith != null
	if valid:
		var terrain := room.get_node("Terrain") as TileMapLayer
		valid = RoomEnemies.haunts_floor(terrain, wraith)
		valid = (
			valid and is_equal_approx(wraith.position.y + RoomEnemies.WRAITH_HOVER, EAST_ENTRY.y)
		)
		var left: float = wraith.get("haunt_left")
		var right: float = wraith.get("haunt_right")
		valid = valid and RoomEnemies.clear_of_entries(room, left, right)
	room.free()
	return valid
