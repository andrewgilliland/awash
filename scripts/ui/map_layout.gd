extends RefCounted

const World := preload("res://scripts/core/world.gd")
# One screen on the Map, keeping the screen's shape.
const CELL_SIZE := Vector2(20, 18)
# How wide an Exit's gap in a Room's wall is.
const EXIT_GAP := 6.0
const MARKER_SIZE := Vector2(5, 5)
# Room around the whole World's picture, with space above for the Regions' names.
const MARGIN := Vector2(4, 12)
const LABEL_RISE := 3.0
const SIDES := {
	&"north": Vector2i.UP,
	&"east": Vector2i.RIGHT,
	&"south": Vector2i.DOWN,
	&"west": Vector2i.LEFT,
}


# Lays out the Map around the current Room: the visited Rooms, the current Room's block, the
# Player's dot and the region name. Rooms map each id to its cell, size, region name and colour,
# Exits and markers, as the World lists them. Empty when the current Room is not on the Map.
static func layout(
	rooms: Dictionary,
	current_id: StringName,
	visited_ids: Array,
	player_position: Vector2,
	view_size: Vector2
) -> Dictionary:
	if not rooms.has(current_id):
		return {}

	var current: Dictionary = rooms[current_id]
	var current_centre := (Vector2(current.cell) + Vector2(current.size) / 2.0) * CELL_SIZE
	var offset := (view_size / 2.0 - current_centre).floor()
	var shown: Array = []
	for room_id in rooms:
		if room_id == current_id or room_id in visited_ids:
			shown.append(_room(rooms[room_id], offset, room_id == current_id))

	var current_block := _block(current, offset)
	var dot := current_block.position + (player_position / World.SCREEN_SIZE * CELL_SIZE).floor()
	return {rooms = shown, current = current_block, dot = dot, region = current.region}


# Lays out every Room at once, the planned ones too, for a picture of the whole World: each
# Region's name above its top-left Room, and the picture's size.
static func whole(rooms: Dictionary) -> Dictionary:
	if rooms.is_empty():
		return {rooms = [], labels = [], size = Vector2.ZERO}
	var corner := Vector2i.MAX
	var far := Vector2i.MIN
	for room: Dictionary in rooms.values():
		corner = corner.min(room.cell)
		far = far.max(room.cell + room.size)
	var offset := MARGIN - Vector2(corner) * CELL_SIZE
	var shown: Array = []
	var name_at := {}
	for room: Dictionary in rooms.values():
		var laid := _room(room, offset, false)
		shown.append(laid)
		var top_left: Vector2 = laid.block.position
		var held: Vector2 = name_at.get(room.region, top_left)
		if top_left.y < held.y or (top_left.y == held.y and top_left.x <= held.x):
			held = top_left
		name_at[room.region] = held
	var labels: Array = []
	for region: String in name_at:
		labels.append({text = region, at = name_at[region] - Vector2(0, LABEL_RISE)})
	var size := Vector2(far - corner) * CELL_SIZE + MARGIN * 2.0
	return {rooms = shown, labels = labels, size = size}


static func _room(room: Dictionary, offset: Vector2, is_current: bool) -> Dictionary:
	var block := _block(room, offset)
	var markers: Array = []
	var room_markers: Dictionary = room.get("markers", {})
	for kind: StringName in room_markers:
		var screen := _screen(block, room_markers[kind])
		var at := (screen.get_center() - MARKER_SIZE / 2.0).floor()
		markers.append({kind = kind, at = Rect2(at, MARKER_SIZE)})
	return {
		block = block,
		colour = room.get("colour", Color.TRANSPARENT),
		current = is_current,
		planned = room.get("planned", false),
		walls = _walls(room, block),
		lines = _lines(room, block),
		markers = markers,
	}


# One pixel round the Room's edge, screen by screen, open in the middle where an Exit leaves.
static func _walls(room: Dictionary, block: Rect2) -> Array:
	var open := {}
	for exit: Dictionary in room.get("exits", []):
		open[[exit.screen, exit.side]] = true
	var walls: Array = []
	var room_size: Vector2i = room.size
	for y in range(room_size.y):
		for x in range(room_size.x):
			var screen := Vector2i(x, y)
			for side: StringName in SIDES:
				var beyond: Vector2i = screen + SIDES[side]
				if Rect2i(Vector2i.ZERO, room_size).has_point(beyond):
					continue
				var edge := _edge(_screen(block, screen), side)
				walls.append_array(_open(edge, side) if open.has([screen, side]) else [edge])
	return walls


static func _edge(screen: Rect2, side: StringName) -> Rect2:
	match side:
		&"north":
			return Rect2(screen.position, Vector2(screen.size.x, 1))
		&"south":
			return Rect2(screen.position.x, screen.end.y - 1, screen.size.x, 1)
		&"west":
			return Rect2(screen.position, Vector2(1, screen.size.y))
		_:
			return Rect2(screen.end.x - 1, screen.position.y, 1, screen.size.y)


# The edge in two, with the Exit's gap in its middle.
static func _open(edge: Rect2, side: StringName) -> Array:
	var along := 0 if side == &"north" or side == &"south" else 1
	var length := edge.size[along]
	var gap_start := floorf((length - EXIT_GAP) / 2.0)
	var before := edge
	before.size[along] = gap_start
	var after := edge
	after.position[along] += gap_start + EXIT_GAP
	after.size[along] = length - gap_start - EXIT_GAP
	return [before, after]


# Where one of the Room's screens meets the next, inside its walls.
static func _lines(room: Dictionary, block: Rect2) -> Array:
	var lines: Array = []
	var room_size: Vector2i = room.size
	for x in range(1, room_size.x):
		lines.append(
			Rect2(block.position.x + x * CELL_SIZE.x, block.position.y + 1, 1, block.size.y - 2)
		)
	for y in range(1, room_size.y):
		lines.append(
			Rect2(block.position.x + 1, block.position.y + y * CELL_SIZE.y, block.size.x - 2, 1)
		)
	return lines


static func _screen(block: Rect2, screen: Vector2i) -> Rect2:
	return Rect2(block.position + Vector2(screen) * CELL_SIZE, CELL_SIZE)


static func _block(room: Dictionary, offset: Vector2) -> Rect2:
	return Rect2(offset + Vector2(room.cell) * CELL_SIZE, Vector2(room.size) * CELL_SIZE)
