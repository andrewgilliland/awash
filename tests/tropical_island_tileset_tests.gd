extends RefCounted

# The Tropical Island pack's terrain: its ground sheet's three sets (beach, cave earth and grass),
# its water, and the ledges the Player stands on: bridge decks, hut floors and mossy pads.
const TERRAIN_PATH := "res://assets/regions/waking_coast/tiles/terrain.tres"
const PACK_DIR := "res://assets/packs/tropical_island/"
const FULL_SQUARE := [Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]
# The water's surface lets the Player sink 10 pixels in, as a shallow pool does.
const SHALLOW := [Vector2(-8, 2), Vector2(8, 2), Vector2(8, 8), Vector2(-8, 8)]
const LEDGE_TOP := [Vector2(-8, -8), Vector2(8, -8), Vector2(8, -1), Vector2(-8, -1)]
# Each ground set is five tiles square: its top-left tile on the ground sheet.
const GROUND_SETS := [Vector2i(1, 1), Vector2i(1, 7), Vector2i(1, 13)]
const WATER := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
const LEDGES := {
	"ladders_and_bridges.png": [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)],
	"jungle_hut.png": [Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6)],
	"jungle_trees.png": [Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7)],
}


func get_tests() -> Array:
	return [
		["The pack's beach, cave earth and grass are solid", _test_ground_is_solid],
		["The pack's water sinks underfoot like a shallow", _test_water_sinks],
		["Bridge decks, hut floors and mossy pads are one-way ledges", _test_ledges],
	]


# The terrain set's atlas cut from the named pack sheet, or null.
static func _atlas(sheet: String) -> TileSetAtlasSource:
	var tile_set := load(TERRAIN_PATH) as TileSet
	if tile_set == null:
		return null
	for i in range(tile_set.get_source_count()):
		var atlas := tile_set.get_source(tile_set.get_source_id(i)) as TileSetAtlasSource
		if atlas != null and atlas.texture.resource_path == PACK_DIR + sheet:
			return atlas
	return null


static func _collides_with(atlas: TileSetAtlasSource, coords: Vector2i, points: Array) -> bool:
	if atlas == null or not atlas.has_tile(coords):
		return false
	var data := atlas.get_tile_data(coords, 0)
	if data.get_collision_polygons_count(0) != 1:
		return false
	return Array(data.get_collision_polygon_points(0, 0)) == points


static func _is_one_way(atlas: TileSetAtlasSource, coords: Vector2i) -> bool:
	return atlas.get_tile_data(coords, 0).is_collision_polygon_one_way(0, 0)


func _test_ground_is_solid() -> bool:
	var atlas := _atlas("ground.png")
	var valid := atlas != null
	for corner in GROUND_SETS:
		for row in range(5):
			for column in range(5):
				var coords: Vector2i = corner + Vector2i(column, row)
				valid = valid and _collides_with(atlas, coords, FULL_SQUARE)
				valid = valid and not _is_one_way(atlas, coords)
	return valid


func _test_water_sinks() -> bool:
	var atlas := _atlas("water.png")
	var valid := atlas != null
	for coords in WATER:
		valid = valid and _collides_with(atlas, coords, SHALLOW) and not _is_one_way(atlas, coords)
	return valid


func _test_ledges() -> bool:
	var valid := true
	for sheet in LEDGES:
		var atlas := _atlas(sheet)
		valid = valid and atlas != null
		for coords in LEDGES[sheet]:
			valid = (
				valid and _collides_with(atlas, coords, LEDGE_TOP) and _is_one_way(atlas, coords)
			)
	return valid
