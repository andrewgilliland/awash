extends RefCounted

const STALKER_SCENE := preload("res://scenes/enemies/stalker.tscn")
const SHEET_PATH := "res://assets/enemies/stalker/stalker_1.png"
const StalkerBrain := preload("res://scripts/enemies/stalker_brain.gd")
const StalkerSounds := preload("res://scripts/enemies/stalker_sounds.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const TERRAIN_LAYER := 1
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_LAYER := 1 << 3
const ENEMY_HITBOX_LAYER := 1 << 4
const SOUNDS: Array[StringName] = [&"Rustle", &"Pounce", &"Hurt", &"Defeat"]
const ANIMATIONS: Array[StringName] = [
	&"perched", &"mark", &"leap_up", &"leap_down", &"recover", &"hurt", &"defeated"
]
const ROOTS_ANIMATION := &"burst"
const SFX_BUS := &"SFX"
const FRAME := 1.0 / 60.0
const MAX_HEALTH := 30
const LEAP_DAMAGE := 12

# Needs a root that is already in the tree: the Stalker finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Stalker has a hurtbox and claws, and stands on the world", _test_boxes],
		["Stalker and its roots are drawn from its sheet", _test_sprite],
		["Stalker carries positional sounds on the SFX bus", _test_sounds_on_sfx_bus],
		["Stalker makes a sound marking, pouncing, struck and defeated", _test_sound_cues],
		["Stalker's claws strike only as its leap comes down", _test_claws],
		["Roots burst at the mark only as it marks and leaps", _test_roots],
		["A hit on a perched Stalker costs Health and makes it flinch", _test_flinches],
		["Stalker's feet are at its middle's foot, drawn standing on them", _test_feet],
	]


func _test_boxes() -> bool:
	var stalker := STALKER_SCENE.instantiate() as CharacterBody2D
	var valid := stalker != null and stalker.is_in_group(&"enemy")
	if valid:
		valid = stalker.collision_layer == ENEMY_LAYER and stalker.collision_mask == TERRAIN_LAYER
		var hurtbox := stalker.get_node_or_null("Hurtbox") as Area2D
		valid = valid and hurtbox != null and hurtbox.collision_layer == ENEMY_HITBOX_LAYER
		var claws := stalker.get_node_or_null("ClawsHitbox") as Area2D
		valid = valid and claws is Hitbox and claws.collision_mask == PLAYER_HITBOX_LAYER
	if stalker != null:
		stalker.free()
	return valid


func _test_sprite() -> bool:
	var stalker := _stalker()
	var frames := (stalker.get_node("AnimatedSprite2D") as AnimatedSprite2D).sprite_frames
	var valid := frames != null
	for animation in ANIMATIONS:
		valid = valid and frames.has_animation(animation)
	if valid:
		var texture := frames.get_frame_texture(&"perched", 0) as AtlasTexture
		valid = texture != null and texture.atlas.resource_path == SHEET_PATH
		valid = valid and texture.region.size == Vector2(24, 16)
	var roots := stalker.get_node_or_null("Roots") as AnimatedSprite2D
	valid = valid and roots != null and roots.sprite_frames.has_animation(ROOTS_ANIMATION)
	if valid:
		var burst := roots.sprite_frames.get_frame_texture(ROOTS_ANIMATION, 0) as AtlasTexture
		valid = burst.atlas.resource_path == SHEET_PATH and burst.region.size == Vector2(16, 16)
	stalker.free()
	return valid


func _test_sounds_on_sfx_bus() -> bool:
	var stalker := _stalker()
	var valid := true
	for sound in SOUNDS:
		var player := stalker.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer2D
		valid = valid and player != null and player.stream != null and player.bus == SFX_BUS
	stalker.free()
	return valid


func _test_sound_cues() -> bool:
	var state := StalkerBrain.State
	var cues := [
		[state.PERCHED, state.MARKING, &"Rustle"],
		[state.MARKING, state.LEAPING, &"Pounce"],
		[state.RECOVERING, state.HURT, &"Hurt"],
		[state.HURT, state.DEFEATED, &"Defeat"],
		[state.RECOVERING, state.RETURNING, &""],
		[state.LEAPING, state.RECOVERING, &""],
	]
	var valid := true
	for cue in cues:
		valid = valid and StalkerSounds.for_state_change(cue[0], cue[1]) == cue[2]
	return valid


func _test_claws() -> bool:
	var stalker := _stalker()
	var claws := stalker.get_node("ClawsHitbox") as Hitbox
	var valid := not claws.active
	for damage in [0, LEAP_DAMAGE, 0]:
		stalker.brain.claws_damage = damage
		stalker.call("_show")
		valid = valid and claws.active == (damage > 0)
		valid = valid and (damage == 0 or claws.damage == damage)
	stalker.free()
	return valid


# The roots stand where the brain marked, wherever the Stalker has gone, and only while shown.
func _test_roots() -> bool:
	var stalker := _stalker()
	stalker.global_position = Vector2(280, 80)
	var roots := stalker.get_node("Roots") as AnimatedSprite2D
	var valid := not roots.visible
	stalker.brain.mark = Vector2(200, 112)
	stalker.brain.roots_showing = true
	stalker.call("_show")
	valid = valid and roots.visible and roots.global_position.x == 200.0
	valid = valid and is_equal_approx(roots.global_position.y + 8.0, 112.0)
	stalker.global_position = Vector2(240, 60)
	stalker.call("_show")
	valid = valid and roots.global_position.x == 200.0
	stalker.brain.roots_showing = false
	stalker.call("_show")
	valid = valid and not roots.visible
	stalker.free()
	return valid


func _test_flinches() -> bool:
	var stalker := _stalker()
	var sword := Hitbox.new()
	sword.damage = 10
	stalker.call("_on_hurtbox_hit", sword)
	stalker.call("_physics_process", FRAME)
	var valid: bool = stalker.health.current == MAX_HEALTH - 10
	valid = valid and stalker.brain.state == StalkerBrain.State.HURT
	valid = valid and not (stalker.get_node("ClawsHitbox") as Hitbox).active
	sword.free()
	stalker.free()
	return valid


# Its body's foot is at its origin, and its frames' bottom row too.
func _test_feet() -> bool:
	var stalker := _stalker()
	var shape := stalker.get_node("CollisionShape2D") as CollisionShape2D
	var box := (shape.shape as RectangleShape2D).size
	var valid := is_equal_approx(shape.position.y + box.y / 2.0, 0.0)
	var sprite := stalker.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var frame := sprite.sprite_frames.get_frame_texture(&"perched", 0) as AtlasTexture
	valid = valid and is_equal_approx(sprite.position.y + frame.region.size.y / 2.0, 0.0)
	stalker.free()
	return valid


func _stalker() -> CharacterBody2D:
	var stalker := STALKER_SCENE.instantiate() as CharacterBody2D
	_root.add_child(stalker)
	return stalker
