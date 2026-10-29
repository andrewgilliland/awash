extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_9.tscn"
const TILESET_PATH := "res://assets/tilesets/waking_coast_2.tres"
const RoomExitScript := preload("res://scripts/core/room_exit.gd")
const RoomReach := preload("res://tests/room_reach.gd")
const LAYER_ORDER := [&"Back", &"Terrain", &"Props", &"Entries", &"Player"]
# Four screens wide, under the rune road, the Warden's gate and Tidefen's west end.
const ROOM_SIZE := Vector2i(640, 144)
const CELLS := Rect2i(0, 0, 40, 9)
const TILE := 16
const WORLD_LAYER := 1
const SHALLOW := Vector2i(5, 5)
# The shaft down from Tidefen's well at the east end, and the way west into the sea cave.
const WELL_ENTRY := Vector2(632, 24)
const WELL_FLOOR := Vector2i(39, 6)
const WEST_ENTRY := Vector2(12, 96)
# Landmark cells from assets/waking_shores_10.aseprite: layer -> {cell: atlas coords}.
const LANDMARKS := {
	&"Back": {Vector2i(0, 2): Vector2i(6, 4), Vector2i(39, 0): Vector2i(6, 4)},
	&"Terrain":
	{
		# runes in the roof, rock to jump in the tunnel, and three pools
		Vector2i(12, 0): Vector2i(0, 4),
		Vector2i(14, 4): Vector2i(1, 2),
		Vector2i(26, 5): Vector2i(1, 2),
		Vector2i(6, 6): Vector2i(2, 8),
		Vector2i(20, 6): SHALLOW,
		Vector2i(34, 6): Vector2i(5, 8),
		Vector2i(0, 6): Vector2i(1, 0),
	},
}


func get_tests() -> Array:
	return [
		["Undertow Room draws its layers in order", _test_draws_layers_in_order],
		["Undertow Room lays out four screens of rock and dark", _test_lays_out_four_screens],
		["Undertow shaft drops from Tidefen's well, one way", _test_shaft_is_one_way],
		["Undertow floor runs from the well west to the sea cave", _test_floor_runs_west],
		["A Scavenger hunts the undertow's middle pool", _test_scavenger_in_pool],
		["Undertow camera scrolls inside the Room", _test_camera_limits],
		["Undertow walls its east edge", _test_walls_east_edge],
	]


static func _room() -> Node2D:
	var packed_scene := load(ROOM_PATH) as PackedScene
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node2D


func _test_draws_layers_in_order() -> bool:
	var room := _room()
	if room == null:
		return false
	var names: Array = []
	for child in room.get_children():
		if child.name in LAYER_ORDER:
			names.append(child.name)
	var valid := names == LAYER_ORDER
	for layer_name in [&"Back", &"Terrain", &"Props"]:
		var layer := room.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		valid = valid and layer != null and layer.tile_set != null
		valid = valid and layer.tile_set.resource_path == TILESET_PATH
	room.free()
	return valid


# Every cell is rock or the tunnel's dark behind the open air, so nothing shows through.
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
		valid = valid and CELLS.encloses(layer.get_used_rect())
		var cells: Dictionary = LANDMARKS[layer_name]
		for cell in cells:
			valid = valid and layer.get_cell_atlas_coords(cell) == cells[cell]
	var back := room.get_node("Back") as TileMapLayer
	var terrain := room.get_node("Terrain") as TileMapLayer
	for row in range(CELLS.size.y):
		for column in range(CELLS.size.x):
			var cell := Vector2i(column, row)
			valid = (
				valid
				and (terrain.get_cell_source_id(cell) == 0 or back.get_cell_source_id(cell) == 0)
			)
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
	valid = valid and terrain.get_cell_source_id(WELL_FLOOR) == 0
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
			valid = valid and terrain.get_cell_atlas_coords(cell) == SHALLOW
	room.free()
	return valid


func _test_camera_limits() -> bool:
	var room := _room()
	if room == null:
		return false
	var camera := room.get_node_or_null("Player/Camera2D") as Camera2D
	var valid := camera != null
	if valid:
		valid = camera.limit_left == 0 and camera.limit_top == 0
		valid = valid and camera.limit_right == ROOM_SIZE.x and camera.limit_bottom == ROOM_SIZE.y
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
