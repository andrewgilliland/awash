extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const INPUT_SETUP_SCRIPT_PATH := "res://scripts/core/input_setup.gd"
const BOMB := &"bomb"
const BOMB_GROUP := &"bomb"

# Needs a root that is already in the tree: the Player reads the Run from /root in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Player holds the Run's Sub Weapon and carries its Bombs", _test_from_run],
		["Finding Bombs owns and holds them, into the Run, saying GOT BOMBS", _test_collect],
		["Player carries up to 9 Bombs", _test_carries_up_to_nine],
		["Ranged Attack throws the held Bomb into the Room and spends one", _test_throws],
		["Ranged Attack lobs the Bomb the way the Player faces", _test_throws_facing],
		["No Bomb is thrown with none held or carried, or while held still", _test_no_throw],
		["Only one Bomb is out at a time", _test_one_at_a_time],
		["Holding another Sub Weapon, or none, goes into the Run", _test_hold_reaches_run],
	]


func _test_from_run() -> bool:
	var run := _run()
	run.call("start_run")
	run.set("player_sub_weapon", BOMB)
	run.set("player_owned_sub_weapons", [BOMB])
	run.set("player_sub_weapon_counts", {BOMB: 3})
	var player := _player()
	var sub_weapons = player.get("sub_weapons")
	var valid: bool = sub_weapons.held == BOMB and sub_weapons.count(BOMB) == 3
	player.free()
	run.call("start_run")
	return valid


func _test_collect() -> bool:
	_run().call("start_run")
	var player := _player()
	var valid: bool = player.call("collect_sub_weapon", BOMB)
	var sub_weapons = player.get("sub_weapons")
	valid = valid and sub_weapons.held == BOMB and sub_weapons.count(BOMB) == 1
	valid = valid and _run().get("player_sub_weapon") == BOMB
	valid = valid and _run().get("player_owned_sub_weapons") == [BOMB]
	valid = valid and _run().get("player_sub_weapon_counts") == {BOMB: 1}
	valid = valid and _playing(player, &"Pickup")
	var notice := player.get_node("LevelUp") as Label
	valid = valid and notice.visible and notice.text == "GOT BOMBS"
	valid = valid and not player.call("collect_sub_weapon", &"nothing")
	player.free()
	_run().call("start_run")
	return valid


func _test_carries_up_to_nine() -> bool:
	_run().call("start_run")
	var player := _player()
	var valid := true
	for i in 9:
		valid = valid and player.call("collect_sub_weapon", BOMB)
	valid = valid and not player.call("collect_sub_weapon", BOMB)
	valid = valid and _run().get("player_sub_weapon_counts") == {BOMB: 9}
	player.free()
	_run().call("start_run")
	return valid


func _test_throws() -> bool:
	_run().call("start_run")
	var player := _player()
	player.call("collect_sub_weapon", BOMB)
	player.call("collect_sub_weapon", BOMB)
	_press_ranged(player)
	var bombs := _bombs()
	var valid := bombs.size() == 1
	if valid:
		valid = bombs[0].get_parent() == player.get_parent()
	valid = valid and player.get("sub_weapons").count(BOMB) == 1
	valid = valid and _run().get("player_sub_weapon_counts") == {BOMB: 1}
	valid = valid and _playing(player, &"Throw")
	_clear_bombs()
	player.free()
	_run().call("start_run")
	return valid


func _test_throws_facing() -> bool:
	_run().call("start_run")
	var valid := true
	for facing in [-1.0, 1.0]:
		var player := _player()
		player.get("controller").facing = facing
		player.call("collect_sub_weapon", BOMB)
		var thrown: Node2D = player.call("throw_sub_weapon")
		valid = valid and thrown != null and thrown.get("facing") == facing
		valid = valid and signf(thrown.global_position.x - player.global_position.x) == facing
		_clear_bombs()
		player.free()
		_run().call("start_run")
	return valid


func _test_no_throw() -> bool:
	_run().call("start_run")
	var player := _player()
	# None owned.
	var valid: bool = player.call("throw_sub_weapon") == null
	player.call("collect_sub_weapon", BOMB)
	player.call("hold_sub_weapon", &"")
	valid = valid and player.call("throw_sub_weapon") == null
	player.call("hold_sub_weapon", BOMB)
	player.set("controls_locked", true)
	valid = valid and player.call("throw_sub_weapon") == null
	player.set("controls_locked", false)
	player.get("sub_weapons").spend(BOMB)
	valid = valid and player.call("throw_sub_weapon") == null and _bombs().is_empty()
	player.free()
	_run().call("start_run")
	return valid


func _test_one_at_a_time() -> bool:
	_run().call("start_run")
	var player := _player()
	player.call("collect_sub_weapon", BOMB)
	player.call("collect_sub_weapon", BOMB)
	var first: Node2D = player.call("throw_sub_weapon")
	var valid: bool = first != null and player.call("throw_sub_weapon") == null
	valid = valid and player.get("sub_weapons").count(BOMB) == 1
	first.free()
	valid = valid and player.call("throw_sub_weapon") != null
	_clear_bombs()
	player.free()
	_run().call("start_run")
	return valid


func _test_hold_reaches_run() -> bool:
	_run().call("start_run")
	var player := _player()
	var valid: bool = not player.call("hold_sub_weapon", BOMB)
	player.call("collect_sub_weapon", BOMB)
	valid = valid and player.call("hold_sub_weapon", &"")
	valid = valid and _run().get("player_sub_weapon") == &""
	valid = valid and player.call("hold_sub_weapon", BOMB)
	valid = valid and _run().get("player_sub_weapon") == BOMB
	player.free()
	_run().call("start_run")
	return valid


func _run() -> Node:
	return _root.get_node("RunState")


func _player() -> CharacterBody2D:
	var input_setup := (load(INPUT_SETUP_SCRIPT_PATH) as GDScript).new() as Node
	input_setup.call("_register_inputs")
	input_setup.free()
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = Vector2(100, 80)
	_root.add_child(player)
	return player


# A press and release of Ranged Attack, as a key or button sends it, between two physics steps.
func _press_ranged(player: Node) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = &"ranged_attack"
		event.pressed = pressed
		player.get_viewport().push_input(event)


func _bombs() -> Array[Node]:
	return _root.get_tree().get_nodes_in_group(BOMB_GROUP)


func _clear_bombs() -> void:
	for bomb in _bombs():
		bomb.free()


func _playing(player: Node, sound: StringName) -> bool:
	var stream_player := player.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer
	return stream_player != null and stream_player.playing
