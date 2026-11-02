extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_8.tscn"
const LANTERN_PATH := "res://assets/regions/waking_coast/props/tidefen_lantern.png"
const RoomReach := preload("res://tests/room_reach.gd")
# Six screens wide: the stilt houses over the shallows, the market square, then the harbour, two
# screens each.
const ROOM_SIZE := Vector2i(960, 144)
const CELLS := Rect2i(0, 0, 60, 9)
const TILE := 16
const WORLD_LAYER := 1
# On the sand, at the height of the Warden's gate's floor.
const WEST_ENTRY := Vector2(12, 112)
# The walkway is a log deck; the roofs are plank slabs.
const WALKWAY_DECKS := [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)]
const ROOFS := [Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6)]
# Each stilt is braced: an X over a post, row by row down to the shallows.
const STILT := {5: Vector2i(1, 3), 6: Vector2i(1, 2)}
# The walkway on stilts over the pools, and the stilts under it.
const WALKWAY_ROW := 4
const WALKWAY := Vector2i(4, 17)
const STILT_COLUMNS := [6, 11, 16]
# The old well in the shallows, down into the undertow.
const WELL_COLUMN := 9
# The market square's columns: the bell, the rest point, stands on its sand, by the Supply
# Shop's door and its stall.
const MARKET := Vector2i(20, 39)
const BELL := Vector2i(0, 0)
const BELL_CELL := Vector2i(33, 6)
const SHOP_DOOR := [Vector2i(22, 4), Vector2i(23, 4)]
const STALL := Rect2i(35, 4, 5, 3)
# The harbour: a plank pier on posts over the shallows, a jump up from the stone quay.
const PIER_ROW := 5
const PIER := Vector2i(48, 56)
const PIER_DECKS := [
	Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2), Vector2i(9, 2), Vector2i(10, 2)
]
const PIER_DECKS_END := Vector2i(11, 2)
const PIER_POSTS := [49, 53]
const HARBOUR_WATER := Vector2i(48, 57)
# Landmark cells from assets/regions/waking_coast/room_layouts/waking_coast_8.aseprite:
# layer -> {cell: atlas coords}.
const LANDMARKS := {
	&"Village":
	{
		# a stilt house's plank wall, and rope rails across the span over the well
		Vector2i(8, 2): Vector2i(4, 3),
		Vector2i(9, 3): Vector2i(4, 3),
		Vector2i(11, 3): Vector2i(7, 3),
	},
	# each house's door and window: the west one's door faces the sand, the east one's the stall
	&"VillageFront":
	{
		Vector2i(6, 2): Vector2i(12, 13),
		Vector2i(6, 3): Vector2i(12, 14),
		Vector2i(7, 2): Vector2i(10, 13),
		Vector2i(12, 2): Vector2i(10, 13),
		Vector2i(14, 2): Vector2i(12, 13),
		Vector2i(14, 3): Vector2i(12, 14),
	},
	# the jungle at the village's back: a tree at each end, crown and roots
	&"Jungle":
	{
		Vector2i(0, 3): Vector2i(7, 1),
		Vector2i(0, 6): Vector2i(7, 4),
		Vector2i(18, 3): Vector2i(7, 1),
		Vector2i(18, 6): Vector2i(7, 4),
	},
	# the harbour's dock crane on the quay: its beam and its foot
	&"Town": {Vector2i(42, 2): Vector2i(3, 1), Vector2i(45, 6): Vector2i(6, 5)},
	# the Supply Shop: its roof's peak and door, and the market cart that is its stall
	&"TownFront":
	{
		Vector2i(24, 0): Vector2i(16, 1),
		Vector2i(22, 4): Vector2i(2, 1),
		Vector2i(35, 4): Vector2i(2, 6),
	},
	&"Terrain":
	{
		Vector2i(0, 7): Vector2i(3, 1),
		Vector2i(2, 5): Vector2i(4, 4),
		Vector2i(4, 7): Vector2i(4, 1),
		Vector2i(5, 7): Vector2i(1, 1),
		Vector2i(16, 7): Vector2i(3, 1),
		Vector2i(17, 7): Vector2i(2, 1),
		Vector2i(19, 7): Vector2i(4, 1),
		# roofs over the houses
		Vector2i(5, 1): Vector2i(1, 6),
		Vector2i(15, 1): Vector2i(4, 6),
		# the stone quay, the pier's first plank, and the stone wall at the east end
		Vector2i(40, 7): Vector2i(7, 4),
		Vector2i(48, 5): Vector2i(6, 2),
		Vector2i(58, 3): Vector2i(1, 3),
	},
	# the village bell, and the Supply Shop's hanging sign
	&"Props": {BELL_CELL: BELL, Vector2i(29, 4): Vector2i(2, 4)},
}


func get_tests() -> Array:
	return [
		["Tidefen Room lays out six screens", _test_lays_out_six_screens],
		["Tidefen west Entry stands on the sand", _test_west_entry_on_sand],
		["Tidefen's walkway runs the village on stilts", _test_walkway_on_stilts],
		["Tidefen's bell and Supply Shop stand in its market square", _test_market],
		["Tidefen's harbour pier stands over the shallows, a jump up", _test_harbour],
		["Blue lanterns hang from Tidefen's eaves", _test_lanterns_under_eaves],
		["An old well in Tidefen's shallows drops into the undertow", _test_well],
		["Tidefen walls its east edge", _test_walls_east_edge],
	]


static func _room() -> Node2D:
	var packed_scene := load(ROOM_PATH) as PackedScene
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node2D


func _test_lays_out_six_screens() -> bool:
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
	var terrain := room.get_node("Terrain") as TileMapLayer
	for column in range(CELLS.size.x):
		var filled := terrain.get_cell_source_id(Vector2i(column, CELLS.end.y - 1)) != -1
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
		valid = terrain.get_cell_source_id(below) != -1
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
		var deck := terrain.get_cell_atlas_coords(Vector2i(column, WALKWAY_ROW))
		valid = valid and deck in WALKWAY_DECKS
	for column in STILT_COLUMNS:
		for row in range(WALKWAY_ROW + 1, 7):
			valid = valid and village.get_cell_atlas_coords(Vector2i(column, row)) == STILT[row]
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	valid = valid and RoomReach.span_at(reached, Vector2i(WALKWAY.y, WALKWAY_ROW)) != null
	room.free()
	return valid


# The bell stands on the square's sand, and the shop's door and stall open onto it, all of it
# walked to from the west Entry.
func _test_market() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var props := room.get_node("Props") as TileMapLayer
	var front := room.get_node_or_null("TownFront") as TileMapLayer
	var valid := front != null and props.get_cell_atlas_coords(BELL_CELL) == BELL
	valid = valid and terrain.get_cell_source_id(BELL_CELL + Vector2i.DOWN) != -1
	valid = valid and BELL_CELL.x >= MARKET.x and BELL_CELL.x <= MARKET.y
	for cell in SHOP_DOOR:
		valid = valid and front != null and front.get_cell_source_id(cell) != -1
	for column in range(STALL.position.x, STALL.end.x):
		var foot := Vector2i(column, STALL.end.y - 1)
		valid = valid and front != null and front.get_cell_source_id(foot) != -1
		valid = valid and terrain.get_cell_source_id(foot + Vector2i.DOWN) != -1
	valid = valid and STALL.position.x >= MARKET.x and STALL.end.x - 1 <= MARKET.y
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	valid = valid and RoomReach.span_at(reached, BELL_CELL + Vector2i.DOWN) != null
	room.free()
	return valid


# The pier's planks run over the harbour's shallows on posts, and the quay is a jump below it.
func _test_harbour() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var town := room.get_node_or_null("Town") as TileMapLayer
	var valid := town != null
	for column in range(PIER.x, PIER.y + 1):
		var plank := terrain.get_cell_atlas_coords(Vector2i(column, PIER_ROW))
		valid = valid and (plank in PIER_DECKS or (column == PIER.y and plank == PIER_DECKS_END))
	for column in PIER_POSTS:
		valid = valid and town != null and town.get_cell_source_id(Vector2i(column, 6)) != -1
	for column in range(HARBOUR_WATER.x, HARBOUR_WATER.y + 1):
		valid = valid and RoomReach.is_water(terrain, Vector2i(column, 7))
	var reached := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	valid = valid and RoomReach.span_at(reached, Vector2i(PIER.y, PIER_ROW)) != null
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
	# in front of the roofs they hang from
	valid = valid and lanterns.get_index() > room.get_node("Props").get_index()
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
			valid = valid and terrain.get_cell_atlas_coords(cell + Vector2i.UP) in ROOFS
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
