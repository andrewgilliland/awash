extends RefCounted

const COUNT_SCENE := preload("res://scenes/ui/sub_weapon_count.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const FIRST_ROOM_SCENE := preload("res://scenes/rooms/waking_coast_1.tscn")
const BOMB := &"bomb"
const BOMB_ICON := "res://assets/items/bomb.png"
const FRAME := 1.0 / 60.0
# Where the Health bar ends: the count sits just below it.
const BAR_BOTTOM := 11.0

# Needs a root that is already in the tree: the count finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["The Sub Weapon count hides with no Player or no Sub Weapon held", _test_hides],
		["The Sub Weapon count shows the held one's icon and how many", _test_shows_count],
		["The Sub Weapon count sits under the Health bar, top-left", _test_under_bar],
		["Every Room puts the Sub Weapon count under its Pause menu", _test_room_has_count],
	]


func _test_hides() -> bool:
	var count := _count()
	count.call("_process", FRAME)
	var valid := not count.visible
	_root.get_node("RunState").call("start_run")
	var player := PLAYER_SCENE.instantiate()
	_root.add_child(player)
	count.call("_process", FRAME)
	valid = valid and not count.visible
	player.call("collect_sub_weapon", BOMB)
	player.call("hold_sub_weapon", &"")
	count.call("_process", FRAME)
	valid = valid and not count.visible
	player.free()
	count.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _test_shows_count() -> bool:
	_root.get_node("RunState").call("start_run")
	var player := PLAYER_SCENE.instantiate()
	_root.add_child(player)
	for i in 5:
		player.call("collect_sub_weapon", BOMB)
	var count := _count()
	count.call("_process", FRAME)
	var icon := count.get_node_or_null("Icon") as TextureRect
	var label := count.get_node_or_null("Count") as Label
	var valid := count.visible and icon != null and label != null
	if valid:
		valid = icon.texture.resource_path == BOMB_ICON and label.text == "5"
		player.get("sub_weapons").spend(BOMB)
		count.call("_process", FRAME)
		valid = valid and label.text == "4"
	player.free()
	count.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _test_under_bar() -> bool:
	var count := _count()
	var valid := count.position.x <= 8.0 and count.position.y >= BAR_BOTTOM
	valid = valid and count.position.y <= BAR_BOTTOM + 4.0
	count.free()
	return valid


func _test_room_has_count() -> bool:
	var room := FIRST_ROOM_SCENE.instantiate()
	_root.add_child(room)
	var canvas := room.get_node("CanvasLayer")
	var count := canvas.get_node_or_null("SubWeaponCount")
	var menu := canvas.get_node_or_null("PauseMenu")
	var valid := count != null and menu != null and count.get_index() < menu.get_index()
	room.free()
	_root.get_tree().paused = false
	return valid


func _count() -> Control:
	var count := COUNT_SCENE.instantiate() as Control
	_root.add_child(count)
	return count
