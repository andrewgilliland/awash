extends RefCounted

# Gold: what the Player earns for each enemy defeated and spends at the Supply Shop. The Run
# carries it, a defeat keeps it, and it shows under the Health bar and on the Stats Panel.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PALM_SHORE_SCENE := preload("res://scenes/rooms/waking_coast_2.tscn")
const FIRST_ROOM_SCENE := preload("res://scenes/rooms/waking_coast_1.tscn")
const COUNT_PATH := "res://scenes/ui/gold_count.tscn"
const GOLD_ICON := "res://assets/ui/gold.png"
const FRAME := 1.0 / 60.0
# Each enemy kind and the Gold its defeat is worth.
const WORTH := [
	["res://scenes/enemies/scavenger.tscn", 2],
	["res://scenes/enemies/storm_wisp.tscn", 3],
	["res://scenes/enemies/lurelight.tscn", 3],
	["res://scenes/enemies/wraith.tscn", 5],
	["res://scenes/enemies/nameless_warden.tscn", 30],
]
# Where the Sub Weapon count ends: the Gold count sits just below it.
const SUB_WEAPON_BOTTOM := 21.0

# Needs a root that is already in the tree: the Player reads the Run in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Each enemy kind is worth its own Gold", _test_worth],
		["The Player gains Gold, and the Run carries it", _test_gains],
		["A Room hands an enemy's Gold to the Player", _test_room_hands_gold],
		["The Gold count shows a coin and the Player's Gold", _test_count_shows],
		["The Gold count hides with no Player, under the Sub Weapon count", _test_count_place],
		["Every Room puts the Gold count under its Pause menu", _test_room_has_count],
	]


func _test_worth() -> bool:
	var valid := true
	for spec in WORTH:
		var enemy := (load(spec[0]) as PackedScene).instantiate()
		valid = valid and _gold(enemy) == spec[1]
		enemy.free()
	return valid


func _test_gains() -> bool:
	var run := _root.get_node("RunState")
	run.call("start_run")
	var player := PLAYER_SCENE.instantiate()
	_root.add_child(player)
	var valid: bool = player.get("gold") == 0
	player.call("gain_gold", 5)
	player.call("gain_gold", 3)
	valid = valid and player.get("gold") == 8 and run.get("player_gold") == 8
	player.free()
	var next := PLAYER_SCENE.instantiate()
	_root.add_child(next)
	valid = valid and next.get("gold") == 8
	next.free()
	run.call("start_run")
	return valid


func _test_room_hands_gold() -> bool:
	var run := _root.get_node("RunState")
	run.call("start_run")
	run.call("enter_room", &"waking_coast_2", &"west")
	var room := PALM_SHORE_SCENE.instantiate()
	_root.add_child(room)
	var scavenger := room.get_node("Enemies/Scavenger")
	scavenger.emit_signal(&"defeated", 10)
	var player := room.get_node("Player")
	var valid: bool = player.get("gold") == _gold(scavenger) and _gold(scavenger) > 0
	room.free()
	run.call("start_run")
	return valid


func _test_count_shows() -> bool:
	var count := _count()
	if count == null:
		return false
	_root.get_node("RunState").call("start_run")
	var player := PLAYER_SCENE.instantiate()
	_root.add_child(player)
	player.call("gain_gold", 12)
	count.call("_process", FRAME)
	var icon := count.get_node_or_null("Icon") as TextureRect
	var label := count.get_node_or_null("Count") as Label
	var valid := count.visible and icon != null and label != null
	if valid:
		valid = icon.texture.resource_path == GOLD_ICON and label.text == "12"
	player.free()
	count.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _test_count_place() -> bool:
	var count := _count()
	if count == null:
		return false
	count.call("_process", FRAME)
	var valid := not count.visible
	valid = valid and count.position.x <= 8.0 and count.position.y >= SUB_WEAPON_BOTTOM
	valid = valid and count.position.y <= SUB_WEAPON_BOTTOM + 4.0
	count.free()
	return valid


func _test_room_has_count() -> bool:
	var room := FIRST_ROOM_SCENE.instantiate()
	_root.add_child(room)
	var canvas := room.get_node("CanvasLayer")
	var count := canvas.get_node_or_null("GoldCount")
	var menu := canvas.get_node_or_null("PauseMenu")
	var valid := count != null and menu != null and count.get_index() < menu.get_index()
	room.free()
	_root.get_tree().paused = false
	_root.get_node("RunState").call("start_run")
	return valid


func _count() -> Control:
	if not ResourceLoader.exists(COUNT_PATH):
		return null
	var count := (load(COUNT_PATH) as PackedScene).instantiate() as Control
	_root.add_child(count)
	return count


static func _gold(enemy: Node) -> int:
	return enemy.get_script().get_script_constant_map().get("GOLD", -1)
