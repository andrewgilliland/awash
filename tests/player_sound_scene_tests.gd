extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PlayerController := preload("res://scripts/player/player_controller.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const Hurtbox := preload("res://scripts/combat/hurtbox.gd")
const SOUNDS: Array[StringName] = [
	&"Jump", &"Land", &"Swing", &"Hit", &"Hurt", &"Defeat", &"LevelUp", &"Pickup", &"Eat"
]
const SFX_BUS := &"SFX"

# Needs a root that is already in the tree: sounds only play inside it.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Player carries its sounds on the SFX bus", _test_sounds_on_sfx_bus],
		["Player sounds its jump and landing", _test_jump_and_land],
		["Player sounds its swing and a sword hit", _test_swing_and_hit],
		["Player sounds being hurt, then defeated", _test_hurt_then_defeat],
	]


func _test_sounds_on_sfx_bus() -> bool:
	var player := PLAYER_SCENE.instantiate()
	var valid := AudioServer.get_bus_index(SFX_BUS) != -1
	for sound in SOUNDS:
		var stream_player := player.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer
		valid = valid and stream_player != null and stream_player.stream != null
		valid = valid and stream_player.bus == SFX_BUS
	player.free()
	return valid


func _test_jump_and_land() -> bool:
	var player := _player()
	var controller := player.get("controller") as PlayerController
	_step(controller, {"jump_pressed": true})
	var valid := _playing(player, &"Jump") and not _playing(player, &"Land")
	_step(controller, {"on_floor": false})
	_step(controller, {})
	valid = valid and _playing(player, &"Land")
	player.free()
	return valid


func _test_swing_and_hit() -> bool:
	var player := _player()
	var controller := player.get("controller") as PlayerController
	_step(controller, {"melee_held": true})
	var valid := not _playing(player, &"Swing")
	_step(controller, {})
	valid = valid and _playing(player, &"Swing")

	# The live sword overlapping an enemy's hurtbox, as the physics server reports it.
	var sword := player.get_node("SwordHitbox") as Hitbox
	var target := Hurtbox.new()
	_root.add_child(target)
	valid = valid and sword.active and not _playing(player, &"Hit")
	sword.area_entered.emit(target)
	valid = valid and _playing(player, &"Hit")
	player.free()
	target.free()
	return valid


func _test_hurt_then_defeat() -> bool:
	var player := _player()
	var hitbox := Hitbox.new()
	_root.add_child(hitbox)
	var hurtbox := player.get_node("Hurtbox")
	hurtbox.call("take_hit", hitbox)
	var valid := _playing(player, &"Hurt") and not _playing(player, &"Defeat")

	(player.get_node("Sounds/Hurt") as AudioStreamPlayer).stop()
	var health = player.get("health")
	health.current = 1
	health.invulnerable_left = 0.0
	hurtbox.call("take_hit", hitbox)
	valid = valid and _playing(player, &"Defeat") and not _playing(player, &"Hurt")
	player.free()
	hitbox.free()
	return valid


func _player() -> CharacterBody2D:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	_root.add_child(player)
	return player


func _playing(player: Node, sound: StringName) -> bool:
	return (player.get_node("Sounds/%s" % sound) as AudioStreamPlayer).playing


func _step(controller: PlayerController, fields: Dictionary) -> void:
	var frame := PlayerController.Frame.new()
	frame.velocity = controller.velocity
	for field in fields:
		frame.set(field, fields[field])
	controller.step(frame, 0.1)
