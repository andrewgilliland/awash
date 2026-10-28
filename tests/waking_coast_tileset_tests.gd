extends RefCounted

const TILESET_PATH := "res://assets/tilesets/waking_coast_2.tres"
const SOURCE_ID := 0
const COLUMNS := 8
const ROWS := 9
const WORLD_LAYER := 1
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
]
const FRAME_COUNT := 4
const FRAME_DURATION := 0.15
# Each frame is a full copy of the sheet, so a tile's next frame sits 8 columns to its right.
const FRAME_SEPARATION := Vector2i(7, 0)


func get_tests() -> Array:
	return [
		["Waking Coast tileset holds every sheet tile", _test_holds_every_tile],
		["Waking Coast sand and rock are solid", _test_sand_and_rock_are_solid],
		["Waking Coast ledges and decks are one-way", _test_ledges_and_decks_are_one_way],
		["Waking Coast scenery does not collide", _test_scenery_does_not_collide],
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


static func _atlas() -> TileSetAtlasSource:
	var tile_set := load(TILESET_PATH) as TileSet
	if tile_set == null or not tile_set.has_source(SOURCE_ID):
		return null
	return tile_set.get_source(SOURCE_ID) as TileSetAtlasSource


static func _collides_with(atlas: TileSetAtlasSource, coords: Vector2i, points: Array) -> bool:
	if not atlas.has_tile(coords):
		return false
	var data := atlas.get_tile_data(coords, 0)
	if data.get_collision_polygons_count(0) != 1:
		return false
	return Array(data.get_collision_polygon_points(0, 0)) == points


func _test_holds_every_tile() -> bool:
	var tile_set := load(TILESET_PATH) as TileSet
	var atlas := _atlas()
	if tile_set == null or atlas == null:
		return false
	var valid := tile_set.tile_size == Vector2i(16, 16)
	valid = valid and tile_set.get_physics_layers_count() == 1
	valid = valid and tile_set.get_physics_layer_collision_layer(0) == WORLD_LAYER
	valid = valid and atlas.get_tiles_count() == COLUMNS * ROWS
	for row in range(ROWS):
		for column in range(COLUMNS):
			valid = valid and atlas.has_tile(Vector2i(column, row))
	return valid


func _test_sand_and_rock_are_solid() -> bool:
	var atlas := _atlas()
	if atlas == null:
		return false
	var valid := true
	for coords in _solid_tiles():
		valid = valid and _collides_with(atlas, coords, FULL_SQUARE)
		valid = valid and not atlas.get_tile_data(coords, 0).is_collision_polygon_one_way(0, 0)
	valid = valid and _collides_with(atlas, SHALLOW, SHALLOW_SAND)
	return valid


func _test_ledges_and_decks_are_one_way() -> bool:
	var atlas := _atlas()
	if atlas == null:
		return false
	var valid := true
	for coords in ONE_WAY:
		valid = valid and _collides_with(atlas, coords, LEDGE_TOP)
		valid = valid and atlas.get_tile_data(coords, 0).is_collision_polygon_one_way(0, 0)
	return valid


func _test_scenery_does_not_collide() -> bool:
	var atlas := _atlas()
	if atlas == null:
		return false
	var colliding := _solid_tiles() + ONE_WAY + [SHALLOW]
	var valid := true
	for row in range(ROWS):
		for column in range(COLUMNS):
			var coords := Vector2i(column, row)
			if coords in colliding or not atlas.has_tile(coords):
				continue
			valid = valid and atlas.get_tile_data(coords, 0).get_collision_polygons_count(0) == 0
	return valid


func _test_animated_tiles_loop() -> bool:
	var atlas := _atlas()
	if atlas == null:
		return false
	var valid := true
	for row in range(ROWS):
		for column in range(COLUMNS):
			var coords := Vector2i(column, row)
			if not atlas.has_tile(coords):
				valid = false
				continue
			if coords not in ANIMATED:
				valid = valid and atlas.get_tile_animation_frames_count(coords) == 1
				continue
			valid = valid and atlas.get_tile_animation_frames_count(coords) == FRAME_COUNT
			valid = valid and atlas.get_tile_animation_columns(coords) == 0
			valid = valid and atlas.get_tile_animation_separation(coords) == FRAME_SEPARATION
			for frame in range(FRAME_COUNT):
				var duration := atlas.get_tile_animation_frame_duration(coords, frame)
				valid = valid and is_equal_approx(duration, FRAME_DURATION)
	return valid
