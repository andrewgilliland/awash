extends Node2D

const TILE_SIZE: int = 16
const ROOM_COUNT: int = 8
const ROOM_WIDTH_TILES: int = 16
const MAP_HEIGHT_TILES: int = 16
const FLOOR_Y: int = 14
const WORLD_ORIGIN_X: float = -232.0
const WORLD_ORIGIN_Y: float = 0.0
const ROOM_SPAWN_Y: float = 180.0

const ATLAS_BG := Vector2i(0, 0)
const ATLAS_GROUND := Vector2i(1, 0)
const ATLAS_FOREGROUND := Vector2i(2, 0)

@onready var _background_layer: TileMapLayer = $Tilemaps/BackgroundLayer
@onready var _ground_layer: TileMapLayer = $Tilemaps/GroundLayer
@onready var _foreground_layer: TileMapLayer = $Tilemaps/ForegroundLayer


func _ready() -> void:
	var tile_set_data := _build_blockout_tileset()
	var tile_set := tile_set_data["tile_set"] as TileSet
	var source_id := tile_set_data["source_id"] as int

	_background_layer.tile_set = tile_set
	_ground_layer.tile_set = tile_set
	_foreground_layer.tile_set = tile_set

	_paint_layers(source_id)


func _build_blockout_tileset() -> Dictionary:
	var image := Image.create(TILE_SIZE * 3, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	image.fill_rect(Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Color(0.086275, 0.141176, 0.2, 1.0))
	image.fill_rect(
		Rect2i(TILE_SIZE, 0, TILE_SIZE, TILE_SIZE), Color(0.145098, 0.239216, 0.313725, 1.0)
	)
	image.fill_rect(
		Rect2i(TILE_SIZE * 2, 0, TILE_SIZE, TILE_SIZE), Color(0.203922, 0.345098, 0.435294, 1.0)
	)

	var texture := ImageTexture.create_from_image(image)

	var tile_set := TileSet.new()
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = texture
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	atlas_source.create_tile(ATLAS_BG)
	atlas_source.create_tile(ATLAS_GROUND)
	atlas_source.create_tile(ATLAS_FOREGROUND)

	var source_id := tile_set.get_next_source_id()
	tile_set.add_source(atlas_source, source_id)

	return {
		"tile_set": tile_set,
		"source_id": source_id,
	}


func _paint_layers(source_id: int) -> void:
	var total_width := ROOM_COUNT * ROOM_WIDTH_TILES

	for layer in [_background_layer, _ground_layer, _foreground_layer]:
		layer.clear()

	# Soft background fill across every room.
	_fill_rect(_background_layer, source_id, ATLAS_BG, 0, total_width - 1, 6, 13)

	# Main biome floor.
	_fill_rect(_ground_layer, source_id, ATLAS_GROUND, 0, total_width - 1, FLOOR_Y, FLOOR_Y + 1)

	for room_index in range(ROOM_COUNT):
		var room_start := room_index * ROOM_WIDTH_TILES
		var room_end := room_start + ROOM_WIDTH_TILES - 1

		# Visual separators so each room reads as its own blockout space.
		_fill_rect(_foreground_layer, source_id, ATLAS_FOREGROUND, room_start, room_start, 8, 13)
		_fill_rect(_foreground_layer, source_id, ATLAS_FOREGROUND, room_end, room_end, 8, 13)

	# Room 1 platforms.
	_fill_rect(_ground_layer, source_id, ATLAS_GROUND, 4, 9, 11, 11)

	# Room 2 platforms.
	_fill_rect(_ground_layer, source_id, ATLAS_GROUND, 20, 26, 9, 9)
	_fill_rect(_ground_layer, source_id, ATLAS_GROUND, 25, 30, 12, 12)

	# Room 3 platforms.
	_fill_rect(_ground_layer, source_id, ATLAS_GROUND, 35, 40, 10, 10)
	_fill_rect(_ground_layer, source_id, ATLAS_GROUND, 41, 45, 7, 7)

	# Room 4 platforms + gate-style ledge for upcoming ability progression.
	_fill_rect(_ground_layer, source_id, ATLAS_GROUND, 52, 58, 11, 11)
	_fill_rect(_foreground_layer, source_id, ATLAS_FOREGROUND, 60, 62, 10, 10)

	# Room 5 vertical climb path.
	_fill_rect(_ground_layer, source_id, ATLAS_GROUND, 68, 73, 10, 10)
	_fill_rect(_ground_layer, source_id, ATLAS_GROUND, 74, 78, 7, 7)

	# Room 6 long finish platform.
	_fill_rect(_ground_layer, source_id, ATLAS_GROUND, 84, 92, 9, 9)
	_fill_rect(_foreground_layer, source_id, ATLAS_FOREGROUND, 93, 94, 8, 12)

	# Room 7 staggered route.
	_fill_rect(_ground_layer, source_id, ATLAS_GROUND, 100, 106, 10, 10)
	_fill_rect(_ground_layer, source_id, ATLAS_GROUND, 108, 111, 7, 7)

	# Room 8 final wide shelf.
	_fill_rect(_ground_layer, source_id, ATLAS_GROUND, 116, 124, 11, 11)
	_fill_rect(_foreground_layer, source_id, ATLAS_FOREGROUND, 125, 127, 8, 12)


func _fill_rect(
	layer: TileMapLayer,
	source_id: int,
	atlas_coords: Vector2i,
	from_x: int,
	to_x: int,
	from_y: int,
	to_y: int
) -> void:
	for y in range(from_y, to_y + 1):
		for x in range(from_x, to_x + 1):
			layer.set_cell(Vector2i(x, y), source_id, atlas_coords)


func get_room_count() -> int:
	return ROOM_COUNT


func get_room_id_from_index(index: int) -> StringName:
	if index < 0 or index >= ROOM_COUNT:
		return StringName("")
	return StringName("room_%d" % (index + 1))


func get_room_index(room_id: StringName) -> int:
	var room_name := String(room_id)
	if not room_name.begins_with("room_"):
		return -1

	var suffix := room_name.trim_prefix("room_")
	if not suffix.is_valid_int():
		return -1

	var index := int(suffix) - 1
	if index < 0 or index >= ROOM_COUNT:
		return -1
	return index


func get_room_bounds(room_id: StringName) -> Rect2:
	var index := get_room_index(room_id)
	if index < 0:
		index = 0

	var room_width := float(ROOM_WIDTH_TILES * TILE_SIZE)
	var room_height := float(MAP_HEIGHT_TILES * TILE_SIZE)
	var left := WORLD_ORIGIN_X + room_width * index
	return Rect2(left, WORLD_ORIGIN_Y, room_width, room_height)


func get_adjacent_room_id(room_id: StringName, direction: int) -> StringName:
	var index := get_room_index(room_id)
	if index < 0:
		return StringName("")

	var next_index := index + direction
	return get_room_id_from_index(next_index)


func get_room_spawn_position(room_id: StringName, entry_side: StringName = &"center") -> Vector2:
	var bounds := get_room_bounds(room_id)
	var spawn_x := bounds.position.x + bounds.size.x * 0.5

	if entry_side == &"left":
		spawn_x = bounds.position.x + 26.0
	elif entry_side == &"right":
		spawn_x = bounds.position.x + bounds.size.x - 26.0

	return Vector2(spawn_x, ROOM_SPAWN_Y)
