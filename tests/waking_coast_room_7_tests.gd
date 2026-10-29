extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_7.tscn"
const TILESET_PATH := "res://assets/tilesets/waking_coast_2.tres"
const RoomReach := preload("res://tests/room_reach.gd")
const LAYER_ORDER := [&"Backdrop", &"Terrain", &"Props", &"Entries", &"Player"]
# One screen: the arena the Nameless Warden will hold.
const ROOM_SIZE := Vector2i(160, 144)
const CELLS := Rect2i(0, 0, 10, 9)
const TILE := 16
# On the road's end, at the height of the rune road's heights; and on the arena floor by the
# way on to Tidefen.
const WEST_ENTRY := Vector2(12, 48)
const EAST_ENTRY := Vector2(148, 112)
# The arena: a flat floor, open above, from the ledge up to the road's end to the east edge.
const ARENA_FLOOR_ROW := 7
const ARENA := Rect2i(4, 0, 6, 7)
const RUNE_STONE := Vector2i(5, 7)
# Landmark cells from assets/waking_shores_8.aseprite: layer -> {cell: atlas coords}.
const LANDMARKS := {
	&"Terrain":
	{
		# the road's end, a ledge down from it, and the arena's stone floor
		Vector2i(0, 3): Vector2i(1, 2),
		Vector2i(1, 3): Vector2i(2, 2),
		Vector2i(2, 5): Vector2i(3, 4),
		Vector2i(2, 7): Vector2i(1, 2),
		Vector2i(9, 7): Vector2i(1, 2),
		Vector2i(0, 6): Vector2i(1, 4),
	},
	# rune stones at the gate on to Tidefen
	&"Props": {Vector2i(6, 5): RUNE_STONE, Vector2i(9, 5): RUNE_STONE},
}


func get_tests() -> Array:
	return [
		["Warden's gate Room draws its layers in order", _test_draws_layers_in_order],
		["Warden's gate Room lays out one screen", _test_lays_out_one_screen],
		["Warden's gate arena is a flat, open floor", _test_arena_is_open],
		["Warden's gate floor climbs back to the road's end", _test_climbs_back],
		["Warden's gate leads west to the road and east to Tidefen", _test_edges],
		["Warden's gate camera holds the arena", _test_camera_limits],
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
	for layer_name in [&"Terrain", &"Props"]:
		var layer := room.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		valid = valid and layer != null and layer.tile_set != null
		valid = valid and layer.tile_set.resource_path == TILESET_PATH
	room.free()
	return valid


func _test_lays_out_one_screen() -> bool:
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


# Room to fight in: the arena floor is unbroken, and nothing solid stands above it.
func _test_arena_is_open() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for column in range(ARENA.position.x, ARENA.end.x):
		valid = valid and terrain.get_cell_source_id(Vector2i(column, ARENA_FLOOR_ROW)) == 0
		for row in range(ARENA.position.y, ARENA.end.y):
			valid = valid and terrain.get_cell_source_id(Vector2i(column, row)) == -1
	room.free()
	return valid


# Dropping into the arena is not a trap: the ledge leads back up to the road's end.
func _test_climbs_back() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(EAST_ENTRY / TILE))
	room.free()
	return RoomReach.span_at(reached, Vector2i(WEST_ENTRY / TILE)) != null


# Until the Warden exists the way on to Tidefen is open.
func _test_edges() -> bool:
	var room := _room()
	if room == null:
		return false
	var valid := room.get_node_or_null("Bounds") == null
	for spec in [["west", WEST_ENTRY], ["east", EAST_ENTRY]]:
		var entry := room.get_node_or_null("Entries/%s" % spec[0]) as Marker2D
		valid = valid and entry != null and entry.position == spec[1]
	var west := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and west != null and west.position.x < 0.0
	valid = valid and west.get("room_id") == &"waking_coast_6" and west.get("entry_id") == &"east"
	var east := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and east != null and east.position.x > ROOM_SIZE.x
	valid = valid and east.get("room_id") == &"waking_coast_8" and east.get("entry_id") == &"west"
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
