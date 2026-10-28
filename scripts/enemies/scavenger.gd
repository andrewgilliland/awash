extends CharacterBody2D

const ScavengerBrain := preload("res://scripts/enemies/scavenger_brain.gd")
const Health := preload("res://scripts/combat/health.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const MAX_HEALTH := 3
const INVULNERABLE_TIME := 0.3
const DEFEAT_TIME := 0.6
const DEFEAT_BLINK := 0.1
const PLAYER_GROUP := &"player"
# The spear's reach, in front of the Scavenger when facing right.
const SPEAR_OFFSET := Vector2(10.0, -9.0)
# One row of 16x16 cells: stride, stride, wind-up, lunge, hurt.
const SHEET := preload("res://assets/sprites/enemies/scavenger_1.png")
const FRAME_SIZE := Vector2i(16, 16)
const ANIMATIONS := {
	&"patrol": {frames = [0, 1], fps = 4.0, loop = true},
	&"windup": {frames = [2], fps = 1.0, loop = false},
	&"lunge": {frames = [3], fps = 1.0, loop = false},
	&"recover": {frames = [0], fps = 1.0, loop = false},
	&"hurt": {frames = [4], fps = 1.0, loop = false},
}
const SHOWN := {
	ScavengerBrain.State.PATROL: &"patrol",
	ScavengerBrain.State.WINDUP: &"windup",
	ScavengerBrain.State.LUNGE: &"lunge",
	ScavengerBrain.State.RECOVER: &"recover",
	ScavengerBrain.State.HURT: &"hurt",
	ScavengerBrain.State.DEFEATED: &"hurt",
}

# The stretch of shallows it patrols, in Room x.
@export var patrol_left: float = 0.0
@export var patrol_right: float = 0.0

# Read-only for callers.
var brain: ScavengerBrain = ScavengerBrain.new()
var health: Health = Health.new(MAX_HEALTH)
var _knocked_toward: float = 0.0
var _defeat_left: float = DEFEAT_TIME

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _spear: Hitbox = $SpearHitbox


func _ready() -> void:
	brain.patrol_left = patrol_left
	brain.patrol_right = patrol_right
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(&"patrol"):
		_sprite.sprite_frames = _build_sprite_frames()
	if not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)
	_show()


func _physics_process(delta: float) -> void:
	health.step(delta)
	if brain.state == ScavengerBrain.State.DEFEATED:
		_defeat_left -= delta
		_sprite.visible = fmod(_defeat_left, DEFEAT_BLINK * 2.0) < DEFEAT_BLINK
		if _defeat_left <= 0.0:
			queue_free()
		return

	brain.step(_read_frame(), delta)
	velocity.x = brain.velocity.x
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	_show()


func _read_frame() -> ScavengerBrain.Frame:
	var frame := ScavengerBrain.Frame.new()
	frame.position = global_position
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player != null:
		frame.sees_player = true
		frame.player_offset = player.global_position - global_position
	frame.knocked_toward = _knocked_toward
	frame.defeated = health.is_defeated()
	_knocked_toward = 0.0
	return frame


# A hit costs Health and pushes the Scavenger away from the hitbox, unless invulnerable.
func _on_hurtbox_hit(hitbox: Area2D) -> void:
	var damage: int = hitbox.damage if hitbox is Hitbox else 1
	if not health.hurt(damage, INVULNERABLE_TIME):
		return
	var toward := signf(global_position.x - hitbox.global_position.x)
	_knocked_toward = toward if toward != 0.0 else -brain.facing
	if health.is_defeated():
		_hurtbox.set_deferred("monitorable", false)


func _show() -> void:
	var animation: StringName = SHOWN[brain.state]
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)
	_sprite.flip_h = brain.facing < 0.0
	_spear.position = Vector2(SPEAR_OFFSET.x * brain.facing, SPEAR_OFFSET.y)
	if _spear.active != brain.spear_active:
		_spear.active = brain.spear_active


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
