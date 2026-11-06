extends CharacterBody2D

# A Bomb: lobbed from the Player's hand along its facing, it bounces once on the world's terrain
# and rests there while its fuse sputters, then bursts. Its blast strikes every enemy round it,
# charged, so it breaks what a Sword Beam breaks, and a blast, so it breaks a Breakable wall too,
# and never the Player.

const Hitbox := preload("res://scripts/combat/hitbox.gd")
const HitFeel := preload("res://scripts/combat/hit_feel.gd")
# How it leaves the hand, facing right.
const THROW := Vector2(100.0, -160.0)
const FUSE_TIME := 1.0
# How long the burst plays, its blast live throughout.
const BURST_TIME := 0.25
# What it keeps of its speed off its one bounce; after that it rests where it lands.
const BOUNCE := 0.4

# Set before it joins the world.
var facing: float = 1.0
var _time: float = 0.0
var _bounced: bool = false
var _burst: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _blast: Hitbox = $Blast
@onready var _fuse_sound: AudioStreamPlayer = $Sounds/Fuse
@onready var _burst_sound: AudioStreamPlayer = $Sounds/Burst


func _ready() -> void:
	velocity = Vector2(THROW.x * facing, THROW.y)
	_blast.charged = true
	_blast.blast = true
	_sprite.play(&"fuse")
	_fuse_sound.play()


func has_burst() -> bool:
	return _burst


func _physics_process(delta: float) -> void:
	_time += delta
	if _burst:
		if _time >= FUSE_TIME + BURST_TIME - 0.001:
			queue_free()
		return
	if _time >= FUSE_TIME - 0.001:
		_burst_now()
		return
	velocity.y += _gravity * delta
	var hit := move_and_collide(velocity * delta)
	if hit == null:
		return
	if _bounced:
		velocity = Vector2.ZERO
	else:
		_bounced = true
		velocity = velocity.bounce(hit.get_normal()) * BOUNCE


func _burst_now() -> void:
	_burst = true
	velocity = Vector2.ZERO
	_blast.active = true
	_sprite.play(&"burst")
	_fuse_sound.stop()
	_burst_sound.play()
	HitFeel.bomb_burst(self)
