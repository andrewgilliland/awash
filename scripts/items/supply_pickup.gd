extends CharacterBody2D

# A Supply lying where a defeated enemy fell: it drops to the ground, glints, and the Player
# collects it by touching it. One the Player has no room for stays where it lies. It is lost if
# it falls with no ground under it.

const GLINT_EVERY := 1.0
const GLINT_TIME := 0.12
const GLINT := Color(1.8, 1.8, 1.8)
# Falling this long without landing means there is no ground below.
const LOST_AFTER := 3.0

@export var kind: StringName = &"brinecap"

var _time: float = 0.0
var _falling_time: float = 0.0

@onready var _reach: Area2D = $Reach
@onready var _sprite: Sprite2D = $Sprite2D


func _physics_process(delta: float) -> void:
	_time += delta
	_sprite.modulate = GLINT if fmod(_time, GLINT_EVERY) < GLINT_TIME else Color.WHITE
	if is_on_floor():
		velocity = Vector2.ZERO
		_falling_time = 0.0
	else:
		velocity += get_gravity() * delta
		_falling_time += delta
		if _falling_time > LOST_AFTER:
			queue_free()
			return
	move_and_slide()
	# Checked every frame, so a Player who makes room while standing on it still collects it.
	for body in _reach.get_overlapping_bodies():
		if body.has_method("collect") and body.call("collect", kind):
			queue_free()
			return
