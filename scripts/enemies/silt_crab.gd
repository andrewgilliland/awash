extends CharacterBody2D

# The Silt Crab: a pale cave crab clinging to the Undertow's low ceilings. When the Player passes
# under it, it shakes silt down, then drops on them; it lies stunned where it lands, then scuttles
# after them. A hit while it still clings, a Sword Beam's or a Bomb's, knocks it down harmlessly.

# Its Health ran out; the Room hands its Experience to the Player.
signal defeated(experience: int)

const SiltCrabBrain := preload("res://scripts/enemies/silt_crab_brain.gd")
const Health := preload("res://scripts/combat/health.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const HitFeel := preload("res://scripts/combat/hit_feel.gd")
const SiltCrabSounds := preload("res://scripts/enemies/silt_crab_sounds.gd")
const MAX_HEALTH := 20
# What defeating a Silt Crab earns the Player.
const EXPERIENCE := 15
# The Gold its defeat earns the Player.
const GOLD := 3
# The chance a defeated Silt Crab leaves a Brinecap where it fell.
const DROP_CHANCE := 0.25
const INVULNERABLE_TIME := 0.3
const DEFEAT_TIME := 0.6
const DEFEAT_BLINK := 0.1
const PLAYER_GROUP := &"player"
# One row of 16x16 cells, facing right: scuttle, scuttle, claws raised, hurt, clinging, shaking,
# shaking, falling, stunned, stunned, defeated. Hanging frames hang from the cell's top, standing
# and lying ones rest on its foot.
const SHEET := preload("res://assets/enemies/silt_crab/silt_crab_1.png")
const FRAME_SIZE := Vector2i(16, 16)
const ANIMATIONS := {
	&"scuttle": {frames = [0, 1], fps = 8.0, loop = true},
	&"hurt": {frames = [3], fps = 1.0, loop = false},
	&"cling": {frames = [4], fps = 1.0, loop = false},
	&"shake": {frames = [5, 6], fps = 16.0, loop = true},
	&"fall": {frames = [7], fps = 1.0, loop = false},
	&"stunned": {frames = [8, 9], fps = 6.0, loop = true},
	&"defeated": {frames = [10], fps = 1.0, loop = false},
}
const SHOWN := {
	SiltCrabBrain.State.CLINGING: &"cling",
	SiltCrabBrain.State.SHAKING: &"shake",
	SiltCrabBrain.State.FALLING: &"fall",
	SiltCrabBrain.State.STUNNED: &"stunned",
	SiltCrabBrain.State.SCUTTLING: &"scuttle",
	SiltCrabBrain.State.HURT: &"hurt",
	SiltCrabBrain.State.DEFEATED: &"defeated",
}

# Read-only for callers.
var brain: SiltCrabBrain = SiltCrabBrain.new()
var health: Health = Health.new(MAX_HEALTH)
var _struck: bool = false
var _defeat_left: float = DEFEAT_TIME
var _sounds: SiltCrabSounds

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _claws: Hitbox = $ClawsHitbox
@onready var _silt: CPUParticles2D = $Silt
@onready var _sound_players: Node = $Sounds


func _ready() -> void:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(&"cling"):
		_sprite.sprite_frames = _build_sprite_frames()
	if not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)
	if _sounds == null:
		_sounds = SiltCrabSounds.new(_sound_players)
	_show()


func _physics_process(delta: float) -> void:
	health.step(delta)
	var previous := brain.state
	if previous != SiltCrabBrain.State.DEFEATED:
		brain.step(_read_frame(), delta)
		if brain.state != previous:
			_sounds.play(SiltCrabSounds.for_state_change(previous, brain.state))
		velocity = brain.velocity
	else:
		# Struck down in the air, it still falls to the floor as it fades.
		velocity.x = 0.0
		velocity.y = 0.0 if is_on_floor() else minf(velocity.y + brain.gravity * delta, 300.0)
		_defeat_left -= delta
		_sprite.visible = fmod(_defeat_left, DEFEAT_BLINK * 2.0) > DEFEAT_BLINK
		if _defeat_left <= 0.0:
			queue_free()
	move_and_slide()
	_show()


func _read_frame() -> SiltCrabBrain.Frame:
	var frame := SiltCrabBrain.Frame.new()
	frame.position = global_position
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player != null:
		frame.sees_player = true
		frame.player_offset = player.global_position - global_position
	frame.struck = _struck
	frame.on_floor = is_on_floor()
	frame.defeated = health.is_defeated()
	_struck = false
	return frame


func _on_hurtbox_hit(hitbox: Area2D) -> void:
	var damage: int = hitbox.damage if hitbox is Hitbox else Hitbox.DEFAULT_DAMAGE
	if not health.hurt(damage, INVULNERABLE_TIME):
		return
	HitFeel.enemy_struck(self, health.is_defeated())
	_struck = true
	if health.is_defeated():
		_hurtbox.set_deferred("monitorable", false)
		defeated.emit(EXPERIENCE)


func _show() -> void:
	var animation: StringName = SHOWN[brain.state]
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)
	_sprite.flip_h = brain.facing < 0.0
	var harms := brain.claws_damage > 0
	if harms:
		_claws.damage = brain.claws_damage
	if _claws.active != harms:
		_claws.active = harms
	if _silt.emitting != brain.silt_falling:
		_silt.emitting = brain.silt_falling


static func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation_name in ANIMATIONS:
		var spec: Dictionary = ANIMATIONS[animation_name]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, spec.fps)
		frames.set_animation_loop(animation_name, spec.loop)
		for frame_index in spec.frames:
			var frame := AtlasTexture.new()
			frame.atlas = SHEET
			frame.region = Rect2(Vector2(frame_index * FRAME_SIZE.x, 0), Vector2(FRAME_SIZE))
			frames.add_frame(animation_name, frame)
	return frames
