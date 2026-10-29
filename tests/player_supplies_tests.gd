extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const Supplies := preload("res://scripts/items/supplies.gd")
const INPUT_SETUP_SCRIPT_PATH := "res://scripts/core/input_setup.gd"
const BRINECAP := &"brinecap"

# Needs a root that is already in the tree: the Player reads the Run from /root in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Player starts with the Run's Supplies", _test_starts_with_runs_supplies],
		["Collecting a Brinecap carries it, into the Run", _test_collect_carries],
		["Player carries no more than the limit", _test_collect_stops_at_limit],
		["Eating a Brinecap restores 10 Health, with a chime", _test_use_eats_brinecap],
		["Eating at full Health keeps the Brinecap", _test_use_at_full_keeps],
		["Eating does nothing with none, held still or defeated", _test_use_does_nothing],
	]


func _test_starts_with_runs_supplies() -> bool:
	var run := _run()
	run.call("start_run")
	run.set("player_supplies", {BRINECAP: 2})
	var player := _player()
	var valid: bool = player.get("supplies").count(BRINECAP) == 2
	player.free()
	run.call("start_run")
	return valid


func _test_collect_carries() -> bool:
	_run().call("start_run")
	var player := _player()
	var collected: bool = player.call("collect", BRINECAP)
	var valid: bool = collected and player.get("supplies").count(BRINECAP) == 1
	valid = valid and _run().get("player_supplies") == {BRINECAP: 1}
	valid = valid and _playing(player, &"Pickup")
	player.free()
	_run().call("start_run")
	return valid


func _test_collect_stops_at_limit() -> bool:
	_run().call("start_run")
	var player := _player()
	for i in Supplies.CARRY_LIMIT:
		player.call("collect", BRINECAP)
	var valid: bool = not player.call("collect", BRINECAP)
	valid = valid and player.get("supplies").count(BRINECAP) == Supplies.CARRY_LIMIT
	player.free()
	_run().call("start_run")
	return valid


func _test_use_eats_brinecap() -> bool:
	_run().call("start_run")
	var player := _player()
	player.call("collect", BRINECAP)
	var health = player.get("health")
	health.hurt(20, 0.0)
	var used: bool = player.call("use_supply", BRINECAP)
	var valid: bool = used and health.current == health.maximum - 10
	valid = valid and player.get("supplies").count(BRINECAP) == 0
	valid = valid and _playing(player, &"Eat")
	valid = valid and _run().get("player_health") == health.current
	valid = valid and _run().get("player_supplies") == {}
	player.free()
	_run().call("start_run")
	return valid


func _test_use_at_full_keeps() -> bool:
	_run().call("start_run")
	var player := _player()
	player.call("collect", BRINECAP)
	var used: bool = player.call("use_supply", BRINECAP)
	var valid: bool = not used and player.get("supplies").count(BRINECAP) == 1
	valid = valid and not _playing(player, &"Eat")
	player.free()
	_run().call("start_run")
	return valid


func _test_use_does_nothing() -> bool:
	_run().call("start_run")
	var player := _player()
	var health = player.get("health")
	health.hurt(20, 0.0)
	var valid: bool = not player.call("use_supply", BRINECAP)
	player.call("collect", BRINECAP)
	player.set("controls_locked", true)
	valid = valid and not player.call("use_supply", BRINECAP)
	player.set("controls_locked", false)
	# A last hit defeats the Player.
	health.hurt(health.current - 10, 0.0)
	health.step(10.0)
	var hitbox := Area2D.new()
	_root.add_child(hitbox)
	player.call("_on_hurtbox_hit", hitbox)
	valid = valid and player.call("is_defeated") and not player.call("use_supply", BRINECAP)
	valid = valid and player.get("supplies").count(BRINECAP) == 1
	hitbox.free()
	player.free()
	_run().call("start_run")
	return valid


func _run() -> Node:
	return _root.get_node("RunState")


func _player() -> CharacterBody2D:
	_register_inputs()
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = Vector2(100, 100)
	_root.add_child(player)
	return player


func _register_inputs() -> void:
	var input_setup := (load(INPUT_SETUP_SCRIPT_PATH) as GDScript).new() as Node
	input_setup.call("_register_inputs")
	input_setup.free()


func _playing(player: Node, sound: StringName) -> bool:
	var stream_player := player.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer
	return stream_player != null and stream_player.playing
