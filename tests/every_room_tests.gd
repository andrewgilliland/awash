extends RefCounted

# What holds for every Room in the World. Each Room's own tests keep only what is its own:
# landmarks, Entries, walls and Exits, enemies and props.

const World := preload("res://scripts/core/world.gd")
const CACHE_PATH := "res://scenes/world/cache.tscn"
# Every Cache in the World: Tidefen's bomb crate, the wreck's chest, the salt cliffs' high crate,
# the sea cave's crate, the passage's chest, the lake's chest, the upper terraces' high chest and
# the Spore Beast's lair's chest.
const CACHES := 8
const RoomCaches := preload("res://tests/room_caches.gd")
const PICKUPS_PATH := "res://scripts/items/pickups.gd"
const RoomExitScript := preload("res://scripts/core/room_exit.gd")
# One screen in tiles.
const SCREEN_CELLS := Vector2i(10, 9)
const TRIGGER_LAYER := 1 << 7
const PLAYER_LAYER := 1 << 1
# Every Room is drawn from the Mucho Pixels packs' sheets, but for art drawn for Awash: the coast's
# own prop, Tidefen's bell, which no pack has, and the jungle's sheets, cut from its mockup.
const PACK_DIR := "res://assets/packs/"
const OWN_PROPS := "res://assets/regions/waking_coast/props/coast_props.png"
const BELL := Vector2i(0, 0)
const JUNGLE_SHEETS := "res://assets/regions/low_canopy_jungle/tiles/"
# The Shrinekeeper Camp's bell, hung in its shrine, on the jungle's sheet.
const JUNGLE_SHEET := JUNGLE_SHEETS + "low_canopy_jungle.png"
const SHRINE_BELL := Vector2i(3, 8)
# The layers drawn in front of the Player: water it wades through.
const FOREGROUND: Array[StringName] = [&"Surf"]

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
		["The World puts every Room's Exits on the Map where they are", _test_exits_on_map],
		["The World marks every Rest point and Boss on the Map", _test_markers_on_map],
		["Every Region has its own colour on the Map", _test_region_colours],
		["No Room scene sets its own camera limits", _test_scene_leaves_camera],
		["Every Room keeps its camera inside its size", _test_camera_inside],
		["Every Room draws its layers in order", _test_layer_order],
		["Every Room keeps its tiles inside its size", _test_tiles_inside],
		["Every Room draws only from its Region's sheets", _test_region_sheets],
		["Every Room draws from the packs, or art drawn for Awash", _test_pack_art],
		["No Room scene holds its own Background", _test_scene_leaves_background],
		["Every Room draws its Region's Background behind all else", _test_background],
		["Every Room's Region has a looping theme", _test_region_theme],
		["Every Cache in the World has an id of its own", _test_cache_ids],
		["Every Cache is drawn whole, shut and open", _test_caches_drawn_whole],
		["Every Cache has a pickup for what it holds", _test_caches_spill],
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


func _test_exits_on_map() -> bool:
	return _every_room(_exits_on_map)


# Each Exit, from just past the Room's edge: the screen it leaves from, and the side.
static func _exits_on_map(room_id: StringName, room: Node2D) -> bool:
	var size := Vector2(World.size(room_id)) * World.SCREEN_SIZE
	var found: Array[String] = []
	for node in room.find_children("*", "Area2D", true, false):
		if node.get_script() != RoomExitScript:
			continue
		var at := (node as Node2D).position
		var side := &"south"
		if at.x < 0.0:
			side = &"west"
		elif at.x > size.x:
			side = &"east"
		elif at.y < 0.0:
			side = &"north"
		found.append(_on_map(_screen_of(room_id, at), side))
	var listed: Array[String] = []
	for exit: Dictionary in World.exits(room_id):
		listed.append(_on_map(exit.screen, exit.side))
	found.sort()
	listed.sort()
	if found != listed:
		push_error("%s has Exits %s; the World lists %s" % [room_id, found, listed])
	return found == listed


func _test_markers_on_map() -> bool:
	return _every_room(_markers_on_map)


# A Boss is a node in the boss group, marked on its screen. A Rest point is rung at a bell, so it is
# marked on a screen with one; not every bell is a Rest point.
static func _markers_on_map(room_id: StringName, room: Node2D) -> bool:
	var bosses := {}
	for node in room.find_children("*", "Node2D", true, false):
		if node.is_in_group(&"boss"):
			bosses[&"boss"] = _screen_of(room_id, (node as Node2D).position)
	var markers := World.markers(room_id)
	var valid: bool = bosses.get(&"boss") == markers.get(&"boss")
	if markers.has(&"rest"):
		valid = valid and markers[&"rest"] in _bell_screens(room_id, room)
	for kind: StringName in markers:
		valid = valid and kind in [&"boss", &"rest"]
	if not valid:
		push_error("%s marks %s on the Map" % [room_id, markers])
	return valid


static func _bell_screens(room_id: StringName, room: Node2D) -> Array[Vector2i]:
	var screens: Array[Vector2i] = []
	for layer: TileMapLayer in room.find_children("*", "TileMapLayer", false, false):
		for cell in layer.get_used_cells():
			var atlas := layer.tile_set.get_source(layer.get_cell_source_id(cell))
			var sheet := (atlas as TileSetAtlasSource).texture.resource_path
			var coords := layer.get_cell_atlas_coords(cell)
			if (
				(sheet == OWN_PROPS and coords == BELL)
				or (sheet == JUNGLE_SHEET and coords == SHRINE_BELL)
			):
				screens.append(_screen_of(room_id, layer.map_to_local(cell)))
	return screens


func _test_region_colours() -> bool:
	var colours := {}
	for room_id in World.room_ids():
		colours[World.region(room_id)] = World.region_colour(room_id)
	var valid := not colours.is_empty()
	for colour: Color in colours.values():
		valid = valid and colour.a == 1.0 and colours.values().count(colour) == 1
	return valid


# The screen of a Room a point is on, counted from its top-left.
static func _screen_of(room_id: StringName, at: Vector2) -> Vector2i:
	var screen := Vector2i((at / World.SCREEN_SIZE).floor())
	return screen.clamp(Vector2i.ZERO, World.size(room_id) - Vector2i.ONE)


static func _on_map(screen: Vector2i, side: StringName) -> String:
	return "%s %s" % [screen, side]


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


# Scenery layers behind the Terrain, then Props, Entries, and the Player; drawn after the Player,
# only what it wades through, in front of it.
static func _layers_in_order(_room_id: StringName, room: Node2D) -> bool:
	var terrain := room.get_node_or_null("Terrain")
	var props := room.get_node_or_null("Props")
	var entries := room.get_node_or_null("Entries")
	var player := room.get_node_or_null("Player")
	if [terrain, props, entries, player].has(null):
		return false
	var valid := terrain.get_index() < props.get_index()
	valid = valid and props.get_index() < entries.get_index()
	valid = valid and entries.get_index() < player.get_index()
	for child in room.get_children():
		if child.get_index() > player.get_index():
			valid = valid and FOREGROUND.has(child.name) and child is TileMapLayer
		elif child is TileMapLayer and child != terrain and child != props:
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


# A Room's Terrain layer comes from its Region's terrain sheet, in the Region's tile folder (its
# own, or the one it shares); every other layer, its Background's included, from the scenery sheet.
static func _draws_from_region_sheets(room_id: StringName, room: Node2D) -> bool:
	var tiles := World.tiles(room_id)
	var terrain := room.get_node_or_null("Terrain")
	var valid := terrain is TileMapLayer
	for layer: TileMapLayer in room.find_children("*", "TileMapLayer", true, false):
		var sheet := "terrain" if layer == terrain else "scenery"
		var path := layer.tile_set.resource_path if layer.tile_set != null else ""
		if path != tiles + sheet + ".tres":
			push_error("%s/%s draws from %s" % [room_id, room.get_path_to(layer), path])
			valid = false
	return valid


func _test_pack_art() -> bool:
	return _every_room(_draws_pack_art)


static func _draws_pack_art(room_id: StringName, room: Node2D) -> bool:
	var valid := true
	for layer in _tile_layers(room):
		for cell in layer.get_used_cells():
			var source := layer.get_cell_source_id(cell)
			var atlas := layer.tile_set.get_source(source) as TileSetAtlasSource
			var sheet := atlas.texture.resource_path if atlas != null else ""
			var coords := layer.get_cell_atlas_coords(cell)
			var drawn := atlas != null and atlas.has_tile(coords)
			var own := (sheet == OWN_PROPS and coords == BELL) or sheet.begins_with(JUNGLE_SHEETS)
			if not drawn or (not sheet.begins_with(PACK_DIR) and not own):
				push_error("%s/%s %s draws from %s" % [room_id, layer.name, cell, sheet])
				valid = false
	return valid


static func _tile_layers(room: Node2D) -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	for child in room.get_children():
		if child is TileMapLayer:
			layers.append(child)
	return layers


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


# The Run remembers a Cache taken by its id, so two sharing one would empty each other.
func _test_cache_ids() -> bool:
	var seen := {}
	for room_id in World.room_ids():
		var room := (load(World.scene(room_id)) as PackedScene).instantiate()
		for node in room.get_children():
			if node.scene_file_path != CACHE_PATH:
				continue
			var id: StringName = node.get("cache_id")
			if id.is_empty() or seen.has(id):
				room.free()
				return false
			seen[id] = true
		room.free()
	return seen.size() >= CACHES


# Each frame of a Cache holds all of its art on the sheet: nothing drawn runs on past either
# side of it, so no Cache shows cut off.
func _test_caches_drawn_whole() -> bool:
	var valid := true
	for room_id in World.room_ids():
		var room := (load(World.scene(room_id)) as PackedScene).instantiate()
		for node in room.get_children():
			if node.scene_file_path != CACHE_PATH:
				continue
			var sheet := (node.get_node("Sprite2D") as Sprite2D).texture.get_image()
			for frame: Rect2 in [node.get("shut_frame"), node.get("open_frame")]:
				if not RoomCaches.drawn_whole(sheet, Rect2i(frame)):
					push_error("Cache '%s' is cut off at %s." % [node.get("cache_id"), frame])
					valid = false
		room.free()
	return valid


# What each Cache holds lies as a pickup of its own kind once spilled.
func _test_caches_spill() -> bool:
	if not ResourceLoader.exists(PICKUPS_PATH):
		return false
	var pickups := load(PICKUPS_PATH) as GDScript
	var valid := true
	for room_id in World.room_ids():
		var room := (load(World.scene(room_id)) as PackedScene).instantiate()
		for node in room.get_children():
			if node.scene_file_path != CACHE_PATH:
				continue
			var scene := pickups.call("scene", node.get("kind")) as PackedScene
			var pickup := scene.instantiate() if scene != null else null
			if pickup == null or pickup.get("kind") != node.get("kind"):
				push_error("Cache '%s' has no pickup to spill." % node.get("cache_id"))
				valid = false
			if pickup != null:
				pickup.free()
		room.free()
	return valid
