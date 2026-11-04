extends RefCounted

const ROOM_PATH := "res://scenes/rooms/undertow_7.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
# Three screens wide: a shallow lake at the bottom of the Undertow, west to a sealed temple door.
const ROOM_SIZE := Vector2i(480, 144)
const TILE := 16
const WORLD_LAYER := 1
const EAST_ENTRY := Vector2(468, 96)
const WEST_END := Vector2i(1, 6)
# The lake's shallows, each the coast's water from edge to edge, with sand banks between them
# wide enough to land a jump out of the water on.
const SHALLOWS := [Rect2i(4, 6, 6, 1), Rect2i(13, 6, 7, 1), Rect2i(23, 6, 4, 1)]
# Landmark cells: layer -> {cell: atlas coords}.
const LANDMARKS := {
	# the sealed temple door at the lake's west end, the way on to come
	&"Door": {Vector2i(0, 3): Vector2i(1, 8)},
	&"Terrain": {Vector2i(11, 6): Vector2i(4, 1), Vector2i(4, 6): Vector2i(1, 1)},
}


func get_tests() -> Array:
	return [
		["Undertow lake lays out three screens", _test_lays_out],
		["Undertow lake's shallows run between sand banks", _test_shallows],
		["Undertow lake runs west to the sealed door, wading its shallows", _test_runs_west],
		["Undertow lake leads east to the stair; its west end is shut", _test_exits],
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


func _test_shallows() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for shallow: Rect2i in SHALLOWS:
		for column in range(shallow.position.x, shallow.end.x):
			valid = valid and RoomReach.is_water(terrain, Vector2i(column, shallow.position.y))
		valid = valid and not RoomReach.is_water(terrain, shallow.position + Vector2i.LEFT)
		valid = valid and not RoomReach.is_water(terrain, Vector2i(shallow.end.x, 6))
	room.free()
	return valid


func _test_runs_west() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(EAST_ENTRY / TILE))
	room.free()
	return RoomReach.span_at(reached, WEST_END) != null


func _test_exits() -> bool:
	var room := _room()
	if room == null:
		return false
	var exits := room.get_node("Exits").get_children()
	var valid := exits.size() == 1
	var east := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and east != null and east.position.x > ROOM_SIZE.x
	valid = valid and east.get("room_id") == &"undertow_6" and east.get("entry_id") == &"west"
	var entry := room.get_node_or_null("Entries/east") as Marker2D
	valid = valid and entry != null and entry.position == EAST_ENTRY
	var bounds := room.get_node_or_null("Bounds") as StaticBody2D
	valid = valid and bounds != null and bounds.collision_layer == WORLD_LAYER
	var west := bounds.get_node_or_null("West") as CollisionShape2D if valid else null
	valid = valid and west != null and west.position.x < 0.0
	room.free()
	return valid
