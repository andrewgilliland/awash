extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_2.tscn"
const TILESET_PATH := "res://assets/tilesets/waking_coast_2.tres"
const LAYER_ORDER := [
	&"Backdrop",
	&"FarTrees",
	&"Trees",
	&"Wreck",
	&"Terrain",
	&"Props",
	&"Entries",
	&"Player",
]
# Two screens wide.
const ROOM_SIZE := Vector2i(320, 144)
const CELLS := Rect2i(0, 0, 20, 9)
# On the cliff top, clear of the west Exit, at the height the first Room's cliff leaves off.
const WEST_ENTRY := Vector2(12, 64)
# On the sand, clear of the east Exit.
const EAST_ENTRY := Vector2(308, 96)
const WORLD_LAYER := 1
# Landmark cells from assets/waking_shores_3.aseprite: layer -> {cell: atlas coords}.
const LANDMARKS := {
	# Far palms on the headland, near palms on the beach: crown middle and base.
	&"FarTrees": {Vector2i(5, 1): Vector2i(5, 10), Vector2i(18, 4): Vector2i(7, 10)},
	&"Trees":
	{
		Vector2i(7, 2): Vector2i(1, 10),
		Vector2i(7, 5): Vector2i(3, 10),
		Vector2i(10, 2): Vector2i(1, 10),
		Vector2i(10, 4): Vector2i(3, 9),
	},
	&"Wreck": {Vector2i(18, 4): Vector2i(2, 6)},
	&"Terrain":
	{
		Vector2i(0, 4): Vector2i(1, 2),
		Vector2i(3, 4): Vector2i(2, 2),
		Vector2i(1, 6): Vector2i(1, 4),
		Vector2i(4, 5): Vector2i(3, 4),
		Vector2i(8, 6): Vector2i(5, 5),
		Vector2i(13, 5): Vector2i(7, 2),
		Vector2i(14, 4): Vector2i(3, 2),
		Vector2i(15, 1): Vector2i(4, 4),
		Vector2i(16, 6): Vector2i(6, 5),
	},
	&"Props":
	{
		Vector2i(11, 4): Vector2i(5, 7),
		Vector2i(15, 2): Vector2i(2, 7),
		Vector2i(16, 0): Vector2i(0, 7),
	},
}


func get_tests() -> Array:
	return [
		["Rune shore Room draws its layers in order", _test_draws_layers_in_order],
		["Rune shore Room lays out two screens", _test_lays_out_two_screens],
		["Rune shore west Entry stands on the cliff", _test_west_entry_on_cliff],
		["Rune shore camera scrolls inside the Room", _test_camera_limits],
		["Rune shore leads east to the salt cliffs", _test_leads_east],
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
		valid = valid and terrain.get_cell_source_id(Vector2i(column, 8)) == 0
	room.free()
	return valid


func _test_west_entry_on_cliff() -> bool:
	var room := _room()
	if room == null:
		return false
	var entry := room.get_node_or_null("Entries/west") as Marker2D
	var valid := entry != null and entry.position == WEST_ENTRY
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


# The shore's east edge is the Exit up to the salt cliffs; neither edge is walled.
func _test_leads_east() -> bool:
	var room := _room()
	if room == null:
		return false
	var valid := room.get_node_or_null("Bounds") == null
	var exit := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and exit != null and exit.position.x > ROOM_SIZE.x
	valid = valid and exit.get("room_id") == &"waking_coast_3" and exit.get("entry_id") == &"west"
	var entry := room.get_node_or_null("Entries/east") as Marker2D
	valid = valid and entry != null and entry.position == EAST_ENTRY
	room.free()
	return valid
