extends RefCounted

# The jungle canopy sheet is the tropical TileSet's second atlas, so a Room can mix its tall
# trees, treehouse and rope bridge with the tropical ground on one layer.
const TILESET_PATH := "res://assets/tilesets/tropical_island_1.tres"
const SHEET_PATH := "res://assets/tilesets/jungle_canopy_1.png"
const SOURCE_ID := 1
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
		["Jungle canopy is the tropical TileSet's second atlas", _test_second_atlas],
		["Jungle branches and the treehouse deck are one-way ledges", _test_ledges],
		["The treehouse roof is one-way and rises, runs flat, then falls", _test_roof],
		["The rope bridge is one-way, unbroken and sags in the middle", _test_bridge],
		["Jungle trees, walls and backdrop do not collide", _test_scenery_does_not_collide],
	]


static func _atlas() -> TileSetAtlasSource:
	var tile_set := load(TILESET_PATH) as TileSet
	if tile_set == null or not tile_set.has_source(SOURCE_ID):
		return null
	return tile_set.get_source(SOURCE_ID) as TileSetAtlasSource


# The one-way polygon's top edge, from its left end to its right end, or null without one.
static func _top(atlas: TileSetAtlasSource, coords: Vector2i) -> Variant:
	if not atlas.has_tile(coords):
		return null
	var data := atlas.get_tile_data(coords, 0)
	if data.get_collision_polygons_count(0) != 1 or not data.is_collision_polygon_one_way(0, 0):
		return null
	var points := data.get_collision_polygon_points(0, 0)
	if points.size() != 4 or points[0].x != -8.0 or points[1].x != 8.0:
		return null
	return Vector2(points[0].y, points[1].y)


func _test_second_atlas() -> bool:
	var atlas := _atlas()
	if atlas == null:
		return false
	var valid := atlas.texture != null and atlas.texture.resource_path == SHEET_PATH
	valid = valid and atlas.texture_region_size == Vector2i(16, 16)
	valid = valid and atlas.get_tiles_count() == COLUMNS * ROWS
	for row in range(ROWS):
		for column in range(COLUMNS):
			valid = valid and atlas.has_tile(Vector2i(column, row))
	return valid


func _test_ledges() -> bool:
	var atlas := _atlas()
	if atlas == null:
		return false
	var valid := true
	for coords in LEDGES:
		var data := atlas.get_tile_data(coords, 0)
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


func _test_scenery_does_not_collide() -> bool:
	var atlas := _atlas()
	if atlas == null:
		return false
	var colliding := LEDGES + ROOF + BRIDGE
	var valid := true
	for row in range(ROWS):
		for column in range(COLUMNS):
			var coords := Vector2i(column, row)
			if coords in colliding or not atlas.has_tile(coords):
				continue
			valid = valid and atlas.get_tile_data(coords, 0).get_collision_polygons_count(0) == 0
	return valid
