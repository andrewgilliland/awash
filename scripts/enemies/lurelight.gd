extends CharacterBody2D

# The Lurelight: a fish lurking under the Undertow's dark water, its lure a pale rune light. It
# drifts toward the Player, goes dark, snaps its jaws straight up out of the water, then lies
# stranded at the surface for a moment: the only time it can be struck.

# Its Health ran out; the Room hands its Experience to the Player.
signal defeated(experience: int)

const LurelightBrain := preload("res://scripts/enemies/lurelight_brain.gd")
const Health := preload("res://scripts/combat/health.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const HitFeel := preload("res://scripts/combat/hit_feel.gd")
const LurelightSounds := preload("res://scripts/enemies/lurelight_sounds.gd")
const MAX_HEALTH := 20
# What defeating a Lurelight earns the Player.
const EXPERIENCE := 15
# The Supply a defeated Lurelight may leave where it fell, and the chance it does.
const DROP := &"glowroe"
const DROP_CHANCE := 0.2
const INVULNERABLE_TIME := 0.3
# Belly-up at the surface, then sinking out of sight.
const DEFEAT_TIME := 0.6
const DEFEAT_SINK := 12.0
const PLAYER_GROUP := &"player"
# One row of 32x32 cells, facing right, the water's surface 24 pixels down each: hidden, hidden,
# dim, dim, snap, snap, stranded, hurt, sunk, defeated.
const SHEET := preload("res://assets/enemies/lurelight/lurelight_1.png")
const FRAME_SIZE := Vector2i(32, 32)
const ANIMATIONS := {
	&"hidden": {frames = [0, 1], fps = 2.0, loop = true},
	&"dim": {frames = [2, 3], fps = 6.0, loop = true},
	&"snap": {frames = [4, 5], fps = 12.0, loop = false},
	&"stranded": {frames = [6], fps = 1.0, loop = false},
	&"hurt": {frames = [7], fps = 1.0, loop = false},
	&"sunk": {frames = [8], fps = 1.0, loop = false},
	&"defeated": {frames = [9], fps = 1.0, loop = false},
}
const SHOWN := {
	LurelightBrain.State.HIDDEN: &"hidden",
	LurelightBrain.State.DIM: &"dim",
	LurelightBrain.State.SNAP: &"snap",
	LurelightBrain.State.STRANDED: &"stranded",
	LurelightBrain.State.HURT: &"hurt",
	LurelightBrain.State.SUNK: &"sunk",
	LurelightBrain.State.DEFEATED: &"defeated",
}

# Its pool's edges, in Room x; it is placed at the water's surface.
@export var pool_left: float = 0.0
@export var pool_right: float = 0.0

# Read-only for callers.
var brain: LurelightBrain = LurelightBrain.new()
var health: Health = Health.new(MAX_HEALTH)
var _struck: bool = false
var _defeat_left: float = DEFEAT_TIME
var _sounds: LurelightSounds

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _jaws: Hitbox = $JawsHitbox
@onready var _sound_players: Node = $Sounds
@onready var _sprite_y: float = _sprite.position.y


func _ready() -> void:
	brain.pool_left = pool_left
	brain.pool_right = pool_right
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(&"hidden"):
		_sprite.sprite_frames = _build_sprite_frames()
	if not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)
	if _sounds == null:
		_sounds = LurelightSounds.new(_sound_players)
	_show()


func _physics_process(delta: float) -> void:
	health.step(delta)
	if brain.state == LurelightBrain.State.DEFEATED:
		_defeat_left -= delta
		var sunk := 1.0 - maxf(_defeat_left, 0.0) / DEFEAT_TIME
		_sprite.position.y = _sprite_y + DEFEAT_SINK * sunk
		_sprite.modulate.a = 1.0 - sunk
		if _defeat_left <= 0.0:
			queue_free()
		return

	var previous := brain.state
	brain.step(_read_frame(), delta)
	if brain.state != previous:
		_sounds.play(LurelightSounds.for_state_change(previous, brain.state))
	velocity = brain.velocity
	move_and_slide()
	_show()


func _read_frame() -> LurelightBrain.Frame:
	var frame := LurelightBrain.Frame.new()
	frame.position = global_position
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player != null:
		frame.sees_player = true
		frame.player_offset = player.global_position - global_position
	frame.struck = _struck
	frame.defeated = health.is_defeated()
	_struck = false
	return frame


# A hit while it lies stranded costs Health and sends it under.
func _on_hurtbox_hit(hitbox: Area2D) -> void:
	var damage: int = hitbox.damage if hitbox is Hitbox else Hitbox.DEFAULT_DAMAGE
	if not health.hurt(damage, INVULNERABLE_TIME):
		return
	HitFeel.enemy_struck(self, health.is_defeated())
	_struck = true
	_hurtbox.set_deferred("monitorable", false)
	if health.is_defeated():
		defeated.emit(EXPERIENCE)


func _show() -> void:
	var animation: StringName = SHOWN[brain.state]
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)
	_sprite.flip_h = brain.facing < 0.0
	if _jaws.active != brain.jaws_active:
		_jaws.active = brain.jaws_active
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
