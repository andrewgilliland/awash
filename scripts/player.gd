extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


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

	move_and_slide()
