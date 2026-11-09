extends CharacterBody2D

# The Player's Health ran out.
signal defeated

const PlayerController := preload("res://scripts/player/player_controller.gd")
const PlayerRig := preload("res://scripts/player/player_rig.gd")
const Health := preload("res://scripts/combat/health.gd")
const Level := preload("res://scripts/player/level.gd")
const Supplies := preload("res://scripts/items/supplies.gd")
const Equipment := preload("res://scripts/items/equipment.gd")
const SubWeapons := preload("res://scripts/items/sub_weapons.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const HitFeel := preload("res://scripts/combat/hit_feel.gd")
const PlayerSounds := preload("res://scripts/player/player_sounds.gd")
const SWORD_BEAM_SCENE := preload("res://scenes/player/sword_beam.tscn")
const INTERACTABLE_GROUP := &"interactable"
const INVULNERABLE_TIME := 1.0
const BLINK_TIME := 0.08
# A defeated Player flickers more slowly where it lies.
const DEFEAT_BLINK_TIME := 0.15
# Up and away from whatever struck the Player.
const KNOCKBACK := Vector2(90.0, -120.0)
# The sword's reach, in front of the Player when facing right.
const SWORD_OFFSET := Vector2(12.0, -8.0)
# A Charged Attack's Sword Beam costs this many times a quick slash.
const CHARGED_MULTIPLIER := 2
# A full Charge makes the sword blink bright, and the Charged Attack let go from it swings lit.
const CHARGED_GLOW := Color(2.0, 2.0, 2.0)
const CHARGED_BLINK_TIME := 0.08
# Where a Sub Weapon leaves the Player's hand, facing right.
const THROW_OFFSET := Vector2(6.0, -10.0)
# Over the Player when it finds a Weapon or Sub Weapon.
const GOT := "GOT %s"
const RESTED := "RESTED"

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
# Read-only for callers: change it through wear_armor(), take_off_armor(), collect_weapon() and
# hold_weapon(). What the Player wears, whose Defense takes Health off each hit, and the Weapon
# it holds, whose Attack adds to each hit it lands.
var equipment: Equipment = Equipment.new()
# Read-only for callers: change it through collect_sub_weapon(), hold_sub_weapon() and
# throw_sub_weapon(). The Sub Weapon Ranged Attack uses, and how many of each are carried.
var sub_weapons: SubWeapons = SubWeapons.new()
# Read-only for callers: change it through gain_gold(). The Gold the Player carries.
var gold: int = 0
# While true the Player ignores walk, jump and melee input: dialogue and the intro hold it
# still.
var controls_locked: bool = false
var _rig: PlayerRig
var _sounds: PlayerSounds
var _attack_finished: bool = false
var _knockback: Vector2 = Vector2.ZERO
var _defeated: bool = false
var _defeat_time: float = 0.0
# The Sub Weapon thrown last, while it is still out.
var _thrown: Node2D

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
		equipment = Equipment.new(
			run.get("player_armor"),
			run.get("player_owned_armor"),
			run.get("player_weapon"),
			run.get("player_owned_weapons")
		)
		sub_weapons = SubWeapons.new(
			run.get("player_sub_weapon"),
			run.get("player_owned_sub_weapons"),
			run.get("player_sub_weapon_counts")
		)
		gold = run.get("player_gold")
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
	_rig.hold(load(Equipment.WEAPONS[equipment.weapon].sheet))
	if _sounds == null:
		_sounds = PlayerSounds.new(_sound_players)
		controller.state_changed.connect(_on_controller_state_changed)
		controller.jumped.connect(_sounds.play.bind(PlayerSounds.JUMP))
		_sword_hitbox.struck.connect(_on_sword_struck)
	_on_controller_stepped()


# Interact and Ranged Attack act on the press itself, so even the quickest tap is never missed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and not event.is_echo() and interact() != null:
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ranged_attack") and not event.is_echo():
		if throw_sub_weapon() != null:
			get_viewport().set_input_as_handled()


# Carries one more of a kind of Supply, with a pickup sound, and returns whether there was room.
func collect(kind: StringName) -> bool:
	if not supplies.add(kind):
		return false
	_write_supplies_to_run()
	_sounds.play(PlayerSounds.PICKUP)
	return true


# Uses one Supply of a kind, as chosen in the Inventory: a Restorative restores its Health.
# Returns whether it did. Nothing is spent with none carried, at full Health, or while the
# Player is held still or defeated.
func use_supply(kind: StringName) -> bool:
	if supplies.count(kind) <= 0 or controls_locked or _defeated:
		return false
	if health.current >= health.maximum:
		return false
	health.heal(Supplies.restores(kind, health.maximum))
	supplies.spend(kind)
	_write_supplies_to_run()
	var run := _get_run()
	if run != null:
		run.set("player_health", health.current)
	_sounds.play(PlayerSounds.EAT)
	return true


# Puts on Armor the Player owns, as chosen in the Equipment Panel; returns whether it could.
func wear_armor(armor_id: StringName) -> bool:
	if not equipment.wear(armor_id):
		return false
	_write_armor_to_run()
	return true


func take_off_armor() -> void:
	equipment.take_off()
	_write_armor_to_run()


# Owns and puts on Armor found in a Cache, with a pickup sound and its name over the Player.
# Returns whether it did: Armor already owned is not collected again.
func collect_armor(armor_id: StringName) -> bool:
	if not equipment.own_armor(armor_id):
		return false
	wear_armor(armor_id)
	_sounds.play(PlayerSounds.PICKUP)
	_level_up.call("announce", GOT % Equipment.ARMOR[armor_id].name.to_upper())
	return true


# Owns and takes up a Weapon found where an enemy fell, with a pickup sound and its name over the
# Player. Returns whether it did: a Weapon already owned is not collected again.
func collect_weapon(weapon_id: StringName) -> bool:
	if not equipment.own_weapon(weapon_id):
		return false
	hold_weapon(weapon_id)
	_sounds.play(PlayerSounds.PICKUP)
	_level_up.call("announce", GOT % Equipment.WEAPONS[weapon_id].name.to_upper())
	return true


# Takes up a Weapon the Player owns, as chosen in the Equipment Panel; returns whether it could.
func hold_weapon(weapon_id: StringName) -> bool:
	if not equipment.hold(weapon_id):
		return false
	_rig.hold(load(Equipment.WEAPONS[weapon_id].sheet))
	var run := _get_run()
	if run != null:
		run.set("player_weapon", equipment.weapon)
		run.set("player_owned_weapons", equipment.owned_weapons.duplicate())
	return true


# Carries one more of a Sub Weapon found in a Cache, with a pickup sound. The first one found is
# owned and taken up, its name shown over the Player. Returns whether there was room.
func collect_sub_weapon(id: StringName) -> bool:
	var found := sub_weapons.own(id)
	if found:
		sub_weapons.hold(id)
		_level_up.call("announce", GOT % SubWeapons.KINDS[id].found)
	if not sub_weapons.add(id) and not found:
		return false
	_write_sub_weapons_to_run()
	_sounds.play(PlayerSounds.PICKUP)
	return true


# Whether the Player could carry one more of a Supply or Sub Weapon, or take up an Armor; one not
# owned yet fits, and an Armor owned already does not.
func has_room_for(kind: StringName) -> bool:
	if Equipment.ARMOR.has(kind):
		return not equipment.owns_armor(kind)
	if SubWeapons.KINDS.has(kind):
		return not sub_weapons.owns(kind) or sub_weapons.count(kind) < SubWeapons.CARRY_LIMIT
	return Supplies.KINDS.has(kind) and supplies.count(kind) < Supplies.CARRY_LIMIT


# Whether the Player has the Gold for a Supply at this price, and room to carry one more.
func can_buy(kind: StringName, price: int) -> bool:
	return gold >= price and supplies.count(kind) < Supplies.CARRY_LIMIT


# Buys one Supply at the Supply Shop: spends its price and carries one more. Returns whether it
# could.
func buy_supply(kind: StringName, price: int) -> bool:
	if not can_buy(kind, price) or not supplies.add(kind):
		return false
	gold -= price
	var run := _get_run()
	if run != null:
		run.set("player_gold", gold)
	_write_supplies_to_run()
	_sounds.play(PlayerSounds.PICKUP)
	return true


# Earns Gold, as a defeated enemy gives it; the Run carries it.
func gain_gold(amount: int) -> void:
	gold += maxi(amount, 0)
	var run := _get_run()
	if run != null:
		run.set("player_gold", gold)


# A rest at a Rest point: Health back to full and every Sub Weapon owned refilled, with RESTED.
func rest() -> void:
	health.heal(health.maximum)
	sub_weapons.refill()
	var run := _get_run()
	if run != null:
		run.set("player_health", health.current)
	_write_sub_weapons_to_run()
	_level_up.call("announce", RESTED)


# Takes up a Sub Weapon the Player owns, or none (&""), as chosen in the Equipment Panel; returns
# whether it could.
func hold_sub_weapon(id: StringName) -> bool:
	if not sub_weapons.hold(id):
		return false
	_write_sub_weapons_to_run()
	return true


# Sends the held Sub Weapon out along the Player's facing, into the Room, spending one, and
# returns it. Nothing is thrown with none held or carried, while the Player is held still or
# defeated, or while the last one thrown is still out.
func throw_sub_weapon() -> Node2D:
	var id := sub_weapons.held
	if id.is_empty() or controls_locked or _defeated or is_instance_valid(_thrown):
		return null
	if not sub_weapons.spend(id):
		return null
	_write_sub_weapons_to_run()
	_thrown = (load(SubWeapons.KINDS[id].scene) as PackedScene).instantiate() as Node2D
	_thrown.set("facing", controller.facing)
	var world := get_parent() if get_parent() != null else self
	world.add_child(_thrown)
	_thrown.global_position = (
		global_position + Vector2(THROW_OFFSET.x * controller.facing, THROW_OFFSET.y)
	)
	_sounds.play(PlayerSounds.THROW)
	return _thrown


func _write_sub_weapons_to_run() -> void:
	var run := _get_run()
	if run != null:
		run.set("player_sub_weapon", sub_weapons.held)
		run.set("player_owned_sub_weapons", sub_weapons.owned.duplicate())
		run.set("player_sub_weapon_counts", sub_weapons.to_counts())


func _write_armor_to_run() -> void:
	var run := _get_run()
	if run != null:
		run.set("player_armor", equipment.armor)
		run.set("player_owned_armor", equipment.owned.duplicate())


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
	var strength_before := level.strength()
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
	_level_up.call("flash", level.max_health() - before, level.strength() - strength_before)


# Whether the Player's Health has run out: it no longer answers the controls.
func is_defeated() -> bool:
	return _defeated


func _read_frame() -> PlayerController.Frame:
	var frame := PlayerController.Frame.new()
	if not controls_locked and not _defeated:
		frame.direction = Input.get_axis(&"move_left", &"move_right")
		frame.jump_pressed = Input.is_action_just_pressed(&"jump")
		frame.jump_held = Input.is_action_pressed(&"jump")
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


# A hit costs Health, less the Armor's Defense, and throws the Player away from the hitbox, unless
# invulnerable.
func _on_hurtbox_hit(hitbox: Area2D) -> void:
	var damage: int = hitbox.damage if hitbox is Hitbox else Hitbox.DEFAULT_DAMAGE
	if not health.hurt(equipment.hit_cost(damage), INVULNERABLE_TIME):
		return
	HitFeel.player_hurt(self)
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
	# A Charged Attack's swing is for show: the Sword Beam it looses is the hit.
	var slashing := attacking and not controller.charged_attack
	if slashing:
		_sword_hitbox.damage = _quick_cost()
	if _sword_hitbox.active != slashing:
		_sword_hitbox.active = slashing
	var lit := (
		(attacking and controller.charged_attack)
		or (
			controller.is_fully_charged()
			and fmod(controller.time_in_state, CHARGED_BLINK_TIME * 2.0) < CHARGED_BLINK_TIME
		)
	)
	_sword_sprite.modulate = CHARGED_GLOW if lit else Color.WHITE


func _on_controller_state_changed(
	previous: PlayerController.State, next: PlayerController.State
) -> void:
	_sounds.play(PlayerSounds.for_state_change(previous, next, controller.time_in_state))
	if next == PlayerController.State.ATTACK and controller.charged_attack:
		_loose_sword_beam()


# What a quick slash costs: the sword's hit, the Player's Strength and the Weapon's Attack.
func _quick_cost() -> int:
	return Hitbox.DEFAULT_DAMAGE + level.strength() + equipment.attack()


# Sends a Sword Beam out from the blade along the Player's facing, into the Room.
func _loose_sword_beam() -> void:
	var beam := SWORD_BEAM_SCENE.instantiate() as Node2D
	beam.set("facing", controller.facing)
	beam.set("damage", _quick_cost() * CHARGED_MULTIPLIER)
	beam.set("sheet", load(Equipment.WEAPONS[equipment.weapon].sheet))
	var world := get_parent() if get_parent() != null else self
	world.add_child(beam)
	beam.global_position = (
		global_position + Vector2(SWORD_OFFSET.x * controller.facing, SWORD_OFFSET.y)
	)


func _on_sword_struck(_hurtbox: Area2D) -> void:
	_sounds.play(PlayerSounds.HIT)
