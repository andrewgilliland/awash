extends CharacterBody2D

# Rusk, the Low Canopy Jungle's Boss: Ilyr's enforcer, with an oversized branded maul. His brain
# decides each move; this body shows it, holds his Health and his plate, speaks his words through
# the dialogue box, and leaps away when he is beaten. Charging, his plate turns aside quick hits
# on his front; otherwise every hit lands while he fights. Before and after, he takes none.

# His Health ran out; the Room hands his Experience to the Player.
signal defeated(experience: int)
# He woke and speaks.
signal woke
# He drives his maul down and the roots rise: the fight begins.
signal fight_began
# He leaps away, beaten.
signal retreated

const RuskBrain := preload("res://scripts/enemies/rusk_brain.gd")
const Health := preload("res://scripts/combat/health.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const HitFeel := preload("res://scripts/combat/hit_feel.gd")
const RuskSounds := preload("res://scripts/enemies/rusk_sounds.gd")
# What the Boss Health bar calls him, and the id the Run remembers this fight by.
const BOSS_NAME := "Rusk"
const BOSS_ID := &"rusk_jungle"
const MAX_HEALTH := 200
# What beating him earns the Player.
const EXPERIENCE := 150
const GOLD := 0
# A Boss leaves nothing where he falls.
const DROP_CHANCE := 0.0
const INVULNERABLE_TIME := 0.3
const TOUCH_DAMAGE := 10
const CHARGE_DAMAGE := 15
const SLAM_DAMAGE := 20
const QUAKE_DAMAGE := 6
# How long the quake strikes the floor as the maul lands.
const QUAKE_TIME := 0.1
# How far in front of him the maul's blow is centred.
const MAUL_REACH := 28.0
const LEAP_VELOCITY := Vector2(110.0, -240.0)
# How often his stride changes as he charges.
const STRIDE_TIME := 0.1
const BRAND_DIM := 0.45
const BRAND_HURRIED := Vector2(0.75, 1.0)
const BRAND_FLICKER := 0.06
const PLAYER_GROUP := &"player"
const DIALOGUE_GROUP := &"dialogue_box"
const WAKE_LINES := [
	["RUSK", "Vael. You're a dead man."],
	["RUSK", "You should have stayed beneath the waves."],
]
const RETREAT_LINES := [
	["RUSK", "Ilyr pays his debts. So do I."],
	["RUSK", "This isn't over."],
]
# Two rows of 48x48 cells: his poses facing right, then his brand's glow alone on each.
const POSES := 10
const CHARGE_POSE := 3
const POSE := {
	RuskBrain.State.DORMANT: 0,
	RuskBrain.State.SPEAKING: 0,
	RuskBrain.State.SUMMONING: 1,
	RuskBrain.State.REST: 0,
	RuskBrain.State.TELL: 2,
	RuskBrain.State.CHARGE: CHARGE_POSE,
	RuskBrain.State.DAZED: 5,
	RuskBrain.State.WIND_UP: 6,
	RuskBrain.State.SLAM: 7,
	RuskBrain.State.KNEEL: 8,
	RuskBrain.State.LEAP: 9,
	RuskBrain.State.GONE: 9,
}

# Read-only for callers.
var brain: RuskBrain = RuskBrain.new()
var health: Health = Health.new(MAX_HEALTH)
var _words_read: bool = false
var _met_wall: bool = false
var _quake_left: float = 0.0
var _clock: float = 0.0
var _leap_velocity: Vector2 = Vector2.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _sounds: RuskSounds

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _brand: Sprite2D = $Brand
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _touch: Hitbox = $TouchHitbox
@onready var _maul: Hitbox = $MaulHitbox
@onready var _quake: Hitbox = $QuakeHitbox
@onready var _sound_players: Node = $Sounds


func _ready() -> void:
	if not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)
	if _sounds == null:
		_sounds = RuskSounds.new(_sound_players)
	_touch.damage = TOUCH_DAMAGE
	_maul.damage = SLAM_DAMAGE
	_quake.damage = QUAKE_DAMAGE
	_show()


# Between the roots rising and his kneel: while this holds, the Boss Health bar shows.
func is_fighting() -> bool:
	return brain.is_fighting() and not health.is_defeated()


func _physics_process(delta: float) -> void:
	health.step(delta)
	_clock += delta
	var previous := brain.state
	brain.step(_read_frame(), delta)
	if brain.state != previous:
		_sounds.play(RuskSounds.for_state_change(previous, brain.state))
		_on_entered(brain.state)
	if brain.roots_called:
		fight_began.emit()
	if brain.crashed:
		_sounds.play(RuskSounds.CRASH)
		HitFeel.slam(self)
	if brain.slammed:
		HitFeel.slam(self)
	if brain.state == RuskBrain.State.GONE:
		queue_free()
		return
	if brain.state == RuskBrain.State.LEAP:
		_leap_velocity.y += _gravity * delta
		position += _leap_velocity * delta
	else:
		velocity.x = brain.velocity.x
		if not is_on_floor():
			velocity.y += _gravity * delta
		move_and_slide()
		_met_wall = brain.charging() and is_on_wall()
	_show_quake(delta)
	_show()


func _read_frame() -> RuskBrain.Frame:
	var frame := RuskBrain.Frame.new()
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player != null:
		frame.sees_player = true
		frame.player_offset = player.global_position - global_position
	frame.health_share = float(health.current) / float(health.maximum)
	# With no dialogue box to read them in, whatever he says counts as read.
	frame.words_read = _words_read or _dialogue_box() == null
	frame.met_wall = _met_wall
	frame.defeated = health.is_defeated()
	_met_wall = false
	return frame


func _on_entered(state: RuskBrain.State) -> void:
	match state:
		RuskBrain.State.SPEAKING:
			woke.emit()
			_speak(WAKE_LINES)
		RuskBrain.State.KNEEL:
			_speak(RETREAT_LINES)
		RuskBrain.State.LEAP:
			_leap()


func _speak(lines: Array) -> void:
	_words_read = false
	var box := _dialogue_box()
	if box == null:
		return
	box.connect(&"closed", _on_words_read, CONNECT_ONE_SHOT)
	box.call("show_lines", lines, self)


func _on_words_read() -> void:
	_words_read = true


func _dialogue_box() -> Node:
	return get_tree().get_first_node_in_group(DIALOGUE_GROUP) if is_inside_tree() else null


# Up and away east, over the roots and off the cliff's edge, through whatever stands in the way.
func _leap() -> void:
	_leap_velocity = LEAP_VELOCITY
	_shape.disabled = true
	retreated.emit()


# Charging, his plate turns aside a quick hit on his front; any other hit lands while he fights.
func _on_hurtbox_hit(hitbox: Area2D) -> void:
	if not is_fighting():
		return
	var charged: bool = hitbox.charged if hitbox is Hitbox else false
	var on_front := (hitbox.global_position.x - global_position.x) * brain.facing > 0.0
	if brain.plated and on_front and not charged:
		_sounds.play(RuskSounds.CLANG)
		return
	var damage: int = hitbox.damage if hitbox is Hitbox else Hitbox.DEFAULT_DAMAGE
	if not health.hurt(damage, INVULNERABLE_TIME):
		return
	HitFeel.enemy_struck(self, health.is_defeated())
	_sounds.play(RuskSounds.GRUNT)
	if health.is_defeated():
		defeated.emit(EXPERIENCE)


func _show_quake(delta: float) -> void:
	if _quake_left <= 0.0:
		return
	_quake_left -= delta
	if _quake_left <= 0.0:
		_quake.active = false


func _show() -> void:
	var pose: int = POSE[brain.state]
	if brain.state == RuskBrain.State.CHARGE:
		pose = CHARGE_POSE + int(_clock / STRIDE_TIME) % 2
	_sprite.frame = pose
	_brand.frame = pose + POSES
	_sprite.flip_h = brain.facing < 0.0
	_brand.flip_h = _sprite.flip_h
	_brand.modulate.a = _brand_glow()
	_touch.damage = CHARGE_DAMAGE if brain.plated else TOUCH_DAMAGE
	if _touch.active != brain.touch_harms:
		_touch.active = brain.touch_harms
	_maul.position.x = MAUL_REACH * brain.facing
	if _maul.active != brain.maul_active:
		_maul.active = brain.maul_active
	if brain.slammed:
		_quake.active = true
		_quake_left = QUAKE_TIME


# Dim, until he hurries: then it burns, flickering.
func _brand_glow() -> float:
	var hurried := float(health.current) / float(health.maximum) < brain.hurry_below
	if not hurried or brain.state == RuskBrain.State.DORMANT:
		return BRAND_DIM
	var lit := fmod(_clock, BRAND_FLICKER * 2.0) < BRAND_FLICKER
	return BRAND_HURRIED.y if lit else BRAND_HURRIED.x
