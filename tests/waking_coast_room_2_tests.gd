extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_2.tscn"
# Two screens wide.
const ROOM_SIZE := Vector2i(320, 144)
const CELLS := Rect2i(0, 0, 20, 9)
# On the cliff top, clear of the west Exit, at the height the first Room's cliff leaves off.
const WEST_ENTRY := Vector2(12, 64)
# On the sand, clear of the east Exit.
const EAST_ENTRY := Vector2(308, 96)
const WORLD_LAYER := 1
# Landmark cells: layer -> {cell: atlas coords}.
const LANDMARKS := {
	# Palms on the beach: crown middle and trunk.
	&"Trees":
	{
		Vector2i(7, 2): Vector2i(5, 1),
		Vector2i(7, 5): Vector2i(5, 4),
		Vector2i(10, 2): Vector2i(8, 1),
		Vector2i(10, 4): Vector2i(8, 3),
	},
	&"Wreck": {Vector2i(18, 4): Vector2i(4, 2)},
	&"Terrain":
	{
		Vector2i(0, 4): Vector2i(3, 13),
		Vector2i(3, 4): Vector2i(5, 13),
		Vector2i(1, 6): Vector2i(3, 15),
		Vector2i(4, 5): Vector2i(4, 4),
		Vector2i(8, 6): Vector2i(1, 1),
		# a sand slope up from the beach to a step a tile high
		Vector2i(13, 5): Vector2i(7, 2),
		Vector2i(14, 5): Vector2i(2, 1),
		Vector2i(15, 1): Vector2i(5, 4),
		Vector2i(16, 6): Vector2i(3, 1),
	},
	&"Props":
	{
		Vector2i(11, 5): Vector2i(14, 7),
		Vector2i(15, 2): Vector2i(3, 7),
		Vector2i(16, 0): Vector2i(10, 3),
	},
}


func get_tests() -> Array:
	return [
		["Palm shore Room lays out two screens", _test_lays_out_two_screens],
		["Palm shore west Entry stands on the cliff", _test_west_entry_on_cliff],
		["Palm shore leads east to the tide pools", _test_leads_east],
	]


static func _room() -> Node2D:
	var packed_scene := load(ROOM_PATH) as PackedScene
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node2D


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
		var cells: Dictionary = LANDMARKS[layer_name]
		for cell in cells:
			valid = valid and layer.get_cell_atlas_coords(cell) == cells[cell]
	var terrain := room.get_node("Terrain") as TileMapLayer
	for column in range(CELLS.size.x):
		valid = valid and terrain.get_cell_source_id(Vector2i(column, 8)) != -1
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


# The shore's east edge is the Exit on to the tide pools; neither edge is walled.
func _test_leads_east() -> bool:
	var room := _room()
	if room == null:
		return false
	var valid := room.get_node_or_null("Bounds") == null
	var exit := room.get_node_or_null("Exits/east") as Area2D
	valid = valid and exit != null and exit.position.x > ROOM_SIZE.x
	valid = valid and exit.get("room_id") == &"waking_coast_10" and exit.get("entry_id") == &"west"
	var entry := room.get_node_or_null("Entries/east") as Marker2D
	valid = valid and entry != null and entry.position == EAST_ENTRY
	room.free()
	return valid
