extends RefCounted

const ROOM_PATH := "res://scenes/rooms/undertow_5.tscn"
const RoomReach := preload("res://tests/room_reach.gd")
const RoomEnemies := preload("res://tests/room_enemies.gd")
# Two screens square: east of the pools, a dead end down to a sunken wreck and its Cache.
const ROOM_SIZE := Vector2i(320, 288)
const SCREEN_HEIGHT := 144
const TILE := 16
const WORLD_LAYER := 1
const WEST_ENTRY := Vector2(12, 96)
# The floor the wreck lies on, and the ledges back up to the way in.
const FLOOR := Vector2i(10, 15)
const LEDGES := [Vector2i(12, 13), Vector2i(9, 11), Vector2i(12, 9), Vector2i(8, 7)]
# Landmark cells: layer -> {cell: atlas coords}.
const LANDMARKS := {
	# the sunken ship's hull, its bow up
	&"Wreck": {Vector2i(13, 10): Vector2i(8, 6)},
	&"Terrain": {LEDGES[0]: Vector2i(5, 7), Vector2i(7, 6): Vector2i(5, 1)},
}


func get_tests() -> Array:
	return [
		["Undertow dead end lays out two screens square", _test_lays_out],
		["Undertow dead end drops to the wreck and climbs back up", _test_both_ways],
		["The dead end's Cache lies in the wreck, on its floor", _test_cache_on_floor],
		["Undertow dead end leads only west, to the pools", _test_only_west],
		["A Silt Crab clings under a ledge over the wreck's floor", _test_silt_crab],
	]


static func _room() -> Node2D:
	if not ResourceLoader.exists(ROOM_PATH):
		return null
	return (load(ROOM_PATH) as PackedScene).instantiate() as Node2D


func _test_lays_out() -> bool:
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
	room.free()
	return valid


func _test_both_ways() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var down := RoomReach.reachable(terrain, Vector2i(WEST_ENTRY / TILE))
	var up := RoomReach.reachable(terrain, FLOOR)
	var valid := RoomReach.span_at(down, FLOOR) != null
	valid = valid and RoomReach.span_at(up, Vector2i(WEST_ENTRY / TILE)) != null
	for ledge: Vector2i in LEDGES:
		valid = valid and RoomReach.span_at(up, ledge) != null
		var data := terrain.get_cell_tile_data(ledge)
		valid = valid and data != null and data.is_collision_polygon_one_way(0, 0)
	room.free()
	return valid


func _test_cache_on_floor() -> bool:
	var room := _room()
	if room == null:
		return false
	var cache := room.get_node_or_null("Cache") as Node2D
	var valid := cache != null
	if valid:
		var terrain := room.get_node("Terrain") as TileMapLayer
		var below := Vector2i(cache.position / TILE)
		valid = terrain.get_cell_source_id(below) != -1 and below.y == FLOOR.y
		valid = valid and terrain.get_cell_source_id(below + Vector2i.UP) == -1
	room.free()
	return valid


func _test_only_west() -> bool:
	var room := _room()
	if room == null:
		return false
	var exits := room.get_node("Exits").get_children()
	var valid := exits.size() == 1
	var west := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and west != null and west.position.x < 0.0
	valid = valid and west.get("room_id") == &"undertow_4" and west.get("entry_id") == &"east"
	var bounds := room.get_node_or_null("Bounds") as StaticBody2D
	valid = valid and bounds != null and bounds.collision_layer == WORLD_LAYER
	var entry := room.get_node_or_null("Entries/west") as Marker2D
	valid = valid and entry != null and entry.position == WEST_ENTRY
	room.free()
	return valid


func _test_silt_crab() -> bool:
	var room := _room()
	if room == null:
		return false
	var crab := room.get_node_or_null("Enemies/SiltCrab") as Node2D
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := RoomEnemies.clings(terrain, crab) == FLOOR.y
	if valid:
		var x := crab.position.x
		var reach := RoomEnemies.CRAB_NOTICE
		valid = RoomEnemies.clear_of_entries(room, x - reach, x + reach)
		var cache := room.get_node("Cache") as Node2D
		valid = valid and absf(cache.position.x - x) > reach
	room.free()
	return valid
