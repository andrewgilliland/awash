extends RefCounted

# The Undertow: a Region of its own under the coast's cliffs, drawn from the Mucho Pixels
# Underwater pack, with its own Background and theme.

const World := preload("res://scripts/core/world.gd")
const RoomReach := preload("res://tests/room_reach.gd")
const UNDERTOW := &"undertow"
const TILES := "res://assets/regions/undertow/tiles/"
const PACK := "res://assets/packs/underwater/"
const BACKGROUND := "res://scenes/regions/undertow/background.tscn"
const COAST_THEME := "res://assets/regions/waking_coast/music/theme.wav"
const WORLD_LAYER := 1
# The pack's earth: its sandy block and its mossy one, each a 5x5 of edges round a middle; and
# its strips of ledge, one-way.
const SANDY := Rect2i(1, 1, 5, 5)
const MOSSY := Rect2i(1, 9, 5, 5)
const LEDGES: Array[Vector2i] = [Vector2i(1, 7), Vector2i(5, 7), Vector2i(9, 7)]
# The temple's stone slab, one-way, and its block of masonry, solid.
const SLAB := Rect2i(14, 12, 5, 1)
const MASONRY := Rect2i(14, 8, 5, 3)
# The Background's layers, back to front, and how fast each scrolls across with the camera: the
# deep water fixed to the screen, the light beams near it, the far ridge, then the drowned ruins.
# None scrolls up or down: under the cliffs they hold their height on the screen, however deep.
const LAYERS := {Deep = 0.0, Beams = 0.05, Ridge = 0.2, Ruins = 0.4}


func get_tests() -> Array:
	return [
		["The Undertow's tiles come in two sets from the packs", _test_tile_sets],
		["The Undertow's earth is solid and its ledges one-way", _test_ground],
		["The Undertow's pools sink underfoot like the coast's shallows", _test_water],
		["The Undertow's Background is drowned ruins in deep water", _test_background],
		["The Undertow has a looping theme of its own", _test_theme],
		["The undertow tunnel lies in the Undertow, under its Background", _test_tunnel],
	]


func _test_tile_sets() -> bool:
	var terrain := load(TILES + "terrain.tres") as TileSet
	var scenery := load(TILES + "scenery.tres") as TileSet
	if terrain == null or scenery == null:
		return false
	var valid := terrain.get_physics_layers_count() == 1
	valid = valid and terrain.get_physics_layer_collision_layer(0) == WORLD_LAYER
	valid = valid and scenery.get_physics_layers_count() == 0
	var underwater := 0
	for tile_set: TileSet in [terrain, scenery]:
		for i in range(tile_set.get_source_count()):
			var atlas := tile_set.get_source(tile_set.get_source_id(i)) as TileSetAtlasSource
			valid = valid and atlas != null and atlas.texture_region_size == Vector2i(16, 16)
			if atlas == null:
				continue
			var sheet := atlas.texture.resource_path
			valid = (
				valid and sheet.begins_with("res://assets/packs/") and atlas.get_tiles_count() > 0
			)
			underwater += 1 if sheet.begins_with(PACK) else 0
			if tile_set == terrain:
				for t in range(atlas.get_tiles_count()):
					var data := atlas.get_tile_data(atlas.get_tile_id(t), 0)
					valid = valid and data.get_collision_polygons_count(0) > 0
	return valid and underwater >= 10


func _test_ground() -> bool:
	var terrain := load(TILES + "terrain.tres") as TileSet
	var ground := _atlas(terrain, "ground_and_rocks.png")
	var temple := _atlas(terrain, "temple_ruins.png")
	if ground == null or temple == null:
		return false
	var valid := true
	for block in [SANDY, MOSSY]:
		for x in range(block.position.x, block.end.x):
			for y in range(block.position.y, block.end.y):
				valid = valid and _solid(ground, Vector2i(x, y))
	for start in LEDGES:
		for x in range(start.x, start.x + 3):
			valid = valid and _one_way(ground, Vector2i(x, start.y))
	for x in range(SLAB.position.x, SLAB.end.x):
		valid = valid and _one_way(temple, Vector2i(x, SLAB.position.y))
	for x in range(MASONRY.position.x, MASONRY.end.x):
		for y in range(MASONRY.position.y, MASONRY.end.y):
			valid = valid and _solid(temple, Vector2i(x, y))
	return valid


# Drawn with the coast's own water, so a pool is the same shallow the Player knows.
func _test_water() -> bool:
	var terrain := load(TILES + "terrain.tres") as TileSet
	var water := _atlas(terrain, RoomReach.WATER_SHEET.get_file())
	return water != null and water.texture.resource_path == RoomReach.WATER_SHEET


func _test_background() -> bool:
	if not ResourceLoader.exists(BACKGROUND):
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


# Read through the tunnel, the Region's first Room.
func _test_theme() -> bool:
	var path := World.theme(&"waking_coast_9")
	var theme := load(path) as AudioStreamWAV if ResourceLoader.exists(path) else null
	return (
		theme != null
		and theme.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and path.begins_with("res://assets/regions/undertow/")
		and path != COAST_THEME
	)


func _test_tunnel() -> bool:
	return (
		World.region(&"waking_coast_9") == UNDERTOW
		and World.background(&"waking_coast_9") == BACKGROUND
	)


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
