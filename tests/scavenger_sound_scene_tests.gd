extends RefCounted

const SCAVENGER_SCENE := preload("res://scenes/enemies/scavenger.tscn")
const ScavengerBrain := preload("res://scripts/enemies/scavenger_brain.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const SOUNDS: Array[StringName] = [&"Windup", &"Lunge", &"Hurt", &"Defeat"]
const SFX_BUS := &"SFX"
const PLAYER_GROUP := &"player"
const FRAME := 1.0 / 60.0

# Needs a root that is already in the tree: the Scavenger finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Scavenger carries positional sounds on the SFX bus", _test_sounds_on_sfx_bus],
		["Scavenger sounds its wind-up, then its lunge", _test_windup_then_lunge],
		["Scavenger sounds being hurt, then defeated", _test_hurt_then_defeat],
	]


func _test_sounds_on_sfx_bus() -> bool:
	var scavenger := SCAVENGER_SCENE.instantiate()
	var valid := true
	for sound in SOUNDS:
		var player := scavenger.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer2D
		valid = valid and player != null and player.stream != null
		valid = valid and player.bus == SFX_BUS and player.max_distance > 0.0
	scavenger.free()
	return valid


func _test_windup_then_lunge() -> bool:
	var scavenger := _scavenger()
	var target := _stand_in_player(Vector2(120, 100))
	_steps(scavenger, 1)
	var brain := scavenger.get("brain") as ScavengerBrain
	var valid := brain.state == ScavengerBrain.State.WINDUP and _playing(scavenger, &"Windup")
	valid = valid and not _playing(scavenger, &"Lunge")
	_steps_until(scavenger, ScavengerBrain.State.LUNGE)
	valid = valid and _playing(scavenger, &"Lunge")
	scavenger.free()
	target.free()
	return valid


func _test_hurt_then_defeat() -> bool:
	var scavenger := _scavenger()
	var hitbox := Hitbox.new()
	hitbox.position = Vector2(90, 100)
	_root.add_child(hitbox)
	var hurtbox := scavenger.get_node("Hurtbox")

	hurtbox.call("take_hit", hitbox)
	_steps(scavenger, 1)
	var valid := _playing(scavenger, &"Hurt") and not _playing(scavenger, &"Defeat")

	var health = scavenger.get("health")
	health.current = 1
	health.invulnerable_left = 0.0
	hurtbox.call("take_hit", hitbox)
	_steps(scavenger, 1)
	valid = valid and _playing(scavenger, &"Defeat")
	scavenger.free()
	hitbox.free()
	return valid


func _scavenger() -> CharacterBody2D:
	var scavenger := SCAVENGER_SCENE.instantiate() as CharacterBody2D
	scavenger.position = Vector2(100, 100)
	scavenger.set("patrol_left", 80.0)
	scavenger.set("patrol_right", 140.0)
	_root.add_child(scavenger)
	return scavenger


# Stands in for the Player: the Scavenger only reads where it is.
func _stand_in_player(at: Vector2) -> Node2D:
	var target := Node2D.new()
	target.position = at
	target.add_to_group(PLAYER_GROUP)
	_root.add_child(target)
	return target


func _steps(scavenger: Node, count: int) -> void:
	for i in count:
		scavenger.call("_physics_process", FRAME)


func _steps_until(scavenger: Node, state: ScavengerBrain.State) -> void:
	var brain := scavenger.get("brain") as ScavengerBrain
	for i in 120:
		if brain.state == state:
			return
		_steps(scavenger, 1)


func _playing(scavenger: Node, sound: StringName) -> bool:
	return (scavenger.get_node("Sounds/%s" % sound) as AudioStreamPlayer2D).playing
