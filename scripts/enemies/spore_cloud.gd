extends Node2D

# A cloud of spores the Spore Beast vents when struck: it stays where it burst, strikes a Player
# inside it as it bursts or as they step in, and fades away.

const Hitbox := preload("res://scripts/combat/hitbox.gd")
const GROUP := &"spore_cloud"
const DAMAGE := 8
const LIFETIME := 1.5
# How long before it is gone that it thins.
const THINNING := 0.5
const SHEET := preload("res://assets/enemies/spore_beast/spore_beast_1.png")
const FRAME_SIZE := Vector2i(48, 48)
const ROW := 24
const ANIMATION := &"burst"
# Bursting, full, thinning.
const FRAMES := [0, 1, 2]

var _left: float = LIFETIME

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hitbox: Hitbox = $Hitbox


func _ready() -> void:
	add_to_group(GROUP)
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(ANIMATION):
		_sprite.sprite_frames = _build_frames()
	_sprite.animation = ANIMATION
	_sprite.frame = 0
	_hitbox.damage = DAMAGE
	_hitbox.active = true


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_hitbox.active = false
		queue_free()
		return
	_sprite.frame = 2 if _left <= THINNING else (0 if _left > LIFETIME - 0.1 else 1)


static func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(ANIMATION)
	frames.set_animation_loop(ANIMATION, false)
	for index in FRAMES:
		var frame := AtlasTexture.new()
		frame.atlas = SHEET
		frame.region = Rect2(Vector2(index * FRAME_SIZE.x, ROW), Vector2(FRAME_SIZE))
		frames.add_frame(ANIMATION, frame)
	return frames
