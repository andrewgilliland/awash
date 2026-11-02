extends RefCounted

# What holds for every Room in the World. Each Room's own tests keep only what is its own:
# landmarks, Entries, walls and Exits, enemies and props.

const World := preload("res://scripts/core/world.gd")
const RoomExitScript := preload("res://scripts/core/room_exit.gd")
# One screen in tiles.
const SCREEN_CELLS := Vector2i(10, 9)
const TRIGGER_LAYER := 1 << 7
const PLAYER_LAYER := 1 << 1

# Needs a root that is already in the tree: a Room sets itself up from the World in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Every Room in the World has a scene", _test_has_scene],
		["Every Room is found in the World by its scene", _test_found_by_scene],
		["Every Room's Region is in the World", _test_region_held],
		["Every Room's Exits lead to Entries in the World", _test_exits_lead_to_entries],
		["No Room scene sets its own camera limits", _test_scene_leaves_camera],
		["Every Room keeps its camera inside its size", _test_camera_inside],
		["Every Room draws its layers in order", _test_layer_order],
		["Every Room keeps its tiles inside its size", _test_tiles_inside],
		["Every Room draws only from its Region's sheets", _test_region_sheets],
		["No Room scene holds its own Background", _test_scene_leaves_background],
		["Every Room draws its Region's Background behind all else", _test_background],
		["Every Room's Region has a looping theme", _test_region_theme],
	]


# Loads each Room in the World and asks the check of it, naming each Room that fails.
static func _every_room(check: Callable) -> bool:
	var valid := not World.room_ids().is_empty()
	for room_id in World.room_ids():
		var room := _load_room(room_id)
		if room == null or not check.call(room_id, room):
			push_error("Room '%s' fails this check." % room_id)
			valid = false
		if room != null:
			room.free()
	return valid


# Enters each Room in the World at its first Entry, as an Exit would, and asks the check of it.
func _every_entered_room(check: Callable) -> bool:
	var run := _root.get_node("RunState")
	var valid := _every_room(
		func(room_id: StringName, room: Node2D) -> bool:
			run.call("enter_room", room_id, room.get_node("Entries").get_child(0).name)
			_root.add_child(room)
			var passed: bool = check.call(room_id, room)
			_root.remove_child(room)
			return passed
	)
	run.call("start_run")
	return valid


static func _load_room(room_id: StringName) -> Node2D:
	var path := World.scene(room_id)
	var packed_scene := load(path) as PackedScene if not path.is_empty() else null
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node2D


static func _size_in_cells(room_id: StringName) -> Vector2i:
	return World.size(room_id) * SCREEN_CELLS


func _test_has_scene() -> bool:
	return _every_room(func(_room_id: StringName, _room: Node2D) -> bool: return true)


func _test_found_by_scene() -> bool:
	return _every_room(
		func(room_id: StringName, room: Node2D) -> bool:
			return World.room_for_scene(room.scene_file_path) == room_id
	)


func _test_region_held() -> bool:
	return _every_room(
		func(room_id: StringName, _room: Node2D) -> bool:
			return World.has_region(World.region(room_id))
	)


func _test_exits_lead_to_entries() -> bool:
	return _every_room(_exits_lead_to_entries)


static func _exits_lead_to_entries(_room_id: StringName, room: Node2D) -> bool:
	var valid := true
	for node in room.find_children("*", "Area2D", true, false):
		if node.get_script() != RoomExitScript:
			continue
		var exit := node as Area2D
		valid = valid and exit.collision_layer == TRIGGER_LAYER
		valid = valid and exit.collision_mask == PLAYER_LAYER
		var target := _load_room(exit.get("room_id"))
		valid = valid and target != null
		if target != null:
			var entry := target.get_node_or_null("Entries/%s" % exit.get("entry_id"))
			valid = valid and entry is Marker2D
			target.free()
	return valid


func _test_scene_leaves_camera() -> bool:
	return _every_room(_leaves_camera)


# The camera's limits are the Room's to set from the World, so the scene keeps Godot's own.
static func _leaves_camera(_room_id: StringName, room: Node2D) -> bool:
	var camera := room.get_node_or_null("Player/Camera2D") as Camera2D
	var unset := Camera2D.new()
	var valid := camera != null
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		valid = valid and camera.get_limit(side) == unset.get_limit(side)
	unset.free()
	return valid


func _test_camera_inside() -> bool:
	return _every_entered_room(_camera_inside)


static func _camera_inside(room_id: StringName, room: Node2D) -> bool:
	var camera := room.get_node_or_null("Player/Camera2D") as Camera2D
	var size := Vector2i(Vector2(World.size(room_id)) * World.SCREEN_SIZE)
	if camera == null:
		return false
	var valid := camera.limit_left == 0 and camera.limit_top == 0
	return valid and camera.limit_right == size.x and camera.limit_bottom == size.y


func _test_layer_order() -> bool:
	return _every_room(_layers_in_order)


# Scenery layers behind the Terrain, then Props, Entries, and the Player drawn last of all.
static func _layers_in_order(_room_id: StringName, room: Node2D) -> bool:
	var terrain := room.get_node_or_null("Terrain")
	var props := room.get_node_or_null("Props")
	var entries := room.get_node_or_null("Entries")
	var player := room.get_node_or_null("Player")
	if [terrain, props, entries, player].has(null):
		return false
	var valid := player.get_index() == room.get_child_count() - 1
	valid = valid and terrain.get_index() < props.get_index()
	valid = valid and props.get_index() < entries.get_index()
	valid = valid and entries.get_index() < player.get_index()
	for child in room.get_children():
		if child is TileMapLayer and child != terrain and child != props:
			valid = valid and child.get_index() < terrain.get_index()
	return valid


func _test_tiles_inside() -> bool:
	return _every_room(_tiles_inside)


static func _tiles_inside(room_id: StringName, room: Node2D) -> bool:
	var cells := Rect2i(Vector2i.ZERO, _size_in_cells(room_id))
	var valid := true
	for child in room.get_children():
		if child is TileMapLayer:
			valid = valid and cells.encloses((child as TileMapLayer).get_used_rect())
	return valid


func _test_region_sheets() -> bool:
	return _every_entered_room(_draws_from_region_sheets)


# A Room's Terrain layer comes from its Region's terrain sheet, in the folder named by the Region's
# id; every other layer, its Background's included, from the scenery sheet.
static func _draws_from_region_sheets(room_id: StringName, room: Node2D) -> bool:
	var tiles := "res://assets/regions/%s/tiles/" % World.region(room_id)
	var terrain := room.get_node_or_null("Terrain")
	var valid := terrain is TileMapLayer
	for layer: TileMapLayer in room.find_children("*", "TileMapLayer", true, false):
		var sheet := "terrain" if layer == terrain else "scenery"
		var path := layer.tile_set.resource_path if layer.tile_set != null else ""
		if path != tiles + sheet + ".tres":
			push_error("%s/%s draws from %s" % [room_id, room.get_path_to(layer), path])
			valid = false
	return valid


func _test_scene_leaves_background() -> bool:
	return _every_room(
		func(_room_id: StringName, room: Node2D) -> bool:
			return room.get_node_or_null("Background") == null
	)


func _test_background() -> bool:
	return _every_entered_room(_shows_region_background)


# The Background the World names for the Room, drawn first of everything in the Room's world.
static func _shows_region_background(room_id: StringName, room: Node2D) -> bool:
	var background := room.get_node_or_null("Background")
	var expected := World.background(room_id)
	if background == null or expected.is_empty() or background.scene_file_path != expected:
		return false
	var valid := true
	for child in room.get_children():
		if child is CanvasItem and child != background:
			valid = valid and child.get_index() > background.get_index()
	return valid


func _test_region_theme() -> bool:
	return _every_room(_region_has_theme)


static func _region_has_theme(room_id: StringName, _room: Node2D) -> bool:
	var path := World.theme(room_id)
	var theme := load(path) as AudioStreamWAV if not path.is_empty() else null
	return theme != null and theme.loop_mode == AudioStreamWAV.LOOP_FORWARD
