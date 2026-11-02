extends RefCounted

const World := preload("res://scripts/core/world.gd")
const BACKGROUND := "res://scenes/regions/waking_coast/background.tscn"
const CAVE_BACKGROUND := "res://scenes/regions/waking_coast/cave_background.tscn"
const CAVE_ROOMS: Array[StringName] = [&"waking_coast_5", &"waking_coast_9"]
# The Waking Coast's layers, back to front, and how fast each scrolls with the camera.
const LAYERS := {Sky = 0.1, Clouds = 0.2, Sea = 0.6}
const CAVE_LAYERS := {Wall = 0.3, Glints = 0.6}
# How far an Exit's edge may sit from the Entry it leads to, across the crossing, in the world.
const SEAM_TOLERANCE := 24.0
# A daytime sky over the sea, from the top of a screen down: sky, the horizon, then sea; the
# pack's sky blue from its background sheet, and its water.
const SKY := Vector2i(8, 1)
const HORIZON := Vector2i(2, 2)
const SEA := Vector2i(1, 2)
const HORIZON_ROW := 5
const SCREEN_CELLS := Vector2i(10, 9)
# The sun (2x2) and a cloud (left, middle, right), where each screen of clouds holds them.
const CLOUDS := {
	Vector2i(4, 0): Vector2i(6, 1),
	Vector2i(5, 1): Vector2i(7, 2),
	Vector2i(1, 1): Vector2i(3, 1),
	Vector2i(2, 1): Vector2i(4, 1),
	Vector2i(3, 1): Vector2i(5, 1),
}

# Needs a root that is already in the tree: a Room sets its Background up in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["The Waking Coast's layers each scroll slower the farther back", _test_layers],
		["The cave Background is a rock wall with glints before it", _test_cave_layers],
		["The Waking Coast's Background is a daytime tropical shore", _test_daytime_shore],
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
	var clouds := background.get_node("Clouds/Tiles") as TileMapLayer
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
	for cell: Vector2i in CLOUDS:
		valid = valid and clouds.get_cell_atlas_coords(cell) == CLOUDS[cell]
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
			valid = valid and parallax.repeat_size.x == World.SCREEN_SIZE.x
			valid = valid and parallax.get_child_count() > 0
	valid = valid and names == layers.keys()
	if drifts:
		var clouds := background.get_node("Clouds") as Parallax2D
		valid = valid and clouds.autoscroll.x < 0.0
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
