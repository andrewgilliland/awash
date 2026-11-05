extends Node2D

# The Sword Beam: what a Charged Attack sends out along the Player's facing, a glowing copy of the
# blade that strikes the first thing in its way, charged, and stops there or at the world's
# terrain, or once it has flown its range.

const Hitbox := preload("res://scripts/combat/hitbox.gd")
const SPEED := 240.0
const RANGE := 240.0
# How bright the blade glows, as the sword does through a Charged Attack's swing.
const GLOW := Color(2.0, 2.0, 2.0)
# The fading copies trailing behind it: how far back each sits, and how faint it is.
const TRAIL_SPACING := 6.0
const TRAIL_ALPHAS: Array[float] = [0.45, 0.2]

# Set before it joins the world, the sheet being the held Weapon's (null keeps the scene's).
var facing: float = 1.0
var damage: int = Hitbox.DEFAULT_DAMAGE * 2
var sheet: Texture2D
var _travelled: float = 0.0
# It met the terrain: one more step to strike a hurtbox there, then it is gone.
var _stopping: bool = false

@onready var _hitbox: Hitbox = $Hitbox
@onready var _terrain: Area2D = $TerrainSensor
@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	_hitbox.damage = damage
	_hitbox.charged = true
	_hitbox.active = true
	_hitbox.struck.connect(_on_struck)
	_terrain.body_entered.connect(_on_terrain_entered)
	if sheet != null:
		var blade := (_sprite.texture as AtlasTexture).duplicate() as AtlasTexture
		blade.atlas = sheet
		_sprite.texture = blade
	_sprite.modulate = GLOW
	_sprite.flip_h = facing > 0.0
	for i in TRAIL_ALPHAS.size():
		var trail := _sprite.duplicate() as Sprite2D
		trail.name = "Trail%d" % (i + 1)
		trail.position.x = -facing * TRAIL_SPACING * (i + 1)
		trail.modulate = Color(GLOW, TRAIL_ALPHAS[i])
		add_child(trail)


func _physics_process(delta: float) -> void:
	if _stopping:
		queue_free()
		return
	var step := SPEED * delta
	position.x += facing * step
	_travelled += step
	if _travelled >= RANGE - 0.001:
		queue_free()


# It stops at the first thing it strikes.
func _on_struck(_hurtbox: Area2D) -> void:
	_hitbox.active = false
	queue_free()


func _on_terrain_entered(_body: Node2D) -> void:
	_stopping = true
