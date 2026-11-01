extends RefCounted

# This art, the jungle canopy's tall trees, treehouse and rope bridge, keeps its layout on the
# Waking Coast's sheets: its ledges on the terrain sheet, all else on the scenery sheet, from
# row 29.
const TERRAIN_PATH := "res://assets/regions/waking_coast/tiles/terrain.tres"
const SCENERY_PATH := "res://assets/regions/waking_coast/tiles/scenery.tres"
const BAND := Vector2i(0, 29)
const COLUMNS := 8
const ROWS := 8
# Branch platforms and the treehouse deck collide along their top 7 pixels.
const LEDGE_TOP := [Vector2(-8, -8), Vector2(8, -8), Vector2(8, -1), Vector2(-8, -1)]
const LEDGES := [
	Vector2i(2, 0),
	Vector2i(3, 0),
	Vector2i(4, 0),
	Vector2i(5, 0),
	Vector2i(6, 0),
	Vector2i(2, 4),
	Vector2i(3, 4),
	Vector2i(4, 4),
	Vector2i(5, 4),
]
# The treehouse roof, left to right: it rises, runs flat, then falls.
const ROOF := [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
# The rope bridge, left anchor to right anchor.
const BRIDGE := [
	Vector2i(0, 5),
	Vector2i(1, 5),
	Vector2i(2, 5),
	Vector2i(3, 5),
	Vector2i(4, 5),
	Vector2i(5, 5),
	Vector2i(6, 5),
	Vector2i(7, 5),
]


func get_tests() -> Array:
	return [
		["Jungle canopy ledges are terrain; the rest is scenery", _test_ledges_are_terrain],
		["Jungle branches and the treehouse deck are one-way ledges", _test_ledges],
		["The treehouse roof is one-way and rises, runs flat, then falls", _test_roof],
		["The rope bridge is one-way, unbroken and sags in the middle", _test_bridge],
	]


static func _atlas(path: String = TERRAIN_PATH) -> TileSetAtlasSource:
	var tile_set := load(path) as TileSet
	if tile_set == null or not tile_set.has_source(0):
		return null
	return tile_set.get_source(0) as TileSetAtlasSource


# The one-way polygon's top edge, from its left end to its right end, or null without one.
static func _top(atlas: TileSetAtlasSource, coords: Vector2i) -> Variant:
	if not atlas.has_tile(coords + BAND):
		return null
	var data := atlas.get_tile_data(coords + BAND, 0)
	if data.get_collision_polygons_count(0) != 1 or not data.is_collision_polygon_one_way(0, 0):
		return null
	var points := data.get_collision_polygon_points(0, 0)
	if points.size() != 4 or points[0].x != -8.0 or points[1].x != 8.0:
		return null
	return Vector2(points[0].y, points[1].y)


func _test_ledges_are_terrain() -> bool:
	var terrain := _atlas()
	var scenery := _atlas(SCENERY_PATH)
	if terrain == null or scenery == null:
		return false
	var colliding := LEDGES + ROOF + BRIDGE
	var valid := true
	for row in range(ROWS):
		for column in range(COLUMNS):
			var coords := Vector2i(column, row)
			var ledge := coords in colliding
			valid = valid and terrain.has_tile(coords + BAND) == ledge
			valid = valid and scenery.has_tile(coords + BAND) != ledge
	return valid


func _test_ledges() -> bool:
	var atlas := _atlas()
	if atlas == null:
		return false
	var valid := true
	for coords in LEDGES:
		var data := atlas.get_tile_data(coords + BAND, 0)
		valid = valid and data.get_collision_polygons_count(0) == 1
		valid = valid and Array(data.get_collision_polygon_points(0, 0)) == LEDGE_TOP
		valid = valid and data.is_collision_polygon_one_way(0, 0)
	return valid


func _test_roof() -> bool:
	var atlas := _atlas()
	if atlas == null:
		return false
	var tops: Array = []
	for coords in ROOF:
		tops.append(_top(atlas, coords))
	if null in tops:
		return false
	var rise: Vector2 = tops[0]
	var flat: Vector2 = tops[1]
	var fall: Vector2 = tops[2]
	var valid := rise.x > rise.y and flat.x == flat.y and fall.x < fall.y
	return valid and rise.y == flat.x and flat.y == fall.x


func _test_bridge() -> bool:
	var atlas := _atlas()
	if atlas == null:
		return false
	var tops: Array = []
	for coords in BRIDGE:
		tops.append(_top(atlas, coords))
	if null in tops:
		return false
	var valid := true
	for i in range(tops.size() - 1):
		valid = valid and (tops[i] as Vector2).y == (tops[i + 1] as Vector2).x
	var ends := minf((tops[0] as Vector2).x, (tops[-1] as Vector2).y)
	var middle := (tops[floori(tops.size() / 2.0)] as Vector2).x
	return valid and middle > ends + 4.0
