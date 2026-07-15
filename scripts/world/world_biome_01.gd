extends Node2D

const TILE_SIZE: int = 16
const ROOM_COUNT: int = 8
const ROOM_WIDTH_TILES: int = 16
const MAP_HEIGHT_TILES: int = 16
const FLOOR_Y: int = 14
const WORLD_ORIGIN_X: float = -232.0
const WORLD_ORIGIN_Y: float = 0.0
const ROOM_SPAWN_Y: float = 180.0

const ATLAS_BG_DARK := Vector2i(0, 0)
const ATLAS_BG_MID := Vector2i(1, 0)
const ATLAS_BG_LIGHT := Vector2i(2, 0)
const ATLAS_GROUND_TOP := Vector2i(3, 0)
const ATLAS_GROUND_FILL := Vector2i(4, 0)
const ATLAS_FOREGROUND := Vector2i(5, 0)
const ATLAS_DECOR := Vector2i(6, 0)

@onready var _background_layer: TileMapLayer = $Tilemaps/BackgroundLayer
@onready var _ground_layer: TileMapLayer = $Tilemaps/GroundLayer
@onready var _foreground_layer: TileMapLayer = $Tilemaps/ForegroundLayer
@onready var _collision_root: Node2D = $Collision


func _ready() -> void:
	var tile_set_data := _build_blockout_tileset()
	var tile_set := tile_set_data["tile_set"] as TileSet
	var source_id := tile_set_data["source_id"] as int
	var solid_rects := _build_ground_rects()

	_background_layer.tile_set = tile_set
	_ground_layer.tile_set = tile_set
	_foreground_layer.tile_set = tile_set

	_paint_layers(source_id, solid_rects)
	_rebuild_collisions(solid_rects)


func _build_blockout_tileset() -> Dictionary:
	var image := Image.create(TILE_SIZE * 7, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	_paint_tile_with_scanlines(image, 0, Color(0.070588, 0.109804, 0.156863, 1.0), 3, 0.06)
	_paint_tile_with_scanlines(image, 1, Color(0.109804, 0.168627, 0.223529, 1.0), 2, 0.045)
	_paint_tile_with_scanlines(image, 2, Color(0.156863, 0.239216, 0.305882, 1.0), 2, 0.04)
	_paint_ground_top_tile(image, 3)
	_paint_ground_fill_tile(image, 4)
	_paint_foreground_tile(image, 5)
	_paint_decor_tile(image, 6)

	var texture := ImageTexture.create_from_image(image)

	var tile_set := TileSet.new()
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = texture
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	atlas_source.create_tile(ATLAS_BG_DARK)
	atlas_source.create_tile(ATLAS_BG_MID)
	atlas_source.create_tile(ATLAS_BG_LIGHT)
	atlas_source.create_tile(ATLAS_GROUND_TOP)
	atlas_source.create_tile(ATLAS_GROUND_FILL)
	atlas_source.create_tile(ATLAS_FOREGROUND)
	atlas_source.create_tile(ATLAS_DECOR)

	var source_id := tile_set.get_next_source_id()
	tile_set.add_source(atlas_source, source_id)

	return {
		"tile_set": tile_set,
		"source_id": source_id,
	}


func _paint_layers(source_id: int, solid_rects: Array[Rect2i]) -> void:
	var total_width := ROOM_COUNT * ROOM_WIDTH_TILES

	for layer in [_background_layer, _ground_layer, _foreground_layer]:
		layer.clear()

	# Background gradient bands make room silhouettes easier to read.
	_fill_rect(_background_layer, source_id, ATLAS_BG_DARK, 0, total_width - 1, 6, 8)
	_fill_rect(_background_layer, source_id, ATLAS_BG_MID, 0, total_width - 1, 9, 11)
	_fill_rect(_background_layer, source_id, ATLAS_BG_LIGHT, 0, total_width - 1, 12, 13)

	for x in range(0, total_width):
		if x % 4 == 0:
			_background_layer.set_cell(Vector2i(x, 9), source_id, ATLAS_BG_LIGHT)
		elif x % 4 == 2:
			_background_layer.set_cell(Vector2i(x, 11), source_id, ATLAS_BG_DARK)

	# Paint all collision-driving ground rectangles from one source of truth.
	for rect in solid_rects:
		if rect.size.y >= 2:
			_fill_rect(
				_ground_layer,
				source_id,
				ATLAS_GROUND_FILL,
				rect.position.x,
				rect.position.x + rect.size.x - 1,
				rect.position.y,
				rect.position.y + rect.size.y - 1
			)
			_fill_rect(
				_ground_layer,
				source_id,
				ATLAS_GROUND_TOP,
				rect.position.x,
				rect.position.x + rect.size.x - 1,
				rect.position.y,
				rect.position.y
			)
		else:
			_fill_rect(
				_ground_layer,
				source_id,
				ATLAS_GROUND_TOP,
				rect.position.x,
				rect.position.x + rect.size.x - 1,
				rect.position.y,
				rect.position.y
			)

	for room_index in range(ROOM_COUNT):
		var room_start := room_index * ROOM_WIDTH_TILES
		var room_end := room_start + ROOM_WIDTH_TILES - 1

		# Visual separators so each room reads as its own blockout space.
		_fill_rect(_foreground_layer, source_id, ATLAS_FOREGROUND, room_start, room_start, 8, 13)
		_fill_rect(_foreground_layer, source_id, ATLAS_FOREGROUND, room_end, room_end, 8, 13)

	# Gate-style ledges for progression readability.
	_fill_rect(_foreground_layer, source_id, ATLAS_FOREGROUND, 60, 62, 10, 10)

	# Room 6 gate detail.
	_fill_rect(_foreground_layer, source_id, ATLAS_FOREGROUND, 93, 94, 8, 12)

	# Room 8 gate detail.
	_fill_rect(_foreground_layer, source_id, ATLAS_FOREGROUND, 125, 127, 8, 12)

	# Sparse top-of-ground details so the blockout reads less flat.
	for x in range(2, total_width - 2):
		if x % 11 == 0:
			_foreground_layer.set_cell(Vector2i(x, FLOOR_Y - 1), source_id, ATLAS_DECOR)


func _build_ground_rects() -> Array[Rect2i]:
	return [
		_tile_rect(0, 127, FLOOR_Y, FLOOR_Y + 1),
		_tile_rect(4, 9, 11, 11),
		_tile_rect(20, 26, 9, 9),
		_tile_rect(25, 30, 12, 12),
		_tile_rect(35, 40, 10, 10),
		_tile_rect(41, 45, 7, 7),
		_tile_rect(52, 58, 11, 11),
		_tile_rect(68, 73, 10, 10),
		_tile_rect(74, 78, 7, 7),
		_tile_rect(84, 92, 9, 9),
		_tile_rect(100, 106, 10, 10),
		_tile_rect(108, 111, 7, 7),
		_tile_rect(116, 124, 11, 11),
	]


func _tile_rect(from_x: int, to_x: int, from_y: int, to_y: int) -> Rect2i:
	return Rect2i(from_x, from_y, to_x - from_x + 1, to_y - from_y + 1)


func _rebuild_collisions(solid_rects: Array[Rect2i]) -> void:
	if _collision_root == null:
		return

	for child in _collision_root.get_children():
		child.queue_free()

	for i in range(solid_rects.size()):
		var rect := solid_rects[i]
		var body := StaticBody2D.new()
		body.name = "Solid_%d" % i

		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(rect.size.x * TILE_SIZE, rect.size.y * TILE_SIZE)
		shape.shape = rectangle

		var left := WORLD_ORIGIN_X + rect.position.x * TILE_SIZE
		var top := WORLD_ORIGIN_Y + rect.position.y * TILE_SIZE
		body.position = Vector2(left + rectangle.size.x * 0.5, top + rectangle.size.y * 0.5)

		body.add_child(shape)
		_collision_root.add_child(body)


func _paint_tile_with_scanlines(
	image: Image, tile_index: int, base_color: Color, line_step: int, line_strength: float
) -> void:
	var tile_x := tile_index * TILE_SIZE
	image.fill_rect(Rect2i(tile_x, 0, TILE_SIZE, TILE_SIZE), base_color)

	for y in range(0, TILE_SIZE, line_step):
		var shade := Color(
			maxf(0.0, base_color.r - line_strength),
			maxf(0.0, base_color.g - line_strength),
			maxf(0.0, base_color.b - line_strength),
			1.0
		)
		image.fill_rect(Rect2i(tile_x, y, TILE_SIZE, 1), shade)


func _paint_ground_top_tile(image: Image, tile_index: int) -> void:
	var tile_x := tile_index * TILE_SIZE
	image.fill_rect(
		Rect2i(tile_x, 0, TILE_SIZE, TILE_SIZE), Color(0.160784, 0.34902, 0.278431, 1.0)
	)
	image.fill_rect(Rect2i(tile_x, 0, TILE_SIZE, 2), Color(0.415686, 0.666667, 0.419608, 1.0))
	for x in range(1, TILE_SIZE, 4):
		image.fill_rect(Rect2i(tile_x + x, 2, 2, 1), Color(0.619608, 0.780392, 0.486275, 1.0))


func _paint_ground_fill_tile(image: Image, tile_index: int) -> void:
	var tile_x := tile_index * TILE_SIZE
	image.fill_rect(
		Rect2i(tile_x, 0, TILE_SIZE, TILE_SIZE), Color(0.121569, 0.25098, 0.203922, 1.0)
	)
	for y in range(2, TILE_SIZE, 4):
		image.fill_rect(Rect2i(tile_x, y, TILE_SIZE, 1), Color(0.090196, 0.188235, 0.160784, 1.0))


func _paint_foreground_tile(image: Image, tile_index: int) -> void:
	var tile_x := tile_index * TILE_SIZE
	image.fill_rect(
		Rect2i(tile_x, 0, TILE_SIZE, TILE_SIZE), Color(0.207843, 0.486275, 0.564706, 1.0)
	)
	image.fill_rect(Rect2i(tile_x + 6, 0, 4, TILE_SIZE), Color(0.172549, 0.392157, 0.466667, 1.0))


func _paint_decor_tile(image: Image, tile_index: int) -> void:
	var tile_x := tile_index * TILE_SIZE
	image.fill_rect(Rect2i(tile_x, 0, TILE_SIZE, TILE_SIZE), Color(0.0, 0.0, 0.0, 0.0))
	image.fill_rect(Rect2i(tile_x + 7, 4, 2, 8), Color(0.541176, 0.733333, 0.427451, 1.0))
	image.fill_rect(Rect2i(tile_x + 5, 7, 2, 6), Color(0.482353, 0.666667, 0.396078, 1.0))
	image.fill_rect(Rect2i(tile_x + 9, 7, 2, 6), Color(0.482353, 0.666667, 0.396078, 1.0))


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
