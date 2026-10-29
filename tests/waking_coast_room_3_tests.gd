extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_3.tscn"
const TILESET_PATH := "res://assets/tilesets/waking_coast_2.tres"
const RoomReach := preload("res://tests/room_reach.gd")
const LAYER_ORDER := [&"Backdrop", &"Wreck", &"Terrain", &"Props", &"Entries", &"Player"]
# Two screens tall.
const ROOM_SIZE := Vector2i(160, 288)
const CELLS := Rect2i(0, 0, 10, 18)
const TILE := 16
const SCREEN_HEIGHT := 144
# On the beach, clear of the west Exit, at the height the rune shore's sand leaves off.
const WEST_ENTRY := Vector2(12, 240)
# On the cliff top, clear of the east Exit.
const EAST_ENTRY := Vector2(148, 64)
# In the tunnel through the cliff's foot, on the beach's level.
const CAVE_ENTRY := Vector2(148, 240)
const TUNNEL := Rect2i(7, 13, 3, 2)
const WORLD_LAYER := 1
const SHALLOW := Vector2i(5, 5)
# The cliff top the climb ends on, and the high ledge left for a double jump.
const CLIFF_TOP := Vector2i(8, 4)
const HIGH_LEDGE := Vector2i(5, 1)
# Landmark cells from assets/waking_shores_4.aseprite: layer -> {cell: atlas coords}.
const LANDMARKS := {
	# A broken mast holds up the wreck decks on the west side of the climb.
	&"Wreck": {Vector2i(0, 6): Vector2i(7, 6), Vector2i(0, 14): Vector2i(7, 6)},
	&"Terrain":
	{
		# the beach, with a tidal pool between wet edges
		Vector2i(0, 15): Vector2i(1, 0),
		Vector2i(1, 15): Vector2i(2, 8),
		Vector2i(2, 15): Vector2i(5, 5),
		Vector2i(3, 15): Vector2i(5, 5),
		Vector2i(4, 15): Vector2i(5, 8),
		# the sea cliff, its top two screens up the climb
		Vector2i(7, 4): Vector2i(0, 2),
		Vector2i(9, 4): Vector2i(1, 2),
		Vector2i(7, 17): Vector2i(0, 3),
		# salt-slick stone ledges on the cliff, wreck decks across from them
		Vector2i(3, 13): Vector2i(3, 4),
		Vector2i(5, 13): Vector2i(5, 4),
		Vector2i(1, 11): Vector2i(4, 6),
		Vector2i(3, 11): Vector2i(6, 6),
		Vector2i(4, 9): Vector2i(3, 4),
		Vector2i(1, 7): Vector2i(4, 6),
		Vector2i(4, 5): Vector2i(3, 4),
		Vector2i(4, 1): Vector2i(3, 4),
	},
	&"Props":
	{
		# a crate on the high ledge, Tidefen's bell on the cliff top
		Vector2i(5, 0): Vector2i(0, 7),
		Vector2i(8, 3): Vector2i(3, 7),
	},
}


func get_tests() -> Array:
	return [
		["Salt cliffs Room draws its layers in order", _test_draws_layers_in_order],
		["Salt cliffs Room lays out two screens tall", _test_lays_out_two_screens_tall],
		["Salt cliffs climb one jump at a time to the top", _test_climb_reaches_top],
		["Salt cliffs high ledge waits for a double jump", _test_high_ledge_out_of_reach],
		["Salt cliffs west Entry stands on the beach", _test_west_entry_on_beach],
		["Salt cliffs camera scrolls up the Room", _test_camera_limits],
		["Salt cliffs lead east from the top and back west from the beach", _test_edges],
		["A Scavenger hunts the salt cliffs' tidal pool", _test_scavenger_in_pool],
		["A tunnel at the cliff's foot leads into the sea cave", _test_tunnel_to_cave],
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
	var backdrop := room.get_node_or_null("Backdrop") as AnimatedSprite2D
	valid = valid and backdrop != null and backdrop.sprite_frames != null
	valid = valid and backdrop.sprite_frames.get_frame_count(&"default") == 4
	if valid:
		var frame := backdrop.sprite_frames.get_frame_texture(&"default", 0)
		valid = Vector2i(frame.get_size()) == ROOM_SIZE
	for layer_name in [&"Wreck", &"Terrain", &"Props"]:
		var layer := room.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		valid = valid and layer != null and layer.tile_set != null
		valid = valid and layer.tile_set.resource_path == TILESET_PATH
	room.free()
	return valid


func _test_lays_out_two_screens_tall() -> bool:
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
	var terrain := room.get_node("Terrain") as TileMapLayer
	for column in range(CELLS.size.x):
		valid = valid and terrain.get_cell_source_id(Vector2i(column, CELLS.end.y - 1)) == 0
	room.free()
	return valid


func _test_climb_reaches_top() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	room.free()
	return RoomReach.span_at(reached, CLIFF_TOP) != null


func _test_high_ledge_out_of_reach() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	var valid := RoomReach.span_at(RoomReach.surfaces(terrain), HIGH_LEDGE) != null
	valid = valid and RoomReach.span_at(reached, HIGH_LEDGE) == null
	room.free()
	return valid


func _test_west_entry_on_beach() -> bool:
	var room := _room()
	if room == null:
		return false
	var entry := room.get_node_or_null("Entries/west") as Marker2D
	var valid := entry != null and entry.position == WEST_ENTRY
	if valid:
		var terrain := room.get_node("Terrain") as TileMapLayer
		var below := Vector2i(entry.position / TILE)
		valid = terrain.get_cell_source_id(below) == 0
		valid = valid and terrain.get_cell_source_id(below + Vector2i.UP) == -1
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


# The cliff top's east edge is the Exit on to the wreck graveyard; below it the cliff is solid
# rock. On the west, the bottom screen is the Exit back to the rune shore and the top screen is
# walled.
func _test_edges() -> bool:
	var room := _room()
	if room == null:
		return false
	var bounds := room.get_node_or_null("Bounds") as StaticBody2D
	var valid := bounds != null and bounds.collision_layer == WORLD_LAYER
	if valid:
		valid = bounds.get_node_or_null("East") == null
		var west := bounds.get_node_or_null("WestTop") as CollisionShape2D
		valid = valid and west != null and west.position.x < 0.0
		valid = valid and _vertical_span(west) == Vector2(0, SCREEN_HEIGHT)
	var exit := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and exit != null and exit.get("room_id") == &"waking_coast_2"
	valid = valid and exit.get("entry_id") == &"east"
	if valid:
		var edge := exit.get_node("Edge") as CollisionShape2D
		valid = exit.position.x < 0.0
		valid = valid and _vertical_span(edge) == Vector2(SCREEN_HEIGHT, ROOM_SIZE.y)
	var east_exit := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and east_exit != null and east_exit.position.x > ROOM_SIZE.x
	valid = valid and east_exit.get("room_id") == &"waking_coast_4"
	valid = valid and east_exit.get("entry_id") == &"west"
	if valid:
		var east_edge := east_exit.get_node("Edge") as CollisionShape2D
		valid = _vertical_span(east_edge) == Vector2(0, SCREEN_HEIGHT)
	var entry := room.get_node_or_null("Entries/east") as Marker2D
	valid = valid and entry != null and entry.position == EAST_ENTRY
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


# A tunnel through the cliff's foot, level with the beach, is the Exit east into the sea cave.
func _test_tunnel_to_cave() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for row in range(TUNNEL.position.y, TUNNEL.end.y):
		for column in range(TUNNEL.position.x, TUNNEL.end.x):
			valid = valid and terrain.get_cell_source_id(Vector2i(column, row)) == -1
	for column in range(TUNNEL.position.x, TUNNEL.end.x):
		valid = valid and terrain.get_cell_source_id(Vector2i(column, TUNNEL.end.y)) == 0
	var exit := room.get_node_or_null("Exits/cave") as Area2D
	valid = valid and exit != null and exit.position.x > ROOM_SIZE.x
	valid = valid and exit.get("room_id") == &"waking_coast_5" and exit.get("entry_id") == &"west"
	if valid:
		var edge := exit.get_node("Edge") as CollisionShape2D
		valid = _vertical_span(edge) == Vector2(SCREEN_HEIGHT, ROOM_SIZE.y)
	var entry := room.get_node_or_null("Entries/cave") as Marker2D
	valid = valid and entry != null and entry.position == CAVE_ENTRY
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
