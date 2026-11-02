extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_1.tscn"
# Two screens wide: an open beach, then the beach Vael wakes on below the jungle cliff. On the Map
# it sits west of the palm shore.
const ROOM_ID := &"waking_coast_1"
const MAP_CELL := Vector2i(-1, 0)
const MAP_SIZE := Vector2i(2, 1)
const CELLS := Rect2i(0, 0, 20, 9)
# A tall tree, two tiles wide, stands on the cliff top: its top-left cell, and the jungle canopy
# rows of the scenery sheet it is built from, top to bottom (leafy top, hollow, vine, roots).
const TALL_TREE := Vector2i(17, 0)
const TALL_TREE_ROWS := [29, 31, 32, 33]
# Its branch, reaching east from the trunk and on off the screen, is the high ledge.
const HIGH_BRANCH := {Vector2i(19, 1): Vector2i(4, 29)}
# The plank step and the high branch stay one-way platforms.
const PLATFORM_CELLS := [Vector2i(16, 5), Vector2i(19, 1)]
# The beach runs open from the west wall to the plank step: nothing stands on the sand to climb.
const OPEN_BEACH := Rect2i(0, 0, 16, 6)
# The sand's surface row, where nothing but the palms' trunks stands.
const SAND_ROW := 5
# Vael starts on the beach below the cliff, in the surf.
const START_ENTRY := Vector2(240, 96)
const BLACKTIDE_PATH := "res://assets/regions/waking_coast/props/blacktide_stuck.png"
# Where the rune stone, knot cord and rune ward used to stand.
const CLEARED_PROPS := [
	Vector2i(17, 2), Vector2i(17, 3), Vector2i(18, 2), Vector2i(19, 2), Vector2i(19, 3)
]
# Water tiles: the beach is open sand, with no tidal pool.
const POOL_TILES := [Vector2i(5, 16), Vector2i(6, 16)]
const WORLD_LAYER := 1
# On the cliff top, clear of the east Exit.
const EAST_ENTRY := Vector2(308, 64)
const World := preload("res://scripts/core/world.gd")
# Landmark cells: layer -> {cell: atlas coords on the Waking Coast's terrain or scenery sheet}.
const LANDMARKS := {
	# Three palms behind the beach, one on the open beach and two by the cliff: crown middles,
	# then their trunks down to the sand.
	&"FarTrees":
	{
		Vector2i(4, 2): Vector2i(1, 17),
		Vector2i(4, 3): Vector2i(1, 18),
		Vector2i(4, 4): Vector2i(0, 19),
		Vector2i(4, 5): Vector2i(3, 24),
		Vector2i(14, 2): Vector2i(1, 17),
		Vector2i(14, 3): Vector2i(1, 18),
		Vector2i(14, 4): Vector2i(2, 19),
		Vector2i(14, 5): Vector2i(1, 19),
		Vector2i(11, 2): Vector2i(1, 17),
		Vector2i(11, 4): Vector2i(0, 19),
		Vector2i(11, 5): Vector2i(3, 24),
	},
	&"Terrain":
	{
		# the sand, from the west wall to the sand Vael wakes on
		Vector2i(0, 6): Vector2i(1, 11),
		Vector2i(9, 6): Vector2i(1, 11),
		Vector2i(10, 6): Vector2i(1, 11),
		Vector2i(15, 6): Vector2i(1, 11),
		# the plank step and the jungle cliff
		Vector2i(16, 5): Vector2i(0, 15),
		Vector2i(17, 4): Vector2i(0, 13),
		Vector2i(17, 6): Vector2i(0, 14),
		# the high branch, growing from the tall tree
		Vector2i(19, 1): Vector2i(4, 29),
	},
	# A bush on the tall tree, and a crate on its branch.
	&"Props":
	{
		Vector2i(18, 3): Vector2i(3, 22),
		Vector2i(19, 0): Vector2i(7, 15),
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
		valid = valid and terrain.get_cell_source_id(Vector2i(column, 6)) == 0
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
		valid = valid and terrain.get_cell_atlas_coords(cell) not in POOL_TILES
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
		for row in range(TALL_TREE_ROWS.size()):
			for column in range(2):
				var cell := TALL_TREE + Vector2i(column, row)
				var piece := Vector2i(column, TALL_TREE_ROWS[row])
				valid = valid and trees.get_cell_atlas_coords(cell) == piece
	for cell in HIGH_BRANCH:
		valid = valid and terrain.get_cell_atlas_coords(cell) == HIGH_BRANCH[cell]
	room.free()
	return valid


# The sand is open from the west wall to the cliff: only the palms' trunks stand on it.
func _test_clear_sand() -> bool:
	var room := _room()
	if room == null:
		return false
	var trunks: Dictionary = LANDMARKS[&"FarTrees"]
	var valid := room.get_node_or_null("Wreck") == null
	for layer: TileMapLayer in room.find_children("*", "TileMapLayer", false, false):
		if layer.name == &"Terrain":
			continue
		for cell in layer.get_used_cells():
			if cell.y >= SAND_ROW:
				valid = valid and layer.name == &"FarTrees" and trunks.has(cell)
	room.free()
	return valid


# No hazy jungle behind the cliff: the Background shows there, around the tall tree.
func _test_no_haze() -> bool:
	var room := _room()
	if room == null:
		return false
	var trees := room.get_node("FarTrees") as TileMapLayer
	var tall_tree := Rect2i(TALL_TREE, Vector2i(2, TALL_TREE_ROWS.size()))
	var valid := room.get_node_or_null("FarJungle") == null
	for cell in trees.get_used_cells():
		if cell.x >= OPEN_BEACH.end.x:
			valid = valid and tall_tree.has_point(cell)
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
