extends CharacterBody2D

enum PlayerState {
	IDLE,
	WALK,
	ATTACK,
}

const PLAYER_SPRITE_SHEET := preload("res://assets/sprites/player_1.png")
const SWORD_SPRITE_SHEET := preload("res://assets/sprites/weapons/sword_1.png")
const FRAME_SIZE := Vector2i(16, 16)
const IDLE_FRAMES: Array[int] = [0]
const WALK_FRAMES: Array[int] = [0, 1]
const ATTACK_FRAMES: Array[int] = [5, 6]
const SWORD_ATTACK_FRAMES: Array[int] = [0, 1]

@export var move_speed: float = 80.0
@export var acceleration: float = 600.0
@export var friction: float = 800.0
@export var walk_animation_fps: float = 8.0
@export var attack_animation_fps: float = 10.0
@export var sword_attack_frame_offsets: Array[Vector2] = [
	Vector2(12.0, -12.0),
	Vector2(16.0, 0.0),
]

var _state: PlayerState = PlayerState.IDLE
var _facing_direction: float = -1.0

@onready var _character_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _sword_sprite: AnimatedSprite2D = $SwordSprite


func _ready() -> void:
	_character_sprite.sprite_frames = _build_character_sprite_frames()
	_sword_sprite.sprite_frames = _build_sword_sprite_frames()
	_sword_sprite.visible = false
	if not _character_sprite.animation_finished.is_connected(_on_character_animation_finished):
		_character_sprite.animation_finished.connect(_on_character_animation_finished)
	if not _sword_sprite.frame_changed.is_connected(_update_sword_position):
		_sword_sprite.frame_changed.connect(_update_sword_position)
	_character_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	_handle_attack_input()
	_update_horizontal_movement(delta)
	_apply_gravity(delta)
	move_and_slide()


func _handle_attack_input() -> void:
	if Input.is_action_just_pressed(&"melee_attack") and _state != PlayerState.ATTACK:
		_start_attack()


func _update_horizontal_movement(delta: float) -> void:
	var direction := Input.get_axis(&"move_left", &"move_right")

	if _state == PlayerState.ATTACK:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	elif direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * delta)
		_update_facing(direction)
		_set_state(PlayerState.WALK)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		_set_state(PlayerState.IDLE)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _update_facing(direction: float) -> void:
	_facing_direction = signf(direction)
	_character_sprite.flip_h = direction > 0.0
	_sword_sprite.flip_h = _character_sprite.flip_h
	_update_sword_position()


func _update_sword_position() -> void:
	if sword_attack_frame_offsets.is_empty():
		return

	var offset_index := clampi(_sword_sprite.frame, 0, sword_attack_frame_offsets.size() - 1)
	var frame_offset := sword_attack_frame_offsets[offset_index]
	_sword_sprite.position = (
		_character_sprite.position + Vector2(frame_offset.x * _facing_direction, frame_offset.y)
	)


func _start_attack() -> void:
	_set_state(PlayerState.ATTACK)


func _on_character_animation_finished() -> void:
	if _state != PlayerState.ATTACK or _character_sprite.animation != &"attack":
		return

	_set_state(PlayerState.IDLE)


func _set_state(next_state: PlayerState) -> void:
	if _state == next_state:
		return

	_state = next_state
	match _state:
		PlayerState.WALK:
			_sword_sprite.visible = false
			_character_sprite.play(&"walk")
		PlayerState.IDLE:
			_sword_sprite.stop()
			_sword_sprite.visible = false
			_character_sprite.play(&"idle")
		PlayerState.ATTACK:
			_sword_sprite.visible = true
			_character_sprite.play(&"attack")
			_sword_sprite.play(&"attack")
			_update_sword_position()


func _build_character_sprite_frames() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	_add_animation(sprite_frames, PLAYER_SPRITE_SHEET, &"idle", IDLE_FRAMES, 1.0, true)
	_add_animation(
		sprite_frames, PLAYER_SPRITE_SHEET, &"walk", WALK_FRAMES, walk_animation_fps, true
	)
	_add_animation(
		sprite_frames, PLAYER_SPRITE_SHEET, &"attack", ATTACK_FRAMES, attack_animation_fps, false
	)
	return sprite_frames


func _build_sword_sprite_frames() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	_add_animation(
		sprite_frames,
		SWORD_SPRITE_SHEET,
		&"attack",
		SWORD_ATTACK_FRAMES,
		attack_animation_fps,
		false
	)
	return sprite_frames


func _add_animation(
	sprite_frames: SpriteFrames,
	sprite_sheet: Texture2D,
	animation_name: StringName,
	frame_indices: Array[int],
	frames_per_second: float,
	looped: bool
) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_loop(animation_name, looped)
	sprite_frames.set_animation_speed(animation_name, frames_per_second)

	for frame_index in frame_indices:
		var frame := AtlasTexture.new()
		frame.atlas = sprite_sheet
		frame.region = Rect2(int(frame_index) * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		sprite_frames.add_frame(animation_name, frame)
