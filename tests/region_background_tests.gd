extends RefCounted

const World := preload("res://scripts/core/world.gd")
const BACKGROUND := "res://scenes/regions/waking_coast/background.tscn"
const CAVE_BACKGROUND := "res://scenes/regions/waking_coast/cave_background.tscn"
const CAVE_ROOMS: Array[StringName] = [&"waking_coast_5", &"waking_coast_9"]
# The Waking Coast's layers, back to front, and how fast each scrolls with the camera: the sky and
# the sun fixed to the screen, as if infinitely far; the haze rides with the sea, on its horizon.
const LAYERS := {
	Sky = 0.0, Haze = 0.3, Sun = 0.0, FarClouds = 0.1, NearClouds = 0.2, Ships = 0.3, Sea = 0.3
}
const CAVE_LAYERS := {Wall = 0.3, Glints = 0.6}
# The clouds and ships repeat every three screens, so the sky doesn't look stamped.
const WIDE_LAYERS: Array[StringName] = [&"FarClouds", &"NearClouds", &"Ships"]
const WIDE_REPEAT := 480.0
# How far an Exit's edge may sit from the Entry it leads to, across the crossing, in the world.
const SEAM_TOLERANCE := 24.0
# A daytime sky over the sea, from the top of a screen down: sky, the horizon, then sea; the
# pack's sky blue from its background sheet, and its water.
const SKY := Vector2i(8, 1)
const HORIZON := Vector2i(2, 2)
const SEA := Vector2i(1, 2)
const HORIZON_ROW := 5
const SCREEN_CELLS := Vector2i(10, 9)
# The pale haze, flipped so it is palest on the horizon and fades up into the sky.
const HAZE := {2: Vector2i(12, 3), 3: Vector2i(12, 2), 4: Vector2i(12, 1)}
const FLIP_V := TileSetAtlasSource.TRANSFORM_FLIP_V
# The sun (2x2), and its beams (8x4) slanting down from the top-left of the screen.
const SUN := {
	Vector2i(3, 2): Vector2i(6, 1),
	Vector2i(4, 2): Vector2i(7, 1),
	Vector2i(3, 3): Vector2i(6, 2),
	Vector2i(4, 3): Vector2i(7, 2),
}
const BEAMS := Rect2i(1, 12, 8, 4)
# The two clouds, by every tile drawn in them: a long low one, and a tall one.
const LONG_CLOUD: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)
]
const TALL_CLOUD: Array[Vector2i] = [
	Vector2i(3, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)
]
# The rowing boat and the sailing ship (two tiles), far off on the horizon.
const BOAT: Array[Vector2i] = [Vector2i(6, 3)]
const SHIP: Array[Vector2i] = [Vector2i(7, 3), Vector2i(8, 3)]
const WIDE_CELLS := 30

# Needs a root that is already in the tree: a Room sets its Background up in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["The Waking Coast's layers each scroll slower the farther back", _test_layers],
		["The cave Background is a rock wall with glints before it", _test_cave_layers],
		["The Waking Coast's Background is a daytime tropical shore", _test_daytime_shore],
		["The sun and its beams hang in the Waking Coast's sky", _test_sun],
		["Clouds near and far fill three screens, the far ones lower", _test_clouds],
		["A rowing boat and a sailing ship sail the horizon", _test_ships],
		["The caves show the cave Background; the rest of the coast its sky and sea", _test_caves],
		["A Background sets its layers by the place it is told", _test_told_place],
		["A Room sets its Background by where it sits in the world", _test_offsets],
		["Every Exit meets its Entry in the world, so Backgrounds carry on", _test_seams],
	]


func _test_layers() -> bool:
	return _has_layers(BACKGROUND, LAYERS, true)


func _test_cave_layers() -> bool:
	return _has_layers(CAVE_BACKGROUND, CAVE_LAYERS, false)


func _test_daytime_shore() -> bool:
	var background := (load(BACKGROUND) as PackedScene).instantiate()
	var sky := background.get_node("Sky/Tiles") as TileMapLayer
	var sea := background.get_node("Sea/Tiles") as TileMapLayer
	var haze := background.get_node("Haze/Tiles") as TileMapLayer
	var valid := true
	for row in range(SCREEN_CELLS.y):
		for column in range(SCREEN_CELLS.x):
			var cell := Vector2i(column, row)
			if row < HORIZON_ROW:
				valid = valid and sky.get_cell_atlas_coords(cell) == SKY
			elif row == HORIZON_ROW:
				valid = valid and sea.get_cell_atlas_coords(cell) == HORIZON
			else:
				valid = valid and sea.get_cell_atlas_coords(cell) == SEA
	# The sky reaches up past the top of the screen, and down behind the sea, so the two never
	# part as the camera climbs; the sea reaches down past the foot of the screen.
	valid = valid and sky.get_cell_atlas_coords(Vector2i(0, -2)) == SKY
	valid = valid and sky.get_cell_atlas_coords(Vector2i(0, SCREEN_CELLS.y + 4)) == SKY
	valid = valid and sea.get_cell_atlas_coords(Vector2i(0, SCREEN_CELLS.y + 4)) == SEA
	for column in range(SCREEN_CELLS.x):
		for row: int in HAZE:
			var cell := Vector2i(column, row)
			valid = valid and haze.get_cell_atlas_coords(cell) == HAZE[row]
			valid = valid and haze.get_cell_alternative_tile(cell) == FLIP_V
	background.free()
	return valid


func _test_sun() -> bool:
	var background := (load(BACKGROUND) as PackedScene).instantiate()
	var sun := background.get_node("Sun/Tiles") as TileMapLayer
	var beams := background.get_node("Sun/Beams") as TileMapLayer
	var valid := true
	for cell: Vector2i in SUN:
		valid = valid and sun.get_cell_atlas_coords(cell) == SUN[cell]
	var drawn := 0
	for cell in beams.get_used_cells():
		var tile := beams.get_cell_atlas_coords(cell)
		valid = valid and BEAMS.has_point(tile) and tile - BEAMS.position == cell
		drawn += 1
	valid = valid and drawn > 0
	background.free()
	return valid


func _test_clouds() -> bool:
	var background := (load(BACKGROUND) as PackedScene).instantiate()
	var far := background.get_node("FarClouds/Tiles") as TileMapLayer
	var near := background.get_node("NearClouds/Tiles") as TileMapLayer
	var shapes := {}
	var far_top := HORIZON_ROW
	var near_bottom := -1
	var valid := true
	for layer in [far, near]:
		for cell in (layer as TileMapLayer).get_used_cells():
			var tile := (layer as TileMapLayer).get_cell_atlas_coords(cell)
			valid = valid and (LONG_CLOUD.has(tile) or TALL_CLOUD.has(tile))
			valid = valid and cell.x >= 0 and cell.x < WIDE_CELLS and cell.y < HORIZON_ROW
			shapes[LONG_CLOUD.has(tile)] = true
			if layer == far:
				far_top = mini(far_top, cell.y)
			else:
				near_bottom = maxi(near_bottom, cell.y)
	valid = valid and shapes.size() == 2 and near_bottom >= 0 and far_top > near_bottom
	background.free()
	return valid


func _test_ships() -> bool:
	var background := (load(BACKGROUND) as PackedScene).instantiate()
	var ships := background.get_node("Ships/Tiles") as TileMapLayer
	var drawn: Array[Vector2i] = []
	var valid := true
	for cell in ships.get_used_cells():
		var tile := ships.get_cell_atlas_coords(cell)
		valid = valid and cell.y == HORIZON_ROW - 1 and cell.x >= 0 and cell.x < WIDE_CELLS
		drawn.append(tile)
	drawn.sort()
	var expected: Array[Vector2i] = []
	expected.append_array(BOAT)
	expected.append_array(SHIP)
	valid = valid and drawn == expected
	background.free()
	return valid


func _test_caves() -> bool:
	var valid := true
	for room_id in World.room_ids():
		if World.region(room_id) == &"waking_coast":
			var expected := CAVE_BACKGROUND if CAVE_ROOMS.has(room_id) else BACKGROUND
			if World.background(room_id) != expected:
				push_error("%s shows %s" % [room_id, World.background(room_id)])
				valid = false
	return valid


# Any place will do: the Background knows nothing of the World.
func _test_told_place() -> bool:
	var origin := Vector2(480, -144)
	var background := (load(BACKGROUND) as PackedScene).instantiate()
	background.set("room_origin", origin)
	_root.add_child(background)
	var valid := true
	for layer in background.get_children():
		if layer is Parallax2D:
			var expected: Vector2 = -origin * (layer as Parallax2D).scroll_scale
			valid = valid and (layer as Parallax2D).scroll_offset.is_equal_approx(expected)
	background.free()
	return valid


func _test_offsets() -> bool:
	var valid := true
	for room_id: StringName in [&"waking_coast_1", &"waking_coast_3", &"waking_coast_9"]:
		var room := _enter(room_id)
		var origin := _origin(room_id)
		for layer in room.get_node("Background").get_children():
			if layer is Parallax2D:
				var expected: Vector2 = -origin * (layer as Parallax2D).scroll_scale
				valid = valid and (layer as Parallax2D).scroll_offset.is_equal_approx(expected)
		room.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _test_seams() -> bool:
	var valid := true
	for room_id in World.room_ids():
		var room := (load(World.scene(room_id)) as PackedScene).instantiate()
		var size := Vector2(World.size(room_id)) * World.SCREEN_SIZE
		for exit in room.get_node("Exits").get_children():
			var to: StringName = exit.get("room_id")
			var there := (load(World.scene(to)) as PackedScene).instantiate()
			var entry := there.get_node("Entries/%s" % exit.get("entry_id")) as Node2D
			var from_world := _origin(room_id) + (exit as Node2D).position
			var to_world := _origin(to) + entry.position
			# Across a side Exit only x must meet; across a top or bottom one, only y.
			var side := (exit as Node2D).position.x < 0.0 or (exit as Node2D).position.x > size.x
			var gap := absf(from_world.x - to_world.x) if side else absf(from_world.y - to_world.y)
			if gap > SEAM_TOLERANCE:
				push_error("%s/%s is %d px from %s in the world" % [room_id, exit.name, gap, to])
				valid = false
			there.free()
		room.free()
	return valid


func _has_layers(path: String, layers: Dictionary, drifts: bool) -> bool:
	var background := (load(path) as PackedScene).instantiate()
	var names: Array = []
	var valid := true
	for layer in background.get_children():
		if layer is Parallax2D:
			var parallax := layer as Parallax2D
			names.append(parallax.name)
			var speed: float = layers.get(parallax.name, -1.0)
			valid = valid and parallax.scroll_scale.is_equal_approx(Vector2(speed, speed))
			var wide := WIDE_LAYERS.has(parallax.name)
			valid = (
				valid and parallax.repeat_size.x == (WIDE_REPEAT if wide else World.SCREEN_SIZE.x)
			)
			valid = valid and parallax.get_child_count() > 0
	valid = valid and names == layers.keys()
	if drifts:
		# The near clouds drift west on the wind; the ships sail east, the way their bows point.
		valid = valid and (background.get_node("NearClouds") as Parallax2D).autoscroll.x < 0.0
		valid = valid and (background.get_node("Ships") as Parallax2D).autoscroll.x > 0.0
	background.free()
	return valid


func _enter(room_id: StringName) -> Node:
	var run := _root.get_node("RunState")
	run.call("start_run")
	var entries := (load(World.scene(room_id)) as PackedScene).instantiate()
	var entry: String = entries.get_node("Entries").get_child(0).name
	entries.free()
	run.call("enter_room", room_id, StringName(entry))
	var room := (load(World.scene(room_id)) as PackedScene).instantiate()
	_root.add_child(room)
	return room


func _origin(room_id: StringName) -> Vector2:
	return Vector2(World.cell(room_id)) * World.SCREEN_SIZE
