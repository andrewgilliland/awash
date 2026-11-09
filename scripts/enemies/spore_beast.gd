extends CharacterBody2D

# The Spore Beast: a swollen garden beast, fungal shelves pulsing on its back, lumbering after the
# Player. Every hit vents a cloud of spores around it; it never flinches, and its hide hurts to
# touch. Its origin is at its feet.

# Its Health ran out; the Room hands its Experience to the Player.
signal defeated(experience: int)

const SporeBeastBrain := preload("res://scripts/enemies/spore_beast_brain.gd")
const Health := preload("res://scripts/combat/health.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const HitFeel := preload("res://scripts/combat/hit_feel.gd")
const SporeBeastSounds := preload("res://scripts/enemies/spore_beast_sounds.gd")
const CLOUD_SCENE := preload("res://scenes/enemies/spore_cloud.tscn")
const MAX_HEALTH := 60
# What defeating a Spore Beast earns the Player.
const EXPERIENCE := 40
# The Gold its defeat earns the Player.
const GOLD := 8
# The chance a defeated Spore Beast leaves a Brinecap where it fell.
const DROP_CHANCE := 0.25
const INVULNERABLE_TIME := 0.3
const DEFEAT_TIME := 0.6
const DEFEAT_BLINK := 0.1
const PLAYER_GROUP := &"player"
# Where a cloud bursts from: the middle of its body, above its feet.
const CLOUD_OFFSET := Vector2(0, -12)
# A row of 32x24 frames facing right: walking, walking, venting, defeated. Under it, the cloud's.
const SHEET := preload("res://assets/enemies/spore_beast/spore_beast_1.png")
const FRAME_SIZE := Vector2i(32, 24)
const ANIMATIONS := {
	&"idle": {frames = [0], fps = 1.0, loop = false},
	&"lumber": {frames = [0, 1], fps = 3.0, loop = true},
	&"vent": {frames = [2], fps = 1.0, loop = false},
	&"defeated": {frames = [3], fps = 1.0, loop = false},
}
const SHOWN := {
	SporeBeastBrain.State.IDLE: &"idle",
	SporeBeastBrain.State.LUMBERING: &"lumber",
	SporeBeastBrain.State.VENTING: &"vent",
	SporeBeastBrain.State.DEFEATED: &"defeated",
}

# Read-only for callers.
var brain: SporeBeastBrain = SporeBeastBrain.new()
var health: Health = Health.new(MAX_HEALTH)
var _struck: bool = false
var _defeat_left: float = DEFEAT_TIME
var _sounds: SporeBeastSounds

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _hide: Hitbox = $HideHitbox
@onready var _sound_players: Node = $Sounds


func _ready() -> void:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(&"lumber"):
		_sprite.sprite_frames = _build_sprite_frames()
	if not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)
	if _sounds == null:
		_sounds = SporeBeastSounds.new(_sound_players)
	_show()


func _physics_process(delta: float) -> void:
	health.step(delta)
	var previous := brain.state
	if previous != SporeBeastBrain.State.DEFEATED:
		brain.step(_read_frame(), delta)
		if brain.state != previous:
			_sounds.play(SporeBeastSounds.for_state_change(previous, brain.state))
		if brain.vented:
			_vent()
		velocity = brain.velocity
	else:
		velocity.x = 0.0
		velocity.y = 0.0 if is_on_floor() else minf(velocity.y + brain.gravity * delta, 300.0)
		_defeat_left -= delta
		_sprite.visible = fmod(_defeat_left, DEFEAT_BLINK * 2.0) > DEFEAT_BLINK
		if _defeat_left <= 0.0:
			queue_free()
	move_and_slide()
	_show()


func _read_frame() -> SporeBeastBrain.Frame:
	var frame := SporeBeastBrain.Frame.new()
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


# A cloud bursts in the Room around it, and stays there as it lumbers on.
func _vent() -> void:
	var cloud := CLOUD_SCENE.instantiate() as Node2D
	var room := get_parent() if get_parent() != null else self
	room.add_child(cloud)
	cloud.global_position = global_position + CLOUD_OFFSET


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
	var harms := brain.touch_damage > 0
	if harms:
		_hide.damage = brain.touch_damage
	if _hide.active != harms:
		_hide.active = harms


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
