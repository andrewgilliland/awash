extends "res://scripts/combat/hitbox.gd"

# A chunk of reef the Reefback throws: it arcs from the Reefback's hands to the spot the Player
# stood on, harming the Player it strikes on the way, and shatters where it lands or hits.

const FLIGHT_TIME := 0.75
const ARC_HEIGHT := 40.0
const SHATTER_TIME := 0.25
const SPIN_TIME := 0.1
const SHATTERED_FRAME := 2

# Where it lands, in the Room.
@export var target: Vector2 = Vector2.ZERO

var _from: Vector2
var _flown: float = 0.0
var _shatter_left: float = -1.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	super._ready()
	damage = 15
	active = true
	struck.connect(_on_struck)


func _physics_process(delta: float) -> void:
	if _shatter_left >= 0.0:
		_shatter_left -= delta
		if _shatter_left <= 0.0:
			queue_free()
		return
	if _flown == 0.0:
		_from = global_position
	_flown = minf(_flown + delta, FLIGHT_TIME)
	var t := _flown / FLIGHT_TIME
	global_position = _from.lerp(target, t) - Vector2(0.0, ARC_HEIGHT * 4.0 * t * (1.0 - t))
	_sprite.frame = int(_flown / SPIN_TIME) % 2
	if t >= 1.0:
		_shatter()


func _on_struck(_hurtbox: Area2D) -> void:
	_shatter()
	active = false


func _shatter() -> void:
	_sprite.frame = SHATTERED_FRAME
	_shatter_left = SHATTER_TIME
