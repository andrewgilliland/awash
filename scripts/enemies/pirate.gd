extends CharacterBody2D

# The Pirate: a corsair in patched storm leathers and a brass half-mask, holding a post. Up close
# on its level it rushes the Player with its cutlass; farther off, or above or below, it lobs
# clay bombs at them. Its origin is at its feet.

# Its Health ran out; the Room hands its Experience to the Player.
signal defeated(experience: int)

const PirateBrain := preload("res://scripts/enemies/pirate_brain.gd")
const Health := preload("res://scripts/combat/health.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const HitFeel := preload("res://scripts/combat/hit_feel.gd")
const PirateSounds := preload("res://scripts/enemies/pirate_sounds.gd")
const BOMB_SCENE := preload("res://scenes/enemies/pirate_bomb.tscn")
const MAX_HEALTH := 40
# What defeating a Pirate earns the Player.
const EXPERIENCE := 30
# The Gold its defeat earns the Player.
const GOLD := 10
# What a defeated Pirate may leave where it fell, and the chance it does.
const DROP := &"bomb"
const DROP_CHANCE := 0.25
const INVULNERABLE_TIME := 0.3
const DEFEAT_TIME := 0.6
const DEFEAT_BLINK := 0.1
const PLAYER_GROUP := &"player"
# Where a bomb leaves its hand, facing right, and how far above a point it comes to rest there.
const HAND := Vector2(6, -18)
const BOMB_RADIUS := 4.0
# How far ahead of its feet it looks for floor, and how far below them.
const LOOK_AHEAD := 8.0
const LOOK_DOWN := 4.0
# A row of 24x24 frames facing right: on guard, walking x2, tell, rush, winded, wind-up, throw,
# hurt, defeated.
const SHEET := preload("res://assets/enemies/pirate/pirate_1.png")
const FRAME_SIZE := Vector2i(24, 24)
const ANIMATIONS := {
	&"guard": {frames = [0], fps = 1.0, loop = false},
	&"walk": {frames = [1, 2], fps = 6.0, loop = true},
	&"tell": {frames = [3], fps = 1.0, loop = false},
	&"rush": {frames = [4], fps = 1.0, loop = false},
	&"winded": {frames = [5], fps = 1.0, loop = false},
	&"wind_up": {frames = [6], fps = 1.0, loop = false},
	&"reload": {frames = [7, 0], fps = 4.0, loop = false},
	&"hurt": {frames = [8], fps = 1.0, loop = false},
	&"defeated": {frames = [9], fps = 1.0, loop = false},
}
const SHOWN := {
	PirateBrain.State.TELL: &"tell",
	PirateBrain.State.RUSH: &"rush",
	PirateBrain.State.WINDED: &"winded",
	PirateBrain.State.WIND_UP: &"wind_up",
	PirateBrain.State.RELOAD: &"reload",
	PirateBrain.State.HURT: &"hurt",
	PirateBrain.State.DEFEATED: &"defeated",
}

# Read-only for callers.
var brain: PirateBrain = PirateBrain.new()
var health: Health = Health.new(MAX_HEALTH)
var _struck: bool = false
var _defeat_left: float = DEFEAT_TIME
var _sounds: PirateSounds

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _touch: Hitbox = $TouchHitbox
@onready var _cutlass: Hitbox = $CutlassHitbox
@onready var _sound_players: Node = $Sounds


func _ready() -> void:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(&"guard"):
		_sprite.sprite_frames = _build_sprite_frames()
	if not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)
	if _sounds == null:
		_sounds = PirateSounds.new(_sound_players)
	_show()


func _physics_process(delta: float) -> void:
	health.step(delta)
	var previous := brain.state
	if previous != PirateBrain.State.DEFEATED:
		brain.step(_read_frame(), delta)
		if brain.state != previous:
			_sounds.play(PirateSounds.for_state_change(previous, brain.state))
		if brain.noticed:
			_sounds.play(PirateSounds.WHISTLE)
		if brain.threw:
			_throw()
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


func _read_frame() -> PirateBrain.Frame:
	var frame := PirateBrain.Frame.new()
	frame.position = global_position
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player != null:
		frame.sees_player = true
		frame.player_position = player.global_position
	frame.struck = _struck
	frame.on_floor = is_on_floor()
	frame.floor_ahead = _floor_ahead()
	frame.defeated = health.is_defeated()
	_struck = false
	return frame


# Whether its body, stepped a little ahead the way it faces, would stand on something.
func _floor_ahead() -> bool:
	var ahead := global_transform.translated(Vector2(LOOK_AHEAD * brain.facing, 0.0))
	return test_move(ahead, Vector2(0.0, LOOK_DOWN))


# A bomb leaves its hand into the Room, aimed to come to rest where the Player stood.
func _throw() -> void:
	var bomb := BOMB_SCENE.instantiate() as CharacterBody2D
	var room := get_parent() if get_parent() != null else self
	room.add_child(bomb)
	bomb.global_position = global_position + Vector2(HAND.x * brain.facing, HAND.y)
	bomb.call("launch", brain.throw_target + Vector2(0.0, -BOMB_RADIUS))


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
		animation = &"walk" if brain.velocity.x != 0.0 else &"guard"
	if _sprite.animation != animation:
		_sprite.play(animation)
	_sprite.flip_h = brain.facing < 0.0
	_cutlass.position.x = absf(_cutlass.position.x) * brain.facing
	var slashes := brain.cutlass_damage > 0
	if slashes:
		_cutlass.damage = brain.cutlass_damage
	if _cutlass.active != slashes:
		_cutlass.active = slashes
	var touches := brain.state != PirateBrain.State.DEFEATED
	if _touch.active != touches:
		_touch.active = touches


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
