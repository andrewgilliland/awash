extends RefCounted

# Draws a Map layout onto a canvas item, from inside its _draw: the Map Panel's view, and the
# picture of the whole World alike.

const CURRENT_FILL := Color("52638c")
const WALL := Color("94a5c6")
const LINE := Color(0.58, 0.65, 0.78, 0.3)
const PLANNED_WALL := Color(0.58, 0.65, 0.78, 0.55)
const DOT := Color("ffff8b")
const DOT_SIZE := Vector2(2, 2)
const LABEL := Color("c6d3e8")
# The markers, a pixel at a time: a Rest point's bell, and a Boss's crown.
const MARKERS := {
	&"rest": {colour = Color("f2f2f2"), rows = ["..#..", ".###.", ".###.", "#####", "..#.."]},
	&"boss": {colour = Color("e8584c"), rows = [".....", "#.#.#", "#####", "#####", "....."]},
}


# The Regions' names, if the layout has them, are written in the font given.
static func draw(
	canvas: CanvasItem, layout: Dictionary, dot_lit: bool, font: Font = null, font_size := 6
) -> void:
	for room: Dictionary in layout.get("rooms", []):
		_draw_room(canvas, room)
	if font != null:
		for label: Dictionary in layout.get("labels", []):
			canvas.draw_string(
				font, label.at, label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, LABEL
			)
	if dot_lit and layout.has("dot"):
		canvas.draw_rect(Rect2(layout.dot, DOT_SIZE), DOT)


static func _draw_room(canvas: CanvasItem, room: Dictionary) -> void:
	if not room.planned:
		canvas.draw_rect(room.block, CURRENT_FILL if room.current else room.colour)
	for line: Rect2 in room.lines:
		canvas.draw_rect(line, LINE)
	for wall: Rect2 in room.walls:
		canvas.draw_rect(wall, PLANNED_WALL if room.planned else WALL)
	for marker: Dictionary in room.markers:
		_draw_marker(canvas, marker.kind, marker.at.position)


static func _draw_marker(canvas: CanvasItem, kind: StringName, at: Vector2) -> void:
	var pattern: Dictionary = MARKERS.get(kind, {})
	var rows: Array = pattern.get("rows", [])
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			if row[x] == "#":
				canvas.draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), pattern.colour)
