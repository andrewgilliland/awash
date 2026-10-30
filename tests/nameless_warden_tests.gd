extends RefCounted

const WARDEN_SCENE := preload("res://scenes/enemies/nameless_warden.tscn")
const SHOCKWAVE_SCENE_PATH := "res://scenes/enemies/shockwave.tscn"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const WardenBrain := preload("res://scripts/enemies/warden_brain.gd")
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_LAYER := 1 << 3
const ENEMY_HITBOX_LAYER := 1 << 4
const STEP := 0.05
const AT := Vector2(136, 112)
const NEAR := Vector2(76, 112)

# Needs a root that is already in the tree: the Warden finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Nameless Warden is a Boss with a body, hurtbox and touch", _test_boxes],
		["A dormant Warden ignores hits", _test_dormant_ignores_hits],
		["A quick Attack glances off the Ward; a Charged one breaks it", _test_ward],
		["While staggered, any hit costs the Warden Health", _test_staggered_hits_land],
		["The Warden's touch costs 10, its bash 15; staggered, nothing", _test_touch],
		["A slam sends a shockwave each way along the floor", _test_slam_shockwaves],
		["A shockwave rolls along the floor, then fades", _test_shockwave_rolls],
		["A defeated Warden kneels and reports its Experience once", _test_defeat],
	]


func _test_boxes() -> bool:
	var warden := WARDEN_SCENE.instantiate() as CharacterBody2D
	var hurtbox := warden.get_node_or_null("Hurtbox") as Area2D
	var touch := warden.get_node_or_null("TouchHitbox") as Hitbox
	var script_constants: Dictionary = warden.get_script().get_script_constant_map()
	var valid := warden.is_in_group(&"enemy") and warden.is_in_group(&"boss")
	valid = valid and warden.collision_layer == ENEMY_LAYER
	valid = valid and hurtbox != null and hurtbox.collision_layer == ENEMY_HITBOX_LAYER
	valid = valid and touch != null and touch.collision_layer == ENEMY_HITBOX_LAYER
	valid = valid and touch.collision_mask == PLAYER_HITBOX_LAYER
	valid = valid and script_constants.get("MAX_HEALTH") == 120
	valid = valid and script_constants.get("EXPERIENCE") == 100
	valid = valid and script_constants.get("DROP_CHANCE") == 0.0
	valid = valid and script_constants.get("BOSS_NAME") == "Nameless Warden"
	warden.free()
	return valid


func _test_dormant_ignores_hits() -> bool:
	var warden := _warden(false)
	warden.call("_on_hurtbox_hit", _sword(20, true))
	_step(warden)
	var brain: WardenBrain = warden.get("brain")
	var valid: bool = warden.get("health").current == 120 and brain.warded
	_clean_up(warden)
	return valid and brain.state == WardenBrain.State.DORMANT


func _test_ward() -> bool:
	var warden := _warden()
	var brain: WardenBrain = warden.get("brain")
	warden.call("_on_hurtbox_hit", _sword(10, false))
	_step(warden)
	var valid: bool = warden.get("health").current == 120 and brain.warded
	warden.call("_on_hurtbox_hit", _sword(20, true))
	_step(warden)
	valid = valid and warden.get("health").current == 120
	valid = valid and brain.state == WardenBrain.State.STAGGERED and not brain.warded
	_clean_up(warden)
	return valid


func _test_staggered_hits_land() -> bool:
	var warden := _warden()
	warden.call("_on_hurtbox_hit", _sword(20, true))
	_step(warden)
	warden.call("_on_hurtbox_hit", _sword(10, false))
	var valid: bool = warden.get("health").current == 110
	_clean_up(warden)
	return valid


func _test_touch() -> bool:
	var warden := _warden()
	var brain: WardenBrain = warden.get("brain")
	var touch := warden.get_node("TouchHitbox") as Hitbox
	var valid := touch.active and touch.damage == 10
	var steps := 0
	while brain.state != WardenBrain.State.BASH and steps < 100:
		_step(warden)
		steps += 1
	valid = valid and touch.active and touch.damage == 15
	warden.call("_on_hurtbox_hit", _sword(20, true))
	_step(warden)
	valid = valid and not touch.active
	_clean_up(warden)
	return valid


func _test_slam_shockwaves() -> bool:
	var warden := _warden()
	var brain: WardenBrain = warden.get("brain")
	var waves: Array = []
	for i in 200:
		_step(warden)
		waves = _shockwaves()
		if not waves.is_empty():
			break
	var valid := brain.state == WardenBrain.State.SLAM and waves.size() == 2
	if valid:
		var directions := waves.map(func(wave: Node) -> float: return wave.get("direction"))
		valid = directions.has(-1.0) and directions.has(1.0)
		for wave: Hitbox in waves:
			valid = valid and wave.active and wave.damage == 10
			valid = valid and wave.collision_mask == PLAYER_HITBOX_LAYER
			valid = valid and is_equal_approx(wave.global_position.y, warden.global_position.y)
	_clean_up(warden)
	return valid


func _test_shockwave_rolls() -> bool:
	var wave := load(SHOCKWAVE_SCENE_PATH).instantiate() as Hitbox
	wave.set("direction", -1.0)
	_root.add_child(wave)
	wave.position = AT
	wave.call("_physics_process", 0.5)
	var speed: float = wave.get_script().get_script_constant_map().get("SPEED", 0.0)
	var valid := speed > 0.0 and is_equal_approx(wave.position.x, AT.x - speed * 0.5)
	valid = valid and not wave.is_queued_for_deletion()
	wave.call("_physics_process", 10.0)
	valid = valid and wave.is_queued_for_deletion()
	wave.free()
	return valid


func _test_defeat() -> bool:
	var warden := _warden()
	var reports: Array[int] = []
	warden.connect(&"defeated", func(experience: int) -> void: reports.append(experience))
	warden.call("_on_hurtbox_hit", _sword(20, true))
	_step(warden)
	warden.get("health").current = 10
	warden.call("_on_hurtbox_hit", _sword(10, false))
	warden.get("health").step(1.0)
	warden.call("_on_hurtbox_hit", _sword(10, false))
	_step(warden)
	var brain: WardenBrain = warden.get("brain")
	var valid := reports == [100] and brain.state == WardenBrain.State.DEFEATED
	valid = valid and not (warden.get_node("Hurtbox") as Area2D).monitorable
	valid = valid and not (warden.get_node("TouchHitbox") as Hitbox).active
	_clean_up(warden)
	return valid


# A Warden in the arena, with a Player near enough to wake it unless told otherwise.
func _warden(awake: bool = true) -> CharacterBody2D:
	var player := PLAYER_SCENE.instantiate() as Node2D
	_root.add_child(player)
	player.global_position = NEAR if awake else Vector2(-400, 112)
	var warden := WARDEN_SCENE.instantiate() as CharacterBody2D
	_root.add_child(warden)
	warden.global_position = AT
	_step(warden)
	return warden


func _step(warden: Node) -> void:
	warden.call("_physics_process", STEP)


func _sword(damage: int, charged: bool) -> Hitbox:
	var sword := Hitbox.new()
	sword.damage = damage
	sword.charged = charged
	sword.position = NEAR
	return sword


func _shockwaves() -> Array:
	return _root.get_children().filter(
		func(node: Node) -> bool: return node.scene_file_path == SHOCKWAVE_SCENE_PATH
	)


func _clean_up(warden: Node) -> void:
	for wave in _shockwaves():
		wave.free()
	warden.free()
	_root.get_tree().get_first_node_in_group(&"player").free()
