extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_9.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
# Four screens wide, under the jungle trail, the Warden's gate and Tidefen's west end.
const ROOM_SIZE := Vector2i(640, 144)
const TILE := 16
# The east end, by the way on to the well's shaft, and the way west to the temple hall.
const EAST_ENTRY := Vector2(628, 96)
const EAST_FLOOR := Vector2i(39, 6)
const WEST_ENTRY := Vector2(12, 96)
# The hole in the floor down to the pools, a tile wide so the way west hops it, and the sand
# beside it where the climb back up comes out.
const HOLE := Rect2i(17, 6, 1, 3)
const SOUTH_ENTRY := Vector2(296, 96)
# Landmark cells, drawn from the Undertow's sheets: layer -> {cell: atlas coords}.
const LANDMARKS := {
	&"Terrain":
	{
		# the mossy earth roof, fallen masonry to jump in the tunnel, and three pools
		Vector2i(12, 0): Vector2i(9, 15),
		Vector2i(14, 4): Vector2i(16, 8),
		Vector2i(26, 5): Vector2i(16, 9),
		Vector2i(6, 6): Vector2i(2, 1),
		Vector2i(22, 6): Vector2i(2, 1),
		Vector2i(34, 6): Vector2i(3, 1),
		Vector2i(0, 6): Vector2i(2, 1),
	},
}


func get_tests() -> Array:
	return [
		["Undertow Room lays out four screens of tunnel", _test_lays_out_four_screens],
		["Undertow tunnel leads east to the shaft from Tidefen's well", _test_leads_east],
		["A hole in the tunnel's floor drops into the pools below", _test_hole_to_pools],
		["Undertow tunnel's floor runs from its east end west to the hall", _test_floor_runs_west],
		["A Scavenger hunts the undertow's middle pool", _test_scavenger_in_pool],
	]


static func _room() -> Node2D:
	var packed_scene := load(ROOM_PATH) as PackedScene
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node2D


func _test_lays_out_four_screens() -> bool:
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


# The roof runs whole over the east end now; its edge is the Exit on to the shaft, which the well
# drops into.
func _test_leads_east() -> bool:
	var room := _room()
	if room == null:
		return false
	var valid := room.get_node_or_null("Bounds") == null
	valid = valid and room.get_node_or_null("Entries/well") == null
	var terrain := room.get_node("Terrain") as TileMapLayer
	valid = valid and terrain.get_cell_source_id(Vector2i(EAST_FLOOR.x, 0)) != -1
	var exit := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and exit != null and exit.position.x > ROOM_SIZE.x
	valid = valid and exit.get("room_id") == &"undertow_1" and exit.get("entry_id") == &"west"
	var entry := room.get_node_or_null("Entries/east") as Marker2D
	valid = valid and entry != null and entry.position == EAST_ENTRY
	room.free()
	return valid


func _test_floor_runs_west() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, EAST_FLOOR)
	var valid := RoomReach.span_at(reached, Vector2i(WEST_ENTRY / TILE)) != null
	var entry := room.get_node_or_null("Entries/west") as Marker2D
	valid = valid and entry != null and entry.position == WEST_ENTRY
	var exit := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and exit != null and exit.position.x < 0.0
	valid = valid and exit.get("room_id") == &"undertow_2" and exit.get("entry_id") == &"east"
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


func _test_hole_to_pools() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for column in range(HOLE.position.x, HOLE.end.x):
		for row in range(HOLE.position.y, HOLE.end.y):
			valid = valid and terrain.get_cell_source_id(Vector2i(column, row)) == -1
	var exit := room.get_node_or_null("Exits/south") as Area2D
	valid = valid and exit != null and exit.position.y > ROOM_SIZE.y
	valid = valid and int(exit.position.x / TILE) in range(HOLE.position.x, HOLE.end.x)
	valid = valid and exit.get("room_id") == &"undertow_4" and exit.get("entry_id") == &"north"
	var entry := room.get_node_or_null("Entries/south") as Marker2D
	valid = valid and entry != null and entry.position == SOUTH_ENTRY
	if valid:
		var below := Vector2i(SOUTH_ENTRY / TILE)
		valid = terrain.get_cell_source_id(below) != -1
		valid = valid and terrain.get_cell_source_id(below + Vector2i.UP) == -1
	room.free()
	return valid
