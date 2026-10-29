extends RefCounted

const STORM_WISP_SCENE := preload("res://scenes/enemies/storm_wisp.tscn")
const RUNE_ROAD_PATH := "res://scenes/rooms/waking_coast_6.tscn"
const SHEET_PATH := "res://assets/sprites/enemies/storm_wisp_1.png"
const StormWispBrain := preload("res://scripts/enemies/storm_wisp_brain.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_LAYER := 1 << 3
const ENEMY_HITBOX_LAYER := 1 << 4
const SOUNDS: Array[StringName] = [&"Crackle", &"Zap", &"Hurt", &"Defeat"]
const ANIMATIONS: Array[StringName] = [&"drift", &"crackle", &"arc", &"rest", &"hurt"]
const SFX_BUS := &"SFX"
const PLAYER_GROUP := &"player"
const FRAME := 1.0 / 60.0
# The rune road's heights: their surface, and the columns they span, in pixels.
const HEIGHTS_Y := 48.0
const HEIGHTS := Vector2(192, 320)
# The Player's sword reaches from 18 pixels above its feet down to them; the Wisp must hover
# where a swing from the ground can hit it.
const SWORD_REACH := Vector2(8, 18)

# Needs a root that is already in the tree: the Wisp finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Storm Wisp has a hurtbox and an arc, and flies through the world", _test_boxes],
		["Storm Wisp is drawn from its sheet", _test_sprite],
		["Storm Wisp carries positional sounds on the SFX bus", _test_sounds_on_sfx_bus],
		["Storm Wisp's arc is live only while it arcs", _test_arc_live_while_arcing],
		["A Storm Wisp rides the wind over the rune road's heights", _test_over_rune_road],
	]


func _test_boxes() -> bool:
	var wisp := STORM_WISP_SCENE.instantiate() as CharacterBody2D
	var valid := wisp != null and wisp.is_in_group(&"enemy")
	if valid:
		valid = wisp.collision_layer == ENEMY_LAYER and wisp.collision_mask == 0
		var hurtbox := wisp.get_node_or_null("Hurtbox") as Area2D
		valid = valid and hurtbox != null and hurtbox.collision_layer == ENEMY_HITBOX_LAYER
		var arc := wisp.get_node_or_null("ArcHitbox") as Area2D
		valid = valid and arc is Hitbox and arc.collision_mask == PLAYER_HITBOX_LAYER
		valid = valid and arc.get_node("Shape").shape is CircleShape2D
	if wisp != null:
		wisp.free()
	return valid


func _test_sprite() -> bool:
	var wisp := _wisp()
	var sprite := wisp.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var frames := sprite.sprite_frames
	var valid := frames != null
	for animation in ANIMATIONS:
		valid = valid and frames.has_animation(animation)
	if valid:
		var texture := frames.get_frame_texture(&"drift", 0) as AtlasTexture
		valid = texture != null and texture.atlas.resource_path == SHEET_PATH
	wisp.free()
	return valid


func _test_sounds_on_sfx_bus() -> bool:
	var wisp := STORM_WISP_SCENE.instantiate()
	var valid := true
	for sound in SOUNDS:
		var player := wisp.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer2D
		valid = valid and player != null and player.stream != null
		valid = valid and player.bus == SFX_BUS and player.max_distance > 0.0
	wisp.free()
	return valid


func _test_arc_live_while_arcing() -> bool:
	var wisp := _wisp()
	var target := _stand_in_player(wisp.global_position + Vector2(20, 14))
	var brain := wisp.get("brain") as StormWispBrain
	var arc := wisp.get_node("ArcHitbox") as Hitbox
	_steps(wisp, 1)
	var valid := brain.state == StormWispBrain.State.CRACKLE and not arc.active
	_steps_until(wisp, StormWispBrain.State.ARC)
	valid = valid and arc.active
	_steps_until(wisp, StormWispBrain.State.REST)
	valid = valid and not arc.active
	wisp.free()
	target.free()
	return valid


func _test_over_rune_road() -> bool:
	var room := (load(RUNE_ROAD_PATH) as PackedScene).instantiate()
	var wisp := room.get_node_or_null("Enemies/StormWisp") as Node2D
	var valid := wisp != null and wisp.scene_file_path == STORM_WISP_SCENE.resource_path
	if valid:
		var left: float = wisp.get("drift_left")
		var right: float = wisp.get("drift_right")
		valid = left >= HEIGHTS.x and right <= HEIGHTS.y and left < right
		valid = valid and wisp.position.x >= left and wisp.position.x <= right
		var above := HEIGHTS_Y - wisp.position.y
		valid = valid and above >= SWORD_REACH.x and above <= SWORD_REACH.y
	room.free()
	return valid


func _wisp() -> CharacterBody2D:
	var wisp := STORM_WISP_SCENE.instantiate() as CharacterBody2D
	wisp.set("drift_left", 200.0)
	wisp.set("drift_right", 280.0)
	wisp.position = Vector2(240, 34)
	_root.add_child(wisp)
	return wisp


func _stand_in_player(at: Vector2) -> Node2D:
	var player := Node2D.new()
	player.add_to_group(PLAYER_GROUP)
	player.global_position = at
	_root.add_child(player)
	return player


func _steps(wisp: Node, count: int) -> void:
	for i in count:
		wisp.call("_physics_process", FRAME)


func _steps_until(wisp: Node, state: int) -> void:
	var brain := wisp.get("brain") as StormWispBrain
	for i in 240:
		if brain.state == state:
			return
		wisp.call("_physics_process", FRAME)
