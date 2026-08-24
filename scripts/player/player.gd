extends CharacterBody2D

enum PlayerState {
	IDLE,
	WALK,
}

const PLAYER_SPRITE_SHEET := preload("res://assets/sprites/player_1.png")
const FRAME_SIZE := Vector2i(16, 16)

@export var move_speed: float = 80.0
@export var acceleration: float = 600.0
@export var friction: float = 800.0
@export var walk_animation_fps: float = 8.0

var _state: PlayerState = PlayerState.IDLE

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_sprite.sprite_frames = _build_sprite_frames()
	_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis(&"move_left", &"move_right")
	var target_velocity := direction * move_speed

	if direction != 0.0:
		velocity.x = move_toward(velocity.x, target_velocity, acceleration * delta)
		_sprite.flip_h = direction < 0.0
		_set_state(PlayerState.WALK)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		_set_state(PlayerState.IDLE)

	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()


func _set_state(next_state: PlayerState) -> void:
	if _state == next_state:
		return

	_state = next_state
	_sprite.play(&"walk" if _state == PlayerState.WALK else &"idle")


func _build_sprite_frames() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	_add_animation(sprite_frames, &"idle", [0], 1.0)
	_add_animation(sprite_frames, &"walk", [0, 1], walk_animation_fps)
	return sprite_frames


func _add_animation(
	sprite_frames: SpriteFrames,
	animation_name: StringName,
	frame_indices: Array,
	frames_per_second: float
) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_loop(animation_name, true)
	sprite_frames.set_animation_speed(animation_name, frames_per_second)

	for frame_index in frame_indices:
		var frame := AtlasTexture.new()
		frame.atlas = PLAYER_SPRITE_SHEET
		frame.region = Rect2(int(frame_index) * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		sprite_frames.add_frame(animation_name, frame)
