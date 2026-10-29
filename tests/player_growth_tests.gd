extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const Level := preload("res://scripts/player/level.gd")
const PlayerController := preload("res://scripts/player/player_controller.gd")
const INPUT_SETUP_SCRIPT_PATH := "res://scripts/core/input_setup.gd"

# Needs a root that is already in the tree: the Player reads the Run from /root in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Player starts at the Run's Level", _test_starts_at_runs_level],
		["Experience raises the Player's Level and Health", _test_experience_raises_level],
		["Player's Experience carries in the Run", _test_experience_carries_in_run],
		["Strength adds to quick and Charged hits", _test_strength_adds_to_hits],
		["Reaching a Level chimes and shows LEVEL UP", _test_level_up_feedback],
		["Experience short of a Level stays quiet", _test_no_level_stays_quiet],
		["LEVEL UP stays on screen at a Room's edge", _test_level_up_stays_on_screen],
	]


func _test_starts_at_runs_level() -> bool:
	var run := _run()
	run.set("player_experience", Level.LEVELS[2].experience)
	var fresh := _player()
	var valid: bool = fresh.get("level").level == 3 and fresh.get("health").maximum == 70
	valid = valid and fresh.get("health").current == 70
	fresh.free()
	# Carried Health is out of the Level's maximum.
	run.set("player_health", 40)
	var hurt := _player()
	valid = valid and hurt.get("health").maximum == 70 and hurt.get("health").current == 40
	hurt.free()
	run.call("start_run")
	return valid


func _test_experience_raises_level() -> bool:
	_run().call("start_run")
	var player := _player()
	var health = player.get("health")
	health.hurt(10, 0.0)
	player.call("gain_experience", Level.LEVELS[1].experience)
	var valid: bool = player.get("level").level == 2
	valid = valid and health.maximum == 60 and health.current == 50
	player.free()
	return valid


func _test_experience_carries_in_run() -> bool:
	var run := _run()
	run.call("start_run")
	var player := _player()
	player.call("gain_experience", 15)
	var valid: bool = run.get("player_experience") == 15
	player.get("health").hurt(10, 0.0)
	player.call("gain_experience", Level.LEVELS[1].experience - 15)
	# The new Level's Health goes into the Run, so the next Room keeps it.
	valid = valid and run.get("player_experience") == Level.LEVELS[1].experience
	valid = valid and run.get("player_health") == 50
	player.free()
	run.call("start_run")
	return valid


func _test_strength_adds_to_hits() -> bool:
	_run().call("start_run")
	var player := _player()
	var controller := player.get("controller") as PlayerController
	var sword := player.get_node("SwordHitbox") as Hitbox
	player.call("gain_experience", Level.LEVELS[-1].experience)
	var strength: int = Level.LEVELS[-1].strength

	_step(controller, {"melee_held": true})
	_step(controller, {})
	var valid := strength > 0 and sword.damage == Hitbox.DEFAULT_DAMAGE + strength
	_step(controller, {"attack_finished": true})

	for i in ceili(controller.charge_time / 0.1) + 1:
		_step(controller, {"melee_held": true})
	_step(controller, {})
	valid = valid and sword.damage == (Hitbox.DEFAULT_DAMAGE + strength) * 2
	player.free()
	_run().call("start_run")
	return valid


func _test_level_up_feedback() -> bool:
	_run().call("start_run")
	var player := _player()
	var label := player.get_node_or_null("LevelUp") as Label
	var valid := label != null and not label.visible
	player.call("gain_experience", Level.LEVELS[1].experience)
	valid = valid and _playing(player, &"LevelUp")
	valid = valid and label != null and label.visible and label.text == "LEVEL UP"
	player.free()
	_run().call("start_run")
	return valid


func _test_no_level_stays_quiet() -> bool:
	_run().call("start_run")
	var player := _player()
	player.call("gain_experience", 1)
	var label := player.get_node_or_null("LevelUp") as Label
	var valid := label != null and not label.visible and not _playing(player, &"LevelUp")
	player.free()
	_run().call("start_run")
	return valid


# A Player by either edge of the screen still shows all of LEVEL UP.
func _test_level_up_stays_on_screen() -> bool:
	var valid := true
	var width := _root.get_visible_rect().size.x
	for x in [4.0, width - 4.0]:
		_run().call("start_run")
		var player := _player()
		player.position = Vector2(x, 100)
		player.call("gain_experience", Level.LEVELS[1].experience)
		var label := player.get_node("LevelUp") as Label
		var left := label.get_global_transform_with_canvas().origin.x
		valid = valid and left >= 0.0 and left + label.size.x <= width
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


func _playing(player: Node, sound: StringName) -> bool:
	var stream_player := player.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer
	return stream_player != null and stream_player.playing


func _step(controller: PlayerController, fields: Dictionary) -> void:
	var frame := PlayerController.Frame.new()
	frame.velocity = controller.velocity
	for field in fields:
		frame.set(field, fields[field])
	controller.step(frame, 0.1)
