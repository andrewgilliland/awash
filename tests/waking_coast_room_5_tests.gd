extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_5.tscn"
const TILESET_PATH := "res://assets/tilesets/waking_coast_2.tres"
const RoomExitScript := preload("res://scripts/core/room_exit.gd")
const RoomReach := preload("res://tests/room_reach.gd")
const LAYER_ORDER := [&"Back", &"Terrain", &"Props", &"Entries", &"Player"]
# Two screens wide, under the wreck graveyard.
const ROOM_SIZE := Vector2i(320, 144)
const CELLS := Rect2i(0, 0, 20, 9)
const TILE := 16
const WORLD_LAYER := 1
const CAVE_DARK := Vector2i(6, 4)
# The shaft down from the graveyard's sinkhole, open to the top of the Room, and the tunnel
# west to the salt cliffs, level with their beach.
const SHAFT_ENTRY := Vector2(312, 24)
const SHAFT_FLOOR := Vector2i(19, 6)
const WEST_ENTRY := Vector2(12, 96)
# At the shaft's foot, coming back from the undertow.
const EAST_ENTRY := Vector2(308, 96)
const SHELF := Vector2i(14, 4)
const CRATE := Vector2i(0, 7)
# Landmark cells from assets/waking_shores_6.aseprite: layer -> {cell: atlas coords}.
const LANDMARKS := {
	&"Back": {Vector2i(0, 4): CAVE_DARK, Vector2i(19, 0): CAVE_DARK, Vector2i(10, 3): CAVE_DARK},
	&"Terrain":
	{
		# the rock roof, low at the tunnel, with old runes set in it
		Vector2i(0, 3): Vector2i(1, 3),
		Vector2i(6, 1): Vector2i(0, 4),
		Vector2i(14, 1): Vector2i(1, 4),
		# the sandy floor and a pool the tide left
		Vector2i(0, 6): Vector2i(1, 0),
		Vector2i(7, 6): Vector2i(2, 8),
		Vector2i(8, 6): Vector2i(5, 5),
		Vector2i(10, 6): Vector2i(5, 8),
		# a shelf up out of the way, with the cave's crate
		Vector2i(13, 4): Vector2i(3, 4),
		Vector2i(15, 4): Vector2i(5, 4),
	},
	&"Props": {Vector2i(14, 3): CRATE},
}


func get_tests() -> Array:
	return [
		["Sea cave Room draws its layers in order", _test_draws_layers_in_order],
		["Sea cave Room lays out two screens of rock and dark", _test_lays_out_two_screens],
		["Sea cave shaft drops from the graveyard, one way", _test_shaft_is_one_way],
		["Sea cave tunnel leads west to the salt cliffs", _test_tunnel_leads_west],
		["Sea cave floor runs from the shaft to the tunnel", _test_floor_runs_west],
		["Sea cave shelf holds a crate a jump up", _test_shelf_holds_crate],
		["Sea cave camera stays inside the Room", _test_camera_limits],
		["Sea cave leads east into the undertow", _test_leads_east],
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


# Every cell is rock or the cave's dark behind the open air, so nothing shows through.
func _test_lays_out_two_screens() -> bool:
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
	var entry := room.get_node_or_null("Entries/shaft") as Marker2D
	var valid := entry != null and entry.position == SHAFT_ENTRY
	var terrain := room.get_node("Terrain") as TileMapLayer
	for row in range(SHAFT_FLOOR.y):
		valid = valid and terrain.get_cell_source_id(Vector2i(SHAFT_FLOOR.x, row)) == -1
	valid = valid and terrain.get_cell_source_id(SHAFT_FLOOR) == 0
	valid = valid and SHAFT_FLOOR.y > RoomReach.jump_rows()
	for exit in _exits(room):
		valid = valid and exit.room_id != &"waking_coast_4"
	room.free()
	return valid


func _test_tunnel_leads_west() -> bool:
	var room := _room()
	if room == null:
		return false
	var entry := room.get_node_or_null("Entries/west") as Marker2D
	var valid := entry != null and entry.position == WEST_ENTRY
	var exit := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and exit != null and exit.position.x < 0.0
	valid = valid and exit.get("room_id") == &"waking_coast_3" and exit.get("entry_id") == &"cave"
	room.free()
	return valid


func _test_floor_runs_west() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, SHAFT_FLOOR)
	room.free()
	return RoomReach.span_at(reached, Vector2i(WEST_ENTRY / TILE)) != null


func _test_shelf_holds_crate() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var props := room.get_node("Props") as TileMapLayer
	var reached := RoomReach.reachable(terrain, SHAFT_FLOOR)
	var valid := RoomReach.span_at(reached, SHELF) != null
	valid = valid and props.get_cell_atlas_coords(SHELF + Vector2i.UP) == CRATE
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


# Past the shaft's foot the tunnel runs on east into the undertow. Falling down the shaft does
# not touch the Exit: it starts at the Room's edge.
func _test_leads_east() -> bool:
	var room := _room()
	if room == null:
		return false
	var valid := room.get_node_or_null("Bounds") == null
	var exit := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and exit != null and exit.position.x > ROOM_SIZE.x
	valid = valid and exit.get("room_id") == &"waking_coast_9" and exit.get("entry_id") == &"west"
	var entry := room.get_node_or_null("Entries/east") as Marker2D
	valid = valid and entry != null and entry.position == EAST_ENTRY
	room.free()
	return valid


static func _exits(room: Node) -> Array:
	var exits: Array = []
	for node in room.find_children("*", "Area2D", true, false):
		if node.get_script() == RoomExitScript:
			exits.append(node)
	return exits
