extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_1.tscn"
const TILESET_PATH := "res://assets/tilesets/waking_coast_2.tres"
const LAYER_ORDER := [&"Backdrop", &"Wreck", &"Terrain", &"Props", &"Entries", &"Player"]
const SCREEN := Rect2i(0, 0, 10, 9)
const START_ENTRY := Vector2(6, 96)
# Landmark cells from assets/waking_shores_2.aseprite: layer -> {cell: atlas coords}.
const LANDMARKS := {
	&"Wreck":
	{
		Vector2i(1, 0): Vector2i(7, 6),
		Vector2i(1, 5): Vector2i(1, 6),
		Vector2i(2, 5): Vector2i(2, 6),
	},
	&"Terrain":
	{
		Vector2i(0, 4): Vector2i(5, 6),
		Vector2i(3, 5): Vector2i(6, 6),
		Vector2i(0, 6): Vector2i(1, 0),
		Vector2i(2, 6): Vector2i(6, 5),
		Vector2i(4, 6): Vector2i(5, 5),
		Vector2i(6, 5): Vector2i(3, 4),
		Vector2i(7, 4): Vector2i(0, 2),
		Vector2i(8, 6): Vector2i(0, 4),
		Vector2i(8, 1): Vector2i(3, 4),
	},
	&"Props":
	{
		Vector2i(0, 3): Vector2i(0, 7),
		Vector2i(7, 2): Vector2i(5, 7),
		Vector2i(9, 2): Vector2i(2, 4),
		Vector2i(9, 0): Vector2i(0, 7),
	},
}


func get_tests() -> Array:
	return [
		["Waking Coast Room draws its layers in order", _test_draws_layers_in_order],
		["Waking Coast Room lays out the screen", _test_lays_out_the_screen],
		["Waking Coast start Entry stands on the sand", _test_start_entry_on_sand],
		["Waking Coast camera stays on the screen", _test_camera_stays_on_screen],
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
