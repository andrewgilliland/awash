extends RefCounted

# Each Region's tiles come on two sheets: terrain, which the Player stands on, and scenery, which
# never collides.
const TERRAIN_PATH := "res://assets/regions/waking_coast/tiles/terrain.tres"
const SCENERY_PATH := "res://assets/regions/waking_coast/tiles/scenery.tres"
const TERRAIN_SHEET := "res://assets/regions/waking_coast/tiles/terrain.png"
const SCENERY_SHEET := "res://assets/regions/waking_coast/tiles/scenery.png"
const WORLD_LAYER := 1
const WorldMap := preload("res://scripts/core/world_map.gd")


func get_tests() -> Array:
	return [
		["Every terrain tile collides or is one-way", _test_terrain_collides],
		["No scenery tile collides", _test_scenery_never_collides],
		["Every Room draws only from its Region's sheets", _test_rooms_use_region_sheets],
	]


func _test_terrain_collides() -> bool:
	var tile_set := load(TERRAIN_PATH) as TileSet
	var atlas := _only_atlas(tile_set, TERRAIN_SHEET)
	if atlas == null:
		return false
	var valid := tile_set.get_physics_layers_count() == 1
	valid = valid and tile_set.get_physics_layer_collision_layer(0) == WORLD_LAYER
	valid = valid and atlas.get_tiles_count() > 0
	for i in range(atlas.get_tiles_count()):
		var coords := atlas.get_tile_id(i)
		valid = valid and atlas.get_tile_data(coords, 0).get_collision_polygons_count(0) > 0
	return valid


func _test_scenery_never_collides() -> bool:
	var tile_set := load(SCENERY_PATH) as TileSet
	var atlas := _only_atlas(tile_set, SCENERY_SHEET)
	if atlas == null:
		return false
	return tile_set.get_physics_layers_count() == 0 and atlas.get_tiles_count() > 0


# A Room's Terrain layer comes from its Region's terrain sheet; every other layer, its Background's
# included, from the scenery sheet.
func _test_rooms_use_region_sheets() -> bool:
	var valid := true
	for room_id: StringName in WorldMap.ROOMS:
		var room_data: Dictionary = WorldMap.ROOMS[room_id]
		var tiles := (
			"res://assets/regions/%s/tiles/" % room_data.region.to_lower().replace(" ", "_")
		)
		var room := (load(room_data.scene) as PackedScene).instantiate()
		var layers := room.find_children("*", "TileMapLayer", true, false)
		valid = valid and room.get_node_or_null("Terrain") is TileMapLayer
		for layer: TileMapLayer in layers:
			var sheet := "terrain" if layer == room.get_node_or_null("Terrain") else "scenery"
			var path := layer.tile_set.resource_path if layer.tile_set != null else ""
			if path != tiles + sheet + ".tres":
				push_error("%s/%s draws from %s" % [room_id, room.get_path_to(layer), path])
				valid = false
		room.free()
	return valid


# The sheet's one atlas, drawn from the given image in 16-pixel tiles, or null.
static func _only_atlas(tile_set: TileSet, sheet: String) -> TileSetAtlasSource:
	if tile_set == null or tile_set.get_source_count() != 1 or not tile_set.has_source(0):
		return null
	var atlas := tile_set.get_source(0) as TileSetAtlasSource
	if atlas == null or atlas.texture == null or atlas.texture.resource_path != sheet:
		return null
	if tile_set.tile_size != Vector2i(16, 16) or atlas.texture_region_size != Vector2i(16, 16):
		return null
	return atlas
