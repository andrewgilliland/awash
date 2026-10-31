extends RefCounted

const REEFBACK_SCENE := preload("res://scenes/enemies/reefback.tscn")
const SHOCKWAVE_PATH := "res://scenes/enemies/shockwave.tscn"
const CHUNK_PATH := "res://scenes/enemies/reef_chunk.tscn"
const RUBBLE_PATH := "res://scenes/enemies/rubble.tscn"
const WARD_SHADER_PATH := "res://assets/shaders/ward_outline.gdshader"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const ReefbackBrain := preload("res://scripts/enemies/reefback_brain.gd")
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_LAYER := 1 << 3
const ENEMY_HITBOX_LAYER := 1 << 4
const STEP := 0.05
const AT := Vector2(132, 112)
const FAR := Vector2(70, 112)
const NEAR := Vector2(104, 112)
# Where each pose sits on its sheet: one row of eight, facing right.
const ROAR := 0
const STAND := 1
const WALK := [2, 3, 4]
const SWIPE := 5
const OVERHEAD := 6
const JUMP := 7

# Needs a root that is already in the tree: the Reefback finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["The Reefback is a Boss with a body, hurtbox and hitboxes", _test_boxes],
		["A dormant Reefback ignores hits", _test_dormant_ignores_hits],
		["A quick Attack glances off the Ward; a Charged one breaks it", _test_ward],
		["While staggered, any hit costs the Reefback Health", _test_staggered_hits_land],
		["Its touch costs 10, 15 while it charges; staggered, nothing", _test_touch],
		["Its swipe is live in front of it, for 15, only as it swipes", _test_swipe],
		["A ground pound sends a shockwave each way along the floor", _test_pound],
		["In a leap it cannot be touched or struck; it lands hard", _test_leap],
		["A reef throw lobs one chunk at where the Player stands", _test_throw],
		["A reef chunk arcs to its mark and shatters there, or on a hit", _test_chunk],
		["Its chest-beat marks three spots, one under the Player", _test_chest_beat],
		["Rubble falls on its mark, striking only as it lands", _test_rubble],
		["The Reefback shows each state's pose from its sheet", _test_frames],
		["Its Ward is an outline drawn round whatever pose it shows", _test_ward_outline],
		["A defeated Reefback reports its Experience once", _test_defeat],
	]


func _test_boxes() -> bool:
	var reefback := REEFBACK_SCENE.instantiate() as CharacterBody2D
	var constants: Dictionary = reefback.get_script().get_script_constant_map()
	var valid := reefback.is_in_group(&"enemy") and reefback.is_in_group(&"boss")
	valid = valid and reefback.collision_layer == ENEMY_LAYER
	var hurtbox := reefback.get_node_or_null("Hurtbox") as Area2D
	valid = valid and hurtbox != null and hurtbox.collision_layer == ENEMY_HITBOX_LAYER
	for hitbox_name in ["TouchHitbox", "SwipeHitbox", "LandHitbox"]:
		var hitbox := reefback.get_node_or_null(hitbox_name) as Hitbox
		valid = valid and hitbox != null and hitbox.collision_layer == ENEMY_HITBOX_LAYER
		valid = valid and hitbox.collision_mask == PLAYER_HITBOX_LAYER
	valid = valid and constants.get("MAX_HEALTH") == 140 and constants.get("EXPERIENCE") == 100
	valid = valid and constants.get("DROP_CHANCE") == 0.0
	valid = valid and constants.get("BOSS_NAME") == "Reefback"
	reefback.free()
	return valid


func _test_dormant_ignores_hits() -> bool:
	var reefback := _reefback(Vector2(-400, 112))
	reefback.call("_on_hurtbox_hit", _sword(20, true))
	_step(reefback)
	var brain: ReefbackBrain = reefback.get("brain")
	var valid: bool = (
		reefback.get("health").current == 140 and brain.state == ReefbackBrain.State.DORMANT
	)
	_clean_up(reefback)
	return valid


func _test_ward() -> bool:
	var reefback := _reefback()
	var brain: ReefbackBrain = reefback.get("brain")
	reefback.call("_on_hurtbox_hit", _sword(10, false))
	_step(reefback)
	var valid: bool = reefback.get("health").current == 140 and brain.warded
	reefback.call("_on_hurtbox_hit", _sword(20, true))
	_step(reefback)
	valid = valid and reefback.get("health").current == 140
	valid = valid and brain.state == ReefbackBrain.State.STAGGERED and not brain.warded
	_clean_up(reefback)
	return valid


func _test_staggered_hits_land() -> bool:
	var reefback := _reefback()
	reefback.call("_on_hurtbox_hit", _sword(20, true))
	_step(reefback)
	reefback.call("_on_hurtbox_hit", _sword(10, false))
	var valid: bool = reefback.get("health").current == 130
	_clean_up(reefback)
	return valid


func _test_touch() -> bool:
	var reefback := _reefback(FAR, ReefbackBrain.Move.CHARGE)
	var touch := reefback.get_node("TouchHitbox") as Hitbox
	var valid := touch.active and touch.damage == 10
	_step_until(reefback, ReefbackBrain.State.CHARGE)
	valid = valid and touch.active and touch.damage == 15
	reefback.call("_on_hurtbox_hit", _sword(20, true))
	_step(reefback)
	valid = valid and not touch.active
	_clean_up(reefback)
	return valid


func _test_swipe() -> bool:
	var reefback := _reefback(NEAR, ReefbackBrain.Move.SWIPE)
	var swipe := reefback.get_node("SwipeHitbox") as Hitbox
	var valid := not swipe.active
	_step_until(reefback, ReefbackBrain.State.SWIPE)
	valid = valid and swipe.active and swipe.damage == 15 and swipe.position.x < 0.0
	_step_until(reefback, ReefbackBrain.State.REST)
	valid = valid and not swipe.active
	_clean_up(reefback)
	return valid


func _test_pound() -> bool:
	var reefback := _reefback(NEAR, ReefbackBrain.Move.POUND)
	_step_until(reefback, ReefbackBrain.State.POUND)
	var waves := _spawned(SHOCKWAVE_PATH)
	var valid := waves.size() == 2
	if valid:
		var directions := waves.map(func(wave: Node) -> float: return wave.get("direction"))
		valid = directions.has(-1.0) and directions.has(1.0)
		for wave: Hitbox in waves:
			valid = valid and wave.damage == 10
	_clean_up(reefback)
	return valid


func _test_leap() -> bool:
	var reefback := _reefback(FAR, ReefbackBrain.Move.LEAP)
	var sprite := reefback.get_node("Sprite2D") as Sprite2D
	var resting_y := sprite.position.y
	var land := reefback.get_node("LandHitbox") as Hitbox
	_step_until(reefback, ReefbackBrain.State.LEAP)
	_step(reefback)
	_step(reefback)
	var valid := not (reefback.get_node("TouchHitbox") as Hitbox).active
	valid = valid and not (reefback.get_node("Hurtbox") as Area2D).monitorable
	valid = valid and sprite.position.y < resting_y and not land.active
	_step_until(reefback, ReefbackBrain.State.LAND)
	valid = valid and land.active and land.damage == 20
	valid = valid and sprite.position.y == resting_y
	var waves := _spawned(SHOCKWAVE_PATH)
	valid = valid and waves.size() == 2
	for wave in waves:
		valid = valid and wave.get("lifetime") < 1.0
	_step_until(reefback, ReefbackBrain.State.REST)
	valid = valid and not land.active
	_clean_up(reefback)
	return valid


func _test_throw() -> bool:
	var reefback := _reefback(FAR, ReefbackBrain.Move.THROW)
	_step_until(reefback, ReefbackBrain.State.THROW)
	var chunks := _spawned(CHUNK_PATH)
	var valid := chunks.size() == 1
	if valid:
		var chunk := chunks[0] as Hitbox
		valid = is_equal_approx(chunk.get("target").x, FAR.x) and chunk.damage == 15
		valid = valid and chunk.global_position.y < reefback.global_position.y - 32.0
	_step(reefback)
	valid = valid and _spawned(CHUNK_PATH).size() == 1
	_clean_up(reefback)
	return valid


func _test_chunk() -> bool:
	var chunk := load(CHUNK_PATH).instantiate() as Hitbox
	chunk.set("target", Vector2(40, 112))
	_root.add_child(chunk)
	chunk.global_position = Vector2(120, 70)
	var flight: float = chunk.get_script().get_script_constant_map().get("FLIGHT_TIME", 0.0)
	chunk.call("_physics_process", flight / 2.0)
	var sprite := chunk.get_node("Sprite2D") as Sprite2D
	# Halfway, it is above the straight line between its start and its mark.
	var valid := chunk.active and chunk.global_position.y < 91.0 and sprite.frame < 2
	valid = valid and is_equal_approx(chunk.global_position.x, 80.0)
	chunk.call("_physics_process", flight)
	valid = valid and chunk.global_position == Vector2(40, 112) and sprite.frame == 2
	chunk.call("_physics_process", 1.0)
	valid = valid and chunk.is_queued_for_deletion()
	chunk.free()
	# A hit shatters it where it is.
	var struck := load(CHUNK_PATH).instantiate() as Hitbox
	struck.set("target", Vector2(40, 112))
	_root.add_child(struck)
	struck.global_position = Vector2(120, 70)
	struck.emit_signal(&"struck", Area2D.new())
	struck.call("_physics_process", 0.05)
	valid = valid and struck.global_position == Vector2(120, 70) and not struck.active
	struck.free()
	return valid


func _test_chest_beat() -> bool:
	var reefback := _reefback(FAR)
	reefback.get("health").current = 60
	_step_until(reefback, ReefbackBrain.State.CHEST_BEAT)
	var rubble := _spawned(RUBBLE_PATH)
	var valid := rubble.size() == 3
	var xs := rubble.map(func(r: Node2D) -> float: return r.global_position.x)
	valid = valid and xs.has(FAR.x)
	for x: float in xs:
		valid = valid and x >= reefback.get("arena_left") and x <= reefback.get("arena_right")
	_clean_up(reefback)
	return valid


func _test_rubble() -> bool:
	var rubble := load(RUBBLE_PATH).instantiate() as Hitbox
	_root.add_child(rubble)
	var constants: Dictionary = rubble.get_script().get_script_constant_map()
	var mark := rubble.get_node("Mark") as CanvasItem
	var rock := rubble.get_node("Rock") as Node2D
	var valid := mark.visible and not rubble.active and rock.position.y < -100.0
	rubble.call("_physics_process", constants.FALL_DELAY + constants.FALL_TIME - 0.05)
	valid = valid and not rubble.active and rock.position.y < 0.0
	rubble.call("_physics_process", 0.06)
	valid = valid and rubble.active and rubble.damage == 10 and rock.position.y == 0.0
	rubble.call("_physics_process", 1.0)
	valid = valid and rubble.is_queued_for_deletion()
	rubble.free()
	return valid


func _test_frames() -> bool:
	var reefback := _reefback(FAR, ReefbackBrain.Move.CHARGE)
	var brain: ReefbackBrain = reefback.get("brain")
	var sprite := reefback.get_node("Sprite2D") as Sprite2D
	var valid := sprite.hframes == 8 and sprite.vframes == 1
	# It wakes stomping toward the Player, facing left.
	_step(reefback)
	valid = valid and WALK.has(sprite.frame) and sprite.flip_h
	_step_until(reefback, ReefbackBrain.State.TELL)
	valid = valid and sprite.frame == ROAR
	_step_until(reefback, ReefbackBrain.State.CHARGE)
	valid = valid and WALK.has(sprite.frame)
	_clean_up(reefback)
	var poses := {
		ReefbackBrain.Move.POUND: [OVERHEAD, ReefbackBrain.State.POUND, SWIPE],
		ReefbackBrain.Move.LEAP: [OVERHEAD, ReefbackBrain.State.LEAP, JUMP],
		ReefbackBrain.Move.THROW: [OVERHEAD, ReefbackBrain.State.THROW, SWIPE],
	}
	for move: ReefbackBrain.Move in poses:
		reefback = _reefback(FAR, move)
		sprite = reefback.get_node("Sprite2D") as Sprite2D
		_step_until(reefback, ReefbackBrain.State.TELL)
		valid = valid and sprite.frame == poses[move][0]
		_step_until(reefback, poses[move][1])
		valid = valid and sprite.frame == poses[move][2]
		_clean_up(reefback)
	reefback = _reefback(NEAR, ReefbackBrain.Move.SWIPE)
	sprite = reefback.get_node("Sprite2D") as Sprite2D
	_step_until(reefback, ReefbackBrain.State.SWIPE)
	valid = valid and sprite.frame == SWIPE
	reefback.call("_on_hurtbox_hit", _sword(20, true))
	_step(reefback)
	valid = valid and sprite.frame == STAND
	_clean_up(reefback)
	reefback = _reefback(FAR)
	brain = reefback.get("brain")
	sprite = reefback.get_node("Sprite2D") as Sprite2D
	reefback.get("health").current = 60
	_step_until(reefback, ReefbackBrain.State.CHEST_BEAT)
	var beat_frames := {}
	while brain.state == ReefbackBrain.State.CHEST_BEAT:
		beat_frames[sprite.frame] = true
		_step(reefback)
	valid = valid and beat_frames.has(ROAR) and beat_frames.has(STAND)
	_clean_up(reefback)
	return valid


func _test_ward_outline() -> bool:
	var reefback := _reefback()
	var sprite := reefback.get_node("Sprite2D") as Sprite2D
	var ward := reefback.get_node_or_null("Ward") as Sprite2D
	var valid := ward != null and ward.material is ShaderMaterial
	if valid:
		valid = (ward.material as ShaderMaterial).shader.resource_path == WARD_SHADER_PATH
		valid = valid and ward.texture == sprite.texture and ward.hframes == sprite.hframes
		for i in 30:
			_step(reefback)
			valid = valid and ward.frame == sprite.frame and ward.flip_h == sprite.flip_h
			valid = valid and ward.position == sprite.position
	_clean_up(reefback)
	return valid


func _test_defeat() -> bool:
	var reefback := _reefback()
	var reports: Array[int] = []
	reefback.connect(&"defeated", func(experience: int) -> void: reports.append(experience))
	reefback.call("_on_hurtbox_hit", _sword(20, true))
	_step(reefback)
	reefback.get("health").current = 10
	reefback.call("_on_hurtbox_hit", _sword(10, false))
	reefback.get("health").step(1.0)
	reefback.call("_on_hurtbox_hit", _sword(10, false))
	_step(reefback)
	var brain: ReefbackBrain = reefback.get("brain")
	var valid := reports == [100] and brain.state == ReefbackBrain.State.DEFEATED
	valid = valid and not (reefback.get_node("Hurtbox") as Area2D).monitorable
	valid = valid and not (reefback.get_node("TouchHitbox") as Hitbox).active
	_clean_up(reefback)
	return valid


# A Reefback in the arena, a Player where given (near enough to wake it unless far off), and, if
# given, the one attack it will always choose.
func _reefback(player_at: Vector2 = FAR, move: int = -1) -> CharacterBody2D:
	var player := PLAYER_SCENE.instantiate() as Node2D
	_root.add_child(player)
	player.global_position = player_at
	var reefback := REEFBACK_SCENE.instantiate() as CharacterBody2D
	_root.add_child(reefback)
	reefback.global_position = AT
	if move != -1:
		(reefback.get("brain") as ReefbackBrain).choose = func(
			_options: Array
		) -> ReefbackBrain.Move:
			return move
	_step(reefback)
	return reefback


# Steps the Reefback as the Room would, holding it on the arena floor so tests need no floor.
func _step(reefback: CharacterBody2D) -> void:
	reefback.call("_physics_process", STEP)
	reefback.global_position.y = AT.y


func _step_until(reefback: CharacterBody2D, state: ReefbackBrain.State) -> void:
	var brain: ReefbackBrain = reefback.get("brain")
	for i in 300:
		if brain.state == state:
			return
		_step(reefback)


func _sword(damage: int, charged: bool) -> Hitbox:
	var sword := Hitbox.new()
	sword.damage = damage
	sword.charged = charged
	sword.position = FAR
	return sword


func _spawned(path: String) -> Array:
	return _root.get_children().filter(
		func(node: Node) -> bool: return node.scene_file_path == path
	)


func _clean_up(reefback: Node) -> void:
	for path in [SHOCKWAVE_PATH, CHUNK_PATH, RUBBLE_PATH]:
		for node in _spawned(path):
			node.free()
	reefback.free()
	_root.get_tree().get_first_node_in_group(&"player").free()
