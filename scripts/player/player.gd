extends CharacterBody2D

# The Player's Health ran out.
signal defeated

const PlayerController := preload("res://scripts/player/player_controller.gd")
const PlayerRig := preload("res://scripts/player/player_rig.gd")
const Health := preload("res://scripts/combat/health.gd")
const Level := preload("res://scripts/player/level.gd")
const Supplies := preload("res://scripts/items/supplies.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const PlayerSounds := preload("res://scripts/player/player_sounds.gd")
const INTERACTABLE_GROUP := &"interactable"
const INVULNERABLE_TIME := 1.0
const BLINK_TIME := 0.08
# A defeated Player flickers more slowly where it lies.
const DEFEAT_BLINK_TIME := 0.15
# Up and away from whatever struck the Player.
const KNOCKBACK := Vector2(90.0, -120.0)
# The sword's reach, in front of the Player when facing right.
const SWORD_OFFSET := Vector2(12.0, -8.0)
# A charged Attack costs this many times a quick one.
const CHARGED_MULTIPLIER := 2
# A full Charge makes the sword blink bright.
const CHARGED_GLOW := Color(2.0, 2.0, 2.0)
const CHARGED_BLINK_TIME := 0.08

@export var move_speed: float = 80.0
@export var acceleration: float = 600.0
@export var friction: float = 800.0
@export var jump_velocity: float = -260.0

# Read-only for callers; owns state, facing and horizontal movement rules.
var controller: PlayerController = PlayerController.new()
# Read-only for callers: change it through gain_experience().
var level: Level = Level.new()
# Read-only for callers.
var health: Health = Health.new(level.max_health())
# Read-only for callers: change it through collect() and use_supply().
var supplies: Supplies = Supplies.new()
# While true the Player ignores walk, jump and melee input: dialogue and the intro hold it
# still.
var controls_locked: bool = false
var _rig: PlayerRig
var _sounds: PlayerSounds
var _attack_finished: bool = false
var _knockback: Vector2 = Vector2.ZERO
var _defeated: bool = false
var _defeat_time: float = 0.0

@onready var _character_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _sword_sprite: AnimatedSprite2D = $SwordSprite
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _sword_hitbox: Hitbox = $SwordHitbox
@onready var _sound_players: Node = $Sounds
@onready var _level_up: Label = $LevelUp


func _ready() -> void:
	var run := get_node_or_null("/root/RunState")
	if run != null:
		level = Level.new(run.get("player_experience"))
		health = Health.new(level.max_health(), run.get("player_health"))
		supplies = Supplies.new(run.get("player_supplies"))
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


# Carries one more of a kind of Supply, with a pickup sound, and returns whether there was room.
func collect(kind: StringName) -> bool:
	if not supplies.add(kind):
		return false
	_write_supplies_to_run()
	_sounds.play(PlayerSounds.PICKUP)
	return true


# Uses one Supply of a kind, as chosen on the Supplies Panel: a Restorative restores its Health.
# Returns whether it did. Nothing is spent with none carried, at full Health, or while the
# Player is held still or defeated.
func use_supply(kind: StringName) -> bool:
	if supplies.count(kind) <= 0 or controls_locked or _defeated:
		return false
	if health.current >= health.maximum:
		return false
	health.heal(Supplies.KINDS[kind].restores)
	supplies.spend(kind)
	_write_supplies_to_run()
	var run := _get_run()
	if run != null:
		run.set("player_health", health.current)
	_sounds.play(PlayerSounds.EAT)
	return true


func _write_supplies_to_run() -> void:
	var run := _get_run()
	if run != null:
		run.set("player_supplies", supplies.to_counts())


# Null outside the tree or without the autoload, as in headless tests.
func _get_run() -> Node:
	return get_node_or_null("/root/RunState") if is_inside_tree() else null


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
	if _defeated:
		# Down where it lands, flickering until the Room gives way.
		_defeat_time += delta
		if is_on_floor():
			_rig.show_lying(true)
		_rig.show_blink(fmod(_defeat_time, DEFEAT_BLINK_TIME * 2.0) < DEFEAT_BLINK_TIME)
		return
	var blink_lit := fmod(health.invulnerable_left, BLINK_TIME * 2.0) < BLINK_TIME
	_rig.show_blink(health.invulnerable_left <= 0.0 or blink_lit)


# Adds Experience toward the next Level. Reaching one raises maximum Health and Strength, chimes
# and shows LEVEL UP; the Run keeps the total and the Health that comes with it.
func gain_experience(amount: int) -> void:
	var before := level.max_health()
	var gained := level.gain(amount)
	var run := get_node_or_null("/root/RunState") if is_inside_tree() else null
	if run != null:
		run.set("player_experience", level.experience)
	if gained == 0:
		return
	health.raise_maximum(level.max_health() - before)
	if run != null:
		run.set("player_health", health.current)
	_sounds.play(PlayerSounds.LEVEL_UP)
	_level_up.call("flash")


# Whether the Player's Health has run out: it no longer answers the controls.
func is_defeated() -> bool:
	return _defeated


func _read_frame() -> PlayerController.Frame:
	var frame := PlayerController.Frame.new()
	if not controls_locked and not _defeated:
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
	var damage: int = hitbox.damage if hitbox is Hitbox else Hitbox.DEFAULT_DAMAGE
	if not health.hurt(damage, INVULNERABLE_TIME):
		return
	var away := signf(global_position.x - hitbox.global_position.x)
	if away == 0.0:
		away = -controller.facing
	_knockback = Vector2(KNOCKBACK.x * away, KNOCKBACK.y)
	var run := get_node_or_null("/root/RunState")
	if run != null:
		run.set("player_health", health.current)
	if health.is_defeated():
		_defeated = true
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
	if attacking:
		var quick := Hitbox.DEFAULT_DAMAGE + level.strength()
		_sword_hitbox.damage = quick * CHARGED_MULTIPLIER if controller.charged_attack else quick
	if _sword_hitbox.active != attacking:
		_sword_hitbox.active = attacking
	var lit := (
		controller.is_fully_charged()
		and fmod(controller.time_in_state, CHARGED_BLINK_TIME * 2.0) < CHARGED_BLINK_TIME
	)
	_sword_sprite.modulate = CHARGED_GLOW if lit else Color.WHITE


func _on_controller_state_changed(
	previous: PlayerController.State, next: PlayerController.State
) -> void:
	_sounds.play(PlayerSounds.for_state_change(previous, next, controller.time_in_state))


func _on_sword_struck(_hurtbox: Area2D) -> void:
	_sounds.play(PlayerSounds.HIT)
