extends RefCounted

# Where a Player can get to in a Room's Terrain, judged from its tiles: the surfaces to stand
# on, and which of them a walk, a single jump or a drop reaches from a starting cell.

const PlayerController := preload("res://scripts/player/player_controller.gd")
const TILE := 16
# How far apart, in tiles, the ends of two surfaces can be for a jump to cross.
const JUMP_GAP := 2


# How many tiles a single jump rises, from the Player's jump and the world's gravity.
static func jump_rows() -> int:
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var jump_speed := -PlayerController.new().jump_velocity
	return int(jump_speed * jump_speed / (2.0 * gravity) / TILE)


# Every run of tiles the Player can stand on: a row, and its first and last column. Tiles
# whose atlas coords are in skip count as empty.
static func surfaces(terrain: TileMapLayer, skip: Array = []) -> Array[Vector3i]:
	var spans: Array[Vector3i] = []
	var rect := terrain.get_used_rect()
	for row in range(rect.position.y, rect.end.y):
		var start := -1
		for column in range(rect.position.x, rect.end.x + 1):
			var standable := (
				_solid(terrain, Vector2i(column, row), skip)
				and not _solid(terrain, Vector2i(column, row - 1), skip)
			)
			if standable and start == -1:
				start = column
			elif not standable and start != -1:
				spans.append(Vector3i(row, start, column - 1))
				start = -1
	return spans


# The surfaces reached from the one under a cell, jumping up at most a jump's rows, or
# dropping down, across gaps of at most JUMP_GAP tiles.
static func reachable(
	terrain: TileMapLayer, from_cell: Vector2i, skip: Array = []
) -> Array[Vector3i]:
	var spans := surfaces(terrain, skip)
	var start: Variant = span_at(spans, from_cell)
	if start == null:
		return []
	var rise := jump_rows()
	var reached: Array[Vector3i] = [start]
	var index := 0
	while index < reached.size():
		var from := reached[index]
		index += 1
		for to in spans:
			if to in reached:
				continue
			var gap := maxi(to.y - from.z, from.y - to.z) - 1
			if gap <= JUMP_GAP and from.x - to.x <= rise:
				reached.append(to)
	return reached


static func span_at(spans: Array[Vector3i], cell: Vector2i) -> Variant:
	for span in spans:
		if span.x == cell.y and cell.x >= span.y and cell.x <= span.z:
			return span
	return null


static func _solid(terrain: TileMapLayer, cell: Vector2i, skip: Array) -> bool:
	return terrain.get_cell_source_id(cell) == 0 and terrain.get_cell_atlas_coords(cell) not in skip
