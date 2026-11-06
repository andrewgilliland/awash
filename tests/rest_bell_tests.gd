extends RefCounted

# Tidefen's bell, its Rest point: rung with Interact, it rests the Player (full Health, every
# Sub Weapon owned refilled, RESTED) with a toll, and a defeat wakes the Player beside it.

const BELL_PATH := "res://scenes/world/rest_bell.tscn"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TIDEFEN_PATH := "res://scenes/rooms/tidefen_village_1.tscn"
const SubWeapons := preload("res://scripts/items/sub_weapons.gd")
const BOMB := &"bomb"
# The bell's tile spans these x, standing on the square's sand.
const BELL_WEST := 528.0
const BELL_EAST := 544.0
const SAND_Y := 112.0

# Needs a root that is already in the tree: the Player and the bell read the Run.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Ringing the bell rests the Player: full Health, Bombs refilled", _test_rests],
		["Ringing the bell tolls and shows RESTED", _test_tolls],
		["Ringing the bell makes it the Run's Rest point", _test_rest_point],
		["Tidefen's bell is rung where it stands, with an Entry at its foot", _test_in_tidefen],
	]


func _test_rests() -> bool:
	var player := _player()
	var bell := _bell()
	if bell == null:
		player.free()
		return false
	var health = player.get("health")
	health.current = 10
	player.call("collect_sub_weapon", BOMB)
	_ring(bell, player)
	var valid: bool = health.current == health.maximum
	valid = valid and player.get("sub_weapons").count(BOMB) == SubWeapons.CARRY_LIMIT
	var run := _root.get_node("RunState")
	valid = valid and run.get("player_health") == health.maximum
	valid = valid and run.get("player_sub_weapon_counts").get(BOMB) == SubWeapons.CARRY_LIMIT
	_close(player, bell)
	return valid


func _test_tolls() -> bool:
	var player := _player()
	var bell := _bell()
	if bell == null:
		player.free()
		return false
	_ring(bell, player)
	var toll := bell.get_node_or_null("Sounds/Toll") as AudioStreamPlayer
	var valid := toll != null and toll.stream != null and toll.playing
	valid = valid and (player.get_node("LevelUp") as Label).text == "RESTED"
	_close(player, bell)
	return valid


func _test_rest_point() -> bool:
	var player := _player()
	var bell := _bell()
	if bell == null:
		player.free()
		return false
	var run := _root.get_node("RunState")
	_ring(bell, player)
	run.call("enter_room", &"waking_coast_2", &"west")
	run.call("recover_from_defeat")
	var valid: bool = run.get("room_id") == &"tidefen_village_1"
	valid = valid and run.get("entry_id") == &"bell"
	_close(player, bell)
	return valid


func _test_in_tidefen() -> bool:
	var room := (load(TIDEFEN_PATH) as PackedScene).instantiate()
	var bell := room.get_node_or_null("RestBell") as Node2D
	var entry := room.get_node_or_null("Entries/bell") as Node2D
	var valid := bell != null and bell.scene_file_path == BELL_PATH and entry != null
	if valid:
		valid = bell.position.x >= BELL_WEST and bell.position.x <= BELL_EAST
		valid = valid and is_equal_approx(bell.position.y, SAND_Y)
		valid = valid and bell.get("entry_id") == &"bell"
		valid = valid and absf(entry.position.x - bell.position.x) <= 16.0
		valid = valid and is_equal_approx(entry.position.y, SAND_Y)
	room.free()
	return valid


# A Player in Tidefen, by the bell.
func _player() -> CharacterBody2D:
	var run := _root.get_node("RunState")
	run.call("start_run")
	run.call("enter_room", &"tidefen_village_1", &"west")
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	_root.add_child(player)
	return player


func _bell() -> Node2D:
	if not ResourceLoader.exists(BELL_PATH):
		return null
	var bell := (load(BELL_PATH) as PackedScene).instantiate() as Node2D
	_root.add_child(bell)
	return bell


func _ring(bell: Node, player: Node) -> void:
	bell.get_node("Interactable").call("use", player)


func _close(player: Node, bell: Node) -> void:
	bell.free()
	player.free()
	_root.get_node("RunState").call("start_run")
