extends Node2D

const TILE_SIZE: int = 16
const ROOM_WIDTH_TILES: int = 16
const DEFAULT_MAP_HEIGHT_TILES: int = 16
const WORLD_ORIGIN_X: float = -232.0
const WORLD_ORIGIN_Y: float = 0.0
const FALLBACK_ROOM_SPAWN_Y: float = 96.0
const SOURCE_SCENE_PATH := "res://scenes/world/mega_world_tilemap_source.tscn"

var _room_count: int = 8
var _map_height_tiles: int = DEFAULT_MAP_HEIGHT_TILES

@onready var _background_layer: TileMapLayer = $Tilemaps/BackgroundLayer
@onready var _ground_layer: TileMapLayer = $Tilemaps/GroundLayer
@onready var _foreground_layer: TileMapLayer = $Tilemaps/ForegroundLayer
@onready var _collision_root: Node2D = $Collision


func _ready() -> void:
	_import_source_tilemap()
	_clear_legacy_collisions()


func _import_source_tilemap() -> void:
	var packed_scene := load(SOURCE_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_warning("Could not load biome source scene: %s" % SOURCE_SCENE_PATH)
		return

	var source_root := packed_scene.instantiate()
	if source_root == null:
		push_warning("Could not instantiate biome source scene")
		return

	var source_tile_map := source_root.get_node_or_null("TileMap") as TileMap
	if source_tile_map == null:
		source_root.queue_free()
		push_warning("Biome source scene does not contain TileMap node")
		return

	var tile_set := source_tile_map.tile_set
	if tile_set == null:
		source_root.queue_free()
		push_warning("Biome source TileMap has no TileSet")
		return

	_background_layer.tile_set = tile_set
	_ground_layer.tile_set = tile_set
	_foreground_layer.tile_set = tile_set

	_background_layer.clear()
	_ground_layer.clear()
	_foreground_layer.clear()

	_copy_tilemap_layer(source_tile_map, 0, _background_layer)
	_copy_tilemap_layer(source_tile_map, 1, _ground_layer)

	var used_rect := source_tile_map.get_used_rect()
	if used_rect.size.x > 0:
		_room_count = maxi(2, int(ceili(float(used_rect.size.x) / float(ROOM_WIDTH_TILES))))
	if used_rect.size.y > 0:
		_map_height_tiles = maxi(DEFAULT_MAP_HEIGHT_TILES, used_rect.size.y)

	source_root.queue_free()


func _copy_tilemap_layer(
	source_tile_map: TileMap, layer_index: int, target_layer: TileMapLayer
) -> void:
	if layer_index < 0 or layer_index >= source_tile_map.get_layers_count():
		return

	for cell in source_tile_map.get_used_cells(layer_index):
		var source_id := source_tile_map.get_cell_source_id(layer_index, cell)
		if source_id == -1:
			continue

		var atlas_coords := source_tile_map.get_cell_atlas_coords(layer_index, cell)
		var alternative_tile := source_tile_map.get_cell_alternative_tile(layer_index, cell)
		target_layer.set_cell(cell, source_id, atlas_coords, alternative_tile)


func _clear_legacy_collisions() -> void:
	if _collision_root == null:
		return

	for child in _collision_root.get_children():
		child.queue_free()


func get_room_count() -> int:
	return _room_count


func get_room_id_from_index(index: int) -> StringName:
	if index < 0 or index >= _room_count:
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
	if index < 0 or index >= _room_count:
		return -1
	return index


func get_room_bounds(room_id: StringName) -> Rect2:
	var index := get_room_index(room_id)
	if index < 0:
		index = 0

	var room_width := float(ROOM_WIDTH_TILES * TILE_SIZE)
	var room_height := float(_map_height_tiles * TILE_SIZE)
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

	var spawn_y := _find_spawn_y_for_world_x(spawn_x)
	return Vector2(spawn_x, spawn_y)


func _find_spawn_y_for_world_x(world_x: float) -> float:
	if _ground_layer == null:
		return FALLBACK_ROOM_SPAWN_Y

	var local_center_x := int(floor((world_x - _ground_layer.position.x) / float(TILE_SIZE)))
	var best_cell_y := -INF

	for probe_x in range(local_center_x - 2, local_center_x + 3):
		var column_y: int = _find_lowest_solid_cell_y(probe_x)
		if column_y >= 0:
			best_cell_y = maxf(best_cell_y, float(column_y))

	if best_cell_y == -INF:
		return FALLBACK_ROOM_SPAWN_Y

	var floor_top_world_y := _ground_layer.position.y + best_cell_y * TILE_SIZE
	# Keep the player slightly above the floor to avoid immediate clipping.
	return floor_top_world_y - 20.0


func _find_lowest_solid_cell_y(local_x: int) -> int:
	if _ground_layer == null:
		return -1

	var found := false
	var lowest_y := -1

	for cell in _ground_layer.get_used_cells():
		if cell.x != local_x:
			continue
		if not found or cell.y > lowest_y:
			lowest_y = cell.y
			found = true

	if found:
		return lowest_y

	return -1
