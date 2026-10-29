extends RefCounted

# The art checks from docs/art-style.md, as plain functions over Images, so each rule can be
# tested on small made-up pictures and run over the real art by scripts/tools/art_report.gd.

const TILE := 16
# A surface's lit top edge must stand this many greyscale steps (of 0-255) apart from what is
# behind it to read.
const READABLE_VALUE_GAP := 40.0
# How much brighter a surface tile's top 2 rows must be than its body to count as a lit edge.
const LIT_EDGE_LIFT := 12.0
# The body a lit edge is measured against: most of a solid tile, and the plank of a one-way one.
const SOLID_BODY := Rect2i(0, 3, 16, 10)
const ONE_WAY_BODY := Rect2i(0, 2, 16, 5)
# A one-way tile collides along its top 7 rows; its art must span most of one of them.
const ONE_WAY_ROWS := 7
const COVERED_SHARE := 0.75
# A seam is a step across a tile edge this much bigger than the steps inside the tiles.
const SEAM_RATIO := 2.0
const SEAM_MARGIN := 12.0
# A loop's last-to-first step may be at most this much more than the average step between frames.
const LOOP_RATIO := 1.5
const LOOP_MARGIN := 4.0


# Greyscale value, 0-255.
static func value(colour: Color) -> float:
	return (0.2126 * colour.r + 0.7152 * colour.g + 0.0722 * colour.b) * 255.0


# The colours of a GIMP palette file, as a set of html colours.
static func load_palette(path: String) -> Dictionary:
	var palette := {}
	for line in FileAccess.get_file_as_string(path).split("\n"):
		# Colour lines are "r g b<tab>name"; the header lines are not.
		var fields := line.replace("\t", " ").split(" ", false)
		if fields.size() < 3 or not (fields[0].is_valid_int() and fields[1].is_valid_int()):
			continue
		var colour := Color8(fields[0].to_int(), fields[1].to_int(), fields[2].to_int())
		palette[colour.to_html(false)] = true
	return palette


# How many opaque pixels are off the palette, and which colours they are.
static func off_palette(image: Image, palette: Dictionary) -> Dictionary:
	var pixels := 0
	var colours := {}
	for y in image.get_height():
		for x in image.get_width():
			var colour := image.get_pixel(x, y)
			if colour.a < 0.5:
				continue
			var html := colour.to_html(false)
			if not palette.has(html):
				pixels += 1
				colours[html] = true
	return {pixels = pixels, colours = colours.keys()}


# The mean greyscale value of a rectangle's opaque pixels, or -1 when it has none.
static func mean_value(image: Image, rect: Rect2i) -> float:
	var total := 0.0
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var colour := image.get_pixel(x, y)
			if colour.a >= 0.5:
				total += value(colour)
				count += 1
	return total / count if count > 0 else -1.0


# Whether a tile's top 2 rows are lit: clearly brighter than its body.
static func has_lit_top_edge(tile: Image, body: Rect2i) -> bool:
	var top := mean_value(tile, Rect2i(0, 0, TILE, 2))
	var rest := mean_value(tile, body)
	return top >= 0.0 and rest >= 0.0 and top >= rest + LIT_EDGE_LIFT


# Whether some row in the tile's top rows is mostly covered, so the art reaches its collision.
static func covers_top(tile: Image, rows: int) -> bool:
	for y in rows:
		var covered := 0
		for x in TILE:
			if tile.get_pixel(x, y).a >= 0.5:
				covered += 1
		if covered >= TILE * COVERED_SHARE:
			return true
	return false


# Whether a surface's colour reads against the colour behind it.
static func reads_against(surface: Color, behind: Color) -> bool:
	return absf(value(surface) - value(behind)) >= READABLE_VALUE_GAP


# How big a colour step is, 0-255, counting alpha.
static func step(a: Color, b: Color) -> float:
	return (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)) / 4.0 * 255.0


# The step across the edge where two tiles meet (b to the right of a, or below it when not
# side_by_side), and the mean step between neighbouring pixels inside them.
static func seam_across(a: Image, b: Image, side_by_side: bool) -> Dictionary:
	var size := a.get_width()
	var seam := 0.0
	var inner := 0.0
	var inner_count := 0
	for i in size:
		seam += step(_at(a, size - 1, i, side_by_side), _at(b, 0, i, side_by_side))
		for along in size - 1:
			for tile in [a, b]:
				inner += step(
					_at(tile, along, i, side_by_side), _at(tile, along + 1, i, side_by_side)
				)
				inner_count += 1
	return {seam = seam / size, inner = inner / inner_count}


static func is_seam(across: Dictionary) -> bool:
	return across.seam > across.inner * SEAM_RATIO + SEAM_MARGIN


# A pixel by its position across the edge and along it.
static func _at(image: Image, across: int, along: int, side_by_side: bool) -> Color:
	return image.get_pixel(across, along) if side_by_side else image.get_pixel(along, across)


# The mean step between two frames.
static func frame_step(a: Image, b: Image) -> float:
	var total := 0.0
	for y in a.get_height():
		for x in a.get_width():
			total += step(a.get_pixel(x, y), b.get_pixel(x, y))
	return total / (a.get_width() * a.get_height())


# Whether the last frame jumps back to the first much harder than the frames step between
# themselves.
static func breaks_loop(frames: Array[Image]) -> bool:
	if frames.size() < 2:
		return false
	var between := 0.0
	for i in frames.size() - 1:
		between += frame_step(frames[i], frames[i + 1])
	between /= frames.size() - 1
	return frame_step(frames[-1], frames[0]) > between * LOOP_RATIO + LOOP_MARGIN


# How many separate pieces the opaque pixels make, touching sides or corners.
static func silhouette_parts(image: Image) -> int:
	var seen := {}
	var parts := 0
	for y in image.get_height():
		for x in image.get_width():
			var start := Vector2i(x, y)
			if seen.has(start) or image.get_pixelv(start).a < 0.5:
				continue
			parts += 1
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var n := p + Vector2i(dx, dy)
						if (
							n.x < 0
							or n.y < 0
							or n.x >= image.get_width()
							or n.y >= image.get_height()
						):
							continue
						if not seen.has(n) and image.get_pixelv(n).a >= 0.5:
							seen[n] = true
							stack.append(n)
	return parts
