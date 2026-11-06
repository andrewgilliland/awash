extends RefCounted

# The Undertow's Shortcut home: a cracked wall at the west end of its passage, broken from the
# Undertow side by a Charged Attack, into the sea cave. From the sea cave it is a Breakable wall
# that only a Bomb's blast breaks.

const PASSAGE_PATH := "res://scenes/rooms/undertow_3.tscn"
const SEA_CAVE_PATH := "res://scenes/rooms/waking_coast_5.tscn"
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const SHORTCUT_ID := &"sea_cave_wall"
const WORLD_LAYER := 1
# Where the Player's sword strikes: the layer it looks for hurtboxes on.
const STRUCK_LAYER := 1 << 4
# The passage and the sea cave are each two screens wide; the wall stands at the passage's west
# end, the Breakable wall at the cave's east end.
const ROOM_WIDTH := 320.0
const NEAR_EDGE := 80.0
const TILE := 16.0
const SEA_CAVE_ROCK_ID := &"sea_cave_rock"

# Needs a root that is already in the tree: a Room reads the Run in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["A cracked wall shuts the passage's west end, toward the sea cave", _test_cracked_wall],
		["A quick Attack glances off the wall; a Charged one breaks it", _test_charged_breaks],
		["From the sea cave the Shortcut is a Breakable wall that opens it", _test_rock_side],
		["With the Shortcut open, both its sides open without the wall", _test_stays_open],
	]


func _test_cracked_wall() -> bool:
	var room := _room(PASSAGE_PATH, &"undertow_3", &"east")
	var wall := room.get_node_or_null("ShortcutWall") as StaticBody2D
	var valid := wall != null and wall.collision_layer == WORLD_LAYER and _shut(wall)
	if valid:
		valid = wall.get("shortcut_id") == SHORTCUT_ID
		var hurtbox := wall.get_node_or_null("Hurtbox") as Area2D
		valid = valid and hurtbox != null and hurtbox.collision_layer == STRUCK_LAYER
		valid = valid and _west_edge(wall) <= 0.0 and _east_edge(wall) <= NEAR_EDGE
		var west := room.get_node("Exits/west") as Area2D
		valid = valid and west.get("room_id") == &"waking_coast_5"
	_close(room)
	return valid


func _test_charged_breaks() -> bool:
	var room := _room(PASSAGE_PATH, &"undertow_3", &"east")
	var run := _root.get_node("RunState")
	var wall := room.get_node("ShortcutWall") as StaticBody2D
	var hurtbox := wall.get_node("Hurtbox") as Area2D
	var quick := Hitbox.new()
	hurtbox.call("take_hit", quick)
	var valid: bool = _shut(wall) and not run.call("has_opened_shortcut", SHORTCUT_ID)
	var charged := Hitbox.new()
	charged.charged = true
	hurtbox.call("take_hit", charged)
	valid = valid and not _shut(wall) and run.call("has_opened_shortcut", SHORTCUT_ID)
	quick.free()
	charged.free()
	_close(room)
	return valid


func _test_rock_side() -> bool:
	var room := _room(SEA_CAVE_PATH, &"waking_coast_5", &"north")
	var wall := room.get_node_or_null("BreakableWall") as StaticBody2D
	var valid := wall != null and wall.collision_layer == WORLD_LAYER and wall.visible
	if valid:
		valid = room.get_node_or_null("ShortcutWall") == null
		valid = valid and wall.get("wall_id") == SEA_CAVE_ROCK_ID
		valid = valid and wall.get("shortcut_id") == SHORTCUT_ID
		valid = valid and not wall.call("is_broken")
		var size := Vector2(wall.get("size") as Vector2i) * TILE
		valid = valid and wall.position.x + size.x >= ROOM_WIDTH
		var east := room.get_node("Exits/east") as Area2D
		valid = valid and east.get("room_id") == &"undertow_3"
		valid = valid and east.position.x > wall.position.x + size.x
	_close(room)
	return valid


func _test_stays_open() -> bool:
	_root.get_node("RunState").call("start_run")
	_root.get_node("RunState").call("open_shortcut", SHORTCUT_ID)
	var valid := true
	var passage := _room(PASSAGE_PATH, &"undertow_3", &"west", false)
	valid = valid and not _shut(passage.get_node("ShortcutWall"))
	passage.free()
	var sea_cave := _room(SEA_CAVE_PATH, &"waking_coast_5", &"east", false)
	var rock := sea_cave.get_node_or_null("BreakableWall")
	valid = valid and rock != null and rock.call("is_broken") and not rock.visible
	sea_cave.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _room(path: String, room_id: StringName, entry: StringName, new_run := true) -> Node2D:
	var run := _root.get_node("RunState")
	if new_run:
		run.call("start_run")
	run.call("enter_room", room_id, entry)
	if not ResourceLoader.exists(path):
		return Node2D.new()
	var room := (load(path) as PackedScene).instantiate() as Node2D
	_root.add_child(room)
	return room


# Shut while it stands: seen, and every shape of it blocking or about to stop.
static func _shut(wall: Node) -> bool:
	if not (wall is StaticBody2D) or not (wall as StaticBody2D).visible:
		return false
	var shapes := wall.find_children("*", "CollisionShape2D", false, false)
	return not shapes.is_empty()


static func _west_edge(wall: StaticBody2D) -> float:
	var shape := wall.get_node("Shape") as CollisionShape2D
	var rect := shape.shape as RectangleShape2D
	return wall.position.x + shape.position.x - rect.size.x / 2.0


static func _east_edge(wall: StaticBody2D) -> float:
	var shape := wall.get_node("Shape") as CollisionShape2D
	var rect := shape.shape as RectangleShape2D
	return wall.position.x + shape.position.x + rect.size.x / 2.0


func _close(room: Node) -> void:
	room.free()
	_root.get_node("RunState").call("start_run")
