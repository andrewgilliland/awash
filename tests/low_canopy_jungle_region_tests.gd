extends RefCounted

# The Low Canopy Jungle: Chapter 2's Region, east of Tidefen's harbour, drawn from its own sheet
# cut from the jungle mockup, with its own Background and theme. The Shrinekeeper Camp, its Safe
# spoke, is a Region of its own that keeps the jungle's sheets and Background.

const World := preload("res://scripts/core/world.gd")
const RoomReach := preload("res://tests/room_reach.gd")
const JUNGLE := &"low_canopy_jungle"
const CAMP := &"shrinekeeper_camp"
const HARBOUR_TRAIL := &"low_canopy_jungle_1"
const CAMP_ROOM := &"shrinekeeper_camp_1"
const TIDEFEN := &"tidefen_village_1"
const TILES := "res://assets/regions/low_canopy_jungle/tiles/"
const SHEET := TILES + "low_canopy_jungle.png"
const BACKGROUND_SHEET := TILES + "low_canopy_jungle_background.png"
const BACKGROUND := "res://scenes/regions/low_canopy_jungle/background.tscn"
const WORLD_LAYER := 1
# The sheet's earth: grass over earth, with its ends and undersides; the terraces' stone walls,
# their caps mossed over; then one-way ledges, the mossy ledge and the plank deck.
const GRASS_AND_EARTH := Rect2i(0, 0, 5, 3)
const STONE := Rect2i(5, 0, 4, 2)
const LEDGES: Array[Vector2i] = [Vector2i(0, 3), Vector2i(3, 3)]
# The Background's layers, back to front, and how fast each scrolls across with the camera: the sky
# fixed to the screen, its clouds, the far trunks, then the thicket. None scrolls up or down: up in
# the trees they hold their height on the screen.
const LAYERS := {Sky = 0.0, Clouds = 0.05, Trunks = 0.2, Thicket = 0.4}


func get_tests() -> Array:
	return [
		["The jungle and its camp have names and colours of their own", _test_regions],
		["The jungle's tiles come in two sets, cut from its own sheet", _test_tile_sets],
		["The jungle's earth and stone are solid and its ledges one-way", _test_ground],
		["The jungle's pools sink underfoot like the coast's shallows", _test_water],
		["The jungle's Background is sky, far trunks and thicket", _test_background],
		["The jungle has a looping theme of its own", _test_theme],
		["The Shrinekeeper Camp keeps the jungle's sheets and Background", _test_camp_shares],
	]


func _test_regions() -> bool:
	var jungle := World.colour_of_region(JUNGLE)
	var camp := World.colour_of_region(CAMP)
	return (
		World.name_of_region(JUNGLE) == "Low Canopy Jungle"
		and World.name_of_region(CAMP) == "Shrinekeeper Camp"
		and jungle.a == 1.0
		and camp.a == 1.0
		and jungle != camp
		and World.region(HARBOUR_TRAIL) == JUNGLE
		and World.region(CAMP_ROOM) == CAMP
	)


func _test_tile_sets() -> bool:
	var terrain := load(TILES + "terrain.tres") as TileSet if _exists("terrain.tres") else null
	var scenery := load(TILES + "scenery.tres") as TileSet if _exists("scenery.tres") else null
	if terrain == null or scenery == null:
		return false
	var valid := terrain.get_physics_layers_count() == 1
	valid = valid and terrain.get_physics_layer_collision_layer(0) == WORLD_LAYER
	valid = valid and scenery.get_physics_layers_count() == 0
	for tile_set: TileSet in [terrain, scenery]:
		for i in range(tile_set.get_source_count()):
			var atlas := tile_set.get_source(tile_set.get_source_id(i)) as TileSetAtlasSource
			valid = valid and atlas != null and atlas.texture_region_size == Vector2i(16, 16)
			valid = valid and atlas != null and atlas.get_tiles_count() > 0
			if atlas != null and tile_set == terrain:
				for t in range(atlas.get_tiles_count()):
					var data := atlas.get_tile_data(atlas.get_tile_id(t), 0)
					valid = valid and data.get_collision_polygons_count(0) > 0
	valid = valid and _atlas(terrain, SHEET.get_file()) != null
	valid = valid and _atlas(scenery, SHEET.get_file()) != null
	return valid and _atlas(scenery, BACKGROUND_SHEET.get_file()) != null


func _test_ground() -> bool:
	var terrain := load(TILES + "terrain.tres") as TileSet if _exists("terrain.tres") else null
	var sheet := _atlas(terrain, SHEET.get_file())
	if sheet == null:
		return false
	var valid := true
	for block in [GRASS_AND_EARTH, STONE]:
		for x in range(block.position.x, block.end.x):
			for y in range(block.position.y, block.end.y):
				valid = valid and _solid(sheet, Vector2i(x, y))
	for start in LEDGES:
		for x in range(start.x, start.x + 3):
			valid = valid and _one_way(sheet, Vector2i(x, start.y))
	return valid


# Drawn with the coast's own water, so a pool is the same shallow the Player knows.
func _test_water() -> bool:
	var terrain := load(TILES + "terrain.tres") as TileSet if _exists("terrain.tres") else null
	var water := _atlas(terrain, RoomReach.WATER_SHEET.get_file())
	return water != null and water.texture.resource_path == RoomReach.WATER_SHEET


func _test_background() -> bool:
	if not ResourceLoader.exists(BACKGROUND) or World.background(HARBOUR_TRAIL) != BACKGROUND:
		return false
	var background := (load(BACKGROUND) as PackedScene).instantiate()
	var names: Array = []
	var valid := true
	for layer in background.get_children():
		if layer is Parallax2D:
			var parallax := layer as Parallax2D
			names.append(parallax.name)
			var speed: float = LAYERS.get(parallax.name, -1.0)
			valid = valid and parallax.scroll_scale.is_equal_approx(Vector2(speed, 0))
			valid = valid and parallax.repeat_size.x > 0.0 and parallax.get_child_count() > 0
			for tiles: TileMapLayer in parallax.find_children("*", "TileMapLayer", true, false):
				valid = valid and tiles.tile_set.resource_path == TILES + "scenery.tres"
				valid = valid and not tiles.get_used_cells().is_empty()
	valid = valid and names == LAYERS.keys()
	background.free()
	return valid


# Read through the harbour trail, the Region's first Room.
func _test_theme() -> bool:
	var path := World.theme(HARBOUR_TRAIL)
	var theme := load(path) as AudioStreamWAV if ResourceLoader.exists(path) else null
	return (
		theme != null
		and theme.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and path.begins_with("res://assets/regions/low_canopy_jungle/")
		and path != World.theme(TIDEFEN)
	)


func _test_camp_shares() -> bool:
	return (
		World.tiles(CAMP_ROOM) == TILES
		and World.background(CAMP_ROOM) == World.background(HARBOUR_TRAIL)
		and not World.background(CAMP_ROOM).is_empty()
	)


static func _exists(file: String) -> bool:
	return ResourceLoader.exists(TILES + file)


static func _atlas(tile_set: TileSet, sheet: String) -> TileSetAtlasSource:
	if tile_set == null:
		return null
	for i in range(tile_set.get_source_count()):
		var atlas := tile_set.get_source(tile_set.get_source_id(i)) as TileSetAtlasSource
		if atlas != null and atlas.texture.resource_path.get_file() == sheet:
			return atlas
	return null


static func _solid(atlas: TileSetAtlasSource, coords: Vector2i) -> bool:
	if not atlas.has_tile(coords):
		return false
	var data := atlas.get_tile_data(coords, 0)
	return data.get_collision_polygons_count(0) > 0 and not data.is_collision_polygon_one_way(0, 0)


static func _one_way(atlas: TileSetAtlasSource, coords: Vector2i) -> bool:
	if not atlas.has_tile(coords):
		return false
	var data := atlas.get_tile_data(coords, 0)
	return data.get_collision_polygons_count(0) > 0 and data.is_collision_polygon_one_way(0, 0)
