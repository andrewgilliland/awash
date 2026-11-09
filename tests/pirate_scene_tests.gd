extends RefCounted

const PIRATE_SCENE := preload("res://scenes/enemies/pirate.tscn")
const BOMB_SCENE := preload("res://scenes/enemies/pirate_bomb.tscn")
const SHEET_PATH := "res://assets/enemies/pirate/pirate_1.png"
const BOMB_SHEET_PATH := "res://assets/items/bomb_lit.png"
const PirateBrain := preload("res://scripts/enemies/pirate_brain.gd")
const PirateSounds := preload("res://scripts/enemies/pirate_sounds.gd")
const PirateBomb := preload("res://scripts/enemies/pirate_bomb.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const TERRAIN_LAYER := 1
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_LAYER := 1 << 3
const ENEMY_HITBOX_LAYER := 1 << 4
const SOUNDS: Array[StringName] = [&"Whistle", &"Swish", &"Grunt", &"Defeat"]
const BOMB_SOUNDS: Array[StringName] = [&"Fuse", &"Burst"]
const ANIMATIONS: Array[StringName] = [
	&"guard", &"walk", &"tell", &"rush", &"winded", &"wind_up", &"reload", &"hurt", &"defeated"
]
const BOMB_GROUP := &"pirate_bomb"
const SFX_BUS := &"SFX"
const FRAME := 1.0 / 60.0
const MAX_HEALTH := 40
const TOUCH_DAMAGE := 6
const RUSH_DAMAGE := 10
const BOMB_DAMAGE := 12
const BOMB_RADIUS := 20.0
const BOMB_FUSE := 1.2
const FLIGHT_TIME := 0.5

# Needs a root that is already in the tree: the Pirate finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		[
			"Pirate has a hurtbox, a harmful touch and a cutlass, and stands on the world",
			_test_boxes
		],
		["Pirate is drawn from its sheet", _test_sprite],
		["Pirate carries positional sounds on the SFX bus", _test_sounds_on_sfx_bus],
		["Pirate swishes rushing, grunts struck and cries out defeated", _test_sound_cues],
		["Pirate's cutlass strikes only in a rush, on the side it faces", _test_cutlass],
		["Pirate's defeat is worth 30 Experience and 10 Gold, and may leave a Bomb", _test_worth],
		["Pirate lobs a Pirate bomb into its Room, from its hand", _test_throws_bomb],
		["A Pirate bomb's arc lands it where it was aimed", _test_bomb_arc],
		["A Pirate bomb strikes only the Player, as it bursts 1.2 s after its throw", _test_bomb],
		["Defeated, it stops harming", _test_defeated_harmless],
		["Pirate's feet are at its origin, drawn standing on them", _test_feet],
	]


func _test_boxes() -> bool:
	var pirate := PIRATE_SCENE.instantiate() as CharacterBody2D
	var valid := pirate != null and pirate.is_in_group(&"enemy")
	if valid:
		valid = pirate.collision_layer == ENEMY_LAYER and pirate.collision_mask == TERRAIN_LAYER
		var hurtbox := pirate.get_node_or_null("Hurtbox") as Area2D
		valid = valid and hurtbox != null and hurtbox.collision_layer == ENEMY_HITBOX_LAYER
		for box in ["TouchHitbox", "CutlassHitbox"]:
			var hitbox := pirate.get_node_or_null(box) as Area2D
			valid = valid and hitbox is Hitbox and hitbox.collision_mask == PLAYER_HITBOX_LAYER
	if pirate != null:
		pirate.free()
	return valid


func _test_sprite() -> bool:
	var pirate := _pirate()
	var frames := (pirate.get_node("AnimatedSprite2D") as AnimatedSprite2D).sprite_frames
	var valid := frames != null
	for animation in ANIMATIONS:
		valid = valid and frames.has_animation(animation)
	if valid:
		var texture := frames.get_frame_texture(&"guard", 0) as AtlasTexture
		valid = texture != null and texture.atlas.resource_path == SHEET_PATH
		valid = valid and texture.region.size == Vector2(24, 24)
	pirate.free()
	return valid


func _test_sounds_on_sfx_bus() -> bool:
	var pirate := _pirate()
	var valid := true
	for sound in SOUNDS:
		var player := pirate.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer2D
		valid = valid and player != null and player.stream != null and player.bus == SFX_BUS
	pirate.free()
	var bomb := BOMB_SCENE.instantiate()
	for sound in BOMB_SOUNDS:
		var player := bomb.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer2D
		valid = valid and player != null and player.stream != null and player.bus == SFX_BUS
	bomb.free()
	return valid


func _test_sound_cues() -> bool:
	var state := PirateBrain.State
	var cues := [
		[state.TELL, state.RUSH, &"Swish"],
		[state.GUARD, state.HURT, &"Grunt"],
		[state.WIND_UP, state.HURT, &"Grunt"],
		[state.RUSH, state.DEFEATED, &"Defeat"],
		[state.GUARD, state.TELL, &""],
		[state.WIND_UP, state.RELOAD, &""],
		[state.RUSH, state.WINDED, &""],
	]
	var valid := true
	for cue in cues:
		valid = valid and PirateSounds.for_state_change(cue[0], cue[1]) == cue[2]
	return valid


func _test_cutlass() -> bool:
	var pirate := _pirate()
	var cutlass := pirate.get_node("CutlassHitbox") as Hitbox
	var touch := pirate.get_node("TouchHitbox") as Hitbox
	var valid := not cutlass.active and touch.active and touch.damage == TOUCH_DAMAGE
	for facing in [1.0, -1.0]:
		pirate.brain.facing = facing
		for damage in [0, RUSH_DAMAGE, 0]:
			pirate.brain.cutlass_damage = damage
			pirate.call("_show")
			valid = valid and cutlass.active == (damage > 0)
			valid = valid and (damage == 0 or cutlass.damage == damage)
			valid = valid and signf(cutlass.position.x) == facing
	pirate.free()
	return valid


func _test_worth() -> bool:
	var constants: Dictionary = (
		(PIRATE_SCENE.instantiate().get_script() as Script).get_script_constant_map()
	)
	return (
		constants.get("EXPERIENCE") == 30
		and constants.get("GOLD") == 10
		and constants.get("DROP") == &"bomb"
		and is_equal_approx(constants.get("DROP_CHANCE"), 0.25)
		and constants.get("MAX_HEALTH") == MAX_HEALTH
	)


# Letting go, it leaves a Pirate bomb in its Room, just above its feet on the side it faces.
func _test_throws_bomb() -> bool:
	var room := Node2D.new()
	_root.add_child(room)
	var pirate := PIRATE_SCENE.instantiate() as CharacterBody2D
	room.add_child(pirate)
	pirate.global_position = Vector2(100, 100)
	pirate.brain.facing = -1.0
	pirate.brain.threw = true
	pirate.brain.throw_target = Vector2(20, 100)
	pirate.call("_throw")
	var bombs := _root.get_tree().get_nodes_in_group(BOMB_GROUP)
	var valid := bombs.size() == 1
	if valid:
		var bomb := bombs[0] as Node2D
		valid = bomb.get_parent() == room
		valid = valid and bomb.global_position.x < 100.0 and bomb.global_position.y < 100.0
		valid = valid and (bomb as CharacterBody2D).velocity.x < 0.0
	room.free()
	return valid


# Flown frame by frame as the bomb flies, gravity first, it comes down on its target.
func _test_bomb_arc() -> bool:
	var valid := true
	var gravity := 980.0
	for target in [Vector2(-80, 18), Vector2(60, -30), Vector2(-140, 60)]:
		var velocity := PirateBomb.launch_velocity(target, FLIGHT_TIME, gravity, FRAME)
		var at := Vector2.ZERO
		for i in range(roundi(FLIGHT_TIME / FRAME)):
			velocity.y += gravity * FRAME
			at += velocity * FRAME
		valid = valid and at.distance_to(target) < 1.0
	return valid


func _test_bomb() -> bool:
	var bomb := BOMB_SCENE.instantiate() as CharacterBody2D
	_root.add_child(bomb)
	var valid := bomb.is_in_group(BOMB_GROUP) and bomb.collision_layer == 0
	valid = valid and bomb.collision_mask == TERRAIN_LAYER
	var blast := bomb.get_node_or_null("Blast") as Hitbox
	valid = valid and blast != null and blast.collision_mask == PLAYER_HITBOX_LAYER
	valid = valid and blast.collision_layer == ENEMY_HITBOX_LAYER
	valid = valid and blast.damage == BOMB_DAMAGE and not blast.charged and not blast.blast
	var shape := blast.get_node("Shape") as CollisionShape2D
	valid = valid and (shape.shape as CircleShape2D).radius == BOMB_RADIUS
	var sprite := bomb.get_node("Sprite") as AnimatedSprite2D
	var frame := sprite.sprite_frames.get_frame_texture(&"fuse", 0) as AtlasTexture
	valid = valid and frame.atlas.resource_path == BOMB_SHEET_PATH
	valid = valid and not blast.active
	bomb.call("_physics_process", BOMB_FUSE - 0.05)
	valid = valid and not blast.active
	bomb.call("_physics_process", 0.1)
	valid = valid and blast.active and sprite.animation == &"burst"
	bomb.call("_physics_process", 0.3)
	valid = valid and bomb.is_queued_for_deletion()
	bomb.free()
	return valid


func _test_defeated_harmless() -> bool:
	var pirate := _pirate()
	var touch := pirate.get_node("TouchHitbox") as Hitbox
	pirate.health.hurt(MAX_HEALTH, 0.0)
	pirate.call("_physics_process", FRAME)
	var valid: bool = pirate.brain.state == PirateBrain.State.DEFEATED and not touch.active
	valid = valid and not (pirate.get_node("CutlassHitbox") as Hitbox).active
	pirate.free()
	return valid


func _test_feet() -> bool:
	var pirate := _pirate()
	var shape := pirate.get_node("CollisionShape2D") as CollisionShape2D
	var box := (shape.shape as RectangleShape2D).size
	var valid := is_equal_approx(shape.position.y + box.y / 2.0, 0.0)
	var sprite := pirate.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var frame := sprite.sprite_frames.get_frame_texture(&"guard", 0) as AtlasTexture
	valid = valid and is_equal_approx(sprite.position.y + frame.region.size.y / 2.0, 0.0)
	pirate.free()
	return valid


func _pirate() -> CharacterBody2D:
	var pirate := PIRATE_SCENE.instantiate() as CharacterBody2D
	_root.add_child(pirate)
	return pirate
