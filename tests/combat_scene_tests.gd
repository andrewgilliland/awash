extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SCAVENGER_SCENE := preload("res://scenes/enemies/scavenger.tscn")
const RUNE_SHORE_SCENE := preload("res://scenes/rooms/waking_coast_2.tscn")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const PlayerController := preload("res://scripts/player/player_controller.gd")
const INPUT_SETUP_SCRIPT_PATH := "res://scripts/core/input_setup.gd"
const WORLD_LAYER := 1 << 0
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_LAYER := 1 << 3
const ENEMY_HITBOX_LAYER := 1 << 4
# The rune shore's tidal pool, in pixels.
const POOL := Vector2(128, 160)

# Needs a root that is already in the tree: bodies read Health and Hitboxes in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Player has a hurtbox and a sword hitbox", _test_player_boxes],
		["Sword hitbox is live only during an Attack", _test_sword_live_in_attack],
		["A hit costs the Player Health and knocks it away", _test_player_hit],
		["Scavenger has a body, hurtbox and spear", _test_scavenger_boxes],
		["Rune shore keeps a Scavenger in its tidal pool", _test_scavenger_in_pool],
	]


func _test_player_boxes() -> bool:
	var player := PLAYER_SCENE.instantiate()
	var hurtbox := player.get_node_or_null("Hurtbox") as Area2D
	var sword := player.get_node_or_null("SwordHitbox") as Area2D
	var valid := _is_hurtbox(hurtbox, PLAYER_HITBOX_LAYER)
	valid = valid and _is_hitbox(sword, PLAYER_HITBOX_LAYER, ENEMY_HITBOX_LAYER)
	player.free()
	return valid


func _test_sword_live_in_attack() -> bool:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	_root.add_child(player)
	var controller := player.get("controller") as PlayerController
	var sword := player.get_node("SwordHitbox") as Hitbox
	var valid := not sword.active

	# Face right first: a charge locks facing.
	_step(controller, {"direction": 1.0})
	_step(controller, {"melee_held": true, "direction": 1.0})
	valid = valid and not sword.active
	_step(controller, {})
	valid = valid and controller.state == PlayerController.State.ATTACK and sword.active
	valid = valid and sword.position.x > 0.0

	_step(controller, {"attack_finished": true})
	valid = valid and not sword.active
	player.free()
	return valid


func _test_player_hit() -> bool:
	_register_inputs()
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = Vector2(100, 100)
	_root.add_child(player)
	var hitbox := Hitbox.new()
	hitbox.position = Vector2(90, 100)
	_root.add_child(hitbox)
	var hurtbox := player.get_node("Hurtbox")

	hurtbox.call("take_hit", hitbox)
	var health = player.get("health")
	var valid: bool = health.current == health.maximum - 1
	var frame := player.call("_read_frame") as PlayerController.Frame
	valid = valid and frame.knockback.x > 0.0 and frame.knockback.y < 0.0

	# Invulnerable straight after: a second hit costs nothing.
	hurtbox.call("take_hit", hitbox)
	valid = valid and health.current == health.maximum - 1
	player.free()
	hitbox.free()
	return valid


func _test_scavenger_boxes() -> bool:
	var scavenger := SCAVENGER_SCENE.instantiate() as CharacterBody2D
	var valid := scavenger != null and scavenger.is_in_group(&"enemy")
	if valid:
		valid = scavenger.collision_layer == ENEMY_LAYER and scavenger.collision_mask == WORLD_LAYER
		valid = valid and _is_hurtbox(scavenger.get_node_or_null("Hurtbox"), ENEMY_HITBOX_LAYER)
		var spear := scavenger.get_node_or_null("SpearHitbox") as Area2D
		valid = valid and _is_hitbox(spear, ENEMY_HITBOX_LAYER, PLAYER_HITBOX_LAYER)
	if scavenger != null:
		scavenger.free()
	return valid


func _test_scavenger_in_pool() -> bool:
	var room := RUNE_SHORE_SCENE.instantiate()
	var scavenger := room.get_node_or_null("Enemies/Scavenger") as Node2D
	var valid := scavenger != null and scavenger.scene_file_path == SCAVENGER_SCENE.resource_path
	if valid:
		var left: float = scavenger.get("patrol_left")
		var right: float = scavenger.get("patrol_right")
		valid = scavenger.position.x > POOL.x and scavenger.position.x < POOL.y
		valid = valid and left > POOL.x and right < POOL.y and left < right
	room.free()
	return valid


static func _is_hurtbox(area: Area2D, layer: int) -> bool:
	return (
		area != null
		and area.collision_layer == layer
		and area.collision_mask == 0
		and area.monitorable
		and area.has_method("take_hit")
	)


static func _is_hitbox(area: Area2D, layer: int, mask: int) -> bool:
	return (
		area is Hitbox
		and area.collision_layer == layer
		and area.collision_mask == mask
		and not area.monitorable
	)


func _register_inputs() -> void:
	var input_setup := (load(INPUT_SETUP_SCRIPT_PATH) as GDScript).new() as Node
	input_setup.call("_register_inputs")
	input_setup.free()


func _step(controller: PlayerController, fields: Dictionary) -> void:
	var frame := PlayerController.Frame.new()
	frame.velocity = controller.velocity
	for field in fields:
		frame.set(field, fields[field])
	controller.step(frame, 0.1)
