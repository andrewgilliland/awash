extends "res://scripts/combat/hitbox.gd"

# A shockwave from a Boss striking the floor: it rolls along the floor away from where it struck,
# harming the Player it meets, and fades once past its reach. Jumping clears it.

const SPEED := 90.0
const LIFETIME := 1.8
const FRAME_TIME := 0.1

# Which way it rolls: -1 left, 1 right; and how long it rolls before it fades.
@export var direction: float = 1.0
@export var lifetime: float = LIFETIME

var _life_left: float = LIFETIME

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	super._ready()
	_life_left = lifetime
	active = true
	_sprite.flip_h = direction < 0.0


func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta
	_life_left -= delta
	_sprite.frame = int(_life_left / FRAME_TIME) % 2
	if _life_left <= 0.0:
		queue_free()
