extends RefCounted

# The World: every Region and every Room. Callers ask it questions rather than reading these
# tables.

# Every Region, by the id that also names its asset folder: its name and colour on the Map, its
# theme, its Background, and any other Backgrounds its Rooms may name instead.
const REGIONS := {
	&"waking_coast":
	{
		name = "Waking Coast",
		colour = Color("183931"),
		theme = "res://assets/regions/waking_coast/music/theme.wav",
		background = "res://scenes/regions/waking_coast/background.tscn",
		backgrounds = {&"cave": "res://scenes/regions/waking_coast/cave_background.tscn"},
	},
	# Under the coast's cliffs, off the Main path: Tidefen's well drops into it once the story opens
	# it, and its Shortcut leads home through the sea cave. Planned: its theme and Background come
	# with its first Room.
	&"undertow":
	{
		name = "Undertow",
		colour = Color("2b2452"),
	},
}
# Every Room: its scene, where it sits in screens (its top-left cell and size), its Region, and its
# Exits and markers as the Map shows them (see exits() and markers()). A Room names one of its
# Region's other Backgrounds only when it shows one. A planned Room has no scene yet: it is laid
# out here to see the World's shape before it is built, and the game leaves it out.
const ROOMS := {
	&"waking_coast_1":
	{
		scene = "res://scenes/rooms/waking_coast_1.tscn",
		cell = Vector2i(-1, 0),
		size = Vector2i(2, 1),
		region = &"waking_coast",
		exits =
		[
			{screen = Vector2i(1, 0), side = &"east"},
		],
	},
	&"waking_coast_2":
	{
		scene = "res://scenes/rooms/waking_coast_2.tscn",
		cell = Vector2i(1, 0),
		size = Vector2i(2, 1),
		region = &"waking_coast",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"west"},
			{screen = Vector2i(1, 0), side = &"east"},
		],
	},
	# Two screens tall: its beach is level with the palm shore, its cliff top a screen above.
	&"waking_coast_3":
	{
		scene = "res://scenes/rooms/waking_coast_3.tscn",
		cell = Vector2i(3, -1),
		size = Vector2i(1, 2),
		region = &"waking_coast",
		exits =
		[
			{screen = Vector2i(0, 1), side = &"west"},
			{screen = Vector2i(0, 0), side = &"east"},
			{screen = Vector2i(0, 1), side = &"east"},
		],
		plan =
		{
			cell = Vector2i(5, -1),
			exits =
			[
				{screen = Vector2i(0, 1), side = &"west"},
				{screen = Vector2i(0, 0), side = &"east"},
				{screen = Vector2i(0, 1), side = &"south"},
			],
		},
	},
	# Two screens wide, along from the salt cliffs' top.
	&"waking_coast_4":
	{
		scene = "res://scenes/rooms/waking_coast_4.tscn",
		cell = Vector2i(4, -1),
		size = Vector2i(2, 1),
		region = &"waking_coast",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"west"},
			{screen = Vector2i(1, 0), side = &"east"},
			{screen = Vector2i(1, 0), side = &"south"},
		],
		plan =
		{
			cell = Vector2i(9, -2),
			exits =
			[
				{screen = Vector2i(0, 0), side = &"west"},
				{screen = Vector2i(1, 0), side = &"east"},
			],
		},
	},
	# Under the wreck graveyard, beside the salt cliffs' foot.
	&"waking_coast_5":
	{
		scene = "res://scenes/rooms/waking_coast_5.tscn",
		cell = Vector2i(4, 0),
		size = Vector2i(2, 1),
		region = &"waking_coast",
		background = &"cave",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"west"},
			{screen = Vector2i(1, 0), side = &"east"},
		],
		plan =
		{
			cell = Vector2i(5, 1),
			exits =
			[
				{screen = Vector2i(0, 0), side = &"north"},
				{screen = Vector2i(1, 0), side = &"east"},
			],
		},
	},
	# Two screens wide, on from the graveyard over its sinkhole, climbing inland.
	&"waking_coast_6":
	{
		scene = "res://scenes/rooms/waking_coast_6.tscn",
		cell = Vector2i(6, -1),
		size = Vector2i(2, 1),
		region = &"waking_coast",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"west"},
			{screen = Vector2i(1, 0), side = &"east"},
		],
		plan =
		{
			cell = Vector2i(12, 0),
		},
	},
	# One screen: the arena at the trail's end.
	&"waking_coast_7":
	{
		scene = "res://scenes/rooms/waking_coast_7.tscn",
		cell = Vector2i(8, -1),
		size = Vector2i(1, 1),
		region = &"waking_coast",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"west"},
			{screen = Vector2i(0, 0), side = &"east"},
		],
		markers = {&"boss": Vector2i(0, 0)},
		plan =
		{
			cell = Vector2i(14, 0),
		},
	},
	# Tidefen, at the end of the coast past the Warden's gate: its stilt houses, market square and
	# harbour, two screens each.
	&"waking_coast_8":
	{
		scene = "res://scenes/rooms/waking_coast_8.tscn",
		cell = Vector2i(9, -1),
		size = Vector2i(6, 1),
		region = &"waking_coast",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"west"},
			{screen = Vector2i(0, 0), side = &"south"},
		],
		markers = {&"rest": Vector2i(3, 0)},
		plan =
		{
			cell = Vector2i(15, 0),
		},
	},
	# Four screens of tunnel under the trail, the gate and Tidefen's well, back to the sea cave.
	&"waking_coast_9":
	{
		scene = "res://scenes/rooms/waking_coast_9.tscn",
		cell = Vector2i(6, 0),
		size = Vector2i(4, 1),
		region = &"waking_coast",
		background = &"cave",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"west"},
		],
		plan =
		{
			cell = Vector2i(11, 2),
			region = &"undertow",
			exits =
			[
				{screen = Vector2i(3, 0), side = &"east"},
				{screen = Vector2i(0, 0), side = &"west"},
				{screen = Vector2i(1, 0), side = &"south"},
			],
		},
	},
	# Tide pools on the beach, before the cliffs.
	&"waking_coast_10":
	{
		cell = Vector2i(3, 0),
		size = Vector2i(2, 1),
		region = &"waking_coast",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"west"},
			{screen = Vector2i(1, 0), side = &"east"},
		],
	},
	# Ledges up from the salt cliffs' top to the cliff tops.
	&"waking_coast_11":
	{
		cell = Vector2i(6, -2),
		size = Vector2i(1, 2),
		region = &"waking_coast",
		exits =
		[
			{screen = Vector2i(0, 1), side = &"west"},
			{screen = Vector2i(0, 0), side = &"east"},
		],
	},
	# The cliff tops, on to the wreck graveyard.
	&"waking_coast_12":
	{
		cell = Vector2i(7, -2),
		size = Vector2i(2, 1),
		region = &"waking_coast",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"west"},
			{screen = Vector2i(1, 0), side = &"east"},
		],
	},
	# A broken stair down from the graveyard to the jungle trail.
	&"waking_coast_13":
	{
		cell = Vector2i(11, -2),
		size = Vector2i(1, 3),
		region = &"waking_coast",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"west"},
			{screen = Vector2i(0, 2), side = &"east"},
		],
	},
	# The shaft Tidefen's well drops into: no way back up.
	&"undertow_1":
	{
		cell = Vector2i(15, 1),
		size = Vector2i(1, 2),
		region = &"undertow",
		exits =
		[
			{screen = Vector2i(0, 1), side = &"west"},
		],
	},
	# A hall west of the undertow tunnel.
	&"undertow_2":
	{
		cell = Vector2i(9, 1),
		size = Vector2i(2, 2),
		region = &"undertow",
		exits =
		[
			{screen = Vector2i(1, 1), side = &"east"},
			{screen = Vector2i(0, 0), side = &"west"},
		],
	},
	# The passage to the sea cave's wall, the Undertow's Shortcut home.
	&"undertow_3":
	{
		cell = Vector2i(7, 1),
		size = Vector2i(2, 1),
		region = &"undertow",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"west"},
			{screen = Vector2i(1, 0), side = &"east"},
		],
	},
	# Pools under the undertow tunnel.
	&"undertow_4":
	{
		cell = Vector2i(12, 3),
		size = Vector2i(2, 1),
		region = &"undertow",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"north"},
			{screen = Vector2i(1, 0), side = &"east"},
			{screen = Vector2i(0, 0), side = &"west"},
		],
	},
	# East of the pools, a dead end for now.
	&"undertow_5":
	{
		cell = Vector2i(14, 3),
		size = Vector2i(2, 2),
		region = &"undertow",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"west"},
		],
	},
	# A stair down from the pools.
	&"undertow_6":
	{
		cell = Vector2i(11, 3),
		size = Vector2i(1, 2),
		region = &"undertow",
		exits =
		[
			{screen = Vector2i(0, 0), side = &"east"},
			{screen = Vector2i(0, 1), side = &"west"},
		],
	},
	# A lake at the bottom, west to the Boss.
	&"undertow_7":
	{
		cell = Vector2i(8, 4),
		size = Vector2i(3, 1),
		region = &"undertow",
		exits =
		[
			{screen = Vector2i(2, 0), side = &"east"},
			{screen = Vector2i(0, 0), side = &"west"},
		],
	},
	# The Undertow's Boss, at its far west end: named and designed later.
	&"undertow_8":
	{
		cell = Vector2i(6, 3),
		size = Vector2i(2, 2),
		region = &"undertow",
		exits =
		[
			{screen = Vector2i(1, 1), side = &"east"},
		],
		markers = {&"boss": Vector2i(0, 1)},
	},
}
const SCREEN_SIZE := Vector2(160, 144)


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
	for room_id: StringName in ROOMS:
		if ROOMS[room_id].get("scene", "") == scene_path:
			return room_id
	return &""


# The Room's scene, or "" when the World doesn't hold it.
static func scene(room_id: StringName) -> String:
	return ROOMS.get(room_id, {}).get("scene", "")


# The Room's top-left screen in the World.
static func cell(room_id: StringName) -> Vector2i:
	return ROOMS.get(room_id, {}).get("cell", Vector2i.ZERO)


# How many screens the Room spans.
static func size(room_id: StringName) -> Vector2i:
	return ROOMS.get(room_id, {}).get("size", Vector2i.ZERO)


# The Room's Exits as the Map shows them: each one's screen, from the Room's top-left, and the
# side it leaves by (&"north", &"east", &"south" or &"west").
static func exits(room_id: StringName) -> Array:
	return ROOMS.get(room_id, {}).get("exits", [])


# What the Map marks in the Room, each on its screen: &"rest" for a Rest point, &"boss" for a Boss.
static func markers(room_id: StringName) -> Dictionary:
	return ROOMS.get(room_id, {}).get("markers", {})


# The Room as the World's plan lays it out: its cell, size, Region, Exits and markers, with any
# plan the Room carries laid over what it is today. A Planned Room is all plan.
static func planned(room_id: StringName) -> Dictionary:
	var record: Dictionary = ROOMS.get(room_id, {})
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
	return ROOMS.get(room_id, {}).get("region", &"")


static func has_region(region_id: StringName) -> bool:
	return REGIONS.has(region_id)


# The name of the Room's Region, as the Map shows it.
static func region_name(room_id: StringName) -> String:
	return name_of_region(region(room_id))


static func name_of_region(region_id: StringName) -> String:
	return REGIONS.get(region_id, {}).get("name", "")


# The colour the Map fills the Room's Region with.
static func region_colour(room_id: StringName) -> Color:
	return colour_of_region(region(room_id))


static func colour_of_region(region_id: StringName) -> Color:
	return REGIONS.get(region_id, {}).get("colour", Color.TRANSPARENT)


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


static func _ids(planned: bool) -> Array[StringName]:
	var ids: Array[StringName] = []
	for room_id: StringName in ROOMS:
		if ROOMS[room_id].has("scene") != planned:
			ids.append(room_id)
	return ids


static func _region_of(room_id: StringName) -> Dictionary:
	return REGIONS.get(region(room_id), {})
