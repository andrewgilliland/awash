extends RefCounted

# The Player taking Armor up: owned, put on at once and into the Run, with a sound and a notice;
# and room for Armor not owned yet, none for Armor owned already.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const INPUT_SETUP_SCRIPT_PATH := "res://scripts/core/input_setup.gd"
const TUNIC := &"worn_leather_tunic"
const SCALE_MAIL := &"scale_mail"

# Needs a root that is already in the tree: the Player reads the Run from /root in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Collecting Armor owns and wears it, into the Run, with a sound", _test_collect],
		["Armor owned already is not collected again", _test_collect_owned],
		["There is room for Armor not owned yet, and none for Armor owned", _test_room],
	]


func _test_collect() -> bool:
	_run().call("start_run")
	var player := _player()
	var collected: bool = player.call("collect_armor", SCALE_MAIL)
	var valid: bool = collected and player.get("equipment").armor == SCALE_MAIL
	valid = valid and _run().get("player_armor") == SCALE_MAIL
	valid = valid and _run().get("player_owned_armor") == [TUNIC, SCALE_MAIL]
	var sound := player.get_node_or_null("Sounds/Pickup") as AudioStreamPlayer
	valid = valid and sound != null and sound.playing
	var notice := player.get_node("LevelUp") as Label
	valid = valid and notice.visible and notice.text == "GOT SCALE MAIL"
	player.free()
	_run().call("start_run")
	return valid


func _test_collect_owned() -> bool:
	_run().call("start_run")
	var player := _player()
	player.call("collect_armor", SCALE_MAIL)
	player.call("wear_armor", TUNIC)
	var valid: bool = not player.call("collect_armor", SCALE_MAIL)
	valid = valid and player.get("equipment").armor == TUNIC
	valid = valid and not player.call("collect_armor", &"nothing")
	player.free()
	_run().call("start_run")
	return valid


func _test_room() -> bool:
	_run().call("start_run")
	var player := _player()
	var valid: bool = player.call("has_room_for", SCALE_MAIL)
	valid = valid and not player.call("has_room_for", TUNIC)
	player.call("collect_armor", SCALE_MAIL)
	valid = valid and not player.call("has_room_for", SCALE_MAIL)
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
	_root.add_child(player)
	return player
