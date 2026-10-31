extends RefCounted

const TILESET_PATH := "res://assets/tilesets/tropical_island_1.tres"
const SHEET_PATH := "res://assets/tilesets/tropical_island_1.png"
const SOURCE_ID := 0
const COLUMNS := 8
const ROWS := 18
const WORLD_LAYER := 1
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
		["Tropical island tileset holds every sheet tile", _test_holds_every_tile],
		["Tropical island beach and jungle ground is solid", _test_ground_is_solid],
		["Tropical island slopes collide along their surface", _test_slopes_collide],
		[
			"Tropical island planks, bridge, branches and logs are one-way",
			_test_planks_are_one_way,
		],
		["Tropical island scenery does not collide", _test_scenery_does_not_collide],
	]


static func _ground_tiles() -> Array:
	var tiles: Array = []
	for row in range(4):
		for column in range(COLUMNS):
			var coords := Vector2i(column, row)
			if coords not in SLOPES_UP and coords not in SLOPES_DOWN:
				tiles.append(coords)
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


static func _is_one_way(atlas: TileSetAtlasSource, coords: Vector2i) -> bool:
	return atlas.get_tile_data(coords, 0).is_collision_polygon_one_way(0, 0)


func _test_holds_every_tile() -> bool:
	var tile_set := load(TILESET_PATH) as TileSet
	var atlas := _atlas()
	if tile_set == null or atlas == null:
		return false
	var valid := tile_set.tile_size == Vector2i(16, 16)
	valid = valid and atlas.texture != null and atlas.texture.resource_path == SHEET_PATH
	valid = valid and tile_set.get_physics_layers_count() == 1
	valid = valid and tile_set.get_physics_layer_collision_layer(0) == WORLD_LAYER
	valid = valid and atlas.get_tiles_count() == COLUMNS * ROWS
	for row in range(ROWS):
		for column in range(COLUMNS):
			valid = valid and atlas.has_tile(Vector2i(column, row))
	return valid


func _test_ground_is_solid() -> bool:
	var atlas := _atlas()
	if atlas == null:
		return false
	var valid := true
	for coords in _ground_tiles():
		valid = valid and _collides_with(atlas, coords, FULL_SQUARE)
		valid = valid and not _is_one_way(atlas, coords)
	return valid


func _test_slopes_collide() -> bool:
	var atlas := _atlas()
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
	var atlas := _atlas()
	if atlas == null:
		return false
	var valid := true
	for coords in ONE_WAY:
		valid = valid and _collides_with(atlas, coords, LEDGE_TOP) and _is_one_way(atlas, coords)
	return valid


func _test_scenery_does_not_collide() -> bool:
	var atlas := _atlas()
	if atlas == null:
		return false
	var colliding := _ground_tiles() + SLOPES_UP + SLOPES_DOWN + ONE_WAY
	var valid := true
	for row in range(ROWS):
		for column in range(COLUMNS):
			var coords := Vector2i(column, row)
			if coords in colliding or not atlas.has_tile(coords):
				continue
			valid = valid and atlas.get_tile_data(coords, 0).get_collision_polygons_count(0) == 0
	return valid
