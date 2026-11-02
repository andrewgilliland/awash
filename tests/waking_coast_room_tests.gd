extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_1.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
# Two screens wide: an open beach, then the beach Vael wakes on below the jungle cliff. On the Map
# it sits west of the palm shore.
const ROOM_ID := &"waking_coast_1"
const MAP_CELL := Vector2i(-1, 0)
const MAP_SIZE := Vector2i(2, 1)
const CELLS := Rect2i(0, 0, 20, 9)
# A hollow jungle tree, three tiles wide and four tall, stands on the cliff top, cut whole from
# the pack's jungle trees sheet: its cells, and its top-left on the sheet.
const TALL_TREE := Rect2i(17, 0, 3, 4)
const TALL_TREE_SHEET := Vector2i(1, 1)
# Three palms lean over the beach, each three tiles wide and four tall, standing on the sand: each
# one's top-left cell, and its top-left on the pack's palm sheet. The westmost stands at the top
# of the shore's slopes, leaning out over the water.
const PALMS := {
	Vector2i(6, 2): Vector2i(11, 1),
	Vector2i(9, 2): Vector2i(14, 1),
	Vector2i(12, 2): Vector2i(11, 1),
}
# Its branch, reaching east from the trunk and on off the screen, is the high ledge.
const HIGH_BRANCH := {Vector2i(19, 1): Vector2i(3, 7)}
# The plank step and the high branch stay one-way platforms.
const PLATFORM_CELLS := [Vector2i(16, 5), Vector2i(19, 1)]
# The beach runs open from the west wall to the plank step: nothing stands on the sand to climb.
const OPEN_BEACH := Rect2i(0, 0, 16, 6)
# The sand's surface row, where nothing but the palms' feet stands.
const SAND_ROW := 5
# West of the beach the sand steps down into the sea: a 45-degree slope, a middle shelf, another
# slope, then a low shelf at the west wall. The row each column's surface tile is in, from the
# west wall to the plank step, and the slopes' tiles on the pack's ground sheet.
const SHORE_ROWS: Array[int] = [8, 8, 8, 7, 7, 7, 7, 6, 6, 6, 6, 6, 6, 6, 6, 6]
const SLOPES := {Vector2i(3, 7): Vector2i(7, 2), Vector2i(7, 6): Vector2i(8, 1)}
# The surf, drawn in front of Vael over the shallows, from the west wall to the upper slope's
# foot, and see-through enough to show what's under it. Its surface is half a tile below the
# middle shelf: Vael walks the shelf dry-footed, and wades in waist-deep at the west wall.
const SURF := Rect2i(0, 7, 7, 2)
const SURF_LINE := 120.0
const TILE := 16
const SURF_TOP: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
const SURF_DEEP: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 2)]
const WATER_SHEET := "res://assets/packs/tropical_island/water.png"
# Vael starts on the beach below the cliff, in the surf.
const START_ENTRY := Vector2(240, 96)
const BLACKTIDE_PATH := "res://assets/regions/waking_coast/props/blacktide_stuck.png"
# Where the rune stone, knot cord and rune ward used to stand.
const CLEARED_PROPS := [
	Vector2i(17, 2), Vector2i(17, 3), Vector2i(18, 2), Vector2i(19, 2), Vector2i(19, 3)
]
const WORLD_LAYER := 1
# On the cliff top, clear of the east Exit.
const EAST_ENTRY := Vector2(308, 64)
const World := preload("res://scripts/core/world.gd")
# Landmark cells: layer -> {cell: atlas coords on the Waking Coast's terrain or scenery sheet}.
const LANDMARKS := {
	# Three palms behind the beach: each one's crown and foot.
	&"FarTrees":
	{
		Vector2i(6, 2): Vector2i(11, 1),
		Vector2i(8, 5): Vector2i(13, 4),
		Vector2i(9, 2): Vector2i(14, 1),
		Vector2i(11, 5): Vector2i(16, 4),
		Vector2i(12, 2): Vector2i(11, 1),
		Vector2i(14, 5): Vector2i(13, 4),
	},
	&"Terrain":
	{
		# the sand, from the shallows at the west wall to the sand Vael wakes on
		Vector2i(0, 8): Vector2i(2, 1),
		Vector2i(4, 7): Vector2i(2, 1),
		Vector2i(9, 6): Vector2i(2, 1),
		Vector2i(10, 6): Vector2i(3, 1),
		Vector2i(15, 6): Vector2i(2, 1),
		# the plank step and the jungle cliff
		Vector2i(16, 5): Vector2i(6, 4),
		Vector2i(17, 4): Vector2i(1, 13),
		Vector2i(17, 6): Vector2i(1, 16),
		# the high branch, growing from the tall tree
		Vector2i(19, 1): Vector2i(3, 7),
	},
	# A bush on the tall tree, and a crate on its branch.
	&"Props":
	{
		Vector2i(18, 3): Vector2i(6, 5),
		Vector2i(18, 0): Vector2i(10, 3),
	},
}


func get_tests() -> Array:
	return [
		["The first Room is two screens wide, west of the palm shore", _test_two_screens],
		["Waking Coast Room lays out its two screens", _test_lays_out_the_screen],
		["Waking Coast start Entry stands on the sand", _test_start_entry_on_sand],
		["Waking Coast west wall holds; east leads on", _test_walls_keep_player_on_screen],
		["The first Room is an open surf beach", _test_open_surf_beach],
		["The plank step and the high branch stay one-way", _test_platforms_one_way],
		["The beach runs open from the west wall", _test_open_beach],
		["West of the beach the sand slopes down into the sea in two steps", _test_shore_slopes],
		["The surf washes over the shallows in front of Vael", _test_surf],
		["A tall jungle tree on the cliff top holds the high branch", _test_tall_tree],
		["Nothing stands on the sand but the palms", _test_clear_sand],
		["Behind the cliff is only the Background and the tall tree", _test_no_haze],
		["Blacktide stands in the sand, shown only by the intro", _test_blacktide_prop],
	]


static func _room() -> Node2D:
	var packed_scene := load(ROOM_PATH) as PackedScene
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node2D


func _test_two_screens() -> bool:
	return World.cell(ROOM_ID) == MAP_CELL and World.size(ROOM_ID) == MAP_SIZE


func _test_lays_out_the_screen() -> bool:
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
		valid = valid and terrain.get_cell_source_id(Vector2i(column, CELLS.end.y - 1)) != -1
	room.free()
	return valid


func _test_start_entry_on_sand() -> bool:
	var room := _room()
	if room == null:
		return false
	var entry := room.get_node_or_null("Entries/start") as Marker2D
	var valid := entry != null and entry.position == START_ENTRY
	room.free()
	return valid


# The west edge leads nowhere yet, so a wall holds it; the east edge is the Exit to the shore.
func _test_walls_keep_player_on_screen() -> bool:
	var room := _room()
	if room == null:
		return false
	var bounds := room.get_node_or_null("Bounds") as StaticBody2D
	var valid := bounds != null and bounds.collision_layer == WORLD_LAYER
	if valid:
		valid = _is_wall(bounds.get_node_or_null("West"), 0.0, Vector2.RIGHT)
		valid = valid and bounds.get_node_or_null("East") == null
	var east := room.get_node_or_null("Entries/east") as Marker2D
	valid = valid and east != null and east.position == EAST_ENTRY
	room.free()
	return valid


static func _is_wall(node: Node, x: float, facing: Vector2) -> bool:
	var shape_node := node as CollisionShape2D
	if shape_node == null or shape_node.position.x != x:
		return false
	var boundary := shape_node.shape as WorldBoundaryShape2D
	return boundary != null and boundary.normal == facing


func _test_open_surf_beach() -> bool:
	var room := _room()
	if room == null:
		return false
	var props := room.get_node("Props") as TileMapLayer
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for cell in CLEARED_PROPS:
		valid = valid and props.get_cell_source_id(cell) == -1
	for cell in terrain.get_used_cells():
		# open sand, with no tidal pool
		valid = valid and not RoomReach.is_water(terrain, cell)
	room.free()
	return valid


func _test_blacktide_prop() -> bool:
	var room := _room()
	if room == null:
		return false
	var sword := room.get_node_or_null("Blacktide") as Sprite2D
	var valid := sword != null and not sword.visible
	if valid:
		valid = sword.texture.resource_path == BLACKTIDE_PATH
		# west of Vael, where Mara comes in from
		valid = valid and sword.position.x < START_ENTRY.x
	room.free()
	return valid


func _test_platforms_one_way() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for cell in PLATFORM_CELLS:
		var data := terrain.get_cell_tile_data(cell)
		valid = valid and data != null and data.get_collision_polygons_count(0) == 1
		valid = valid and data.is_collision_polygon_one_way(0, 0)
	room.free()
	return valid


func _test_tall_tree() -> bool:
	var room := _room()
	if room == null:
		return false
	var trees := room.get_node_or_null("FarTrees") as TileMapLayer
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := trees != null
	if valid:
		for row in range(TALL_TREE.size.y):
			for column in range(TALL_TREE.size.x):
				var offset := Vector2i(column, row)
				var cell := TALL_TREE.position + offset
				valid = valid and trees.get_cell_atlas_coords(cell) == TALL_TREE_SHEET + offset
	for cell in HIGH_BRANCH:
		valid = valid and terrain.get_cell_atlas_coords(cell) == HIGH_BRANCH[cell]
	room.free()
	return valid


static func _in_palm(cell: Vector2i) -> bool:
	for corner in PALMS:
		if Rect2i(corner, Vector2i(3, 4)).has_point(cell):
			return true
	return false


# The sand is open from the west wall to the cliff: only the palms' feet stand on it.
func _test_clear_sand() -> bool:
	var room := _room()
	if room == null:
		return false
	var valid := room.get_node_or_null("Wreck") == null
	for layer: TileMapLayer in room.find_children("*", "TileMapLayer", false, false):
		if layer.name == &"Terrain" or layer.name == &"Surf":
			continue
		for cell in layer.get_used_cells():
			if cell.y >= SAND_ROW:
				valid = valid and layer.name == &"FarTrees" and _in_palm(cell)
	room.free()
	return valid


# No hazy jungle behind the cliff: the Background shows there, around the tall tree.
func _test_no_haze() -> bool:
	var room := _room()
	if room == null:
		return false
	var trees := room.get_node("FarTrees") as TileMapLayer
	var valid := room.get_node_or_null("FarJungle") == null
	for cell in trees.get_used_cells():
		if cell.x >= OPEN_BEACH.end.x:
			valid = valid and TALL_TREE.has_point(cell)
	room.free()
	return valid


func _test_open_beach() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for row in range(OPEN_BEACH.position.y, OPEN_BEACH.end.y):
		for column in range(OPEN_BEACH.position.x, OPEN_BEACH.end.x):
			valid = valid and terrain.get_cell_source_id(Vector2i(column, row)) == -1
	room.free()
	return valid


func _test_shore_slopes() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := true
	for column in range(SHORE_ROWS.size()):
		var cell := Vector2i(column, SHORE_ROWS[column])
		valid = valid and terrain.get_cell_source_id(cell) != -1
		valid = valid and terrain.get_cell_source_id(cell + Vector2i.UP) == -1
		var data := terrain.get_cell_tile_data(cell)
		if data == null:
			valid = false
			continue
		var points := data.get_collision_polygon_points(0, 0)
		if SLOPES.has(cell):
			# solid below a diagonal that rises from the cell's west foot to its east top
			valid = valid and terrain.get_cell_atlas_coords(cell) == SLOPES[cell]
			valid = valid and points.size() == 3
			valid = valid and Vector2(-8, 8) in points and Vector2(8, -8) in points
		else:
			valid = valid and points.size() == 4
	room.free()
	return valid


func _test_surf() -> bool:
	var room := _room()
	if room == null:
		return false
	var surf := room.get_node_or_null("Surf") as TileMapLayer
	var valid := surf != null
	if valid:
		# drawn after Vael, and see-through
		valid = surf.get_index() > room.get_node("Player").get_index()
		valid = valid and surf.modulate.a > 0.5 and surf.modulate.a < 1.0
		valid = valid and surf.get_used_rect() == SURF
		valid = valid and surf.position.y + SURF.position.y * TILE == SURF_LINE
		for cell in surf.get_used_cells():
			var atlas := surf.tile_set.get_source(surf.get_cell_source_id(cell))
			valid = valid and (atlas as TileSetAtlasSource).texture.resource_path == WATER_SHEET
			var tiles := SURF_TOP if cell.y == SURF.position.y else SURF_DEEP
			valid = valid and surf.get_cell_atlas_coords(cell) in tiles
		valid = valid and surf.get_used_cells().size() == SURF.get_area()
	room.free()
	return valid
