extends RefCounted

const World := preload("res://scripts/core/world.gd")
# The Map's zooms, out to in: the whole World at once, then Near and Close round the Player.
const ZOOMS: Array[StringName] = [&"world", &"near", &"close"]
# One screen on the Map Close up, keeping the screen's shape; Near is half as large.
const CELL_SIZE := Vector2(20, 18)
const NEAR_CELL_SIZE := Vector2(10, 9)
# The smallest a screen is drawn at World zoom, still a block with its walls: past it, a World too
# wide for the view is looked at round the Player instead, and pans as Near and Close do.
const SMALLEST_SCREEN := Vector2(5, 4)
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
# A letter of a Region's name in the Map's pixel font, its baseline at the bottom: how much room a
# name takes. A name raised clear of another rises a letter and a pixel at a time.
const LABEL_LETTER := Vector2(4, 6)
const SIDES := {
	&"north": Vector2i.UP,
	&"east": Vector2i.RIGHT,
	&"south": Vector2i.DOWN,
	&"west": Vector2i.LEFT,
}


# Lays out the Map at a zoom: Near or Close round the current Room, looking the pan away from its
# middle, in screens, as far as the World's edge; or the whole World at once, as large as fits
# the view but no smaller than the smallest screen, where a pan changes nothing. A World too
# large for that is looked at as Near is, its edge stopping at the view's, and pans only along the
# side it doesn't fit. Shows the visited Rooms, the current Room's block, the Player's dot and the
# region name. Rooms map each id to its cell, size, region name and colour, Exits and markers, as
# the World lists them. Empty when the current Room is not on the Map.
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
	var cell := _cell(rooms, view_size, zoom)
	var looked_at := _middle(current) + clamp_pan(rooms, current_id, pan, view_size, zoom)
	var bounds := _bounds(rooms, view_size, zoom)
	for axis in 2:
		if bounds.size[axis] <= 0.0:
			looked_at[axis] = bounds.get_center()[axis]
	var offset := (view_size / 2.0 - looked_at * cell).floor()
	if zoom == &"world":
		# Held inside the World's edge in whole pixels, which rounding might pass by one.
		var span := Rect2(_span(rooms))
		for axis in 2:
			if bounds.size[axis] > 0.0:
				var low := view_size[axis] - span.end[axis] * cell[axis]
				offset[axis] = clampf(offset[axis], low, -span.position[axis] * cell[axis])
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


# The pan, held so the spot it looks at stays within the World: at Near and Close its edge comes
# no further than the middle of the view, and at World zoom no further than the view's edge. Along
# a side the whole World fits at World zoom, the pan is kept as it is, for the nearer zooms.
static func clamp_pan(
	rooms: Dictionary,
	current_id: StringName,
	pan: Vector2,
	view_size := Vector2.ZERO,
	zoom: StringName = &"close"
) -> Vector2:
	if not rooms.has(current_id):
		return Vector2.ZERO
	var bounds := _bounds(rooms, view_size, zoom)
	var middle := _middle(rooms[current_id])
	var held := pan
	for axis in 2:
		if bounds.size[axis] > 0.0:
			held[axis] = clampf(middle[axis] + pan[axis], bounds.position[axis], bounds.end[axis])
			held[axis] -= middle[axis]
	return held


# How far a pan of so many Map pixels looks, in the zoom's screens: none along a side the whole
# World fits at World zoom.
static func pan_step(
	rooms: Dictionary, view_size: Vector2, zoom: StringName, pixels: Vector2
) -> Vector2:
	var step := pixels / _cell(rooms, view_size, zoom)
	var bounds := _bounds(rooms, view_size, zoom)
	for axis in 2:
		if bounds.size[axis] <= 0.0:
			step[axis] = 0.0
	return step


# One screen at a zoom: World zoom's fitted to the view.
static func _cell(rooms: Dictionary, view_size: Vector2, zoom: StringName) -> Vector2:
	return _fitted_cell(_span(rooms), view_size) if zoom == &"world" else cell_for(zoom)


# The spots the view may look at, in screens: the World's span, brought in at World zoom by half
# the view so the World's edge stops at the view's. Along a side the whole World fits at World
# zoom, the size is nothing or less, and the view stays on the World's middle.
static func _bounds(rooms: Dictionary, view_size: Vector2, zoom: StringName) -> Rect2:
	var span := _span(rooms)
	var bounds := Rect2(span)
	if zoom == &"world":
		var half := view_size / 2.0 / _cell(rooms, view_size, zoom)
		bounds = Rect2(bounds.position + half, bounds.size - half * 2.0)
	return bounds


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
# than Close up nor smaller than the smallest.
static func _fitted_cell(span: Rect2i, view_size: Vector2) -> Vector2:
	var shape := CELL_SIZE.y / CELL_SIZE.x
	var width := floorf(minf(view_size.x / span.size.x, view_size.y / (span.size.y * shape)))
	width = clampf(width, SMALLEST_SCREEN.x, CELL_SIZE.x)
	return Vector2(width, maxf(SMALLEST_SCREEN.y, floorf(width * shape)))


# Lays out every Room at once, the planned ones too, for a picture of the whole World: each
# Region's name above its top-left Room, slid back inside the picture and raised clear of any name
# it would run into, the picture growing upward to hold it; and the picture's size.
static func whole(rooms: Dictionary) -> Dictionary:
	if rooms.is_empty():
		return {rooms = [], labels = [], size = Vector2.ZERO}
	var span := _span(rooms)
	var offset := MARGIN - Vector2(span.position) * CELL_SIZE
	var size := Vector2(span.size) * CELL_SIZE + MARGIN * 2.0
	var name_at := {}
	for room: Dictionary in rooms.values():
		var top_left := _block(room, offset, CELL_SIZE).position
		var held: Vector2 = name_at.get(room.region, top_left)
		if top_left.y < held.y or (top_left.y == held.y and top_left.x <= held.x):
			held = top_left
		name_at[room.region] = held
	var labels := _labels(name_at, size.x)
	# As much room above the highest name as a name just above the top row has.
	var headroom := MARGIN.y - LABEL_RISE - LABEL_LETTER.y
	var rise := 0.0
	for label: Dictionary in labels:
		rise = maxf(rise, headroom - label.top)
	offset.y += rise
	size.y += rise
	for label: Dictionary in labels:
		label.at.y += rise
		label.erase("top")
	var shown: Array = []
	for room: Dictionary in rooms.values():
		shown.append(_room(room, offset, false, CELL_SIZE))
	return {rooms = shown, labels = labels, size = size}


# The Regions' names, west to east, each above its Room's top-left corner, slid back inside the
# picture's width and raised clear of the names before it.
static func _labels(name_at: Dictionary, width: float) -> Array:
	var regions := name_at.keys()
	regions.sort_custom(
		func(a: String, b: String) -> bool:
			var at_a: Vector2 = name_at[a]
			var at_b: Vector2 = name_at[b]
			return at_a.x < at_b.x or (at_a.x == at_b.x and at_a.y < at_b.y)
	)
	var labels: Array = []
	var taken: Array[Rect2] = []
	for region: String in regions:
		var text_size := Vector2(region.length() * LABEL_LETTER.x, LABEL_LETTER.y)
		var at: Vector2 = name_at[region] - Vector2(0, LABEL_RISE)
		at.x = maxf(MARGIN.x, minf(at.x, width - MARGIN.x - text_size.x))
		var text := Rect2(at - Vector2(0, text_size.y), text_size)
		while _runs_into(text, taken):
			text.position.y -= LABEL_LETTER.y + 1.0
		taken.append(text)
		labels.append(
			{text = region, at = Vector2(text.position.x, text.end.y), top = text.position.y}
		)
	return labels


static func _runs_into(text: Rect2, taken: Array[Rect2]) -> bool:
	for other in taken:
		if other.intersects(text):
			return true
	return false


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
