extends RefCounted

# A Room's Caches: what each holds, what it is drawn from, and that it rests on a floor.

const TILE := 16
const CRATE_SHEET := "res://assets/world/crate.png"
const CHEST_SHEET := "res://assets/packs/underwater/sunken_treasures.png"


# The Cache holds count of kind under its id, drawn from the sheet.
static func holds(cache: Node, id: StringName, kind: StringName, count: int, sheet: String) -> bool:
	if cache == null:
		return false
	var valid: bool = cache.get("cache_id") == id and cache.get("kind") == kind
	valid = valid and cache.get("count") == count
	var sprite := cache.get_node("Sprite2D") as Sprite2D
	return valid and sprite.texture.resource_path == sheet


# It stands on a Terrain cell with open air above, on the given row.
static func on_floor(terrain: TileMapLayer, cache: Node2D, row: int) -> bool:
	var below := Vector2i(cache.position / TILE)
	var valid := terrain.get_cell_source_id(below) != -1 and below.y == row
	return valid and terrain.get_cell_source_id(below + Vector2i.UP) == -1
