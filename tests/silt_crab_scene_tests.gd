extends RefCounted

const SILT_CRAB_SCENE := preload("res://scenes/enemies/silt_crab.tscn")
const SHEET_PATH := "res://assets/enemies/silt_crab/silt_crab_1.png"
const SiltCrabBrain := preload("res://scripts/enemies/silt_crab_brain.gd")
const SiltCrabSounds := preload("res://scripts/enemies/silt_crab_sounds.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const TERRAIN_LAYER := 1
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_LAYER := 1 << 3
const ENEMY_HITBOX_LAYER := 1 << 4
const SOUNDS: Array[StringName] = [&"Skitter", &"Thud", &"Hurt", &"Defeat"]
const ANIMATIONS: Array[StringName] = [
	&"cling", &"shake", &"fall", &"stunned", &"scuttle", &"hurt", &"defeated"
]
const SFX_BUS := &"SFX"
const FRAME := 1.0 / 60.0
const MAX_HEALTH := 20
# Its feet, hanging from a ceiling or standing on a floor, are this far from its middle.
const FEET := 8.0

# Needs a root that is already in the tree: the Silt Crab finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Silt Crab has a hurtbox and claws, and falls onto the world", _test_boxes],
		["Silt Crab is drawn from its sheet", _test_sprite],
		["Silt Crab carries positional sounds on the SFX bus", _test_sounds_on_sfx_bus],
		["Silt Crab makes a sound shaking, landing, struck and defeated", _test_sound_cues],
		["Silt Crab's claws strike only as it drops and scuttles", _test_claws],
		["Silt trickles from the Silt Crab only as it shakes", _test_silt],
		["A hit on a clinging Silt Crab costs Health and knocks it down", _test_knocked_down],
		["Silt Crab's feet meet the ceiling it hangs from and the floor it stands on", _test_feet],
	]


func _test_boxes() -> bool:
	var crab := SILT_CRAB_SCENE.instantiate() as CharacterBody2D
	var valid := crab != null and crab.is_in_group(&"enemy")
	if valid:
		valid = crab.collision_layer == ENEMY_LAYER and crab.collision_mask == TERRAIN_LAYER
		var hurtbox := crab.get_node_or_null("Hurtbox") as Area2D
		valid = valid and hurtbox != null and hurtbox.collision_layer == ENEMY_HITBOX_LAYER
		var claws := crab.get_node_or_null("ClawsHitbox") as Area2D
		valid = valid and claws is Hitbox and claws.collision_mask == PLAYER_HITBOX_LAYER
	if crab != null:
		crab.free()
	return valid


func _test_sprite() -> bool:
	var crab := _crab()
	var frames := (crab.get_node("AnimatedSprite2D") as AnimatedSprite2D).sprite_frames
	var valid := frames != null
	for animation in ANIMATIONS:
		valid = valid and frames.has_animation(animation)
	if valid:
		var texture := frames.get_frame_texture(&"cling", 0) as AtlasTexture
		valid = texture != null and texture.atlas.resource_path == SHEET_PATH
	crab.free()
	return valid


func _test_sounds_on_sfx_bus() -> bool:
	var crab := _crab()
	var valid := true
	for sound in SOUNDS:
		var player := crab.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer2D
		valid = valid and player != null and player.stream != null and player.bus == SFX_BUS
	crab.free()
	return valid


func _test_sound_cues() -> bool:
	var state := SiltCrabBrain.State
	var cues := [
		[state.CLINGING, state.SHAKING, &"Skitter"],
		[state.FALLING, state.STUNNED, &"Thud"],
		[state.SCUTTLING, state.HURT, &"Hurt"],
		[state.HURT, state.DEFEATED, &"Defeat"],
		[state.STUNNED, state.SCUTTLING, &""],
	]
	var valid := true
	for cue in cues:
		valid = valid and SiltCrabSounds.for_state_change(cue[0], cue[1]) == cue[2]
	return valid


func _test_claws() -> bool:
	var crab := _crab()
	var claws := crab.get_node("ClawsHitbox") as Hitbox
	var valid := not claws.active
	var expected := {
		SiltCrabBrain.State.SHAKING: 0,
		SiltCrabBrain.State.FALLING: 15,
		SiltCrabBrain.State.STUNNED: 0,
		SiltCrabBrain.State.SCUTTLING: 10,
	}
	for state: SiltCrabBrain.State in expected:
		crab.brain.call("_enter", state, 1.0)
		crab.call("_show")
		var damage: int = expected[state]
		valid = valid and claws.active == (damage > 0)
		valid = valid and (damage == 0 or claws.damage == damage)
	crab.free()
	return valid


func _test_silt() -> bool:
	var crab := _crab()
	var silt := crab.get_node("Silt") as CPUParticles2D
	var valid := not silt.emitting
	crab.brain.call("_enter", SiltCrabBrain.State.SHAKING, 1.0)
	crab.call("_show")
	valid = valid and silt.emitting
	crab.brain.call("_enter", SiltCrabBrain.State.FALLING, 0.0)
	crab.call("_show")
	valid = valid and not silt.emitting
	crab.free()
	return valid


func _test_knocked_down() -> bool:
	var crab := _crab()
	var beam := Hitbox.new()
	beam.damage = 10
	beam.charged = true
	crab.call("_on_hurtbox_hit", beam)
	crab.call("_physics_process", FRAME)
	var valid: bool = crab.health.current == MAX_HEALTH - 10
	valid = valid and crab.brain.state == SiltCrabBrain.State.FALLING
	valid = valid and not (crab.get_node("ClawsHitbox") as Hitbox).active
	beam.free()
	crab.free()
	return valid


func _test_feet() -> bool:
	var crab := _crab()
	var shape := crab.get_node("CollisionShape2D") as CollisionShape2D
	var box := (shape.shape as RectangleShape2D).size
	# Standing, its body's foot is at its feet.
	var valid := is_equal_approx(shape.position.y + box.y / 2.0, FEET)
	# Hanging, the cling frame's top row is at its feet on the ceiling.
	var frames := crab.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var cling := frames.sprite_frames.get_frame_texture(&"cling", 0) as AtlasTexture
	var top := frames.position.y - cling.region.size.y / 2.0
	valid = valid and is_equal_approx(top, -FEET)
	crab.free()
	return valid


func _crab() -> CharacterBody2D:
	var crab := SILT_CRAB_SCENE.instantiate() as CharacterBody2D
	_root.add_child(crab)
	return crab
