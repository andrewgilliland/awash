extends RefCounted

# The World: every Region and every Room. Callers ask it questions rather than reading its
# tables, which live in assets/world.json for the World editor to write
# (docs/adr/0001-world-data-in-json.md).
#
# Its regions: each by the id that also names its asset folder, with its name and colour on the
# Map, its theme, its Background, and any other Backgrounds its Rooms may name instead.
# Its rooms: each with its scene, where it sits in screens (its top-left cell and size), its
# Region, and its Exits and markers as the Map shows them (see exits() and markers()). A Room names
# one of its Region's other Backgrounds only when it shows one. A built Room that is to move
# carries a plan; a Planned Room has no scene yet, and the game leaves it out. Vectors are [x, y],
# colours "#rrggbb"; a note is for whoever reads the file.

const DATA_PATH := "res://assets/world.json"
const SCREEN_SIZE := Vector2(160, 144)

static var _regions: Dictionary = {}
static var _rooms: Dictionary = {}


# Every Room built in the World: every Room with a scene.
static func room_ids() -> Array[StringName]:
	return _ids(false)


# Every planned Room: laid out in the World, with no scene yet.
static func planned_ids() -> Array[StringName]:
	return _ids(true)


static func has_room(room_id: StringName) -> bool:
	return room_id in room_ids()


# The Room a scene is, or &"" when the World holds no Room with that scene.
static func room_for_scene(scene_path: String) -> StringName:
	for room_id: StringName in _rooms_table():
		if _rooms_table()[room_id].get("scene", "") == scene_path:
			return room_id
	return &""


# The Room's scene, or "" when the World doesn't hold it.
static func scene(room_id: StringName) -> String:
	return _rooms_table().get(room_id, {}).get("scene", "")


# The Room's top-left screen in the World.
static func cell(room_id: StringName) -> Vector2i:
	return _rooms_table().get(room_id, {}).get("cell", Vector2i.ZERO)


# How many screens the Room spans.
static func size(room_id: StringName) -> Vector2i:
	return _rooms_table().get(room_id, {}).get("size", Vector2i.ZERO)


# The Room's Exits as the Map shows them: each one's screen, from the Room's top-left, and the
# side it leaves by (&"north", &"east", &"south" or &"west").
static func exits(room_id: StringName) -> Array:
	return _rooms_table().get(room_id, {}).get("exits", [])


# What the Map marks in the Room, each on its screen: &"rest" for a Rest point, &"boss" for a Boss.
static func markers(room_id: StringName) -> Dictionary:
	return _rooms_table().get(room_id, {}).get("markers", {})


# The Room as the World's plan lays it out: its cell, size, Region, Exits and markers, with any
# plan the Room carries laid over what it is today. A Planned Room is all plan.
static func planned(room_id: StringName) -> Dictionary:
	var record: Dictionary = _rooms_table().get(room_id, {})
	var plan := {
		cell = cell(room_id),
		size = size(room_id),
		region = region(room_id),
		exits = exits(room_id),
		markers = markers(room_id),
	}
	plan.merge(record.get("plan", {}), true)
	return plan


# The id of the Room's Region, or &"" when the World doesn't hold the Room.
static func region(room_id: StringName) -> StringName:
	return _rooms_table().get(room_id, {}).get("region", &"")


static func has_region(region_id: StringName) -> bool:
	return _regions_table().has(region_id)


# The name of the Room's Region, as the Map shows it.
static func region_name(room_id: StringName) -> String:
	return name_of_region(region(room_id))


static func name_of_region(region_id: StringName) -> String:
	return _regions_table().get(region_id, {}).get("name", "")


# The colour the Map fills the Room's Region with.
static func region_colour(room_id: StringName) -> Color:
	return colour_of_region(region(room_id))


static func colour_of_region(region_id: StringName) -> Color:
	return _regions_table().get(region_id, {}).get("colour", Color.TRANSPARENT)


# The folder a Room's tile sets are in: its Region's own, or the one of another Region it shares.
static func tiles(room_id: StringName) -> String:
	var region_id := region(room_id)
	return "res://assets/regions/%s/tiles/" % _region_of(room_id).get("tiles", region_id)


# The theme for a Room's Region, or "" when it has none.
static func theme(room_id: StringName) -> String:
	return _region_of(room_id).get("theme", "")


# The Background the Room shows: its Region's, or the other one the Room names. "" when it has none.
static func background(room_id: StringName) -> String:
	var region_record := _region_of(room_id)
	var variant: StringName = _rooms_table().get(room_id, {}).get("background", &"")
	if variant.is_empty():
		return region_record.get("background", "")
	return region_record.get("backgrounds", {}).get(variant, "")


static func _ids(planned: bool) -> Array[StringName]:
	var ids: Array[StringName] = []
	for room_id: StringName in _rooms_table():
		if _rooms_table()[room_id].has("scene") != planned:
			ids.append(room_id)
	return ids


static func _region_of(room_id: StringName) -> Dictionary:
	return _regions_table().get(region(room_id), {})


static func _rooms_table() -> Dictionary:
	_read()
	return _rooms


static func _regions_table() -> Dictionary:
	_read()
	return _regions


# Reads the World's data the first time it is asked for, turning its plain values into the ones
# the World answers with: vectors, colours and ids.
static func _read() -> void:
	if not _rooms.is_empty():
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not data is Dictionary:
		push_error("The World's data at '%s' could not be read." % DATA_PATH)
		return
	for id: String in data.get("regions", {}):
		_regions[StringName(id)] = _region_record(data.regions[id])
	for id: String in data.get("rooms", {}):
		_rooms[StringName(id)] = _room_record(data.rooms[id])


static func _region_record(plain: Dictionary) -> Dictionary:
	var record := {}
	for key: String in ["name", "theme", "background", "tiles"]:
		if plain.has(key):
			record[key] = plain[key]
	if plain.has("colour"):
		record.colour = Color(plain.colour)
	if plain.has("backgrounds"):
		var backgrounds := {}
		for variant: String in plain.backgrounds:
			backgrounds[StringName(variant)] = plain.backgrounds[variant]
		record.backgrounds = backgrounds
	return record


# A Room's record, or the plan it carries, which holds the same fields.
static func _room_record(plain: Dictionary) -> Dictionary:
	var record := {}
	if plain.has("scene"):
		record.scene = plain.scene
	for key: String in ["cell", "size"]:
		if plain.has(key):
			record[key] = Vector2i(int(plain[key][0]), int(plain[key][1]))
	for key: String in ["region", "background"]:
		if plain.has(key):
			record[key] = StringName(plain[key])
	if plain.has("exits"):
		var exits: Array = []
		for exit: Dictionary in plain.exits:
			(
				exits
				. append(
					{
						screen = Vector2i(int(exit.screen[0]), int(exit.screen[1])),
						side = StringName(exit.side),
					}
				)
			)
		record.exits = exits
	if plain.has("markers"):
		var markers := {}
		for kind: String in plain.markers:
			var at: Array = plain.markers[kind]
			markers[StringName(kind)] = Vector2i(int(at[0]), int(at[1]))
		record.markers = markers
	if plain.has("plan"):
		record.plan = _room_record(plain.plan)
	return record
