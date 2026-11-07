extends RefCounted

const ROOM_PATH := "res://scenes/rooms/undertow_3.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
const RoomEnemies := preload("res://tests/room_enemies.gd")
# Two screens wide: the passage from the temple hall west to the Shortcut's wall.
const ROOM_SIZE := Vector2i(320, 144)
const TILE := 16
const WEST_ENTRY := Vector2(12, 96)
const EAST_ENTRY := Vector2(308, 96)
# Landmark cells: layer -> {cell: atlas coords}.
const LANDMARKS := {
	# the drowned temple's colonnade, its arches standing on the floor
	&"Temple": {Vector2i(6, 2): Vector2i(4, 1), Vector2i(10, 5): Vector2i(8, 4)},
	&"Terrain":
	{
		# the sandy floor and the mossy roof
		Vector2i(0, 6): Vector2i(2, 1),
		Vector2i(10, 0): Vector2i(3, 13),
	},
}


func get_tests() -> Array:
	return [
		["Undertow passage lays out two screens", _test_lays_out],
		["Undertow passage's floor runs from the hall to the wall", _test_floor_runs_west],
		["Undertow passage leads west to the sea cave and east to the hall", _test_exits],
		["A Wraith haunts the passage under its arches", _test_wraith],
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


func _test_floor_runs_west() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(EAST_ENTRY / TILE))
	room.free()
	return RoomReach.span_at(reached, Vector2i(WEST_ENTRY / TILE)) != null


func _test_exits() -> bool:
	var room := _room()
	if room == null:
		return false
	var west := room.get_node_or_null("Exits/west") as Area2D
	var valid := west != null and west.position.x < 0.0
	valid = valid and west.get("room_id") == &"waking_coast_5" and west.get("entry_id") == &"east"
	var east := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and east != null and east.position.x > ROOM_SIZE.x
	valid = valid and east.get("room_id") == &"undertow_2" and east.get("entry_id") == &"west"
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


# It floats over the passage floor between its two Entries, under the arches.
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
			valid and is_equal_approx(wraith.position.y + RoomEnemies.WRAITH_HOVER, WEST_ENTRY.y)
		)
		var left: float = wraith.get("haunt_left")
		var right: float = wraith.get("haunt_right")
		valid = valid and RoomEnemies.clear_of_entries(room, left, right)
	room.free()
	return valid
