extends CharacterBody2D

# The Wraith: a spectral oathkeeper haunting the tunnels under the coast. It drifts phased
# through rock and sword alike, manifests to lash at a Player who comes close, then shows the
# rune anchor in its chest for a moment: the only time it can be struck.

const WraithBrain := preload("res://scripts/enemies/wraith_brain.gd")
const Health := preload("res://scripts/combat/health.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const WraithSounds := preload("res://scripts/enemies/wraith_sounds.gd")
const MAX_HEALTH := 30
const INVULNERABLE_TIME := 0.3
const DEFEAT_TIME := 0.6
const DEFEAT_BLINK := 0.08
# How see-through it looks while phased.
const PHASED_ALPHA := 0.45
const PLAYER_GROUP := &"player"
# Its claw's reach, in front of it when facing right.
const LASH_OFFSET := Vector2(14.0, 0.0)
# One row of 32x32 cells, facing right: drift, drift, manifest, manifest, lash, lash, exposed,
# hurt.
const SHEET := preload("res://assets/sprites/enemies/wraith_1.png")
const FRAME_SIZE := Vector2i(32, 32)
const ANIMATIONS := {
	&"drift": {frames = [0, 1], fps = 3.0, loop = true},
	&"manifest": {frames = [2, 3], fps = 8.0, loop = true},
	&"lash": {frames = [4, 5], fps = 12.0, loop = false},
	&"exposed": {frames = [6], fps = 1.0, loop = false},
	&"hurt": {frames = [7], fps = 1.0, loop = false},
}
const SHOWN := {
	WraithBrain.State.DRIFT: &"drift",
	WraithBrain.State.MANIFEST: &"manifest",
	WraithBrain.State.LASH: &"lash",
	WraithBrain.State.EXPOSED: &"exposed",
	WraithBrain.State.HURT: &"hurt",
	WraithBrain.State.DEFEATED: &"hurt",
}

# The stretch of tunnel it haunts, in Room x; it bobs at the height it is placed at.
@export var haunt_left: float = 0.0
@export var haunt_right: float = 0.0

# Read-only for callers.
var brain: WraithBrain = WraithBrain.new()
var health: Health = Health.new(MAX_HEALTH)
var _knocked_toward: float = 0.0
var _defeat_left: float = DEFEAT_TIME
var _sounds: WraithSounds

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _lash: Hitbox = $LashHitbox
@onready var _sound_players: Node = $Sounds


func _ready() -> void:
	brain.haunt_left = haunt_left
	brain.haunt_right = haunt_right
	brain.home_y = global_position.y
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(&"drift"):
		_sprite.sprite_frames = _build_sprite_frames()
	if not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)
	if _sounds == null:
		_sounds = WraithSounds.new(_sound_players)
	_show()


func _physics_process(delta: float) -> void:
	health.step(delta)
	if brain.state == WraithBrain.State.DEFEATED:
		_defeat_left -= delta
		_sprite.visible = fmod(_defeat_left, DEFEAT_BLINK * 2.0) < DEFEAT_BLINK
		if _defeat_left <= 0.0:
			queue_free()
		return

	var previous := brain.state
	brain.step(_read_frame(), delta)
	if brain.state != previous:
		_sounds.play(WraithSounds.for_state_change(previous, brain.state))
	velocity = brain.velocity
	move_and_slide()
	_show()


func _read_frame() -> WraithBrain.Frame:
	var frame := WraithBrain.Frame.new()
	frame.position = global_position
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player != null:
		frame.sees_player = true
		frame.player_offset = player.global_position - global_position
	frame.knocked_toward = _knocked_toward
	frame.defeated = health.is_defeated()
	_knocked_toward = 0.0
	return frame


# A hit on its exposed anchor costs Health and pushes it away from the hitbox.
func _on_hurtbox_hit(hitbox: Area2D) -> void:
	var damage: int = hitbox.damage if hitbox is Hitbox else Hitbox.DEFAULT_DAMAGE
	if not health.hurt(damage, INVULNERABLE_TIME):
		return
	var toward := signf(global_position.x - hitbox.global_position.x)
	_knocked_toward = toward if toward != 0.0 else -brain.facing
	_hurtbox.set_deferred("monitorable", false)


func _show() -> void:
	var animation: StringName = SHOWN[brain.state]
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)
	_sprite.flip_h = brain.facing < 0.0
	_sprite.modulate.a = 1.0 if brain.solid else PHASED_ALPHA
	_lash.position = Vector2(LASH_OFFSET.x * brain.facing, LASH_OFFSET.y)
	if _lash.active != brain.lash_active:
		_lash.active = brain.lash_active
	if _hurtbox.monitorable != brain.exposed:
		_hurtbox.monitorable = brain.exposed


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
