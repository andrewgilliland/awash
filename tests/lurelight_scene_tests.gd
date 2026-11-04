extends RefCounted

const LURELIGHT_SCENE := preload("res://scenes/enemies/lurelight.tscn")
const POOLS_PATH := "res://scenes/rooms/undertow_4.tscn"
const LAKE_PATH := "res://scenes/rooms/undertow_7.tscn"
const SHEET_PATH := "res://assets/enemies/lurelight/lurelight_1.png"
const LurelightBrain := preload("res://scripts/enemies/lurelight_brain.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_LAYER := 1 << 3
const ENEMY_HITBOX_LAYER := 1 << 4
const SOUNDS: Array[StringName] = [&"Gulp", &"Snap", &"Hurt", &"Defeat"]
const ANIMATIONS: Array[StringName] = [
	&"hidden", &"dim", &"snap", &"stranded", &"hurt", &"sunk", &"defeated"
]
const SFX_BUS := &"SFX"
const PLAYER_GROUP := &"player"
const FRAME := 1.0 / 60.0
const SNAP_DAMAGE := 15
# Its jaws rise this high out of the water.
const SNAP_HEIGHT := 24.0
# The water's surface in both Rooms, and the pools each Lurelight keeps to, in pixels.
const SURFACE_Y := 96.0
const POOLS := [Vector2(160, 208), Vector2(240, 288)]
const LAKE_STRETCHES := [Vector2(64, 160), Vector2(208, 320)]
# A Player wading beside it, in its jaws' reach.
const WADING := Vector2(12, 10)

# Needs a root that is already in the tree: the Lurelight finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Lurelight has a hurtbox and jaws, and lies in the water", _test_boxes],
		["Lurelight is drawn from its sheet", _test_sprite],
		["Lurelight carries positional sounds on the SFX bus", _test_sounds_on_sfx_bus],
		["Lurelight's jaws strike only as it snaps", _test_jaws_only_snapping],
		["Lurelight can be struck only while stranded", _test_struck_only_stranded],
		["Lurelight's jaws rise from the surface, in a wading Player's way", _test_jaws_reach],
		["Lurelights lurk in the pools under the undertow tunnel", _test_in_pools],
		["Lurelights lurk in the lake's two long shallows", _test_in_lake],
	]


func _test_boxes() -> bool:
	var lurelight := LURELIGHT_SCENE.instantiate() as CharacterBody2D
	var valid := lurelight != null and lurelight.is_in_group(&"enemy")
	if valid:
		valid = lurelight.collision_layer == ENEMY_LAYER and lurelight.collision_mask == 0
		var hurtbox := lurelight.get_node_or_null("Hurtbox") as Area2D
		valid = valid and hurtbox != null and hurtbox.collision_layer == ENEMY_HITBOX_LAYER
		var jaws := lurelight.get_node_or_null("JawsHitbox") as Area2D
		valid = valid and jaws is Hitbox and jaws.collision_mask == PLAYER_HITBOX_LAYER
		valid = valid and jaws.get_node("Shape").shape is RectangleShape2D
		valid = valid and (jaws as Hitbox).damage == SNAP_DAMAGE
	if lurelight != null:
		lurelight.free()
	return valid


func _test_sprite() -> bool:
	var lurelight := _lurelight()
	var sprite := lurelight.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var frames := sprite.sprite_frames
	var valid := frames != null
	for animation in ANIMATIONS:
		valid = valid and frames.has_animation(animation)
	if valid:
		var texture := frames.get_frame_texture(&"hidden", 0) as AtlasTexture
		valid = texture != null and texture.atlas.resource_path == SHEET_PATH
	lurelight.free()
	return valid


func _test_sounds_on_sfx_bus() -> bool:
	var lurelight := LURELIGHT_SCENE.instantiate()
	var valid := true
	for sound in SOUNDS:
		var player := lurelight.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer2D
		valid = valid and player != null and player.stream != null
		valid = valid and player.bus == SFX_BUS and player.max_distance > 0.0
	lurelight.free()
	return valid


func _test_jaws_only_snapping() -> bool:
	var lurelight := _lurelight()
	var target := _stand_in_player(lurelight.global_position + WADING)
	var jaws := lurelight.get_node("JawsHitbox") as Hitbox
	var valid := not jaws.active
	_steps(lurelight, 1)
	valid = valid and _state(lurelight) == LurelightBrain.State.DIM and not jaws.active
	_steps_until(lurelight, LurelightBrain.State.SNAP)
	valid = valid and jaws.active
	_steps_until(lurelight, LurelightBrain.State.STRANDED)
	valid = valid and not jaws.active
	lurelight.free()
	target.free()
	return valid


func _test_struck_only_stranded() -> bool:
	var lurelight := _lurelight()
	var target := _stand_in_player(lurelight.global_position + WADING)
	var hurtbox := lurelight.get_node("Hurtbox") as Area2D
	var valid := not hurtbox.monitorable
	_steps_until(lurelight, LurelightBrain.State.SNAP)
	valid = valid and not hurtbox.monitorable
	_steps_until(lurelight, LurelightBrain.State.STRANDED)
	valid = valid and hurtbox.monitorable
	_steps_until(lurelight, LurelightBrain.State.SUNK)
	valid = valid and not hurtbox.monitorable
	lurelight.free()
	target.free()
	return valid


# From the surface up to its full height, wide enough to meet a Player wading beside it.
func _test_jaws_reach() -> bool:
	var lurelight := LURELIGHT_SCENE.instantiate() as Node2D
	var jaws := lurelight.get_node("JawsHitbox") as Node2D
	var shape := (jaws.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D
	var centre := jaws.position + (jaws.get_node("Shape") as Node2D).position
	var top := centre.y - shape.size.y / 2.0
	var bottom := centre.y + shape.size.y / 2.0
	var valid := absf(top + SNAP_HEIGHT) < 0.5 and absf(bottom) < 0.5
	valid = valid and absf(centre.x) < 0.5 and shape.size.x >= 16.0
	lurelight.free()
	return valid


func _test_in_pools() -> bool:
	return _lurks_in(POOLS_PATH, POOLS)


func _test_in_lake() -> bool:
	return _lurks_in(LAKE_PATH, LAKE_STRETCHES)


# One Lurelight in each stretch of water, at its surface, keeping to it.
func _lurks_in(room_path: String, waters: Array) -> bool:
	var room := (load(room_path) as PackedScene).instantiate()
	var found := []
	for enemy in room.get_node("Enemies").get_children():
		if enemy.scene_file_path != LURELIGHT_SCENE.resource_path:
			continue
		var at := (enemy as Node2D).position
		var water := Vector2(enemy.get("pool_left"), enemy.get("pool_right"))
		var inside := at.x >= water.x and at.x <= water.y and absf(at.y - SURFACE_Y) < 0.5
		if inside:
			found.append(water)
	room.free()
	found.sort()
	return found == waters


func _lurelight() -> CharacterBody2D:
	var lurelight := LURELIGHT_SCENE.instantiate() as CharacterBody2D
	lurelight.set("pool_left", 160.0)
	lurelight.set("pool_right", 208.0)
	lurelight.position = Vector2(184, SURFACE_Y)
	_root.add_child(lurelight)
	return lurelight


func _stand_in_player(at: Vector2) -> Node2D:
	var player := Node2D.new()
	player.add_to_group(PLAYER_GROUP)
	player.global_position = at
	_root.add_child(player)
	return player


func _state(lurelight: Node) -> int:
	return (lurelight.get("brain") as LurelightBrain).state


func _steps(lurelight: Node, count: int) -> void:
	for i in count:
		lurelight.call("_physics_process", FRAME)


func _steps_until(lurelight: Node, state: int) -> void:
	for i in 240:
		if _state(lurelight) == state:
			return
		lurelight.call("_physics_process", FRAME)
