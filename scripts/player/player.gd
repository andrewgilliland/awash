extends CharacterBody2D

const PlayerController := preload("res://scripts/player/player_controller.gd")
const PLAYER_SPRITE_SHEET := preload("res://assets/sprites/player_1.png")
const SWORD_SPRITE_SHEET := preload("res://assets/sprites/weapons/sword_1.png")
const FRAME_SIZE := Vector2i(16, 16)
const IDLE_FRAMES: Array[int] = [0]
const WALK_FRAMES: Array[int] = [0, 1]
const JUMP_FRAMES: Array[int] = [2, 3, 4]
const ATTACK_FRAMES: Array[int] = [5, 6]
const SWORD_CHARGE_FRAMES: Array[int] = [1]
const SWORD_ATTACK_FRAMES: Array[int] = [0, 1]

@export var move_speed: float = 80.0
@export var acceleration: float = 600.0
@export var friction: float = 800.0
@export var jump_velocity: float = -260.0
@export var walk_animation_fps: float = 8.0
@export var jump_animation_fps: float = 8.0
@export var attack_animation_fps: float = 10.0
@export var sword_charge_offset: Vector2 = Vector2(11.0, 0.0)
@export var sword_attack_frame_offsets: Array[Vector2] = [
	Vector2(12.0, -12.0),
	Vector2(16.0, 0.0),
]

# Read-only for callers; owns state, facing and horizontal movement rules.
var controller: PlayerController = PlayerController.new()
var _attack_finished: bool = false

@onready var _character_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _sword_sprite: AnimatedSprite2D = $SwordSprite


func _ready() -> void:
	controller.move_speed = move_speed
	controller.acceleration = acceleration
	controller.friction = friction
	controller.jump_velocity = jump_velocity
	if not controller.state_changed.is_connected(_on_state_changed):
		controller.state_changed.connect(_on_state_changed)
	if not controller.stepped.is_connected(_on_controller_stepped):
		controller.stepped.connect(_on_controller_stepped)

	_character_sprite.sprite_frames = _build_character_sprite_frames()
	_sword_sprite.sprite_frames = _build_sword_sprite_frames()
	_sword_sprite.visible = false
	if not _character_sprite.animation_finished.is_connected(_on_character_animation_finished):
		_character_sprite.animation_finished.connect(_on_character_animation_finished)
	if not _sword_sprite.frame_changed.is_connected(_update_sword_position):
		_sword_sprite.frame_changed.connect(_update_sword_position)
	_character_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	controller.step(_read_frame(), delta)
	velocity = controller.velocity
	_apply_gravity(delta)
	move_and_slide()


func _read_frame() -> PlayerController.Frame:
	var frame := PlayerController.Frame.new()
	frame.direction = Input.get_axis(&"move_left", &"move_right")
	frame.jump_pressed = Input.is_action_just_pressed(&"jump")
	frame.melee_held = Input.is_action_pressed(&"melee_attack")
	frame.on_floor = is_on_floor()
	frame.attack_finished = _attack_finished
	frame.velocity = velocity
	_attack_finished = false
	return frame


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _on_character_animation_finished() -> void:
	if _character_sprite.animation == &"attack":
		_attack_finished = true


func _on_controller_stepped() -> void:
	_character_sprite.flip_h = controller.facing > 0.0
	_sword_sprite.flip_h = _character_sprite.flip_h
	if controller.state == PlayerController.State.CHARGE:
		var pose := &"walk" if controller.is_moving else &"idle"
		if _character_sprite.animation != pose:
			_character_sprite.play(pose)
	_update_sword_position()


func _update_sword_position() -> void:
	if controller.state == PlayerController.State.CHARGE:
		_sword_sprite.position = (
			_character_sprite.position
			+ Vector2(sword_charge_offset.x * controller.facing, sword_charge_offset.y)
		)
		return

	if sword_attack_frame_offsets.is_empty():
		return

	var offset_index := clampi(_sword_sprite.frame, 0, sword_attack_frame_offsets.size() - 1)
	var frame_offset := sword_attack_frame_offsets[offset_index]
	_sword_sprite.position = (
		_character_sprite.position + Vector2(frame_offset.x * controller.facing, frame_offset.y)
	)


func _on_state_changed(_previous: PlayerController.State, next: PlayerController.State) -> void:
	match next:
		PlayerController.State.WALK:
			_hide_sword()
			_character_sprite.play(&"walk")
		PlayerController.State.JUMP:
			_hide_sword()
			_character_sprite.play(&"jump")
		PlayerController.State.IDLE:
			_hide_sword()
			_character_sprite.play(&"idle")
		PlayerController.State.CHARGE:
			_sword_sprite.visible = true
			_sword_sprite.play(&"charge")
			_character_sprite.play(&"idle")
		PlayerController.State.ATTACK:
			_sword_sprite.visible = true
			_character_sprite.play(&"attack")
			_sword_sprite.play(&"attack")


func _hide_sword() -> void:
	_sword_sprite.stop()
	_sword_sprite.visible = false


func _build_character_sprite_frames() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	_add_animation(sprite_frames, PLAYER_SPRITE_SHEET, &"idle", IDLE_FRAMES, 1.0, true)
	_add_animation(
		sprite_frames, PLAYER_SPRITE_SHEET, &"walk", WALK_FRAMES, walk_animation_fps, true
	)
	_add_animation(
		sprite_frames, PLAYER_SPRITE_SHEET, &"jump", JUMP_FRAMES, jump_animation_fps, false
	)
	_add_animation(
		sprite_frames, PLAYER_SPRITE_SHEET, &"attack", ATTACK_FRAMES, attack_animation_fps, false
	)
	return sprite_frames


func _build_sword_sprite_frames() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	_add_animation(sprite_frames, SWORD_SPRITE_SHEET, &"charge", SWORD_CHARGE_FRAMES, 1.0, true)
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
