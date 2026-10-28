extends CharacterBody2D

const PlayerController := preload("res://scripts/player/player_controller.gd")
const PlayerRig := preload("res://scripts/player/player_rig.gd")

@export var move_speed: float = 80.0
@export var acceleration: float = 600.0
@export var friction: float = 800.0
@export var jump_velocity: float = -260.0

# Read-only for callers; owns state, facing and horizontal movement rules.
var controller: PlayerController = PlayerController.new()
var _rig: PlayerRig
var _attack_finished: bool = false

@onready var _character_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _sword_sprite: AnimatedSprite2D = $SwordSprite


func _ready() -> void:
	controller.move_speed = move_speed
	controller.acceleration = acceleration
	controller.friction = friction
	controller.jump_velocity = jump_velocity
	if not controller.stepped.is_connected(_on_controller_stepped):
		controller.stepped.connect(_on_controller_stepped)
	if _rig == null:
		_rig = PlayerRig.new(_character_sprite, _sword_sprite)
		_rig.attack_finished.connect(_on_rig_attack_finished)
	_on_controller_stepped()


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


func _on_rig_attack_finished() -> void:
	_attack_finished = true


func _on_controller_stepped() -> void:
	_rig.show(controller.state, controller.facing, controller.is_moving)
