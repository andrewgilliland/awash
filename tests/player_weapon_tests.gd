extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const Equipment := preload("res://scripts/items/equipment.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const PlayerController := preload("res://scripts/player/player_controller.gd")
const INPUT_SETUP_SCRIPT_PATH := "res://scripts/core/input_setup.gd"
const SHORT_SWORD := &"short_sword"
const OATHBLADE := &"oathblade"

# Needs a root that is already in the tree: the Player reads the Run from /root in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Player holds the Run's Weapon", _test_holds_runs_weapon],
		["Collecting a Weapon owns and holds it, into the Run, with a sound", _test_collect],
		["A Weapon owned already is not collected again", _test_collect_owned],
		["Holding another Weapon goes into the Run", _test_hold_reaches_run],
		["The held Weapon's Attack adds to quick and Charged hits", _test_attack_adds],
		["The sword in hand and its Sword Beam are drawn from the held Weapon", _test_drawn],
	]


func _test_holds_runs_weapon() -> bool:
	var run := _run()
	run.call("start_run")
	var valid: bool = run.get("player_weapon") == SHORT_SWORD
	valid = valid and run.get("player_owned_weapons") == [SHORT_SWORD]
	run.set("player_weapon", OATHBLADE)
	run.set("player_owned_weapons", [SHORT_SWORD, OATHBLADE])
	var player := _player()
	var equipment = player.get("equipment")
	valid = valid and equipment.weapon == OATHBLADE
	valid = valid and equipment.owned_weapons == [SHORT_SWORD, OATHBLADE]
	player.free()
	run.call("start_run")
	return valid


func _test_collect() -> bool:
	_run().call("start_run")
	var player := _player()
	var collected: bool = player.call("collect_weapon", OATHBLADE)
	var valid: bool = collected and player.get("equipment").weapon == OATHBLADE
	valid = valid and _run().get("player_weapon") == OATHBLADE
	valid = valid and _run().get("player_owned_weapons") == [SHORT_SWORD, OATHBLADE]
	valid = valid and _playing(player, &"Pickup")
	var notice := player.get_node("LevelUp") as Label
	valid = valid and notice.visible and notice.text == "GOT OATHBLADE"
	valid = valid and (notice.get_node("Gains") as Label).text == ""
	player.free()
	_run().call("start_run")
	return valid


func _test_collect_owned() -> bool:
	_run().call("start_run")
	var player := _player()
	player.call("collect_weapon", OATHBLADE)
	player.call("hold_weapon", SHORT_SWORD)
	var valid: bool = not player.call("collect_weapon", OATHBLADE)
	valid = valid and player.get("equipment").weapon == SHORT_SWORD
	valid = valid and not player.call("collect_weapon", &"nothing")
	player.free()
	_run().call("start_run")
	return valid


func _test_hold_reaches_run() -> bool:
	_run().call("start_run")
	var player := _player()
	var valid: bool = not player.call("hold_weapon", OATHBLADE)
	player.call("collect_weapon", OATHBLADE)
	valid = valid and player.call("hold_weapon", SHORT_SWORD)
	valid = valid and _run().get("player_weapon") == SHORT_SWORD
	valid = valid and player.get("equipment").weapon == SHORT_SWORD
	player.free()
	_run().call("start_run")
	return valid


func _test_attack_adds() -> bool:
	_run().call("start_run")
	var player := _player()
	var controller := player.get("controller") as PlayerController
	var sword := player.get_node("SwordHitbox") as Hitbox
	player.call("collect_weapon", OATHBLADE)
	_step(controller, {"melee_held": true})
	var valid := sword.damage == Hitbox.DEFAULT_DAMAGE + 5
	_step(controller, {"attack_finished": true})
	# A full Charge let go: its Sword Beam carries the Charged Attack's cost.
	_step(controller, {"melee_held": true})
	_step(controller, {"melee_held": true, "attack_finished": true})
	for i in ceili(controller.charge_time / 0.1) + 1:
		_step(controller, {"melee_held": true})
	_step(controller, {})
	var beams := player.get_tree().get_nodes_in_group(&"sword_beam")
	valid = valid and beams.size() == 1
	if beams.size() == 1:
		var hitbox := beams[0].get_node("Hitbox") as Hitbox
		valid = valid and hitbox.damage == (Hitbox.DEFAULT_DAMAGE + 5) * 2
	for beam in beams:
		beam.free()
	player.free()
	_run().call("start_run")
	return valid


func _test_drawn() -> bool:
	_run().call("start_run")
	var player := _player()
	var valid := _sword_sheet(player) == Equipment.WEAPONS[SHORT_SWORD].sheet
	player.call("collect_weapon", OATHBLADE)
	valid = valid and _sword_sheet(player) == Equipment.WEAPONS[OATHBLADE].sheet
	var controller := player.get("controller") as PlayerController
	_step(controller, {"melee_held": true})
	_step(controller, {"melee_held": true, "attack_finished": true})
	for i in ceili(controller.charge_time / 0.1) + 1:
		_step(controller, {"melee_held": true})
	_step(controller, {})
	var beams := player.get_tree().get_nodes_in_group(&"sword_beam")
	valid = valid and beams.size() == 1
	if beams.size() == 1:
		var blade := (beams[0].get_node("Sprite") as Sprite2D).texture as AtlasTexture
		valid = valid and blade.atlas.resource_path == Equipment.WEAPONS[OATHBLADE].sheet
	for beam in beams:
		beam.free()
	player.call("hold_weapon", SHORT_SWORD)
	valid = valid and _sword_sheet(player) == Equipment.WEAPONS[SHORT_SWORD].sheet
	player.free()
	_run().call("start_run")
	return valid


# The sheet the sword in hand is cut from.
func _sword_sheet(player: Node) -> String:
	var frames := (player.get_node("SwordSprite") as AnimatedSprite2D).sprite_frames
	var frame := frames.get_frame_texture(&"attack", 0) as AtlasTexture
	return frame.atlas.resource_path if frame != null else ""


func _run() -> Node:
	return _root.get_node("RunState")


func _player() -> CharacterBody2D:
	var input_setup := (load(INPUT_SETUP_SCRIPT_PATH) as GDScript).new() as Node
	input_setup.call("_register_inputs")
	input_setup.free()
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	_root.add_child(player)
	return player


func _playing(player: Node, sound: StringName) -> bool:
	var stream_player := player.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer
	return stream_player != null and stream_player.playing


func _step(controller: PlayerController, fields: Dictionary) -> void:
	var frame := PlayerController.Frame.new()
	frame.velocity = controller.velocity
	for field in fields:
		frame.set(field, fields[field])
	controller.step(frame, 0.1)
