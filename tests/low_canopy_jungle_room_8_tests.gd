extends RefCounted

# The root's mouth: where the root hollow's foot opens east into daylight above Smuggler Inlet. Its
# west screen steps down out of the root; its east screen is Rusk's arena, flat from edge to edge,
# where his branded roots shut the Player in with him until he is beaten.

const ROOM_ID := &"low_canopy_jungle_8"
const ROOM_PATH := "res://scenes/rooms/low_canopy_jungle_8.tscn"
const Checks := preload("res://tests/jungle_room_checks.gd")
const World := preload("res://scripts/core/world.gd")
const MusicScript := preload("res://scripts/core/music.gd")
const RUSK_SCENE := "res://scenes/enemies/rusk.tscn"
const RUSK_THEME := "res://assets/enemies/rusk/rusk_theme.wav"
const JUNGLE_THEME := "res://assets/regions/low_canopy_jungle/music/theme.wav"
const RUSK_ID := &"rusk_jungle"
const ROOM_CELLS := Vector2i(20, 9)
const TILE := 16
# Level with the hollow's foot; and the arena's floor, a step down.
const WEST_ENTRY := Vector2(12, 96)
const ARENA_FLOOR := 112.0
const ARENA := Vector2(160, 320)
const RUSK_POST := Vector2(280, 112)
const ROOTS_X := Vector2(164, 316)

# Needs a root that is already in the tree: the arena reads the Run, and plays music, in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["The root's mouth lays out two screens, its arena flat edge to edge", _test_two_screens],
		["The root's mouth's west Entry stands level with the hollow's foot", _test_west],
		["From the root the Player walks down into the arena, and back", _test_reaches],
		["Rusk stands at his post on the arena's east side, his roots down", _test_rusk],
		["The root's mouth is walled east, toward Smuggler Inlet", _test_walls],
		["As Rusk speaks, the camera holds on the arena and the theme falls silent", _test_woke],
		["As his roots rise, the arena shuts and his theme plays", _test_shuts],
		["Beaten, Rusk is remembered; as he leaps, the roots wither and all lets go", _test_opens],
		["With Rusk beaten this Run, the root's mouth opens without him", _test_beaten_stays_gone],
	]


func _test_two_screens() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var valid := terrain.get_used_rect().end == ROOM_CELLS
	var floor_row := int(ARENA_FLOOR) / TILE
	for column in range(int(ARENA.x) / TILE, ROOM_CELLS.x):
		valid = valid and terrain.get_cell_source_id(Vector2i(column, floor_row)) != -1
		for row in range(floor_row):
			valid = valid and terrain.get_cell_source_id(Vector2i(column, row)) == -1
	room.free()
	return valid


func _test_west() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var valid := Checks.entry_leads(room, &"west", WEST_ENTRY, &"low_canopy_jungle_7", &"east")
	room.free()
	return valid


func _test_reaches() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var arena := Vector2(ARENA.x + 48.0, ARENA_FLOOR)
	var valid := Checks.reaches(room, WEST_ENTRY, arena) and Checks.reaches(room, arena, WEST_ENTRY)
	room.free()
	return valid


func _test_rusk() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var rusk := room.get_node_or_null("Rusk") as Node2D
	var valid := rusk != null and rusk.scene_file_path == RUSK_SCENE
	valid = valid and rusk.position == RUSK_POST
	var index := 0
	for name in ["Arena/RootsWest", "Arena/RootsEast"]:
		var roots := room.get_node_or_null(name) as Node2D
		valid = valid and roots != null
		if valid:
			var x := ROOTS_X.x if index == 0 else ROOTS_X.y
			valid = valid and roots.global_position == Vector2(x, ARENA_FLOOR)
			valid = valid and not roots.call("is_up")
		index += 1
	room.free()
	return valid


func _test_walls() -> bool:
	var room := Checks.load_room(ROOM_PATH)
	if room == null:
		return false
	var east := room.get_node_or_null("Bounds/East") as CollisionShape2D
	var valid := east != null and room.get_node_or_null("Exits/east") == null
	valid = valid and (east.shape as RectangleShape2D).size.y >= World.SCREEN_SIZE.y
	valid = valid and World.background(ROOM_ID) == World.background(&"low_canopy_jungle_1")
	room.free()
	return valid


func _test_woke() -> bool:
	var room := _room()
	var music := _music()
	var camera := room.get_node("Player/Camera2D") as Camera2D
	var valid := _playing(music, JUNGLE_THEME)
	room.get_node("Rusk").emit_signal(&"woke")
	valid = valid and music.current() == null
	valid = valid and camera.limit_left == int(ARENA.x) and camera.limit_right == int(ARENA.y)
	_close(room)
	return valid


func _test_shuts() -> bool:
	var room := _room()
	var music := _music()
	var camera := room.get_node("Player/Camera2D") as Camera2D
	room.get_node("Rusk").emit_signal(&"woke")
	room.get_node("Rusk").emit_signal(&"fight_began")
	var valid: bool = room.get_node("Arena/RootsWest").call("is_up")
	valid = valid and room.get_node("Arena/RootsEast").call("is_up")
	valid = valid and camera.limit_left == int(ARENA.x) and camera.limit_right == int(ARENA.y)
	valid = valid and _playing(music, RUSK_THEME)
	_close(room)
	return valid


func _test_opens() -> bool:
	var room := _room()
	var music := _music()
	var run := _root.get_node("RunState")
	var rusk := room.get_node("Rusk")
	var camera := room.get_node("Player/Camera2D") as Camera2D
	rusk.emit_signal(&"woke")
	rusk.emit_signal(&"fight_began")
	rusk.emit_signal(&"defeated", 150)
	var valid: bool = run.call("has_defeated_boss", RUSK_ID)
	valid = valid and room.get_node("Player").get("level").experience == 150
	rusk.emit_signal(&"retreated")
	for name in ["Arena/RootsWest", "Arena/RootsEast"]:
		var roots := room.get_node(name)
		roots.call("_process", 2.0)
		valid = valid and not roots.call("is_up") and not roots.visible
	valid = valid and camera.limit_left == 0 and camera.limit_right == int(ARENA.y)
	valid = valid and _playing(music, JUNGLE_THEME)
	_close(room)
	return valid


func _test_beaten_stays_gone() -> bool:
	_root.get_node("RunState").call("start_run")
	_root.get_node("RunState").call("defeat_boss", RUSK_ID)
	var room := _room(false)
	var rusk := room.get_node_or_null("Rusk")
	var valid := rusk == null or rusk.is_queued_for_deletion()
	valid = valid and not room.get_node("Arena/RootsWest").call("is_up")
	_close(room)
	return valid


func _room(new_run: bool = true) -> Node2D:
	var run := _root.get_node("RunState")
	if new_run:
		run.call("start_run")
	run.call("enter_room", ROOM_ID, &"west")
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as Node2D
	_root.add_child(room)
	return room


func _music() -> MusicScript:
	return _root.get_node("Music") as MusicScript


func _playing(music: MusicScript, path: String) -> bool:
	return music.current() != null and music.current().resource_path == path


func _close(room: Node2D) -> void:
	room.free()
	_music().stop()
	_root.get_node("RunState").call("start_run")
