extends CharacterBody2D

# The Reefback, the Waking Coast's Boss: a great sea-ape guarding the road to Tidefen. Its brain
# decides each attack; this body shows it, holds its Ward and Health, and sends what each attack
# throws out: a pound's shockwaves, a landing's short ones, a chunk of reef, the chest-beat's
# rubble. While the Ward is up, a quick Attack glances off and a Charged Attack breaks the Ward
# without costing Health; while staggered, any hit costs Health. Asleep, it takes no hits at all.

# Its Health ran out; the Room hands its Experience to the Player.
signal defeated(experience: int)

const ReefbackBrain := preload("res://scripts/enemies/reefback_brain.gd")
const Health := preload("res://scripts/combat/health.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const ReefbackSounds := preload("res://scripts/enemies/reefback_sounds.gd")
const SHOCKWAVE_SCENE := preload("res://scenes/enemies/shockwave.tscn")
const CHUNK_SCENE := preload("res://scenes/enemies/reef_chunk.tscn")
const RUBBLE_SCENE := preload("res://scenes/enemies/rubble.tscn")
# What the Boss Health bar calls it.
const BOSS_NAME := "Reefback"
const MAX_HEALTH := 140
# What defeating the Reefback earns the Player.
const EXPERIENCE := 100
# A Boss leaves nothing where it falls; the road it opens is the reward.
const DROP_CHANCE := 0.0
const INVULNERABLE_TIME := 0.3
const TOUCH_DAMAGE := 10
const CHARGE_DAMAGE := 15
# Where a pound's shockwaves start either side of it, how long a landing's short ones roll, and
# where a thrown chunk leaves its hands, for a Reefback facing right.
const SHOCKWAVE_START := 14.0
const SHORT_SHOCKWAVE := 0.5
const THROW_FROM := Vector2(6.0, -46.0)
# How far apart the chest-beat's three rubble marks fall: under the Player, and either side.
const RUBBLE_SPREAD := 36.0
# How high a leap carries the sprite, and how much of a landing its landing hit lasts.
const LEAP_HEIGHT := 44.0
const LAND_HIT_SHARE := 0.4
# How long it takes to fade once it falls.
const DEFEAT_TIME := 1.5
const BLINK_TIME := 0.08
const TELL_GLOW := Color(1.7, 1.7, 1.7)
const PLAYER_GROUP := &"player"
# Its sheet, facing right, one row of eight 48x48 frames.
const FRAMES := {
	roar = 0,
	stand = 1,
	walk = [2, 3, 4],
	swipe = 5,
	overhead = 6,
	jump = 7,
}
# The one pose each of these states holds.
const STATE_POSE := {
	ReefbackBrain.State.SWIPE: FRAMES.swipe,
	ReefbackBrain.State.POUND: FRAMES.swipe,
	ReefbackBrain.State.LAND: FRAMES.swipe,
	ReefbackBrain.State.THROW: FRAMES.swipe,
	ReefbackBrain.State.LEAP: FRAMES.jump,
}
const WALK_FPS := 7.0
const CHARGE_FPS := 14.0
const BEAT_FPS := 6.0
# The pose each attack's Tell holds.
const TELL_POSE := {
	ReefbackBrain.Move.CHARGE: FRAMES.roar,
	ReefbackBrain.Move.SWIPE: FRAMES.roar,
	ReefbackBrain.Move.POUND: FRAMES.overhead,
	ReefbackBrain.Move.LEAP: FRAMES.overhead,
	ReefbackBrain.Move.THROW: FRAMES.overhead,
}

# The arena's floor, in Room x: the chest-beat's rubble falls within it.
@export var arena_left: float = 40.0
@export var arena_right: float = 148.0

# Read-only for callers.
var brain: ReefbackBrain = ReefbackBrain.new()
var health: Health = Health.new(MAX_HEALTH)
var _ward_broken: bool = false
var _defeat_left: float = DEFEAT_TIME
var _clock: float = 0.0
var _sounds: ReefbackSounds

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _ward: Sprite2D = $Ward
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _touch: Hitbox = $TouchHitbox
@onready var _swipe: Hitbox = $SwipeHitbox
@onready var _land: Hitbox = $LandHitbox
@onready var _sound_players: Node = $Sounds
@onready var _sprite_rest: Vector2 = _sprite.position
@onready var _swipe_reach: float = absf(_swipe.position.x)


func _ready() -> void:
	if not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)
	if _sounds == null:
		_sounds = ReefbackSounds.new(_sound_players)
	_show()


# Awake and not yet defeated: while this holds, the Boss Health bar shows.
func is_fighting() -> bool:
	return brain.is_awake() and not health.is_defeated()


func _physics_process(delta: float) -> void:
	health.step(delta)
	_clock += delta
	if brain.state == ReefbackBrain.State.DEFEATED:
		_defeat_left -= delta
		modulate.a = clampf(_defeat_left / DEFEAT_TIME, 0.0, 1.0)
		if _defeat_left <= 0.0:
			queue_free()
		return

	var previous := brain.state
	brain.step(_read_frame(), delta)
	if brain.state != previous:
		_sounds.play(ReefbackSounds.for_state_change(previous, brain.state))
	_send_what_it_throws()
	velocity.x = brain.velocity.x
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	_show()


func _read_frame() -> ReefbackBrain.Frame:
	var frame := ReefbackBrain.Frame.new()
	var player := _player()
	if player != null:
		frame.sees_player = true
		frame.player_offset = player.global_position - global_position
	frame.health_share = float(health.current) / float(health.maximum)
	frame.ward_broken = _ward_broken
	frame.defeated = health.is_defeated()
	_ward_broken = false
	return frame


# The Ward turns hits aside, but a Charged Attack breaks it; a staggered Reefback pays for each.
func _on_hurtbox_hit(hitbox: Area2D) -> void:
	if not brain.is_awake() or health.is_defeated():
		return
	if brain.warded:
		var charged: bool = hitbox.charged if hitbox is Hitbox else false
		_ward_broken = _ward_broken or charged
		_sounds.play(ReefbackSounds.WARD_BREAK if charged else ReefbackSounds.CLANG)
		return
	var damage: int = hitbox.damage if hitbox is Hitbox else Hitbox.DEFAULT_DAMAGE
	if not health.hurt(damage, INVULNERABLE_TIME):
		return
	_sounds.play(ReefbackSounds.HURT)
	if health.is_defeated():
		_hurtbox.set_deferred("monitorable", false)
		defeated.emit(EXPERIENCE)


func _send_what_it_throws() -> void:
	if brain.pounded:
		_send_shockwaves(SHOCKWAVE_SCENE.instantiate().get("lifetime"))
	if brain.landed:
		_send_shockwaves(SHORT_SHOCKWAVE)
	if brain.threw:
		var chunk := CHUNK_SCENE.instantiate()
		chunk.set("target", global_position + Vector2(brain.throw_offset, 0.0))
		_join(chunk, global_position + Vector2(THROW_FROM.x * brain.facing, THROW_FROM.y))
	if brain.beat:
		var player := _player()
		var under := player.global_position.x if player != null else global_position.x
		for x in [under, under - RUBBLE_SPREAD, under + RUBBLE_SPREAD]:
			var spot := Vector2(clampf(x, arena_left, arena_right), global_position.y)
			_join(RUBBLE_SCENE.instantiate(), spot)


func _send_shockwaves(lifetime: float) -> void:
	for direction: float in [-1.0, 1.0]:
		var wave := SHOCKWAVE_SCENE.instantiate()
		wave.set("direction", direction)
		wave.set("lifetime", lifetime)
		_join(wave, global_position + Vector2(direction * SHOCKWAVE_START, 0.0))


func _join(thing: Node2D, at: Vector2) -> void:
	get_parent().add_child(thing)
	thing.global_position = at


# The pose its state shows: a Tell holds its attack's pose; a charge gallops; a chest-beat
# alternates roaring and standing; a rest stomps if it is moving; the rest hold one pose each.
func _frame() -> int:
	var cycle: Array = []
	var fps := 0.0
	match brain.state:
		ReefbackBrain.State.TELL:
			return TELL_POSE[brain.move]
		ReefbackBrain.State.CHARGE:
			cycle = FRAMES.walk
			fps = CHARGE_FPS
		ReefbackBrain.State.CHEST_BEAT:
			cycle = [FRAMES.roar, FRAMES.stand]
			fps = BEAT_FPS
		_:
			if STATE_POSE.has(brain.state):
				return STATE_POSE[brain.state]
			if brain.velocity.x != 0.0:
				cycle = FRAMES.walk
				fps = WALK_FPS * (brain.hurry if brain.hurried else 1.0)
	if cycle.is_empty():
		return FRAMES.stand
	return cycle[int(_clock * fps) % cycle.size()]


func _show() -> void:
	_sprite.frame = _frame()
	_sprite.flip_h = brain.facing < 0.0
	var lift := 0.0
	if brain.airborne:
		var t := brain.progress()
		lift = LEAP_HEIGHT * 4.0 * t * (1.0 - t)
	_sprite.position = _sprite_rest - Vector2(0.0, lift)
	_ward.frame = _sprite.frame
	_ward.flip_h = _sprite.flip_h
	_ward.position = _sprite.position
	var blink := fmod(_clock, BLINK_TIME * 2.0) < BLINK_TIME
	_ward.visible = brain.warded and brain.is_awake() and blink
	var telling := (
		brain.state == ReefbackBrain.State.TELL or brain.state == ReefbackBrain.State.CHEST_BEAT
	)
	_sprite.self_modulate = TELL_GLOW if telling and blink else Color.WHITE
	_touch.damage = CHARGE_DAMAGE if brain.charging else TOUCH_DAMAGE
	_set_live(_touch, brain.touch_harms)
	_swipe.position.x = _swipe_reach * brain.facing
	_set_live(_swipe, brain.swipe_active)
	var landing := brain.state == ReefbackBrain.State.LAND and brain.progress() < LAND_HIT_SHARE
	_set_live(_land, landing)
	var strikable := brain.state != ReefbackBrain.State.DEFEATED and not brain.airborne
	if _hurtbox.monitorable != strikable:
		_hurtbox.monitorable = strikable


func _set_live(hitbox: Hitbox, live: bool) -> void:
	if hitbox.active != live:
		hitbox.active = live


func _player() -> Node2D:
	return get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D if is_inside_tree() else null
