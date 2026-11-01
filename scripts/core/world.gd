extends RefCounted

# The World: every Region and every Room. Callers ask it questions rather than reading these
# tables.

# Every Region, by the id that also names its asset folder: its name on the Map, its theme, its
# Background, and any other Backgrounds its Rooms may name instead.
const REGIONS := {
	&"waking_coast":
	{
		name = "Waking Coast",
		theme = "res://assets/regions/waking_coast/music/theme.wav",
		background = "res://scenes/regions/waking_coast/background.tscn",
		backgrounds = {&"cave": "res://scenes/regions/waking_coast/cave_background.tscn"},
	},
}
# Every Room: its scene, where it sits in screens (its top-left cell and size), and its Region.
# A Room names one of its Region's other Backgrounds only when it shows one.
const ROOMS := {
	&"waking_coast_1":
	{
		scene = "res://scenes/rooms/waking_coast_1.tscn",
		cell = Vector2i(-1, 0),
		size = Vector2i(2, 1),
		region = &"waking_coast",
	},
	&"waking_coast_2":
	{
		scene = "res://scenes/rooms/waking_coast_2.tscn",
		cell = Vector2i(1, 0),
		size = Vector2i(2, 1),
		region = &"waking_coast",
	},
	# Two screens tall: its beach is level with the rune shore, its cliff top a screen above.
	&"waking_coast_3":
	{
		scene = "res://scenes/rooms/waking_coast_3.tscn",
		cell = Vector2i(3, -1),
		size = Vector2i(1, 2),
		region = &"waking_coast",
	},
	# Two screens wide, along from the salt cliffs' top.
	&"waking_coast_4":
	{
		scene = "res://scenes/rooms/waking_coast_4.tscn",
		cell = Vector2i(4, -1),
		size = Vector2i(2, 1),
		region = &"waking_coast",
	},
	# Under the wreck graveyard, beside the salt cliffs' foot.
	&"waking_coast_5":
	{
		scene = "res://scenes/rooms/waking_coast_5.tscn",
		cell = Vector2i(4, 0),
		size = Vector2i(2, 1),
		region = &"waking_coast",
		background = &"cave",
	},
	# Two screens wide, on from the graveyard over its sinkhole, climbing inland.
	&"waking_coast_6":
	{
		scene = "res://scenes/rooms/waking_coast_6.tscn",
		cell = Vector2i(6, -1),
		size = Vector2i(2, 1),
		region = &"waking_coast",
	},
	# One screen: the arena at the road's end.
	&"waking_coast_7":
	{
		scene = "res://scenes/rooms/waking_coast_7.tscn",
		cell = Vector2i(8, -1),
		size = Vector2i(1, 1),
		region = &"waking_coast",
	},
	# Tidefen, at the end of the coast: two screens past the Warden's gate.
	&"waking_coast_8":
	{
		scene = "res://scenes/rooms/waking_coast_8.tscn",
		cell = Vector2i(9, -1),
		size = Vector2i(2, 1),
		region = &"waking_coast",
	},
	# Four screens of tunnel under the road, the gate and Tidefen's well, back to the sea cave.
	&"waking_coast_9":
	{
		scene = "res://scenes/rooms/waking_coast_9.tscn",
		cell = Vector2i(6, 0),
		size = Vector2i(4, 1),
		region = &"waking_coast",
		background = &"cave",
	},
}
const SCREEN_SIZE := Vector2(160, 144)


# Every Room in the World.
static func room_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(ROOMS.keys())
	return ids


static func has_room(room_id: StringName) -> bool:
	return ROOMS.has(room_id)


# The Room's scene, or "" when the World doesn't hold it.
static func scene(room_id: StringName) -> String:
	return ROOMS.get(room_id, {}).get("scene", "")


# The Room's top-left screen in the World.
static func cell(room_id: StringName) -> Vector2i:
	return ROOMS.get(room_id, {}).get("cell", Vector2i.ZERO)


# How many screens the Room spans.
static func size(room_id: StringName) -> Vector2i:
	return ROOMS.get(room_id, {}).get("size", Vector2i.ZERO)


# The id of the Room's Region, or &"" when the World doesn't hold the Room.
static func region(room_id: StringName) -> StringName:
	return ROOMS.get(room_id, {}).get("region", &"")


static func has_region(region_id: StringName) -> bool:
	return REGIONS.has(region_id)


# The name of the Room's Region, as the Map shows it.
static func region_name(room_id: StringName) -> String:
	return _region_of(room_id).get("name", "")


# The theme for a Room's Region, or "" when it has none.
static func theme(room_id: StringName) -> String:
	return _region_of(room_id).get("theme", "")


# The Background the Room shows: its Region's, or the other one the Room names. "" when it has none.
static func background(room_id: StringName) -> String:
	var region_record := _region_of(room_id)
	var variant: StringName = ROOMS.get(room_id, {}).get("background", &"")
	if variant.is_empty():
		return region_record.get("background", "")
	return region_record.get("backgrounds", {}).get(variant, "")


static func _region_of(room_id: StringName) -> Dictionary:
	return REGIONS.get(region(room_id), {})
