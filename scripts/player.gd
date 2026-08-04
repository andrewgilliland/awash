extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@export var animation_frame_offsets: Dictionary = {
	"attack_1":
	{
		1: Vector2(0.0, -6.0),
	},
}

var _sprite_base_position: Vector2 = Vector2.ZERO

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if _animated_sprite != null:
		_sprite_base_position = _animated_sprite.position


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if _animated_sprite != null and _animated_sprite.sprite_frames != null:
		if (
			Input.is_action_just_pressed("melee_attack")
			and _animated_sprite.sprite_frames.has_animation(&"attack_1")
		):
			_animated_sprite.play(&"attack_1")

		if _animated_sprite.animation == &"attack_1" and _animated_sprite.is_playing():
			_apply_animation_frame_offset()
			velocity.x = 0.0
			move_and_slide()
			return

		if direction:
			_animated_sprite.flip_h = direction < 0.0

		if not is_on_floor():
			if _animated_sprite.sprite_frames.has_animation(&"jump"):
				_animated_sprite.play(&"jump")
		elif direction and _animated_sprite.sprite_frames.has_animation(&"walk_1"):
			_animated_sprite.play(&"walk_1")
		elif _animated_sprite.sprite_frames.has_animation(&"idle"):
			_animated_sprite.play(&"idle")

		_apply_animation_frame_offset()

	move_and_slide()


func _apply_animation_frame_offset() -> void:
	if _animated_sprite == null:
		return

	var animation_key := String(_animated_sprite.animation)
	if not animation_frame_offsets.has(animation_key):
		_animated_sprite.position = _sprite_base_position
		return

	var existing: Variant = animation_frame_offsets[animation_key]
	if existing is Vector2:
		var absolute_offset := existing as Vector2
		if _animated_sprite.flip_h:
			absolute_offset.x = -absolute_offset.x
		_animated_sprite.position = _sprite_base_position + absolute_offset
		return

	if existing is Dictionary:
		var frame_offsets := existing as Dictionary
		var frame_index := _animated_sprite.frame
		if frame_offsets.has(frame_index):
			var frame_value: Variant = frame_offsets[frame_index]
			if frame_value is Vector2:
				var absolute_frame_offset := frame_value as Vector2
				if _animated_sprite.flip_h:
					absolute_frame_offset.x = -absolute_frame_offset.x
				_animated_sprite.position = _sprite_base_position + absolute_frame_offset
				return

		if frame_offsets.has("default"):
			var fallback: Variant = frame_offsets["default"]
			if fallback is Vector2:
				var absolute_default_offset := fallback as Vector2
				if _animated_sprite.flip_h:
					absolute_default_offset.x = -absolute_default_offset.x
				_animated_sprite.position = _sprite_base_position + absolute_default_offset
				return

	_animated_sprite.position = _sprite_base_position
