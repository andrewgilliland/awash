extends RefCounted

# Every Room: its scene, and where it sits on the Map in screens (its top-left cell and size),
# with its region.
const ROOMS := {
	&"waking_coast_1":
	{
		scene = "res://scenes/rooms/waking_coast_1.tscn",
		cell = Vector2i(0, 0),
		size = Vector2i(1, 1),
		region = "Waking Coast",
	},
	&"waking_coast_2":
	{
		scene = "res://scenes/rooms/waking_coast_2.tscn",
		cell = Vector2i(1, 0),
		size = Vector2i(2, 1),
		region = "Waking Coast",
	},
}
const SCREEN_SIZE := Vector2(160, 144)
# One screen on the Map, keeping the screen's shape.
const CELL_SIZE := Vector2(20, 18)


# Lays out the Map around the current Room: blocks for the visited Rooms, the current Room's
# block, the Player's dot and the region name. Empty when the current Room is not on the Map.
static func layout(
	rooms: Dictionary,
	current_id: StringName,
	visited_ids: Array,
	player_position: Vector2,
	view_size: Vector2
) -> Dictionary:
	if not rooms.has(current_id):
		return {}

	var current: Dictionary = rooms[current_id]
	var current_centre := (Vector2(current.cell) + Vector2(current.size) / 2.0) * CELL_SIZE
	var offset := (view_size / 2.0 - current_centre).floor()
	var blocks: Array[Rect2] = []
	for room_id in rooms:
		if room_id == current_id or room_id in visited_ids:
			blocks.append(_block(rooms[room_id], offset))

	var current_block := _block(current, offset)
	var dot := current_block.position + (player_position / SCREEN_SIZE * CELL_SIZE).floor()
	return {blocks = blocks, current = current_block, dot = dot, region = current.region}


static func _block(room: Dictionary, offset: Vector2) -> Rect2:
	return Rect2(offset + Vector2(room.cell) * CELL_SIZE, Vector2(room.size) * CELL_SIZE)
