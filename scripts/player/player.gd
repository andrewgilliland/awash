extends CharacterBody2D

# The Player's Health ran out.
signal defeated

const PlayerController := preload("res://scripts/player/player_controller.gd")
const PlayerRig := preload("res://scripts/player/player_rig.gd")
const Health := preload("res://scripts/combat/health.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const PlayerSounds := preload("res://scripts/player/player_sounds.gd")
const INTERACTABLE_GROUP := &"interactable"
const MAX_HEALTH := 5
const INVULNERABLE_TIME := 1.0
const BLINK_TIME := 0.08
# Up and away from whatever struck the Player.
const KNOCKBACK := Vector2(90.0, -120.0)
# The sword's reach, in front of the Player when facing right.
const SWORD_OFFSET := Vector2(12.0, -8.0)

@export var move_speed: float = 80.0
@export var acceleration: float = 600.0
@export var friction: float = 800.0
@export var jump_velocity: float = -260.0

# Read-only for callers; owns state, facing and horizontal movement rules.
var controller: PlayerController = PlayerController.new()
# Read-only for callers.
var health: Health = Health.new(MAX_HEALTH)
# While true the Player ignores walk, jump and melee input: dialogue and the intro hold it
# still.
var controls_locked: bool = false
var _rig: PlayerRig
var _sounds: PlayerSounds
var _attack_finished: bool = false
var _knockback: Vector2 = Vector2.ZERO

@onready var _character_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _sword_sprite: AnimatedSprite2D = $SwordSprite
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _sword_hitbox: Hitbox = $SwordHitbox
@onready var _sound_players: Node = $Sounds


func _ready() -> void:
	controller.move_speed = move_speed
	controller.acceleration = acceleration
	controller.friction = friction
	controller.jump_velocity = jump_velocity
	if not controller.stepped.is_connected(_on_controller_stepped):
		controller.stepped.connect(_on_controller_stepped)
	if not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)
	if _rig == null:
		_rig = PlayerRig.new(_character_sprite, _sword_sprite)
		_rig.attack_finished.connect(_on_rig_attack_finished)
	if _sounds == null:
		_sounds = PlayerSounds.new(_sound_players)
		controller.state_changed.connect(_on_controller_state_changed)
		controller.jumped.connect(_sounds.play.bind(PlayerSounds.JUMP))
		_sword_hitbox.struck.connect(_on_sword_struck)
	_on_controller_stepped()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and not event.is_echo() and interact() != null:
		get_viewport().set_input_as_handled()


# Uses the nearest Interactable in reach, and returns it; null when none is in reach or the
# Player is held still.
func interact() -> Node2D:
	if controls_locked or not is_inside_tree():
		return null
	var nearest: Node2D = null
	for target: Node2D in get_tree().get_nodes_in_group(INTERACTABLE_GROUP):
		if not target.call("reaches", self):
			continue
		var closer := nearest == null
		if not closer:
			var here := global_position.distance_to(target.global_position)
			closer = here < global_position.distance_to(nearest.global_position)
		if closer:
			nearest = target
	if nearest != null:
		nearest.call("use", self)
	return nearest


func _physics_process(delta: float) -> void:
	health.step(delta)
	controller.step(_read_frame(), delta)
	velocity = controller.velocity
	_apply_gravity(delta)
	move_and_slide()
	var blink_lit := fmod(health.invulnerable_left, BLINK_TIME * 2.0) < BLINK_TIME
	_rig.show_blink(health.invulnerable_left <= 0.0 or blink_lit)


func _read_frame() -> PlayerController.Frame:
	var frame := PlayerController.Frame.new()
	if not controls_locked:
		frame.direction = Input.get_axis(&"move_left", &"move_right")
		frame.jump_pressed = Input.is_action_just_pressed(&"jump")
		frame.melee_held = Input.is_action_pressed(&"melee_attack")
	frame.on_floor = is_on_floor()
	frame.attack_finished = _attack_finished
	frame.velocity = velocity
	frame.knockback = _knockback
	_attack_finished = false
	_knockback = Vector2.ZERO
	return frame


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _on_rig_attack_finished() -> void:
	_attack_finished = true


# A hit costs Health and throws the Player away from the hitbox, unless invulnerable.
func _on_hurtbox_hit(hitbox: Area2D) -> void:
	var damage: int = hitbox.damage if hitbox is Hitbox else 1
	if not health.hurt(damage, INVULNERABLE_TIME):
		return
	var away := signf(global_position.x - hitbox.global_position.x)
	if away == 0.0:
		away = -controller.facing
	_knockback = Vector2(KNOCKBACK.x * away, KNOCKBACK.y)
	if health.is_defeated():
		_sounds.play(PlayerSounds.DEFEAT)
		defeated.emit()
	else:
		_sounds.play(PlayerSounds.HURT)


# Lies the Player down on its side, as when it washes up, or stands it back up.
func set_lying(lying: bool) -> void:
	_rig.show_lying(lying)


func _on_controller_stepped() -> void:
	_rig.show(controller.state, controller.facing, controller.is_moving)
	_sword_hitbox.position = Vector2(SWORD_OFFSET.x * controller.facing, SWORD_OFFSET.y)
	var attacking := controller.state == PlayerController.State.ATTACK
	if _sword_hitbox.active != attacking:
		_sword_hitbox.active = attacking


func _on_controller_state_changed(
	previous: PlayerController.State, next: PlayerController.State
) -> void:
	_sounds.play(PlayerSounds.for_state_change(previous, next, controller.time_in_state))


func _on_sword_struck(_hurtbox: Area2D) -> void:
	_sounds.play(PlayerSounds.HIT)
