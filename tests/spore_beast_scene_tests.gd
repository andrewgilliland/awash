extends RefCounted

const SPORE_BEAST_SCENE := preload("res://scenes/enemies/spore_beast.tscn")
const SHEET_PATH := "res://assets/enemies/spore_beast/spore_beast_1.png"
const SporeBeastBrain := preload("res://scripts/enemies/spore_beast_brain.gd")
const SporeBeastSounds := preload("res://scripts/enemies/spore_beast_sounds.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const TERRAIN_LAYER := 1
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_LAYER := 1 << 3
const ENEMY_HITBOX_LAYER := 1 << 4
const SOUNDS: Array[StringName] = [&"Snort", &"Hiss", &"Defeat"]
const ANIMATIONS: Array[StringName] = [&"idle", &"lumber", &"vent", &"defeated"]
const CLOUD_ANIMATION := &"burst"
const CLOUD_GROUP := &"spore_cloud"
const SFX_BUS := &"SFX"
const FRAME := 1.0 / 60.0
const MAX_HEALTH := 60
const TOUCH_DAMAGE := 10
const CLOUD_DAMAGE := 8
const CLOUD_RADIUS := 24.0
const CLOUD_LIFETIME := 1.5

# Needs a root that is already in the tree: the Spore Beast finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Spore Beast has a hurtbox and a harmful hide, and stands on the world", _test_boxes],
		["Spore Beast is drawn from its sheet", _test_sprite],
		["Spore Beast carries positional sounds on the SFX bus", _test_sounds_on_sfx_bus],
		["Spore Beast snorts noticing, hisses venting and groans defeated", _test_sound_cues],
		["A hit costs it Health and bursts a cloud of spores around it", _test_hit_vents],
		["A spore cloud, drawn as wide as it strikes, strikes for 8, then fades", _test_cloud],
		["Its hide stops harming once it is defeated", _test_defeated_harmless],
		["Spore Beast's feet are at its origin, drawn standing on them", _test_feet],
	]


func _test_boxes() -> bool:
	var beast := SPORE_BEAST_SCENE.instantiate() as CharacterBody2D
	var valid := beast != null and beast.is_in_group(&"enemy")
	if valid:
		valid = beast.collision_layer == ENEMY_LAYER and beast.collision_mask == TERRAIN_LAYER
		var hurtbox := beast.get_node_or_null("Hurtbox") as Area2D
		valid = valid and hurtbox != null and hurtbox.collision_layer == ENEMY_HITBOX_LAYER
		var hide := beast.get_node_or_null("HideHitbox") as Area2D
		valid = valid and hide is Hitbox and hide.collision_mask == PLAYER_HITBOX_LAYER
	if beast != null:
		beast.free()
	return valid


func _test_sprite() -> bool:
	var beast := _beast()
	var frames := (beast.get_node("AnimatedSprite2D") as AnimatedSprite2D).sprite_frames
	var valid := frames != null
	for animation in ANIMATIONS:
		valid = valid and frames.has_animation(animation)
	if valid:
		var texture := frames.get_frame_texture(&"lumber", 0) as AtlasTexture
		valid = texture != null and texture.atlas.resource_path == SHEET_PATH
		valid = valid and texture.region.size == Vector2(32, 24)
	beast.free()
	return valid


func _test_sounds_on_sfx_bus() -> bool:
	var beast := _beast()
	var valid := true
	for sound in SOUNDS:
		var player := beast.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer2D
		valid = valid and player != null and player.stream != null and player.bus == SFX_BUS
	beast.free()
	return valid


func _test_sound_cues() -> bool:
	var state := SporeBeastBrain.State
	var cues := [
		[state.IDLE, state.LUMBERING, &"Snort"],
		[state.LUMBERING, state.VENTING, &"Hiss"],
		[state.VENTING, state.VENTING, &""],
		[state.LUMBERING, state.DEFEATED, &"Defeat"],
		[state.VENTING, state.LUMBERING, &""],
		[state.LUMBERING, state.IDLE, &""],
	]
	var valid := true
	for cue in cues:
		valid = valid and SporeBeastSounds.for_state_change(cue[0], cue[1]) == cue[2]
	return valid


# Struck, it loses Health and a cloud bursts beside it, in the Room, centred on its body.
func _test_hit_vents() -> bool:
	var room := Node2D.new()
	_root.add_child(room)
	var beast := SPORE_BEAST_SCENE.instantiate() as CharacterBody2D
	room.add_child(beast)
	beast.global_position = Vector2(100, 100)
	var sword := Hitbox.new()
	sword.damage = 10
	beast.call("_on_hurtbox_hit", sword)
	beast.call("_physics_process", FRAME)
	var valid: bool = beast.health.current == MAX_HEALTH - 10
	valid = valid and beast.brain.state == SporeBeastBrain.State.VENTING
	var clouds := _root.get_tree().get_nodes_in_group(CLOUD_GROUP)
	valid = valid and clouds.size() == 1
	if valid:
		var cloud := clouds[0] as Node2D
		valid = cloud.get_parent() == room
		valid = (
			valid
			and absf(cloud.global_position.x - 100.0) < 1.0
			and cloud.global_position.y < 100.0
		)
	sword.free()
	room.free()
	return valid


func _test_cloud() -> bool:
	var beast := _beast()
	var cloud_scene: PackedScene = beast.get("CLOUD_SCENE")
	beast.free()
	var cloud := cloud_scene.instantiate() as Node2D
	_root.add_child(cloud)
	var hitbox := cloud.get_node_or_null("Hitbox") as Hitbox
	var valid := hitbox != null and hitbox.active and hitbox.damage == CLOUD_DAMAGE
	valid = valid and hitbox.collision_mask == PLAYER_HITBOX_LAYER
	if valid:
		var shape := hitbox.get_node("Shape") as CollisionShape2D
		valid = (shape.shape as CircleShape2D).radius == CLOUD_RADIUS
		var sprite := cloud.get_node("AnimatedSprite2D") as AnimatedSprite2D
		valid = valid and sprite.sprite_frames.has_animation(CLOUD_ANIMATION)
		var frame := sprite.sprite_frames.get_frame_texture(CLOUD_ANIMATION, 0) as AtlasTexture
		valid = valid and frame.atlas.resource_path == SHEET_PATH
		# Drawn as wide as it strikes.
		valid = valid and frame.region.size == Vector2.ONE * CLOUD_RADIUS * 2.0
	cloud.call("_physics_process", CLOUD_LIFETIME - 0.1)
	valid = valid and not cloud.is_queued_for_deletion()
	cloud.call("_physics_process", 0.2)
	valid = valid and cloud.is_queued_for_deletion()
	cloud.free()
	return valid


func _test_defeated_harmless() -> bool:
	var beast := _beast()
	var hide := beast.get_node("HideHitbox") as Hitbox
	var valid := hide.active and hide.damage == TOUCH_DAMAGE
	beast.health.hurt(MAX_HEALTH, 0.0)
	beast.call("_physics_process", FRAME)
	valid = valid and beast.brain.state == SporeBeastBrain.State.DEFEATED and not hide.active
	for cloud in _root.get_tree().get_nodes_in_group(CLOUD_GROUP):
		cloud.free()
	beast.free()
	return valid


func _test_feet() -> bool:
	var beast := _beast()
	var shape := beast.get_node("CollisionShape2D") as CollisionShape2D
	var box := (shape.shape as RectangleShape2D).size
	var valid := is_equal_approx(shape.position.y + box.y / 2.0, 0.0)
	var sprite := beast.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var frame := sprite.sprite_frames.get_frame_texture(&"lumber", 0) as AtlasTexture
	valid = valid and is_equal_approx(sprite.position.y + frame.region.size.y / 2.0, 0.0)
	beast.free()
	return valid


func _beast() -> CharacterBody2D:
	var beast := SPORE_BEAST_SCENE.instantiate() as CharacterBody2D
	_root.add_child(beast)
	return beast
