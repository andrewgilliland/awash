extends RefCounted

const World := preload("res://scripts/core/world.gd")
# The Map's zooms, out to in: the whole World at once, then Near and Close round the Player.
const ZOOMS: Array[StringName] = [&"world", &"near", &"close"]
# One screen on the Map Close up, keeping the screen's shape; Near is half as large.
const CELL_SIZE := Vector2(20, 18)
const NEAR_CELL_SIZE := Vector2(10, 9)
# How wide an Exit's gap in a Room's wall is, Close up; it shrinks with the screen, to no less
# than the smallest gap.
const EXIT_GAP := 6.0
const SMALLEST_GAP := 2.0
const MARKER_SIZE := Vector2(5, 5)
# A Rest point or Boss on a screen too small for its mark is a dot in its colour.
const SMALL_MARKER_SIZE := Vector2(2, 2)
# Room around the whole World's picture, with space above for the Regions' names.
const MARGIN := Vector2(4, 12)
const LABEL_RISE := 3.0
const SIDES := {
	&"north": Vector2i.UP,
	&"east": Vector2i.RIGHT,
	&"south": Vector2i.DOWN,
	&"west": Vector2i.LEFT,
}


# Lays out the Map at a zoom: Near or Close round the current Room, looking the pan away from its
# middle, in screens, as far as the World's edge; or the whole World at once, as large as fits
# the view, where a pan changes nothing. Shows the visited Rooms, the current Room's block, the
# Player's dot and the region name. Rooms map each id to its cell, size, region name and colour,
# Exits and markers, as the World lists them. Empty when the current Room is not on the Map.
static func layout(
	rooms: Dictionary,
	current_id: StringName,
	visited_ids: Array,
	player_position: Vector2,
	view_size: Vector2,
	zoom: StringName = &"close",
	pan := Vector2.ZERO
) -> Dictionary:
	if not rooms.has(current_id):
		return {}

	var current: Dictionary = rooms[current_id]
	var cell := cell_for(zoom)
	var offset: Vector2
	if zoom == &"world":
		var span := _span(rooms)
		cell = _fitted_cell(span, view_size)
		offset = ((view_size - Vector2(span.size) * cell) / 2.0 - Vector2(span.position) * cell)
	else:
		var looked_at := _middle(current) + clamp_pan(rooms, current_id, pan)
		offset = view_size / 2.0 - looked_at * cell
	offset = offset.floor()
	var shown: Array = []
	for room_id in rooms:
		if room_id == current_id or room_id in visited_ids:
			shown.append(_room(rooms[room_id], offset, room_id == current_id, cell))

	var current_block := _block(current, offset, cell)
	var dot := current_block.position + (player_position / World.SCREEN_SIZE * cell).floor()
	return {rooms = shown, current = current_block, dot = dot, region = current.region}


# One screen at Near or Close.
static func cell_for(zoom: StringName) -> Vector2:
	return NEAR_CELL_SIZE if zoom == &"near" else CELL_SIZE


# The pan, held so the spot it looks at stays within the World: its edge comes no further than
# the middle of the view.
static func clamp_pan(rooms: Dictionary, current_id: StringName, pan: Vector2) -> Vector2:
	if not rooms.has(current_id):
		return Vector2.ZERO
	var span := _span(rooms)
	var middle := _middle(rooms[current_id])
	var looked_at := (middle + pan).clamp(Vector2(span.position), Vector2(span.end))
	return looked_at - middle


# The middle of a Room, in screens.
static func _middle(room: Dictionary) -> Vector2:
	return Vector2(room.cell) + Vector2(room.size) / 2.0


# The screens every Room spans, together.
static func _span(rooms: Dictionary) -> Rect2i:
	var corner := Vector2i.MAX
	var far := Vector2i.MIN
	for room: Dictionary in rooms.values():
		corner = corner.min(room.cell)
		far = far.max(room.cell + room.size)
	return Rect2i(corner, far - corner)


# The largest screen that fits the whole span in the view, about a screen's shape, never larger
# than Close up.
static func _fitted_cell(span: Rect2i, view_size: Vector2) -> Vector2:
	var shape := CELL_SIZE.y / CELL_SIZE.x
	var width := floorf(minf(view_size.x / span.size.x, view_size.y / (span.size.y * shape)))
	width = clampf(width, 1.0, CELL_SIZE.x)
	return Vector2(width, maxf(1.0, floorf(width * shape)))


# Lays out every Room at once, the planned ones too, for a picture of the whole World: each
# Region's name above its top-left Room, and the picture's size.
static func whole(rooms: Dictionary) -> Dictionary:
	if rooms.is_empty():
		return {rooms = [], labels = [], size = Vector2.ZERO}
	var span := _span(rooms)
	var offset := MARGIN - Vector2(span.position) * CELL_SIZE
	var shown: Array = []
	var name_at := {}
	for room: Dictionary in rooms.values():
		var laid := _room(room, offset, false, CELL_SIZE)
		shown.append(laid)
		var top_left: Vector2 = laid.block.position
		var held: Vector2 = name_at.get(room.region, top_left)
		if top_left.y < held.y or (top_left.y == held.y and top_left.x <= held.x):
			held = top_left
		name_at[room.region] = held
	var labels: Array = []
	for region: String in name_at:
		labels.append({text = region, at = name_at[region] - Vector2(0, LABEL_RISE)})
	var size := Vector2(span.size) * CELL_SIZE + MARGIN * 2.0
	return {rooms = shown, labels = labels, size = size}


static func _room(room: Dictionary, offset: Vector2, is_current: bool, cell: Vector2) -> Dictionary:
	var block := _block(room, offset, cell)
	var fits_mark := cell.x >= MARKER_SIZE.x + 2.0 and cell.y >= MARKER_SIZE.y + 2.0
	var mark_size := MARKER_SIZE if fits_mark else SMALL_MARKER_SIZE
	var markers: Array = []
	var room_markers: Dictionary = room.get("markers", {})
	for kind: StringName in room_markers:
		var screen := _screen(block, room_markers[kind], cell)
		var at := (screen.get_center() - mark_size / 2.0).floor()
		markers.append({kind = kind, at = Rect2(at, mark_size)})
	return {
		block = block,
		colour = room.get("colour", Color.TRANSPARENT),
		current = is_current,
		planned = room.get("planned", false),
		walls = _walls(room, block, cell),
		lines = _lines(room, block, cell) if fits_mark else [],
		markers = markers,
	}


# One pixel round the Room's edge, screen by screen, open in the middle where an Exit leaves.
static func _walls(room: Dictionary, block: Rect2, cell: Vector2) -> Array:
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
				var edge := _edge(_screen(block, screen, cell), side)
				var gap := maxf(SMALLEST_GAP, roundf(EXIT_GAP * cell.x / CELL_SIZE.x))
				walls.append_array(_open(edge, side, gap) if open.has([screen, side]) else [edge])
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
static func _open(edge: Rect2, side: StringName, gap: float) -> Array:
	var along := 0 if side == &"north" or side == &"south" else 1
	var length := edge.size[along]
	var gap_start := floorf((length - gap) / 2.0)
	var before := edge
	before.size[along] = gap_start
	var after := edge
	after.position[along] += gap_start + gap
	after.size[along] = length - gap_start - gap
	return [before, after]


# Where one of the Room's screens meets the next, inside its walls.
static func _lines(room: Dictionary, block: Rect2, cell: Vector2) -> Array:
	var lines: Array = []
	var room_size: Vector2i = room.size
	for x in range(1, room_size.x):
		lines.append(
			Rect2(block.position.x + x * cell.x, block.position.y + 1, 1, block.size.y - 2)
		)
	for y in range(1, room_size.y):
		lines.append(
			Rect2(block.position.x + 1, block.position.y + y * cell.y, block.size.x - 2, 1)
		)
	return lines


static func _screen(block: Rect2, screen: Vector2i, cell: Vector2) -> Rect2:
	return Rect2(block.position + Vector2(screen) * cell, cell)


static func _block(room: Dictionary, offset: Vector2, cell: Vector2) -> Rect2:
	return Rect2(offset + Vector2(room.cell) * cell, Vector2(room.size) * cell)
