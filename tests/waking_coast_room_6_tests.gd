extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_6.tscn"
const TILESET_PATH := "res://assets/tilesets/waking_coast_2.tres"
const RoomReach := preload("res://tests/room_reach.gd")
const LAYER_ORDER := [&"Backdrop", &"Trees", &"Terrain", &"Props", &"Entries", &"Player"]
# Two screens wide.
const ROOM_SIZE := Vector2i(320, 144)
const CELLS := Rect2i(0, 0, 20, 9)
const TILE := 16
# On the sand, clear of the west Exit, at the height of the graveyard's beach.
const WEST_ENTRY := Vector2(12, 96)
const WORLD_LAYER := 1
# The heights the road climbs to, at the rune gate by the east edge.
const EAST_END := Vector2i(19, 3)
const RUNE_STONE := Vector2i(5, 7)
const RUNE_STONE_BASE := Vector2i(6, 7)
# Landmark cells from assets/waking_shores_7.aseprite: layer -> {cell: atlas coords}.
const LANDMARKS := {
	# a palm on the beach before the road: crown middle and base
	&"Trees": {Vector2i(2, 2): Vector2i(1, 10), Vector2i(2, 5): Vector2i(3, 10)},
	&"Terrain":
	{
		# the beach the road leaves from
		Vector2i(0, 6): Vector2i(1, 0),
		Vector2i(3, 6): Vector2i(1, 0),
		# the road, a step at a time up onto the heights
		Vector2i(4, 5): Vector2i(0, 2),
		Vector2i(7, 5): Vector2i(1, 2),
		Vector2i(8, 4): Vector2i(0, 2),
		Vector2i(12, 3): Vector2i(0, 2),
		Vector2i(19, 3): Vector2i(1, 2),
		# runes set in the rock under it
		Vector2i(10, 6): Vector2i(1, 4),
		Vector2i(15, 5): Vector2i(0, 4),
	},
	&"Props":
	{
		# rune stones along the road, and a pair at the gate
		Vector2i(6, 3): RUNE_STONE,
		Vector2i(10, 2): RUNE_STONE,
		Vector2i(16, 1): RUNE_STONE,
		Vector2i(18, 1): RUNE_STONE,
	},
}


func get_tests() -> Array:
	return [
		["Rune road Room draws its layers in order", _test_draws_layers_in_order],
		["Rune road Room lays out two screens", _test_lays_out_two_screens],
		["Rune road west Entry stands on the beach", _test_west_entry_on_beach],
		["Rune road climbs east a step at a time", _test_climbs_east],
		["Rune stones stand on the road", _test_rune_stones_on_road],
		["Rune road camera scrolls inside the Room", _test_camera_limits],
		["Rune road walls its east edge", _test_walls_east_edge],
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
	for layer_name in [&"Trees", &"Terrain", &"Props"]:
		var layer := room.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		valid = valid and layer != null and layer.tile_set != null
		valid = valid and layer.tile_set.resource_path == TILESET_PATH
	room.free()
	return valid


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
	var terrain := room.get_node("Terrain") as TileMapLayer
	for column in range(CELLS.size.x):
		valid = valid and terrain.get_cell_source_id(Vector2i(column, CELLS.end.y - 1)) == 0
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
	var exit := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and exit != null and exit.position.x < 0.0
	valid = valid and exit.get("room_id") == &"waking_coast_4" and exit.get("entry_id") == &"east"
	room.free()
	return valid


# Each step of the road is one tile up from the last, so the climb never needs more than a
# small jump, and it reaches the heights at the east edge.
func _test_climbs_east() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	var valid := RoomReach.span_at(reached, EAST_END) != null
	var previous := _surface_row(terrain, 0)
	for column in range(1, CELLS.size.x):
		var surface := _surface_row(terrain, column)
		valid = valid and previous - surface <= 1
		previous = surface
	room.free()
	return valid


# The row of a column's topmost Terrain tile.
static func _surface_row(terrain: TileMapLayer, column: int) -> int:
	var row := 0
	while row < CELLS.end.y and terrain.get_cell_source_id(Vector2i(column, row)) == -1:
		row += 1
	return row


# Each rune stone is two tiles tall, its base standing on the road's surface.
func _test_rune_stones_on_road() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var props := room.get_node("Props") as TileMapLayer
	var stones := 0
	var valid := true
	for cell in props.get_used_cells():
		if props.get_cell_atlas_coords(cell) != RUNE_STONE:
			continue
		stones += 1
		var base := cell + Vector2i.DOWN
		valid = valid and props.get_cell_atlas_coords(base) == RUNE_STONE_BASE
		valid = valid and terrain.get_cell_source_id(base) == -1
		valid = valid and terrain.get_cell_source_id(base + Vector2i.DOWN) == 0
	room.free()
	return valid and stones == LANDMARKS[&"Props"].size()


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


# The Warden's gate is not built yet, so the east edge is a wall.
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
