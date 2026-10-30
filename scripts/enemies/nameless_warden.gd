extends CharacterBody2D

# The Nameless Warden, the Waking Coast's Boss: an armored spirit guarding the road to Tidefen.
# Its brain decides each move; this body shows it, holds its Ward and Health, and sends the
# slam's shockwaves. While the Ward is up, a quick Attack glances off and a Charged Attack breaks
# the Ward without costing Health; while staggered, any hit costs Health. Asleep, it takes no
# hits at all.

# Its Health ran out; the Room hands its Experience to the Player.
signal defeated(experience: int)

const WardenBrain := preload("res://scripts/enemies/warden_brain.gd")
const Health := preload("res://scripts/combat/health.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const WardenSounds := preload("res://scripts/enemies/warden_sounds.gd")
const SHOCKWAVE_SCENE := preload("res://scenes/enemies/shockwave.tscn")
# What the Boss Health bar calls it.
const BOSS_NAME := "Nameless Warden"
const MAX_HEALTH := 120
# What defeating the Warden earns the Player.
const EXPERIENCE := 100
# A Boss leaves nothing where it falls; the road it opens is the reward.
const DROP_CHANCE := 0.0
const INVULNERABLE_TIME := 0.3
const TOUCH_DAMAGE := 10
const BASH_DAMAGE := 15
# How far either side of it a slam's shockwaves start.
const SHOCKWAVE_START := 12.0
# How long it takes to fade once it kneels.
const DEFEAT_TIME := 1.5
const BLINK_TIME := 0.08
const WINDUP_GLOW := Color(1.6, 1.6, 1.6)
const PLAYER_GROUP := &"player"
# Two rows of 32x32 cells: its poses facing right, then the Ward's outline around each.
const POSES_PER_ROW := 6
const POSE := {
	WardenBrain.State.DORMANT: 0,
	WardenBrain.State.REST: 0,
	WardenBrain.State.WINDUP: 1,
	WardenBrain.State.BASH: 2,
	WardenBrain.State.SLAM: 3,
	WardenBrain.State.STAGGERED: 4,
	WardenBrain.State.DEFEATED: 5,
}

# Read-only for callers.
var brain: WardenBrain = WardenBrain.new()
var health: Health = Health.new(MAX_HEALTH)
var _ward_broken: bool = false
var _defeat_left: float = DEFEAT_TIME
var _clock: float = 0.0
var _sounds: WardenSounds

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _ward: Sprite2D = $Ward
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _touch: Hitbox = $TouchHitbox
@onready var _sound_players: Node = $Sounds


func _ready() -> void:
	if not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)
	if _sounds == null:
		_sounds = WardenSounds.new(_sound_players)
	_show()


# Awake and not yet defeated: while this holds, the Boss Health bar shows.
func is_fighting() -> bool:
	return brain.is_awake() and not health.is_defeated()


func _physics_process(delta: float) -> void:
	health.step(delta)
	_clock += delta
	if brain.state == WardenBrain.State.DEFEATED:
		_defeat_left -= delta
		modulate.a = clampf(_defeat_left / DEFEAT_TIME, 0.0, 1.0)
		if _defeat_left <= 0.0:
			queue_free()
		return

	var previous := brain.state
	brain.step(_read_frame(), delta)
	if brain.state != previous or brain.slammed:
		_sounds.play(WardenSounds.for_state_change(previous, brain.state))
	if brain.slammed:
		_send_shockwaves()
	velocity.x = brain.velocity.x
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	_show()


func _read_frame() -> WardenBrain.Frame:
	var frame := WardenBrain.Frame.new()
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player != null:
		frame.sees_player = true
		frame.player_offset = player.global_position - global_position
	frame.health_share = float(health.current) / float(health.maximum)
	frame.ward_broken = _ward_broken
	frame.defeated = health.is_defeated()
	_ward_broken = false
	return frame


# The Ward turns hits aside, but a Charged Attack breaks it; a staggered Warden pays for each hit.
func _on_hurtbox_hit(hitbox: Area2D) -> void:
	if not brain.is_awake() or health.is_defeated():
		return
	if brain.warded:
		var charged: bool = hitbox.charged if hitbox is Hitbox else false
		_ward_broken = _ward_broken or charged
		_sounds.play(WardenSounds.WARD_BREAK if charged else WardenSounds.CLANG)
		return
	var damage: int = hitbox.damage if hitbox is Hitbox else Hitbox.DEFAULT_DAMAGE
	if not health.hurt(damage, INVULNERABLE_TIME):
		return
	_sounds.play(WardenSounds.HURT)
	if health.is_defeated():
		_hurtbox.set_deferred("monitorable", false)
		defeated.emit(EXPERIENCE)


# One shockwave rolls each way along the floor from where the shield struck.
func _send_shockwaves() -> void:
	for direction: float in [-1.0, 1.0]:
		var wave := SHOCKWAVE_SCENE.instantiate()
		wave.set("direction", direction)
		get_parent().add_child(wave)
		wave.global_position = global_position + Vector2(direction * SHOCKWAVE_START, 0.0)


func _show() -> void:
	var pose: int = POSE[brain.state]
	_sprite.frame = pose
	_ward.frame = pose + POSES_PER_ROW
	_sprite.flip_h = brain.facing < 0.0
	_ward.flip_h = _sprite.flip_h
	var blink := fmod(_clock, BLINK_TIME * 2.0) < BLINK_TIME
	_ward.visible = brain.warded and brain.is_awake() and blink
	var winding_up := brain.state == WardenBrain.State.WINDUP
	_sprite.self_modulate = WINDUP_GLOW if winding_up and blink else Color.WHITE
	_touch.damage = BASH_DAMAGE if brain.bash_active else TOUCH_DAMAGE
	if _touch.active != brain.touch_harms:
		_touch.active = brain.touch_harms
	var defeated_now := brain.state == WardenBrain.State.DEFEATED
	if _hurtbox.monitorable == defeated_now:
		_hurtbox.monitorable = not defeated_now
