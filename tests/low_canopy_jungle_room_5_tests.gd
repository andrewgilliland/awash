extends RefCounted

# The Spore Beast's lair: two screens of den under the lower terraces, dropped into through a hole
# in their floor and climbed back out up two ledges, the Spore Beast lumbering in its den and a
# chest at the far end. It shows a dark den behind it rather than the sky.

const ROOM_ID := &"low_canopy_jungle_5"
const ROOM_PATH := "res://scenes/rooms/low_canopy_jungle_5.tscn"
const Checks := preload("res://tests/jungle_room_checks.gd")
const RoomReach := preload("res://tests/room_reach.gd")
const World := preload("res://scripts/core/world.gd")
const DEN_BACKGROUND := "res://scenes/regions/low_canopy_jungle/den_background.tscn"
const SPORE_BEAST_SCENE := "res://scenes/enemies/spore_beast.tscn"
const ROOM_CELLS := Vector2i(20, 9)
const TILE := 16
# The hole in its roof, under the terraces' floor, and the Entry the drop arrives by.
const HOLE := Vector2i(4, 5)
const NORTH_ENTRY := Vector2(80, 24)
# Up from the floor: a ledge, then one under the hole, a jump below the roof.
const FLOOR := Vector2(160, 112)
const UNDER_HOLE := Vector3i(3, 3, 5)
# Its den, on the east screen, and its chest at the far end.
const BEAST := Vector2(248, 112)
const CHEST := Vector2(296, 96)
const CHEST_ID := &"lair_chest"


func get_tests() -> Array:
	return [
		["The lair lays out two screens under a roof", _test_two_screens],
		["The lair is dropped into through a hole in its roof, from the terraces", _test_hole],
		["Ledges climb from the lair's floor to just under the hole", _test_climb_out],
		["The Spore Beast lumbers in its den on the east screen", _test_beast],
		["A chest of three Glowroe waits at the lair's far end", _test_chest],
		["The lair is walled at both ends and shows a dark den behind it", _test_den],
	]


func _test_two_screens() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := terrain.get_used_rect() == Rect2i(Vector2i.ZERO, ROOM_CELLS)
	for column in range(ROOM_CELLS.x):
		valid = valid and terrain.get_cell_source_id(Vector2i(column, ROOM_CELLS.y - 1)) != -1
		var roofed := terrain.get_cell_source_id(Vector2i(column, 0)) != -1
		valid = valid and roofed == (column < HOLE.x or column > HOLE.y)
	room.free()
	return valid


func _test_hole() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var entry := room.get_node_or_null("Entries/north") as Marker2D
	var valid := entry != null and entry.position == NORTH_ENTRY
	var exit := room.get_node_or_null("Exits/north") as Area2D
	valid = valid and exit != null and exit.position.y < 0.0
	if valid:
		var column := int(exit.position.x / TILE)
		valid = column >= HOLE.x and column <= HOLE.y
		valid = valid and exit.get("room_id") == &"low_canopy_jungle_2"
		valid = valid and exit.get("entry_id") == &"south"
	room.free()
	return valid


func _test_climb_out() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var under := Vector2(UNDER_HOLE.y * TILE + 8, UNDER_HOLE.x * TILE)
	var valid := Checks.reaches(room, FLOOR, under)
	valid = valid and UNDER_HOLE.y <= HOLE.x and UNDER_HOLE.z >= HOLE.y
	valid = valid and UNDER_HOLE.x - 1 <= RoomReach.jump_rows()
	for column in range(UNDER_HOLE.y, UNDER_HOLE.z + 1):
		valid = valid and terrain.get_cell_source_id(Vector2i(column, UNDER_HOLE.x)) != -1
	room.free()
	return valid


func _test_beast() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var beasts: Array = []
	if room.has_node("Enemies"):
		beasts = room.get_node("Enemies").get_children()
	var valid := beasts.size() == 1
	if valid:
		var beast := beasts[0] as Node2D
		valid = beast.scene_file_path == SPORE_BEAST_SCENE and beast.position == BEAST
		valid = valid and beast.position.x >= World.SCREEN_SIZE.x
		valid = valid and terrain.get_cell_source_id(Vector2i(beast.position / TILE)) != -1
	room.free()
	return valid


func _test_chest() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var chest := room.get_node_or_null("DenChest") as Node2D
	var valid := chest != null and chest.position == CHEST
	if valid:
		valid = chest.get("cache_id") == CHEST_ID and chest.get("kind") == &"glowroe"
		valid = valid and chest.get("count") == 3
		valid = valid and chest.position.x > BEAST.x
	valid = valid and Checks.reaches(room, FLOOR, CHEST + Vector2(0, 16))
	room.free()
	return valid


func _test_den() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var west := room.get_node_or_null("Bounds/West")
	var east := room.get_node_or_null("Bounds/East")
	var valid := west != null and east != null
	valid = valid and World.background(ROOM_ID) == DEN_BACKGROUND
	room.free()
	return valid
