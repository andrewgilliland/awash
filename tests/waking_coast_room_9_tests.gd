extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_9.tscn"
const RoomExitScript := preload("res://scripts/core/room_exit.gd")
const RoomReach := preload("res://tests/room_reach.gd")
# Four screens wide, under the jungle trail, the Warden's gate and Tidefen's west end.
const ROOM_SIZE := Vector2i(640, 144)
const TILE := 16
const WORLD_LAYER := 1
# The shaft down from Tidefen's well at the east end, and the way west into the sea cave.
const WELL_ENTRY := Vector2(632, 24)
const WELL_FLOOR := Vector2i(39, 6)
const WEST_ENTRY := Vector2(12, 96)
# Landmark cells from assets/regions/waking_coast/room_layouts/waking_coast_9.aseprite:
# layer -> {cell: atlas coords}.
const LANDMARKS := {
	&"Terrain":
	{
		# the earth roof, mounds to jump in the tunnel, and three pools
		Vector2i(12, 0): Vector2i(2, 8),
		Vector2i(14, 4): Vector2i(1, 6),
		Vector2i(26, 5): Vector2i(1, 5),
		Vector2i(6, 6): Vector2i(2, 1),
		Vector2i(20, 6): Vector2i(2, 1),
		Vector2i(34, 6): Vector2i(3, 1),
		Vector2i(0, 6): Vector2i(2, 1),
	},
}


func get_tests() -> Array:
	return [
		["Undertow Room lays out four screens of tunnel", _test_lays_out_four_screens],
		["Undertow shaft drops from Tidefen's well, one way", _test_shaft_is_one_way],
		["Undertow floor runs from the well west to the sea cave", _test_floor_runs_west],
		["A Scavenger hunts the undertow's middle pool", _test_scavenger_in_pool],
		["Undertow walls its east edge", _test_walls_east_edge],
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


# The shaft is open to the Room's top and too tall to jump back up; no Exit leads up.
func _test_shaft_is_one_way() -> bool:
	var room := _room()
	if room == null:
		return false
	var entry := room.get_node_or_null("Entries/well") as Marker2D
	var valid := entry != null and entry.position == WELL_ENTRY
	var terrain := room.get_node("Terrain") as TileMapLayer
	for row in range(WELL_FLOOR.y):
		valid = valid and terrain.get_cell_source_id(Vector2i(WELL_FLOOR.x, row)) == -1
	valid = valid and terrain.get_cell_source_id(WELL_FLOOR) != -1
	valid = valid and WELL_FLOOR.y > RoomReach.jump_rows()
	for node in room.find_children("*", "Area2D", true, false):
		if node.get_script() == RoomExitScript:
			valid = valid and node.room_id != &"waking_coast_8"
	room.free()
	return valid


func _test_floor_runs_west() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, WELL_FLOOR)
	var valid := RoomReach.span_at(reached, Vector2i(WEST_ENTRY / TILE)) != null
	var entry := room.get_node_or_null("Entries/west") as Marker2D
	valid = valid and entry != null and entry.position == WEST_ENTRY
	var exit := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and exit != null and exit.position.x < 0.0
	valid = valid and exit.get("room_id") == &"waking_coast_5" and exit.get("entry_id") == &"east"
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


func _test_walls_east_edge() -> bool:
	var room := _room()
	if room == null:
		return false
	var bounds := room.get_node_or_null("Bounds") as StaticBody2D
	var valid := bounds != null and bounds.collision_layer == WORLD_LAYER
	if valid:
		var east := bounds.get_node_or_null("East") as CollisionShape2D
		var boundary := east.shape as WorldBoundaryShape2D if east != null else null
		valid = boundary != null and boundary.normal == Vector2.LEFT
		valid = valid and east.position.x == ROOM_SIZE.x
	room.free()
	return valid
