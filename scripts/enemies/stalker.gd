extends CharacterBody2D

# The Stalker: an altered jungle cat, six-legged and bark-shouldered, waiting on a high perch. When
# the Player comes near below it, roots burst under their feet to mark them, and it pounces onto
# the mark; it recovers where it lands, then leaps back to its perch. Its origin is at its feet.

# Its Health ran out; the Room hands its Experience to the Player.
signal defeated(experience: int)

const StalkerBrain := preload("res://scripts/enemies/stalker_brain.gd")
const Health := preload("res://scripts/combat/health.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const HitFeel := preload("res://scripts/combat/hit_feel.gd")
const StalkerSounds := preload("res://scripts/enemies/stalker_sounds.gd")
const MAX_HEALTH := 30
# What defeating a Stalker earns the Player.
const EXPERIENCE := 20
# The Gold its defeat earns the Player.
const GOLD := 4
# The chance a defeated Stalker leaves a Brinecap where it fell.
const DROP_CHANCE := 0.25
const INVULNERABLE_TIME := 0.3
const DEFEAT_TIME := 0.6
const DEFEAT_BLINK := 0.1
const PLAYER_GROUP := &"player"
# A row of 24x16 frames facing right: perched, perched, marking, leaping up, leaping down,
# recovering, recovering, hurt, defeated. Under it, 16x16 frames of the roots bursting.
const SHEET := preload("res://assets/enemies/stalker/stalker_1.png")
const FRAME_SIZE := Vector2i(24, 16)
const ROOTS_SIZE := Vector2i(16, 16)
const ROOTS_ROW := 16
const ANIMATIONS := {
	&"perched": {frames = [0, 1], fps = 2.0, loop = true},
	&"mark": {frames = [2], fps = 1.0, loop = false},
	&"leap_up": {frames = [3], fps = 1.0, loop = false},
	&"leap_down": {frames = [4], fps = 1.0, loop = false},
	&"recover": {frames = [5, 6], fps = 6.0, loop = true},
	&"hurt": {frames = [7], fps = 1.0, loop = false},
	&"defeated": {frames = [8], fps = 1.0, loop = false},
}
const ROOTS_ANIMATION := &"burst"
const ROOTS_FRAMES := [0, 1, 2]
const ROOTS_FPS := 8.0
const SHOWN := {
	StalkerBrain.State.PERCHED: &"perched",
	StalkerBrain.State.MARKING: &"mark",
	StalkerBrain.State.RECOVERING: &"recover",
	StalkerBrain.State.HURT: &"hurt",
	StalkerBrain.State.DEFEATED: &"defeated",
}

# Read-only for callers.
var brain: StalkerBrain = StalkerBrain.new()
var health: Health = Health.new(MAX_HEALTH)
var _struck: bool = false
var _defeat_left: float = DEFEAT_TIME
var _sounds: StalkerSounds

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _roots: AnimatedSprite2D = $Roots
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _claws: Hitbox = $ClawsHitbox
@onready var _sound_players: Node = $Sounds


func _ready() -> void:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(&"perched"):
		_sprite.sprite_frames = _build_sprite_frames()
	if _roots.sprite_frames == null or not _roots.sprite_frames.has_animation(ROOTS_ANIMATION):
		_roots.sprite_frames = _build_roots_frames()
	if not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)
	if _sounds == null:
		_sounds = StalkerSounds.new(_sound_players)
	_show()


func _physics_process(delta: float) -> void:
	health.step(delta)
	var previous := brain.state
	if previous != StalkerBrain.State.DEFEATED:
		brain.step(_read_frame(), delta)
		if brain.state != previous:
			_sounds.play(StalkerSounds.for_state_change(previous, brain.state))
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


func _read_frame() -> StalkerBrain.Frame:
	var frame := StalkerBrain.Frame.new()
	frame.position = global_position
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player != null:
		frame.sees_player = true
		frame.player_position = player.global_position
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
	var animation: StringName = SHOWN.get(brain.state, &"")
	if animation.is_empty():
		animation = &"leap_up" if brain.velocity.y < 0.0 else &"leap_down"
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)
	_sprite.flip_h = brain.facing < 0.0
	_claws.position.x = absf(_claws.position.x) * brain.facing
	var harms := brain.claws_damage > 0
	if harms:
		_claws.damage = brain.claws_damage
	if _claws.active != harms:
		_claws.active = harms
	# The roots stand at the mark, wherever the Stalker has gone, their foot on the ground there.
	if brain.roots_showing and not _roots.visible:
		_roots.play(ROOTS_ANIMATION)
	_roots.visible = brain.roots_showing
	_roots.global_position = brain.mark - Vector2(0, ROOTS_SIZE.y / 2.0)


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


static func _build_roots_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(ROOTS_ANIMATION)
	frames.set_animation_speed(ROOTS_ANIMATION, ROOTS_FPS)
	frames.set_animation_loop(ROOTS_ANIMATION, false)
	for frame_index in ROOTS_FRAMES:
		var frame := AtlasTexture.new()
		frame.atlas = SHEET
		frame.region = Rect2(Vector2(frame_index * ROOTS_SIZE.x, ROOTS_ROW), Vector2(ROOTS_SIZE))
		frames.add_frame(ROOTS_ANIMATION, frame)
	return frames
