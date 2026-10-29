extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_8.tscn"
const TILESET_PATH := "res://assets/tilesets/waking_coast_2.tres"
const LANTERN_PATH := "res://assets/sprites/props/tidefen_lantern.png"
const RoomReach := preload("res://tests/room_reach.gd")
const LAYER_ORDER := [
	&"Backdrop",
	&"Village",
	&"Terrain",
	&"Props",
	&"Lanterns",
	&"Entries",
	&"Player",
]
# Two screens wide.
const ROOM_SIZE := Vector2i(320, 144)
const CELLS := Rect2i(0, 0, 20, 9)
const TILE := 16
const WORLD_LAYER := 1
# On the sand, at the height of the Warden's gate's floor.
const WEST_ENTRY := Vector2(12, 112)
const DECKS := [Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6)]
const STILT := Vector2i(7, 6)
const CAVE_DARK := Vector2i(6, 4)
# The walkway on stilts over the pools, and the stilts under it.
const WALKWAY_ROW := 4
const WALKWAY := Vector2i(4, 17)
const STILT_COLUMNS := [6, 11, 16]
# The old well in the shallows, down into the undertow.
const WELL_COLUMN := 9
const BELL := Vector2i(3, 7)
const CRATE := Vector2i(0, 7)
const BARREL := Vector2i(1, 7)
# Landmark cells from assets/waking_shores_9.aseprite: layer -> {cell: atlas coords}.
const LANDMARKS := {
	&"Village":
	{
		# two stilt houses on the walkway, and the well's dark
		Vector2i(6, 2): Vector2i(0, 6),
		Vector2i(7, 3): Vector2i(1, 6),
		Vector2i(14, 2): Vector2i(2, 6),
		Vector2i(9, 7): CAVE_DARK,
	},
	&"Terrain":
	{
		Vector2i(0, 7): Vector2i(1, 0),
		Vector2i(2, 5): Vector2i(3, 4),
		Vector2i(4, 7): Vector2i(2, 8),
		Vector2i(5, 7): Vector2i(5, 5),
		Vector2i(16, 7): Vector2i(5, 5),
		Vector2i(17, 7): Vector2i(5, 8),
		Vector2i(19, 7): Vector2i(1, 0),
		# roofs over the houses
		Vector2i(5, 1): Vector2i(4, 6),
		Vector2i(15, 1): Vector2i(6, 6),
	},
	# the village bell, and the shop's stall by the east house
	&"Props": {Vector2i(10, 3): BELL, Vector2i(16, 3): CRATE, Vector2i(17, 3): BARREL},
}


func get_tests() -> Array:
	return [
		["Tidefen Room draws its layers in order", _test_draws_layers_in_order],
		["Tidefen Room lays out two screens", _test_lays_out_two_screens],
		["Tidefen west Entry stands on the sand", _test_west_entry_on_sand],
		["Tidefen's walkway runs the village on stilts", _test_walkway_on_stilts],
		["Tidefen's bell and stall stand on the walkway", _test_bell_and_stall],
		["Blue lanterns hang from Tidefen's eaves", _test_lanterns_under_eaves],
		["An old well in Tidefen's shallows drops into the undertow", _test_well],
		["Tidefen camera scrolls inside the Room", _test_camera_limits],
		["Tidefen walls its east edge", _test_walls_east_edge],
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
	for layer_name in [&"Village", &"Terrain", &"Props"]:
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
		var filled := terrain.get_cell_source_id(Vector2i(column, CELLS.end.y - 1)) == 0
		valid = valid and filled == (column != WELL_COLUMN)
	room.free()
	return valid


func _test_west_entry_on_sand() -> bool:
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
	valid = valid and exit.get("room_id") == &"waking_coast_7" and exit.get("entry_id") == &"east"
	room.free()
	return valid


# One unbroken walkway of decks, stilts under it, reached from the sand a jump at a time.
func _test_walkway_on_stilts() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var village := room.get_node("Village") as TileMapLayer
	var valid := true
	for column in range(WALKWAY.x, WALKWAY.y + 1):
		valid = valid and terrain.get_cell_atlas_coords(Vector2i(column, WALKWAY_ROW)) in DECKS
	for column in STILT_COLUMNS:
		for row in range(WALKWAY_ROW + 1, 7):
			valid = valid and village.get_cell_atlas_coords(Vector2i(column, row)) == STILT
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	valid = valid and RoomReach.span_at(reached, Vector2i(WALKWAY.y, WALKWAY_ROW)) != null
	room.free()
	return valid


func _test_bell_and_stall() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var props := room.get_node("Props") as TileMapLayer
	var valid := true
	for cell in LANDMARKS[&"Props"]:
		valid = valid and props.get_cell_atlas_coords(cell) == LANDMARKS[&"Props"][cell]
		valid = valid and terrain.get_cell_atlas_coords(cell + Vector2i.DOWN) in DECKS
	room.free()
	return valid


# Each lantern swings from just under a roof's deck, flickering through its four frames.
func _test_lanterns_under_eaves() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var lanterns := room.get_node_or_null("Lanterns")
	var valid := lanterns != null and lanterns.get_child_count() >= 4
	if valid:
		for lantern in lanterns.get_children():
			var sprite := lantern as AnimatedSprite2D
			valid = valid and sprite != null and sprite.sprite_frames != null
			if not valid:
				break
			valid = valid and sprite.sprite_frames.get_frame_count(&"default") == 4
			var frame := sprite.sprite_frames.get_frame_texture(&"default", 0) as AtlasTexture
			valid = valid and frame != null and frame.atlas.resource_path == LANTERN_PATH
			var cell := Vector2i(sprite.position / TILE)
			valid = valid and terrain.get_cell_source_id(cell) == -1
			valid = valid and terrain.get_cell_atlas_coords(cell + Vector2i.UP) in DECKS
	room.free()
	return valid


# A hole in the shallows to the bottom of the Room, and an Exit under it down into the
# undertow's shaft.
func _test_well() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for row in range(7, CELLS.end.y):
		valid = valid and terrain.get_cell_source_id(Vector2i(WELL_COLUMN, row)) == -1
	var exit := room.get_node_or_null("Exits/well") as Area2D
	valid = valid and exit != null and exit.position.y > ROOM_SIZE.y
	valid = valid and int(exit.position.x / TILE) == WELL_COLUMN
	valid = valid and exit.get("room_id") == &"waking_coast_9" and exit.get("entry_id") == &"well"
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


# Tidefen is the end of the coast; the jungle past it is the next chapter.
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
