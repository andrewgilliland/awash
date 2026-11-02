extends RefCounted

# Each Region's tiles come in two sets: terrain, which the Player stands on, and scenery, which
# never collides. The coast's are drawn from the Tropical Island pack's sheets, as they come, and
# one sheet of its own props.
const TERRAIN_PATH := "res://assets/regions/waking_coast/tiles/terrain.tres"
const SCENERY_PATH := "res://assets/regions/waking_coast/tiles/scenery.tres"
const PACK_DIR := "res://assets/packs/tropical_island/"
const OWN_PROPS := "res://assets/regions/waking_coast/props/coast_props.png"
const WORLD_LAYER := 1


func get_tests() -> Array:
	return [
		["Every terrain tile collides or is one-way", _test_terrain_collides],
		["No scenery tile collides", _test_scenery_never_collides],
		["The coast's tiles come from the pack's sheets and its own props", _test_sheets],
	]


func _test_terrain_collides() -> bool:
	var tile_set := load(TERRAIN_PATH) as TileSet
	var atlases := _atlases(tile_set)
	if atlases.is_empty():
		return false
	var valid := tile_set.get_physics_layers_count() == 1
	valid = valid and tile_set.get_physics_layer_collision_layer(0) == WORLD_LAYER
	for atlas in atlases:
		valid = valid and atlas.get_tiles_count() > 0
		for i in range(atlas.get_tiles_count()):
			var data := atlas.get_tile_data(atlas.get_tile_id(i), 0)
			valid = valid and data.get_collision_polygons_count(0) > 0
	return valid


func _test_scenery_never_collides() -> bool:
	var tile_set := load(SCENERY_PATH) as TileSet
	var atlases := _atlases(tile_set)
	if atlases.is_empty():
		return false
	var valid := tile_set.get_physics_layers_count() == 0
	for atlas in atlases:
		valid = valid and atlas.get_tiles_count() > 0
	return valid


func _test_sheets() -> bool:
	var valid := true
	for path in [TERRAIN_PATH, SCENERY_PATH]:
		var atlases := _atlases(load(path) as TileSet)
		valid = valid and not atlases.is_empty()
		for atlas in atlases:
			var sheet := atlas.texture.resource_path
			valid = valid and (sheet.begins_with(PACK_DIR) or sheet == OWN_PROPS)
	return valid


# Every source of the set, each an atlas cut in 16-pixel tiles; empty if any is not.
static func _atlases(tile_set: TileSet) -> Array[TileSetAtlasSource]:
	var atlases: Array[TileSetAtlasSource] = []
	if tile_set == null or tile_set.tile_size != Vector2i(16, 16):
		return atlases
	for i in range(tile_set.get_source_count()):
		var atlas := tile_set.get_source(tile_set.get_source_id(i)) as TileSetAtlasSource
		if atlas == null or atlas.texture == null:
			return []
		if atlas.texture_region_size != Vector2i(16, 16):
			return []
		atlases.append(atlas)
	return atlases
