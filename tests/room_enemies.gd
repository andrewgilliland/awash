extends RefCounted

# Where a Room's enemies can stand: each kind has its own ground, checked against the Room's
# Terrain.

const RoomReach := preload("res://tests/room_reach.gd")
const TILE := 16
# How far above its floor a Wraith floats.
const WRAITH_HOVER := 16.0
# How finely a span is walked, in pixels.
const STEP := 8.0


# A Scavenger wades: both ends of its patrol are water on its own row.
static func wades(terrain: TileMapLayer, scavenger: Node2D) -> bool:
	var row := int(scavenger.position.y / TILE)
	for x in [scavenger.get("patrol_left"), scavenger.get("patrol_right")]:
		if not RoomReach.is_water(terrain, Vector2i(int(x / TILE), row)):
			return false
	return true


# A Storm Wisp drifts through open air: no Terrain anywhere along its drift.
static func drifts_clear(terrain: TileMapLayer, wisp: Node2D) -> bool:
	var left: float = wisp.get("drift_left")
	var right: float = wisp.get("drift_right")
	if left >= right:
		return false
	var x := left
	while x <= right:
		var cell := Vector2i(int(x / TILE), int(wisp.position.y / TILE))
		if terrain.get_cell_source_id(cell) != -1:
			return false
		x += STEP
	return true


# A Wraith haunts a stretch of floor, floating its hover above it the whole way.
static func haunts_floor(terrain: TileMapLayer, wraith: Node2D) -> bool:
	var left: float = wraith.get("haunt_left")
	var right: float = wraith.get("haunt_right")
	if left >= right or wraith.position.x < left or wraith.position.x > right:
		return false
	var floor_row := int((wraith.position.y + WRAITH_HOVER) / TILE)
	var x := left
	while x <= right:
		var column := int(x / TILE)
		if terrain.get_cell_source_id(Vector2i(column, floor_row)) == -1:
			return false
		if terrain.get_cell_source_id(Vector2i(column, floor_row - 1)) != -1:
			return false
		x += STEP
	return true


# Keeps two tiles clear of every Entry, so a Player arriving never lands in its reach.
static func clear_of_entries(room: Node, left: float, right: float) -> bool:
	for entry in room.get_node("Entries").get_children():
		var x: float = (entry as Node2D).position.x
		if x > left - 2 * TILE and x < right + 2 * TILE:
			return false
	return true


# Which screen across the Room a point is on.
static func screen_of(point: Vector2) -> int:
	return int(point.x / 160.0)
