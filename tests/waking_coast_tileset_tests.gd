extends RefCounted

# This art, the shore and sea cave of Rooms 2-9, keeps its layout on the Waking Coast's sheets:
# its ground on the terrain sheet, all else on the scenery sheet, from row 0 of each.
const TERRAIN_PATH := "res://assets/regions/waking_coast/tiles/terrain.tres"
const SCENERY_PATH := "res://assets/regions/waking_coast/tiles/scenery.tres"
const BAND := Vector2i(0, 0)
const COLUMNS := 8
const ROWS := 11
const FULL_SQUARE := [Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]
# One-way ledges and decks collide along their top 7 pixels.
const LEDGE_TOP := [Vector2(-8, -8), Vector2(8, -8), Vector2(8, -1), Vector2(-8, -1)]
# Shallow water stands the Player on the sand under it, 10 pixels down.
const SHALLOW_SAND := [Vector2(-8, 2), Vector2(8, 2), Vector2(8, 8), Vector2(-8, 8)]
const SHALLOW := Vector2i(5, 5)
const ONE_WAY := [
	Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6)
]
const ANIMATED := [
	Vector2i(0, 4),
	Vector2i(2, 4),
	Vector2i(0, 5),
	Vector2i(1, 5),
	Vector2i(2, 5),
	Vector2i(3, 5),
	Vector2i(4, 5),
	Vector2i(5, 5),
	Vector2i(6, 5),
	Vector2i(7, 5),
	Vector2i(2, 7),
	Vector2i(5, 7),
	Vector2i(2, 8),
	Vector2i(5, 8),
	# Palm crowns sway: near (columns 0-2) and far (columns 4-6), rows 9-10.
	Vector2i(0, 9),
	Vector2i(1, 9),
	Vector2i(2, 9),
	Vector2i(0, 10),
	Vector2i(1, 10),
	Vector2i(2, 10),
	Vector2i(4, 9),
	Vector2i(5, 9),
	Vector2i(6, 9),
	Vector2i(4, 10),
	Vector2i(5, 10),
	Vector2i(6, 10),
]
const FRAME_COUNT := 4
const FRAME_DURATION := 0.15
# Each frame is a full copy of the sheet, so a tile's next frame sits 8 columns to its right.
const FRAME_SEPARATION := Vector2i(7, 0)


func get_tests() -> Array:
	return [
		["Waking Coast ground is terrain; the rest is scenery", _test_ground_is_terrain],
		["Waking Coast sand and rock are solid", _test_sand_and_rock_are_solid],
		["Waking Coast ledges and decks are one-way", _test_ledges_and_decks_are_one_way],
		["Waking Coast surf and runes loop four frames", _test_animated_tiles_loop],
	]


static func _solid_tiles() -> Array:
	var tiles: Array = []
	for row in range(4):
		for column in range(COLUMNS):
			tiles.append(Vector2i(column, row))
	for column in range(COLUMNS):
		tiles.append(Vector2i(column, 8))
	tiles.append_array([Vector2i(0, 4), Vector2i(1, 4), Vector2i(6, 5)])
	return tiles


static func _atlas(path: String) -> TileSetAtlasSource:
	var tile_set := load(path) as TileSet
	if tile_set == null or not tile_set.has_source(0):
		return null
	return tile_set.get_source(0) as TileSetAtlasSource


static func _colliding() -> Array:
	return _solid_tiles() + ONE_WAY + [SHALLOW]


static func _collides_with(atlas: TileSetAtlasSource, coords: Vector2i, points: Array) -> bool:
	if not atlas.has_tile(coords + BAND):
		return false
	var data := atlas.get_tile_data(coords + BAND, 0)
	if data.get_collision_polygons_count(0) != 1:
		return false
	return Array(data.get_collision_polygon_points(0, 0)) == points


func _test_ground_is_terrain() -> bool:
	var terrain := _atlas(TERRAIN_PATH)
	var scenery := _atlas(SCENERY_PATH)
	if terrain == null or scenery == null:
		return false
	var valid := true
	for row in range(ROWS):
		for column in range(COLUMNS):
			var coords := Vector2i(column, row)
			var ground := coords in _colliding()
			valid = valid and terrain.has_tile(coords + BAND) == ground
			valid = valid and scenery.has_tile(coords + BAND) != ground
	return valid


func _test_sand_and_rock_are_solid() -> bool:
	var atlas := _atlas(TERRAIN_PATH)
	if atlas == null:
		return false
	var valid := true
	for coords in _solid_tiles():
		valid = valid and _collides_with(atlas, coords, FULL_SQUARE)
		valid = (
			valid and not atlas.get_tile_data(coords + BAND, 0).is_collision_polygon_one_way(0, 0)
		)
	valid = valid and _collides_with(atlas, SHALLOW, SHALLOW_SAND)
	return valid


func _test_ledges_and_decks_are_one_way() -> bool:
	var atlas := _atlas(TERRAIN_PATH)
	if atlas == null:
		return false
	var valid := true
	for coords in ONE_WAY:
		valid = valid and _collides_with(atlas, coords, LEDGE_TOP)
		valid = valid and atlas.get_tile_data(coords + BAND, 0).is_collision_polygon_one_way(0, 0)
	return valid


func _test_animated_tiles_loop() -> bool:
	var terrain := _atlas(TERRAIN_PATH)
	var scenery := _atlas(SCENERY_PATH)
	if terrain == null or scenery == null:
		return false
	var valid := true
	for row in range(ROWS):
		for column in range(COLUMNS):
			var coords := Vector2i(column, row)
			var atlas := terrain if coords in _colliding() else scenery
			var tile := coords + BAND
			if not atlas.has_tile(tile):
				valid = false
				continue
			if coords not in ANIMATED:
				valid = valid and atlas.get_tile_animation_frames_count(tile) == 1
				continue
			valid = valid and atlas.get_tile_animation_frames_count(tile) == FRAME_COUNT
			valid = valid and atlas.get_tile_animation_columns(tile) == 0
			valid = valid and atlas.get_tile_animation_separation(tile) == FRAME_SEPARATION
			for frame in range(FRAME_COUNT):
				var duration := atlas.get_tile_animation_frame_duration(tile, frame)
				valid = valid and is_equal_approx(duration, FRAME_DURATION)
	return valid
