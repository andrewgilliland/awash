extends RefCounted

# Where combat feel is felt: each enemy flashes and stops play when a blow lands on it, a hurt
# Player stops play and shakes its camera, a Bomb's burst and a crumbling wall shake it, and every
# Room keeps a hit-stop.

const Hitbox := preload("res://scripts/combat/hitbox.gd")
const HIT_STOP_PATH := "res://scripts/combat/hit_stop.gd"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const BOMB_SCENE := preload("res://scenes/items/bomb.tscn")
const WALL_SCENE := preload("res://scenes/world/breakable_wall.tscn")
const FIRST_ROOM := preload("res://scenes/rooms/waking_coast_1.tscn")
const ENEMIES := [
	"res://scenes/enemies/scavenger.tscn",
	"res://scenes/enemies/storm_wisp.tscn",
	"res://scenes/enemies/wraith.tscn",
	"res://scenes/enemies/lurelight.tscn",
]
const FRAME := 1.0 / 60.0
# A Bomb's fuse, and a frame to burst.
const FUSE_FRAMES := 61

# Needs a root that is already in the tree: hit-stop and shake are found through their groups.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["A blow landing on each enemy flashes it and stops play", _test_enemies_struck],
		["A blow glancing off an invulnerable enemy neither flashes nor stops", _test_glance],
		["A hurt Player stops play and shakes its camera", _test_player_hurt],
		["A Bomb's burst shakes the camera", _test_bomb_burst],
		["A Breakable wall crumbling shakes the camera", _test_wall_crumble],
		["Every Room keeps a hit-stop", _test_room_hit_stop],
	]


func _test_enemies_struck() -> bool:
	var stop := _hit_stop()
	if stop == null:
		return false
	var valid := true
	for path in ENEMIES:
		var enemy := _enemy(path)
		var flash := enemy.get_node_or_null("HitFlash")
		var sword := _sword()
		enemy.call("_on_hurtbox_hit", sword)
		valid = valid and flash != null and flash.call("is_flashing")
		valid = valid and stop.call("frames_left") > 0
		stop.call("_exit_tree")
		sword.free()
		enemy.free()
	stop.free()
	return valid


func _test_glance() -> bool:
	var stop := _hit_stop()
	if stop == null:
		return false
	var enemy := _enemy(ENEMIES[0])
	var sword := _sword()
	enemy.call("_on_hurtbox_hit", sword)
	var flash := enemy.get_node_or_null("HitFlash")
	if flash == null:
		sword.free()
		enemy.free()
		stop.free()
		return false
	for i in 6:
		flash.call("_process", FRAME)
	stop.call("_exit_tree")
	enemy.call("_on_hurtbox_hit", sword)
	var valid: bool = not flash.call("is_flashing") and stop.call("frames_left") == 0
	sword.free()
	enemy.free()
	stop.free()
	return valid


func _test_player_hurt() -> bool:
	var stop := _hit_stop()
	if stop == null:
		return false
	var player := PLAYER_SCENE.instantiate()
	_root.add_child(player)
	var shake := player.get_node_or_null("Camera2D/Shake")
	var spear := Hitbox.new()
	player.call("_on_hurtbox_hit", spear)
	var valid: bool = stop.call("frames_left") == 5
	valid = valid and shake != null and shake.call("strength") == 2
	spear.free()
	player.free()
	stop.free()
	return valid


func _test_bomb_burst() -> bool:
	var player := PLAYER_SCENE.instantiate()
	_root.add_child(player)
	var shake := player.get_node_or_null("Camera2D/Shake")
	var bomb := BOMB_SCENE.instantiate()
	bomb.set("position", Vector2(200, 80))
	_root.add_child(bomb)
	for i in FUSE_FRAMES:
		bomb.call("_physics_process", FRAME)
	var valid: bool = shake != null and shake.call("strength") == 3
	bomb.free()
	player.free()
	return valid


func _test_wall_crumble() -> bool:
	var player := PLAYER_SCENE.instantiate()
	_root.add_child(player)
	var shake := player.get_node_or_null("Camera2D/Shake")
	var wall := WALL_SCENE.instantiate()
	wall.set("wall_id", &"test_rock")
	_root.add_child(wall)
	var blast := Hitbox.new()
	blast.blast = true
	wall.get_node("Hurtbox").call("take_hit", blast)
	var valid: bool = shake != null and shake.call("strength") == 2
	blast.free()
	wall.free()
	player.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _test_room_hit_stop() -> bool:
	var room := FIRST_ROOM.instantiate()
	_root.add_child(room)
	var stop := room.get_node_or_null("HitStop")
	var valid := stop != null and stop.get_script() != null
	if valid:
		valid = (stop.get_script() as Script).resource_path == HIT_STOP_PATH
	room.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _enemy(path: String) -> Node2D:
	var enemy := (load(path) as PackedScene).instantiate() as Node2D
	enemy.position = Vector2(100, 100)
	_root.add_child(enemy)
	return enemy


func _sword() -> Hitbox:
	var sword := Hitbox.new()
	sword.damage = 10
	sword.position = Vector2(80, 100)
	return sword


func _hit_stop() -> Node:
	if not ResourceLoader.exists(HIT_STOP_PATH):
		return null
	var stop := Node.new()
	stop.set_script(load(HIT_STOP_PATH))
	_root.add_child(stop)
	return stop
