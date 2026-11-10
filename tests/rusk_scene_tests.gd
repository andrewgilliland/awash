extends RefCounted

const RUSK_SCENE := preload("res://scenes/enemies/rusk.tscn")
const DIALOGUE_BOX_SCENE := preload("res://scenes/ui/dialogue_box.tscn")
const SHEET_PATH := "res://assets/enemies/rusk/rusk_1.png"
const THEME_PATH := "res://assets/enemies/rusk/rusk_theme.wav"
const RuskBrain := preload("res://scripts/enemies/rusk_brain.gd")
const RuskSounds := preload("res://scripts/enemies/rusk_sounds.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const TERRAIN_LAYER := 1
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_LAYER := 1 << 3
const ENEMY_HITBOX_LAYER := 1 << 4
const SOUNDS: Array[StringName] = [
	&"Roar", &"Stamp", &"Crash", &"Whoosh", &"Boom", &"Clang", &"Grunt", &"Cry"
]
const SFX_BUS := &"SFX"
const FRAME := 1.0 / 60.0
const POSES := 10
const ARENA_WIDTH := 160.0

# Needs a root that is already in the tree: Rusk finds the Player and the dialogue box by group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Rusk is a Boss, with a hurtbox, a harmful touch, a maul and a quake", _test_boxes],
		["Rusk is drawn from his sheet, his brand's glow over him", _test_sprite],
		["Rusk carries positional sounds on the SFX bus", _test_sounds_on_sfx_bus],
		["Rusk roars, stamps, whooshes, booms and cries out as he fights", _test_sound_cues],
		["Rusk's defeat is worth 150 Experience, and nothing else", _test_worth],
		["Rusk speaks through the dialogue box, and waits for it to close", _test_speaks],
		["Rusk takes no hits until he fights, then every hit", _test_takes_hits_fighting],
		["Charging, his plate turns quick hits on his front aside", _test_plate],
		["Rusk's touch harms as he fights, more as he charges", _test_touch],
		["Rusk's maul strikes only as it lands, on the side he faces", _test_maul],
		["The quake strikes the whole arena's floor, as the maul lands", _test_quake],
		["Beaten, Rusk is defeated once and kneels, harmless", _test_defeated],
		["Leaping, Rusk flies up and away east, through walls, and is gone", _test_leaps],
		["Rusk's feet are at his origin, drawn standing on them", _test_feet],
		["Rusk's theme is a loop of his own", _test_theme],
	]


func _test_boxes() -> bool:
	var rusk := RUSK_SCENE.instantiate() as CharacterBody2D
	var valid := rusk.is_in_group(&"enemy") and rusk.is_in_group(&"boss")
	valid = valid and rusk.collision_layer == ENEMY_LAYER and rusk.collision_mask == TERRAIN_LAYER
	var hurtbox := rusk.get_node_or_null("Hurtbox") as Area2D
	valid = valid and hurtbox != null and hurtbox.collision_layer == ENEMY_HITBOX_LAYER
	for box in ["TouchHitbox", "MaulHitbox", "QuakeHitbox"]:
		var hitbox := rusk.get_node_or_null(box) as Area2D
		valid = valid and hitbox is Hitbox and hitbox.collision_mask == PLAYER_HITBOX_LAYER
		valid = valid and hitbox.collision_layer == ENEMY_HITBOX_LAYER
	rusk.free()
	return valid


func _test_sprite() -> bool:
	var rusk := RUSK_SCENE.instantiate()
	var sprite := rusk.get_node("Sprite2D") as Sprite2D
	var brand := rusk.get_node_or_null("Brand") as Sprite2D
	var valid := sprite.texture.resource_path == SHEET_PATH and brand != null
	valid = valid and sprite.hframes == POSES and sprite.vframes == 2
	valid = valid and sprite.texture.get_size() == Vector2(48 * POSES, 96)
	valid = valid and brand.texture == sprite.texture and brand.frame == POSES
	rusk.free()
	return valid


func _test_sounds_on_sfx_bus() -> bool:
	var rusk := RUSK_SCENE.instantiate()
	var valid := true
	for sound in SOUNDS:
		var player := rusk.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer2D
		valid = valid and player != null and player.stream != null and player.bus == SFX_BUS
	rusk.free()
	return valid


func _test_sound_cues() -> bool:
	var state := RuskBrain.State
	var cues := [
		[state.SPEAKING, state.SUMMONING, &"Roar"],
		[state.SUMMONING, state.REST, &""],
		[state.REST, state.TELL, &"Stamp"],
		[state.REST, state.WIND_UP, &"Whoosh"],
		[state.CHARGE, state.WIND_UP, &"Whoosh"],
		[state.WIND_UP, state.SLAM, &"Boom"],
		[state.KNEEL, state.LEAP, &"Cry"],
		[state.TELL, state.CHARGE, &""],
		[state.CHARGE, state.DAZED, &""],
		[state.DAZED, state.REST, &""],
		[state.SLAM, state.REST, &""],
	]
	var valid := true
	for cue in cues:
		valid = valid and RuskSounds.for_state_change(cue[0], cue[1]) == cue[2]
	return valid


func _test_worth() -> bool:
	var constants: Dictionary = (
		(RUSK_SCENE.instantiate().get_script() as Script).get_script_constant_map()
	)
	return (
		constants.get("EXPERIENCE") == 150
		and constants.get("GOLD") == 0
		and constants.get("DROP_CHANCE") == 0.0
		and constants.get("MAX_HEALTH") == 200
		and constants.get("BOSS_NAME") == "Rusk"
		and constants.get("BOSS_ID") == &"rusk_jungle"
	)


func _test_speaks() -> bool:
	var box := DIALOGUE_BOX_SCENE.instantiate()
	_root.add_child(box)
	var player := _player_at(Vector2(-60, 0))
	var rusk := _rusk()
	rusk.call("_physics_process", FRAME)
	var valid: bool = rusk.brain.state == RuskBrain.State.SPEAKING and box.call("is_open")
	valid = valid and box.get("dialogue").speaker() == "RUSK"
	for i in 10:
		rusk.call("_physics_process", FRAME)
	valid = valid and rusk.brain.state == RuskBrain.State.SPEAKING
	# As the box closes on its last line; closing it for real waits a frame to free the Player.
	box.emit_signal(&"closed")
	rusk.call("_physics_process", FRAME)
	valid = valid and rusk.brain.state == RuskBrain.State.SUMMONING
	rusk.free()
	player.free()
	box.free()
	return valid


func _test_takes_hits_fighting() -> bool:
	var rusk := _rusk()
	var sword := _hitbox(rusk, Vector2(-16, -16), 10)
	rusk.call("_on_hurtbox_hit", sword)
	var valid: bool = rusk.health.current == 200
	rusk.brain.state = RuskBrain.State.SPEAKING
	rusk.call("_on_hurtbox_hit", sword)
	valid = valid and rusk.health.current == 200
	_set_state(rusk, RuskBrain.State.REST)
	rusk.call("_on_hurtbox_hit", sword)
	valid = valid and rusk.health.current == 190
	rusk.free()
	return valid


func _test_plate() -> bool:
	var rusk := _rusk()
	_set_state(rusk, RuskBrain.State.CHARGE)
	var front := _hitbox(rusk, Vector2(-16, -16), 10)
	rusk.call("_on_hurtbox_hit", front)
	var valid: bool = rusk.health.current == 200
	rusk.health.step(1.0)
	var behind := _hitbox(rusk, Vector2(16, -16), 10)
	rusk.call("_on_hurtbox_hit", behind)
	valid = valid and rusk.health.current == 190
	rusk.health.step(1.0)
	front.charged = true
	front.damage = 20
	rusk.call("_on_hurtbox_hit", front)
	valid = valid and rusk.health.current == 170
	rusk.free()
	return valid


func _test_touch() -> bool:
	var rusk := _rusk()
	var touch := rusk.get_node("TouchHitbox") as Hitbox
	var valid := not touch.active
	_set_state(rusk, RuskBrain.State.REST)
	rusk.call("_show")
	valid = valid and touch.active and touch.damage == 10
	_set_state(rusk, RuskBrain.State.CHARGE)
	rusk.call("_show")
	valid = valid and touch.active and touch.damage == 15
	_set_state(rusk, RuskBrain.State.DAZED)
	rusk.call("_show")
	valid = valid and not touch.active
	rusk.free()
	return valid


func _test_maul() -> bool:
	var rusk := _rusk()
	var maul := rusk.get_node("MaulHitbox") as Hitbox
	var valid := not maul.active and maul.damage == 20
	for facing in [1.0, -1.0]:
		rusk.brain.facing = facing
		for state in [RuskBrain.State.WIND_UP, RuskBrain.State.SLAM, RuskBrain.State.REST]:
			_set_state(rusk, state)
			rusk.call("_show")
			valid = valid and maul.active == (state == RuskBrain.State.SLAM)
			valid = valid and signf(maul.position.x) == facing
	rusk.free()
	return valid


func _test_quake() -> bool:
	var rusk := _rusk()
	var quake := rusk.get_node("QuakeHitbox") as Hitbox
	var shape := quake.get_node("Shape") as CollisionShape2D
	var size := (shape.shape as RectangleShape2D).size
	var valid := not quake.active and quake.damage == 6
	valid = valid and size.x >= ARENA_WIDTH * 2.0 and size.y <= 4.0
	valid = valid and shape.position.y + size.y / 2.0 <= 0.5 and shape.position.y > -4.0
	_set_state(rusk, RuskBrain.State.WIND_UP)
	rusk.brain.slammed = true
	rusk.call("_show")
	valid = valid and quake.active
	rusk.brain.slammed = false
	rusk.call("_show")
	valid = valid and quake.active
	for i in 12:
		rusk.call("_show_quake", FRAME)
	valid = valid and not quake.active
	rusk.free()
	return valid


func _test_defeated() -> bool:
	var rusk := _rusk()
	var count := [0]
	rusk.connect(&"defeated", func(experience: int) -> void: count[0] += experience)
	_set_state(rusk, RuskBrain.State.REST)
	rusk.health.current = 10
	var sword := _hitbox(rusk, Vector2(-16, -16), 10)
	rusk.call("_on_hurtbox_hit", sword)
	rusk.health.step(1.0)
	rusk.call("_on_hurtbox_hit", sword)
	rusk.call("_physics_process", FRAME)
	var valid: bool = count[0] == 150 and rusk.brain.state == RuskBrain.State.KNEEL
	valid = valid and not (rusk.get_node("TouchHitbox") as Hitbox).active
	valid = valid and not rusk.call("is_fighting")
	rusk.free()
	return valid


func _test_leaps() -> bool:
	var rusk := _rusk()
	var count := [0]
	rusk.connect(&"retreated", func() -> void: count[0] += 1)
	_set_state(rusk, RuskBrain.State.KNEEL)
	rusk.health.current = 0
	rusk.call("_physics_process", FRAME)
	var start: Vector2 = rusk.global_position
	var valid: bool = rusk.brain.state == RuskBrain.State.LEAP and count[0] == 1
	valid = valid and (rusk.get_node("CollisionShape2D") as CollisionShape2D).disabled
	for i in 20:
		rusk.call("_physics_process", FRAME)
	valid = valid and rusk.global_position.x > start.x and rusk.global_position.y < start.y
	for i in 60:
		rusk.call("_physics_process", FRAME)
	valid = valid and rusk.is_queued_for_deletion() and count[0] == 1
	rusk.free()
	return valid


func _test_feet() -> bool:
	var rusk := RUSK_SCENE.instantiate()
	var shape := rusk.get_node("CollisionShape2D") as CollisionShape2D
	var box := (shape.shape as RectangleShape2D).size
	var valid := is_equal_approx(shape.position.y + box.y / 2.0, 0.0)
	var sprite := rusk.get_node("Sprite2D") as Sprite2D
	valid = valid and is_equal_approx(sprite.position.y + 24.0, 0.0)
	rusk.free()
	return valid


func _test_theme() -> bool:
	var theme := load(THEME_PATH) as AudioStreamWAV
	return theme != null and theme.loop_mode == AudioStreamWAV.LOOP_FORWARD


# Rusk in the tree, with no dialogue box: whatever he says counts as read.
func _rusk() -> CharacterBody2D:
	var rusk := RUSK_SCENE.instantiate() as CharacterBody2D
	_root.add_child(rusk)
	rusk.global_position = Vector2(200, 100)
	return rusk


func _player_at(offset: Vector2) -> Node2D:
	var player := Node2D.new()
	player.add_to_group(&"player")
	_root.add_child(player)
	player.global_position = Vector2(200, 100) + offset
	return player


# A blow from where it lands, relative to Rusk's feet.
func _hitbox(rusk: Node2D, offset: Vector2, damage: int) -> Hitbox:
	var hitbox := Hitbox.new()
	rusk.add_child(hitbox)
	hitbox.position = offset
	hitbox.damage = damage
	return hitbox


# Puts the brain in a state as if it had entered it, outputs and all.
func _set_state(rusk: Node, state: RuskBrain.State) -> void:
	rusk.brain.call("_enter", state, 1.0)
