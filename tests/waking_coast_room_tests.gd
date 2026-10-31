extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_1.tscn"
const TILESET_PATH := "res://assets/tilesets/tropical_island_1.tres"
const LAYER_ORDER := [
	&"Backdrop", &"Clouds", &"FarTrees", &"Wreck", &"Terrain", &"Props", &"Entries", &"Player"
]
const TILE_LAYERS := [&"Backdrop", &"Clouds", &"FarTrees", &"Wreck", &"Terrain", &"Props"]
# A daytime sky over the sea: sky, a hazy band, the horizon, then sea, from the top down.
const SKY := Vector2i(7, 7)
const HAZE := Vector2i(7, 8)
const HORIZON := Vector2i(7, 9)
const HORIZON_SHIP := Vector2i(3, 10)
const SEA := Vector2i(7, 10)
const HAZE_ROW := 4
const HORIZON_ROW := 5
# The wreck's deck and the ledges up to the cliff top stay one-way platforms.
const PLATFORM_CELLS := [
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(6, 5), Vector2i(8, 1), Vector2i(9, 1)
]
const SCREEN := Rect2i(0, 0, 10, 9)
# Vael starts in the middle of the beach, in the surf.
const START_ENTRY := Vector2(80, 96)
const BLACKTIDE_PATH := "res://assets/sprites/weapons/blacktide_stuck.png"
# Where the rune stone, knot cord and rune ward used to stand.
const CLEARED_PROPS := [
	Vector2i(7, 2), Vector2i(7, 3), Vector2i(8, 2), Vector2i(9, 2), Vector2i(9, 3)
]
# Water tiles: the beach is open sand, with no tidal pool.
const POOL_TILES := [Vector2i(5, 5), Vector2i(6, 5)]
const WORLD_LAYER := 1
# On the cliff top, clear of the east Exit.
const EAST_ENTRY := Vector2(148, 64)
# Landmark cells from assets/tilesets/tropical_island_1.png: layer -> {cell: atlas coords}.
const LANDMARKS := {
	&"Backdrop":
	{
		Vector2i(0, 0): SKY,
		Vector2i(0, 4): HAZE,
		Vector2i(0, 5): HORIZON,
		Vector2i(3, 5): HORIZON_SHIP,
		Vector2i(0, 6): SEA,
	},
	# The sun (2x2) and a cloud (left, middle, right).
	&"Clouds":
	{
		Vector2i(5, 0): Vector2i(5, 7),
		Vector2i(6, 1): Vector2i(6, 8),
		Vector2i(2, 1): Vector2i(5, 6),
		Vector2i(3, 1): Vector2i(6, 6),
		Vector2i(4, 1): Vector2i(7, 6),
	},
	# A palm behind the beach: crown middle, then its trunk bending down to the sand.
	&"FarTrees":
	{
		Vector2i(4, 2): Vector2i(1, 6),
		Vector2i(4, 3): Vector2i(1, 7),
		Vector2i(4, 4): Vector2i(2, 8),
		Vector2i(4, 5): Vector2i(1, 8),
	},
	# The wreck: a mast and the posts under its deck.
	&"Wreck":
	{
		Vector2i(1, 0): Vector2i(6, 4),
		Vector2i(0, 5): Vector2i(6, 4),
		Vector2i(2, 5): Vector2i(6, 4),
	},
	&"Terrain":
	{
		# the wreck's deck of planks
		Vector2i(0, 4): Vector2i(1, 4),
		Vector2i(2, 4): Vector2i(2, 4),
		# the sand Vael wakes on
		Vector2i(0, 6): Vector2i(1, 0),
		Vector2i(5, 6): Vector2i(1, 0),
		# the plank step and the jungle cliff
		Vector2i(6, 5): Vector2i(0, 4),
		Vector2i(7, 4): Vector2i(0, 2),
		Vector2i(7, 6): Vector2i(0, 3),
		# the high branch
		Vector2i(8, 1): Vector2i(0, 9),
	},
	&"Props":
	{
		Vector2i(0, 3): Vector2i(7, 4),
		Vector2i(9, 0): Vector2i(7, 4),
	},
}


func get_tests() -> Array:
	return [
		["Waking Coast Room draws its layers in order", _test_draws_layers_in_order],
		["Waking Coast Room lays out the screen", _test_lays_out_the_screen],
		["Waking Coast start Entry stands on the sand", _test_start_entry_on_sand],
		["Waking Coast camera stays on the screen", _test_camera_stays_on_screen],
		["Waking Coast west wall holds; east leads on", _test_walls_keep_player_on_screen],
		["The first Room is an open surf beach", _test_open_surf_beach],
		["The first Room is a daytime tropical shore", _test_daytime_backdrop],
		["The wreck's deck and the ledges stay one-way", _test_platforms_one_way],
		["Blacktide stands in the sand, shown only by the intro", _test_blacktide_prop],
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
	for layer_name in TILE_LAYERS:
		var layer := room.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		valid = valid and layer != null and layer.tile_set != null
		valid = valid and layer.tile_set.resource_path == TILESET_PATH
	room.free()
	return valid


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
		valid = valid and SCREEN.encloses(layer.get_used_rect())
		var cells: Dictionary = LANDMARKS[layer_name]
		for cell in cells:
			valid = valid and layer.get_cell_atlas_coords(cell) == cells[cell]
	var terrain := room.get_node("Terrain") as TileMapLayer
	for column in range(SCREEN.size.x):
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


func _test_camera_stays_on_screen() -> bool:
	var room := _room()
	if room == null:
		return false
	var camera := room.get_node_or_null("Player/Camera2D") as Camera2D
	var valid := camera != null
	if valid:
		valid = camera.limit_left == 0 and camera.limit_top == 0
		valid = valid and camera.limit_right == 160 and camera.limit_bottom == 144
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
		# on the wreck's side of Vael, where Mara comes in from
		valid = valid and sword.position.x < START_ENTRY.x
	room.free()
	return valid


func _test_daytime_backdrop() -> bool:
	var room := _room()
	if room == null:
		return false
	var backdrop := room.get_node_or_null("Backdrop") as TileMapLayer
	var valid := backdrop != null
	if valid:
		for row in range(SCREEN.size.y):
			for column in range(SCREEN.size.x):
				var coords := backdrop.get_cell_atlas_coords(Vector2i(column, row))
				if row < HAZE_ROW:
					valid = valid and coords == SKY
				elif row == HAZE_ROW:
					valid = valid and coords == HAZE
				elif row == HORIZON_ROW:
					valid = valid and coords in [HORIZON, HORIZON_SHIP]
				else:
					valid = valid and coords == SEA
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
