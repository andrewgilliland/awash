extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_1.tscn"
const TILESET_PATH := "res://assets/tilesets/waking_coast_2.tres"
const LAYER_ORDER := [
	&"Backdrop", &"FarTrees", &"Wreck", &"Terrain", &"Props", &"Entries", &"Player"
]
const SCREEN := Rect2i(0, 0, 10, 9)
# Vael starts in the middle of the beach, in the surf.
const START_ENTRY := Vector2(80, 96)
const BLACKTIDE_PATH := "res://assets/sprites/weapons/blacktide_stuck.png"
# Where the rune stone, knot cord and rune ward used to stand.
const CLEARED_PROPS := [
	Vector2i(7, 2), Vector2i(7, 3), Vector2i(8, 2), Vector2i(9, 2), Vector2i(9, 3)
]
# The tidal pool's water and shallows.
const POOL_TILES := [Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5)]
const WORLD_LAYER := 1
# On the cliff top, clear of the east Exit.
const EAST_ENTRY := Vector2(148, 64)
# Landmark cells from assets/waking_shores_2.aseprite: layer -> {cell: atlas coords}.
const LANDMARKS := {
	# Far palms on the headland: crown middle, trunk and base.
	&"FarTrees":
	{
		Vector2i(4, 1): Vector2i(5, 10),
		Vector2i(4, 2): Vector2i(7, 9),
		Vector2i(4, 4): Vector2i(7, 10),
		Vector2i(7, 1): Vector2i(5, 10),
	},
	&"Wreck":
	{
		Vector2i(1, 0): Vector2i(7, 6),
		Vector2i(1, 5): Vector2i(1, 6),
		Vector2i(2, 5): Vector2i(2, 6),
	},
	&"Terrain":
	{
		Vector2i(0, 4): Vector2i(5, 6),
		Vector2i(0, 6): Vector2i(1, 0),
		Vector2i(2, 6): Vector2i(1, 0),
		# the surf: foam washing over wet sand where Vael lies, between soft edges
		Vector2i(3, 6): Vector2i(2, 8),
		Vector2i(4, 6): Vector2i(6, 5),
		Vector2i(5, 6): Vector2i(6, 5),
		Vector2i(6, 6): Vector2i(5, 8),
		Vector2i(6, 5): Vector2i(3, 4),
		Vector2i(7, 4): Vector2i(0, 2),
		Vector2i(8, 6): Vector2i(0, 4),
		Vector2i(8, 1): Vector2i(3, 4),
	},
	&"Props":
	{
		Vector2i(0, 3): Vector2i(0, 7),
		Vector2i(9, 0): Vector2i(0, 7),
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
	var backdrop := room.get_node_or_null("Backdrop") as AnimatedSprite2D
	valid = valid and backdrop != null and backdrop.sprite_frames != null
	valid = valid and backdrop.sprite_frames.get_frame_count(&"default") == 4
	valid = valid and backdrop.autoplay == "default" and not backdrop.centered
	for layer_name in [&"Wreck", &"Terrain", &"Props"]:
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
