extends RefCounted

# Where a Room's enemies can stand: each kind has its own ground, checked against the Room's
# Terrain.

const RoomReach := preload("res://tests/room_reach.gd")
const TILE := 16
# How far above its floor a Wraith floats.
const WRAITH_HOVER := 16.0
# A Silt Crab's feet are this far above its middle while it clings; how close sideways it notices
# a Player below; and the most it may drop to the floor under it.
const CRAB_FEET := 8.0
const CRAB_NOTICE := 24.0
const CRAB_MOST_DROP := 6
const SILT_CRAB_SCENE := "res://scenes/enemies/silt_crab.tscn"
const STALKER_SCENE := "res://scenes/enemies/stalker.tscn"
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


# A Silt Crab clings: Terrain right above its feet, open air where it hangs, and a floor below it,
# no more than its most drop down, to land on. Returns that floor's row, or -1.
static func clings(terrain: TileMapLayer, crab: Node2D) -> int:
	if crab == null or crab.scene_file_path != SILT_CRAB_SCENE:
		return -1
	var column := int(crab.position.x / TILE)
	var ceiling := int((crab.position.y - CRAB_FEET - 1.0) / TILE)
	if terrain.get_cell_source_id(Vector2i(column, ceiling)) == -1:
		return -1
	if not is_equal_approx(crab.position.y - CRAB_FEET, (ceiling + 1) * TILE):
		return -1
	for row in range(ceiling + 1, ceiling + 2 + CRAB_MOST_DROP):
		if terrain.get_cell_source_id(Vector2i(column, row)) != -1:
			return row if row > ceiling + 1 else -1
	return -1


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


# A Stalker perches: its feet, at its origin, stand on a surface, with open air above them.
static func perches(terrain: TileMapLayer, stalker: Node2D) -> bool:
	var feet := Vector2i((stalker.position + Vector2(0, -1)) / TILE)
	return (
		stalker.scene_file_path == STALKER_SCENE
		and terrain.get_cell_source_id(feet + Vector2i.DOWN) != -1
		and terrain.get_cell_source_id(feet) == -1
		and is_zero_approx(fmod(stalker.position.y, TILE))
	)
