extends "res://scripts/combat/hitbox.gd"

# A slam's rune shockwave: it rolls along the floor away from the Nameless Warden, harming the
# Player it meets, and fades once past its reach. Jumping clears it.

const SPEED := 90.0
const LIFETIME := 1.8
const FRAME_TIME := 0.1

# Which way it rolls: -1 left, 1 right.
@export var direction: float = 1.0

var _life_left: float = LIFETIME

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	super._ready()
	active = true
	_sprite.flip_h = direction < 0.0


func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta
	_life_left -= delta
	_sprite.frame = int(_life_left / FRAME_TIME) % 2
	if _life_left <= 0.0:
		queue_free()
