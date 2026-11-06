extends RefCounted

# A Breakable wall: cracked rock across a way, sized in tiles. Only a Bomb's blast breaks it;
# anything else knocks hollow off it. Once broken the Run remembers, and it stays open.

const WALL_PATH := "res://scenes/world/breakable_wall.tscn"
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const WALL_ID := &"test_rock"
const SHORTCUT_ID := &"test_shortcut"
const TILE := 16.0
const WORLD_LAYER := 1
# Where the Player's sword and a Bomb's blast strike: the layer they look for hurtboxes on.
const STRUCK_LAYER := 1 << 4

# Needs a root that is already in the tree: a wall reads the Run in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		[
			"A Breakable wall blocks the world, sized in tiles, struck where swords strike",
			_test_blocks
		],
		["A quick or a Charged hit knocks hollow off it and leaves it standing", _test_knocks],
		["A Bomb's blast breaks it: it crumbles and the Run remembers", _test_blast_breaks],
		["Breaking a wall across a Shortcut opens the Shortcut", _test_opens_shortcut],
		["A wall broken this Run stands open from the start", _test_stays_broken],
		["A wall across a Shortcut already open stands open from the start", _test_shortcut_open],
	]


func _test_blocks() -> bool:
	var wall := _wall(Vector2i(3, 2))
	if wall == null:
		return false
	var body := wall.get_node_or_null("Shape") as CollisionShape2D
	var hurtbox := wall.get_node_or_null("Hurtbox") as Area2D
	var valid := wall is StaticBody2D and (wall as StaticBody2D).collision_layer == WORLD_LAYER
	valid = valid and body != null and _covers(body, Vector2(3, 2))
	valid = valid and hurtbox != null and hurtbox.collision_layer == STRUCK_LAYER
	if valid:
		valid = _covers(hurtbox.get_node("Shape") as CollisionShape2D, Vector2(3, 2))
	valid = valid and wall.visible and not wall.call("is_broken")
	_close(wall)
	return valid


func _test_knocks() -> bool:
	var wall := _wall(Vector2i(2, 3))
	if wall == null:
		return false
	var run := _root.get_node("RunState")
	var valid := true
	for charged in [false, true]:
		var hit := Hitbox.new()
		hit.charged = charged
		wall.get_node("Hurtbox").call("take_hit", hit)
		hit.free()
		valid = valid and not wall.call("is_broken") and _playing(wall, &"Knock")
		valid = valid and not _playing(wall, &"Crumble")
	valid = valid and not run.call("has_broken_wall", WALL_ID)
	_close(wall)
	return valid


func _test_blast_breaks() -> bool:
	var wall := _wall(Vector2i(2, 3))
	if wall == null:
		return false
	var run := _root.get_node("RunState")
	_blast(wall)
	var valid: bool = wall.call("is_broken") and run.call("has_broken_wall", WALL_ID)
	valid = valid and _playing(wall, &"Crumble") and not _playing(wall, &"Knock")
	var rubble := wall.get_node_or_null("Rubble") as CPUParticles2D
	valid = valid and rubble != null and rubble.emitting and rubble.texture != null
	valid = valid and not run.call("has_opened_shortcut", SHORTCUT_ID)
	_close(wall)
	return valid


func _test_opens_shortcut() -> bool:
	var wall := _wall(Vector2i(2, 3), SHORTCUT_ID)
	if wall == null:
		return false
	_blast(wall)
	var valid: bool = _root.get_node("RunState").call("has_opened_shortcut", SHORTCUT_ID)
	_close(wall)
	return valid


func _test_stays_broken() -> bool:
	_root.get_node("RunState").call("start_run")
	_root.get_node("RunState").call("break_wall", WALL_ID)
	var wall := _wall(Vector2i(2, 3), &"", false)
	if wall == null:
		return false
	var valid: bool = wall.call("is_broken") and not wall.visible
	_close(wall)
	return valid


func _test_shortcut_open() -> bool:
	_root.get_node("RunState").call("start_run")
	_root.get_node("RunState").call("open_shortcut", SHORTCUT_ID)
	var wall := _wall(Vector2i(2, 3), SHORTCUT_ID, false)
	if wall == null:
		return false
	var valid: bool = wall.call("is_broken") and not wall.visible
	_close(wall)
	return valid


func _wall(size: Vector2i, shortcut_id := &"", new_run := true) -> Node2D:
	if new_run:
		_root.get_node("RunState").call("start_run")
	if not ResourceLoader.exists(WALL_PATH):
		return null
	var wall := (load(WALL_PATH) as PackedScene).instantiate() as Node2D
	wall.set("wall_id", WALL_ID)
	wall.set("shortcut_id", shortcut_id)
	wall.set("size", size)
	_root.add_child(wall)
	return wall


func _blast(wall: Node) -> void:
	var blast := Hitbox.new()
	blast.charged = true
	blast.blast = true
	wall.get_node("Hurtbox").call("take_hit", blast)
	blast.free()


# A shape covering the tiles down and right of the wall's corner.
static func _covers(shape: CollisionShape2D, tiles: Vector2) -> bool:
	var rect := shape.shape as RectangleShape2D if shape != null else null
	if rect == null:
		return false
	var size := tiles * TILE
	return rect.size.is_equal_approx(size) and shape.position.is_equal_approx(size / 2.0)


static func _playing(wall: Node, sound: StringName) -> bool:
	var stream_player := wall.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer
	return stream_player != null and stream_player.stream != null and stream_player.playing


func _close(wall: Node) -> void:
	wall.free()
	_root.get_node("RunState").call("start_run")
