extends RefCounted

const WRAITH_SCENE := preload("res://scenes/enemies/wraith.tscn")
const UNDERTOW_PATH := "res://scenes/rooms/waking_coast_9.tscn"
const SHEET_PATH := "res://assets/sprites/enemies/wraith_1.png"
const WraithBrain := preload("res://scripts/enemies/wraith_brain.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_LAYER := 1 << 3
const ENEMY_HITBOX_LAYER := 1 << 4
const SOUNDS: Array[StringName] = [&"Wail", &"Lash", &"Hurt", &"Defeat"]
const ANIMATIONS: Array[StringName] = [&"drift", &"manifest", &"lash", &"exposed", &"hurt"]
const SFX_BUS := &"SFX"
const PLAYER_GROUP := &"player"
const FRAME := 1.0 / 60.0
const LASH_DAMAGE := 15
# The undertow's tall stretch of tunnel west of its east pool, and its floor, in pixels.
const TALL_STRETCH := Vector2(432, 544)
const FLOOR_Y := 96.0
# The Player's sword reaches from 18 pixels above its feet down to them; the anchor must float
# where a swing from the ground can hit it.
const SWORD_REACH := Vector2(8, 18)

# Needs a root that is already in the tree: the Wraith finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Wraith has a hurtbox and a lash, and floats through the world", _test_boxes],
		["Wraith is drawn from its sheet", _test_sprite],
		["Wraith carries positional sounds on the SFX bus", _test_sounds_on_sfx_bus],
		["Wraith's anchor can be struck only while exposed", _test_anchor_only_exposed],
		["Wraith looks see-through phased and solid manifest", _test_see_through],
		["Wraith turns its lash toward the Player", _test_faces_player],
		["A Wraith haunts the undertow's tall stretch", _test_in_undertow],
	]


func _test_boxes() -> bool:
	var wraith := WRAITH_SCENE.instantiate() as CharacterBody2D
	var valid := wraith != null and wraith.is_in_group(&"enemy")
	if valid:
		valid = wraith.collision_layer == ENEMY_LAYER and wraith.collision_mask == 0
		var hurtbox := wraith.get_node_or_null("Hurtbox") as Area2D
		valid = valid and hurtbox != null and hurtbox.collision_layer == ENEMY_HITBOX_LAYER
		var lash := wraith.get_node_or_null("LashHitbox") as Area2D
		valid = valid and lash is Hitbox and lash.collision_mask == PLAYER_HITBOX_LAYER
		valid = valid and lash.get_node("Shape").shape is RectangleShape2D
		valid = valid and (lash as Hitbox).damage == LASH_DAMAGE
	if wraith != null:
		wraith.free()
	return valid


func _test_sprite() -> bool:
	var wraith := _wraith()
	var sprite := wraith.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var frames := sprite.sprite_frames
	var valid := frames != null
	for animation in ANIMATIONS:
		valid = valid and frames.has_animation(animation)
	if valid:
		var texture := frames.get_frame_texture(&"drift", 0) as AtlasTexture
		valid = texture != null and texture.atlas.resource_path == SHEET_PATH
	wraith.free()
	return valid


func _test_sounds_on_sfx_bus() -> bool:
	var wraith := WRAITH_SCENE.instantiate()
	var valid := true
	for sound in SOUNDS:
		var player := wraith.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer2D
		valid = valid and player != null and player.stream != null
		valid = valid and player.bus == SFX_BUS and player.max_distance > 0.0
	wraith.free()
	return valid


func _test_anchor_only_exposed() -> bool:
	var wraith := _wraith()
	var target := _stand_in_player(wraith.global_position + Vector2(18, 8))
	var hurtbox := wraith.get_node("Hurtbox") as Area2D
	var lash := wraith.get_node("LashHitbox") as Hitbox
	var valid := not hurtbox.monitorable and not lash.active
	_steps(wraith, 1)
	valid = valid and _state(wraith) == WraithBrain.State.MANIFEST
	valid = valid and not hurtbox.monitorable and not lash.active
	_steps_until(wraith, WraithBrain.State.LASH)
	valid = valid and not hurtbox.monitorable and lash.active
	_steps_until(wraith, WraithBrain.State.EXPOSED)
	valid = valid and hurtbox.monitorable and not lash.active
	_steps_until(wraith, WraithBrain.State.DRIFT)
	valid = valid and not hurtbox.monitorable
	wraith.free()
	target.free()
	return valid


func _test_see_through() -> bool:
	var wraith := _wraith()
	var sprite := wraith.get_node("AnimatedSprite2D") as CanvasItem
	var valid := sprite.modulate.a < 1.0
	var target := _stand_in_player(wraith.global_position + Vector2(18, 8))
	_steps(wraith, 1)
	valid = valid and sprite.modulate.a == 1.0
	wraith.free()
	target.free()
	return valid


func _test_faces_player() -> bool:
	var valid := true
	for side in [-1.0, 1.0]:
		var wraith := _wraith()
		var target := _stand_in_player(wraith.global_position + Vector2(side * 18, 8))
		_steps(wraith, 1)
		var sprite := wraith.get_node("AnimatedSprite2D") as AnimatedSprite2D
		var lash := wraith.get_node("LashHitbox") as Node2D
		valid = valid and signf(lash.position.x) == side and sprite.flip_h == (side < 0.0)
		wraith.free()
		target.free()
	return valid


func _test_in_undertow() -> bool:
	var room := (load(UNDERTOW_PATH) as PackedScene).instantiate()
	var wraith := room.get_node_or_null("Enemies/Wraith") as Node2D
	var valid := wraith != null and wraith.scene_file_path == WRAITH_SCENE.resource_path
	if valid:
		var left: float = wraith.get("haunt_left")
		var right: float = wraith.get("haunt_right")
		valid = left >= TALL_STRETCH.x and right <= TALL_STRETCH.y and left < right
		valid = valid and wraith.position.x >= left and wraith.position.x <= right
		var above := FLOOR_Y - wraith.position.y
		valid = valid and above >= SWORD_REACH.x and above <= SWORD_REACH.y
	room.free()
	return valid


func _wraith() -> CharacterBody2D:
	var wraith := WRAITH_SCENE.instantiate() as CharacterBody2D
	wraith.set("haunt_left", 448.0)
	wraith.set("haunt_right", 528.0)
	wraith.position = Vector2(488, 80)
	_root.add_child(wraith)
	return wraith


func _stand_in_player(at: Vector2) -> Node2D:
	var player := Node2D.new()
	player.add_to_group(PLAYER_GROUP)
	player.global_position = at
	_root.add_child(player)
	return player


func _state(wraith: Node) -> int:
	return (wraith.get("brain") as WraithBrain).state


func _steps(wraith: Node, count: int) -> void:
	for i in count:
		wraith.call("_physics_process", FRAME)


func _steps_until(wraith: Node, state: int) -> void:
	for i in 240:
		if _state(wraith) == state:
			return
		wraith.call("_physics_process", FRAME)
