extends CharacterBody2D

# A Pirate bomb: a clay bomb a Pirate lobs at where the Player stands. It flies its arc, stops
# where it first lands and sits with its fuse sputtering, then bursts, striking the Player round
# it as it bursts. It never strikes an enemy, nor breaks a Breakable wall; a sword passes through.

const Hitbox := preload("res://scripts/combat/hitbox.gd")
# From its throw to its burst.
const FUSE_TIME := 1.2
# How long the burst plays, its blast live throughout.
const BURST_TIME := 0.25
# How long it takes to fly to where it was aimed.
const FLIGHT_TIME := 0.5
# A hit whose normal points this far up is a floor it lands on; anything else, it drops off.
const FLOOR_NORMAL := -0.5

var _time: float = 0.0
var _landed: bool = false
var _burst: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _blast: Hitbox = $Blast
@onready var _fuse_sound: AudioStreamPlayer2D = $Sounds/Fuse
@onready var _burst_sound: AudioStreamPlayer2D = $Sounds/Burst


func _ready() -> void:
	_sprite.play(&"fuse")
	_fuse_sound.play()


# Sets it flying from where it is to land on a point in the Room. Call once it is placed.
func launch(target: Vector2) -> void:
	var physics_delta := 1.0 / Engine.physics_ticks_per_second
	velocity = launch_velocity(target - global_position, FLIGHT_TIME, _gravity, physics_delta)


# The speed that carries it by an offset in a flight's time, flown a frame at a time with gravity
# added before each move.
static func launch_velocity(
	offset: Vector2, flight_time: float, gravity: float, delta: float
) -> Vector2:
	var rise := offset.y / flight_time - 0.5 * gravity * (flight_time + delta)
	return Vector2(offset.x / flight_time, rise)


func _physics_process(delta: float) -> void:
	_time += delta
	if _burst:
		if _time >= FUSE_TIME + BURST_TIME - 0.001:
			_blast.active = false
			queue_free()
		return
	if _time >= FUSE_TIME - 0.001:
		_burst_now()
		return
	if _landed:
		return
	velocity.y += _gravity * delta
	var hit := move_and_collide(velocity * delta)
	if hit == null:
		return
	if hit.get_normal().y <= FLOOR_NORMAL:
		_landed = true
		velocity = Vector2.ZERO
	else:
		velocity.x = 0.0


func _burst_now() -> void:
	_burst = true
	velocity = Vector2.ZERO
	_blast.active = true
	_sprite.play(&"burst")
	_fuse_sound.stop()
	_burst_sound.play()
