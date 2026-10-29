extends CharacterBody2D

# The Storm Wisp: a knot of mist and lightning that rides the wind over the coast's heights.
# It flies through the world, crackles when the Player comes near, then arcs lightning all
# around itself and rests, dim, before drifting on.

# Its Health ran out; the Room hands its Experience to the Player.
signal defeated(experience: int)

const StormWispBrain := preload("res://scripts/enemies/storm_wisp_brain.gd")
const Health := preload("res://scripts/combat/health.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const StormWispSounds := preload("res://scripts/enemies/storm_wisp_sounds.gd")
const MAX_HEALTH := 20
# What defeating a Storm Wisp earns the Player.
const EXPERIENCE := 15
const INVULNERABLE_TIME := 0.3
const DEFEAT_TIME := 0.5
const DEFEAT_BLINK := 0.08
const PLAYER_GROUP := &"player"
# One row of 32x32 cells: drift, drift, crackle, crackle, arc, arc, rest, hurt.
const SHEET := preload("res://assets/sprites/enemies/storm_wisp_1.png")
const FRAME_SIZE := Vector2i(32, 32)
const ANIMATIONS := {
	&"drift": {frames = [0, 1], fps = 4.0, loop = true},
	&"crackle": {frames = [2, 3], fps = 12.0, loop = true},
	&"arc": {frames = [4, 5], fps = 16.0, loop = true},
	&"rest": {frames = [6], fps = 1.0, loop = false},
	&"hurt": {frames = [7], fps = 1.0, loop = false},
}
const SHOWN := {
	StormWispBrain.State.DRIFT: &"drift",
	StormWispBrain.State.CRACKLE: &"crackle",
	StormWispBrain.State.ARC: &"arc",
	StormWispBrain.State.REST: &"rest",
	StormWispBrain.State.HURT: &"hurt",
	StormWispBrain.State.DEFEATED: &"hurt",
}

# The stretch of sky it drifts over, in Room x; it bobs at the height it is placed at.
@export var drift_left: float = 0.0
@export var drift_right: float = 0.0

# Read-only for callers.
var brain: StormWispBrain = StormWispBrain.new()
var health: Health = Health.new(MAX_HEALTH)
var _knocked_toward: float = 0.0
var _defeat_left: float = DEFEAT_TIME
var _sounds: StormWispSounds

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _arc: Hitbox = $ArcHitbox
@onready var _sound_players: Node = $Sounds


func _ready() -> void:
	brain.drift_left = drift_left
	brain.drift_right = drift_right
	brain.home_y = global_position.y
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(&"drift"):
		_sprite.sprite_frames = _build_sprite_frames()
	if not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)
	if _sounds == null:
		_sounds = StormWispSounds.new(_sound_players)
	_show()


func _physics_process(delta: float) -> void:
	health.step(delta)
	if brain.state == StormWispBrain.State.DEFEATED:
		_defeat_left -= delta
		_sprite.visible = fmod(_defeat_left, DEFEAT_BLINK * 2.0) < DEFEAT_BLINK
		if _defeat_left <= 0.0:
			queue_free()
		return

	var previous := brain.state
	brain.step(_read_frame(), delta)
	if brain.state != previous:
		_sounds.play(StormWispSounds.for_state_change(previous, brain.state))
	velocity = brain.velocity
	move_and_slide()
	_show()


func _read_frame() -> StormWispBrain.Frame:
	var frame := StormWispBrain.Frame.new()
	frame.position = global_position
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player != null:
		frame.sees_player = true
		frame.player_offset = player.global_position - global_position
	frame.knocked_toward = _knocked_toward
	frame.defeated = health.is_defeated()
	_knocked_toward = 0.0
	return frame


# A hit costs Health and pushes the Wisp away from the hitbox, unless invulnerable.
func _on_hurtbox_hit(hitbox: Area2D) -> void:
	var damage: int = hitbox.damage if hitbox is Hitbox else Hitbox.DEFAULT_DAMAGE
	if not health.hurt(damage, INVULNERABLE_TIME):
		return
	var toward := signf(global_position.x - hitbox.global_position.x)
	_knocked_toward = toward if toward != 0.0 else -brain.facing
	if health.is_defeated():
		_hurtbox.set_deferred("monitorable", false)
		defeated.emit(EXPERIENCE)


func _show() -> void:
	var animation: StringName = SHOWN[brain.state]
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)
	if _arc.active != brain.arc_active:
		_arc.active = brain.arc_active


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
