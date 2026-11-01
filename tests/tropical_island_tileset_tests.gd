extends RefCounted

# This art, the tropical beach and jungle of the first Room, keeps its layout on the Waking
# Coast's sheets: its ground on the terrain sheet, all else on the scenery sheet, from row 11.
const TERRAIN_PATH := "res://assets/regions/waking_coast/tiles/terrain.tres"
const SCENERY_PATH := "res://assets/regions/waking_coast/tiles/scenery.tres"
const BAND := Vector2i(0, 11)
const COLUMNS := 8
const ROWS := 18
const FULL_SQUARE := [Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]
# Slopes rise 45 degrees across one tile: up to the right, and down to the right.
const SLOPE_UP := [Vector2(-8, 8), Vector2(8, -8), Vector2(8, 8)]
const SLOPE_DOWN := [Vector2(-8, -8), Vector2(8, 8), Vector2(-8, 8)]
# Beach slopes sit in row 0 and jungle slopes in row 2.
const SLOPES_UP := [Vector2i(3, 0), Vector2i(3, 2)]
const SLOPES_DOWN := [Vector2i(4, 0), Vector2i(4, 2)]
# Planks, the rope bridge, branch platforms and floating logs collide along their top 7 pixels,
# like the Waking Coast's ledges.
const LEDGE_TOP := [Vector2(-8, -8), Vector2(8, -8), Vector2(8, -1), Vector2(-8, -1)]
const ONE_WAY := [
	Vector2i(0, 4),
	Vector2i(1, 4),
	Vector2i(2, 4),
	Vector2i(3, 4),
	Vector2i(0, 9),
	Vector2i(1, 9),
	Vector2i(2, 9),
	Vector2i(0, 10),
	Vector2i(1, 10),
	Vector2i(2, 10),
]


func get_tests() -> Array:
	return [
		["Tropical island ground is terrain; the rest is scenery", _test_ground_is_terrain],
		["Tropical island beach and jungle ground is solid", _test_ground_is_solid],
		["Tropical island slopes collide along their surface", _test_slopes_collide],
		[
			"Tropical island planks, bridge, branches and logs are one-way",
			_test_planks_are_one_way,
		],
	]


static func _ground_tiles() -> Array:
	var tiles: Array = []
	for row in range(4):
		for column in range(COLUMNS):
			var coords := Vector2i(column, row)
			if coords not in SLOPES_UP and coords not in SLOPES_DOWN:
				tiles.append(coords)
	return tiles


static func _atlas(path: String) -> TileSetAtlasSource:
	var tile_set := load(path) as TileSet
	if tile_set == null or not tile_set.has_source(0):
		return null
	return tile_set.get_source(0) as TileSetAtlasSource


static func _collides_with(atlas: TileSetAtlasSource, coords: Vector2i, points: Array) -> bool:
	if not atlas.has_tile(coords + BAND):
		return false
	var data := atlas.get_tile_data(coords + BAND, 0)
	if data.get_collision_polygons_count(0) != 1:
		return false
	return Array(data.get_collision_polygon_points(0, 0)) == points


static func _is_one_way(atlas: TileSetAtlasSource, coords: Vector2i) -> bool:
	return atlas.get_tile_data(coords + BAND, 0).is_collision_polygon_one_way(0, 0)


func _test_ground_is_terrain() -> bool:
	var terrain := _atlas(TERRAIN_PATH)
	var scenery := _atlas(SCENERY_PATH)
	if terrain == null or scenery == null:
		return false
	var colliding := _ground_tiles() + SLOPES_UP + SLOPES_DOWN + ONE_WAY
	var valid := true
	for row in range(ROWS):
		for column in range(COLUMNS):
			var coords := Vector2i(column, row)
			var ground := coords in colliding
			valid = valid and terrain.has_tile(coords + BAND) == ground
			valid = valid and scenery.has_tile(coords + BAND) != ground
	return valid


func _test_ground_is_solid() -> bool:
	var atlas := _atlas(TERRAIN_PATH)
	if atlas == null:
		return false
	var valid := true
	for coords in _ground_tiles():
		valid = valid and _collides_with(atlas, coords, FULL_SQUARE)
		valid = valid and not _is_one_way(atlas, coords)
	return valid


func _test_slopes_collide() -> bool:
	var atlas := _atlas(TERRAIN_PATH)
	if atlas == null:
		return false
	var valid := true
	for coords in SLOPES_UP:
		valid = valid and _collides_with(atlas, coords, SLOPE_UP) and not _is_one_way(atlas, coords)
	for coords in SLOPES_DOWN:
		valid = valid and _collides_with(atlas, coords, SLOPE_DOWN)
		valid = valid and not _is_one_way(atlas, coords)
	return valid


func _test_planks_are_one_way() -> bool:
	var atlas := _atlas(TERRAIN_PATH)
	if atlas == null:
		return false
	var valid := true
	for coords in ONE_WAY:
		valid = valid and _collides_with(atlas, coords, LEDGE_TOP) and _is_one_way(atlas, coords)
	return valid
