extends Node2D

# The Axe Throw: what a Charged Attack with the Stout Axe looses, a glowing copy of the axe that
# spins up and out along the Player's facing and falls in an arc. Like a Sword Beam it strikes the
# first thing in its way, charged, and stops there or at the world's terrain.

const Hitbox := preload("res://scripts/combat/hitbox.gd")
# How it leaves the hand, facing right, and how fast it turns, its way.
const THROW := Vector2(180.0, -210.0)
const SPIN := TAU * 3.0
# However far it falls, it is gone by then.
const LIFETIME := 1.5
# How bright the axe glows, as the sword does through a Charged Attack's swing.
const GLOW := Color(2.0, 2.0, 2.0)

# Set before it joins the world, the sheet being the held Weapon's (null keeps the scene's).
var facing: float = 1.0
var damage: int = Hitbox.DEFAULT_DAMAGE * 2
var sheet: Texture2D
var _velocity: Vector2
var _time: float = 0.0
# It met the terrain: one more step to strike a hurtbox there, then it is gone.
var _stopping: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var _hitbox: Hitbox = $Hitbox
@onready var _terrain: Area2D = $TerrainSensor
@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	_velocity = Vector2(THROW.x * facing, THROW.y)
	_hitbox.damage = damage
	_hitbox.charged = true
	_hitbox.active = true
	_hitbox.struck.connect(_on_struck)
	_terrain.body_entered.connect(_on_terrain_entered)
	if sheet != null:
		var axe := (_sprite.texture as AtlasTexture).duplicate() as AtlasTexture
		axe.atlas = sheet
		_sprite.texture = axe
	_sprite.modulate = GLOW
	_sprite.flip_h = facing > 0.0


func _physics_process(delta: float) -> void:
	if _stopping:
		queue_free()
		return
	_velocity.y += _gravity * delta
	position += _velocity * delta
	_sprite.rotation += facing * SPIN * delta
	_time += delta
	if _time >= LIFETIME - 0.001:
		queue_free()


# It stops at the first thing it strikes.
func _on_struck(_hurtbox: Area2D) -> void:
	_hitbox.active = false
	queue_free()


func _on_terrain_entered(_body: Node2D) -> void:
	_stopping = true
