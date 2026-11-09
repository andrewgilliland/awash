extends RefCounted

# The Axe Throw: what a Charged Attack with the Stout Axe looses, a glowing copy of the axe that
# spins up and out along the Player's facing and falls in an arc.

const AXE_THROW_SCENE := preload("res://scenes/player/axe_throw.tscn")
const AXE_SHEET_PATH := "res://assets/player/stout_axe.png"
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_HITBOX_LAYER := 1 << 4
const WORLD_LAYER := 1 << 0
const FRAME := 1.0 / 60.0
# How it leaves the hand, facing right, and how fast it turns.
const THROW := Vector2(180.0, -210.0)
const SPIN := TAU * 3.0
# The axe's cell on its sheet: held level.
const AXE_REGION := Rect2(16, 0, 16, 16)
# However far it falls, it is gone by then.
const LIFETIME := 1.5

# Needs a root that is already in the tree: a throw flies in the world.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Axe Throw strikes enemies, charged, for the cost it carries", _test_strikes_charged],
		["Axe Throw leaves the hand up and out along its facing", _test_leaves_up_and_out],
		["Axe Throw falls in an arc", _test_falls_in_arc],
		["Axe Throw spins its way, three turns a second", _test_spins],
		["Axe Throw stops at the first thing it strikes", _test_stops_at_first_strike],
		["Axe Throw stops at the world's terrain", _test_stops_at_terrain],
		["Axe Throw is gone once it has fallen out of play", _test_gone_in_time],
		["Axe Throw is drawn as the axe, lit, facing its way", _test_drawn_as_axe],
	]


func _test_strikes_charged() -> bool:
	var axe := _axe(-1.0, 40)
	var hitbox := axe.get_node_or_null("Hitbox") as Hitbox
	var valid := hitbox != null and hitbox.charged and hitbox.damage == 40 and hitbox.active
	if valid:
		valid = hitbox.collision_layer == PLAYER_HITBOX_LAYER
		valid = valid and hitbox.collision_mask == ENEMY_HITBOX_LAYER
		var sensor := axe.get_node_or_null("TerrainSensor") as Area2D
		valid = valid and sensor != null and sensor.collision_mask == WORLD_LAYER
	axe.free()
	return valid


func _test_leaves_up_and_out() -> bool:
	var valid := true
	for facing in [-1.0, 1.0]:
		var axe := _axe(facing)
		var start := axe.position
		_steps(axe, 6)
		var moved := axe.position - start
		valid = valid and absf(moved.x - facing * THROW.x * 6.0 * FRAME) < 0.5
		valid = valid and moved.y < -10.0
		axe.free()
	return valid


func _test_falls_in_arc() -> bool:
	var axe := _axe(1.0)
	var start := axe.position
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var apex := roundi(-THROW.y / gravity / FRAME)
	_steps(axe, apex)
	var top := axe.position.y
	var valid := top < start.y - 15.0
	_steps(axe, apex + 6)
	valid = valid and axe.position.y > start.y and not axe.is_queued_for_deletion()
	axe.free()
	return valid


func _test_spins() -> bool:
	var valid := true
	for facing in [-1.0, 1.0]:
		var axe := _axe(facing)
		var sprite := axe.get_node("Sprite") as Sprite2D
		_steps(axe, 10)
		valid = valid and absf(sprite.rotation - facing * SPIN * 10.0 * FRAME) < 0.01
		axe.free()
	return valid


func _test_stops_at_first_strike() -> bool:
	var axe := _axe(1.0)
	var hitbox := axe.get_node("Hitbox") as Hitbox
	var target := Area2D.new()
	hitbox.struck.emit(target)
	var valid := not hitbox.active and axe.is_queued_for_deletion()
	axe.free()
	target.free()
	return valid


# It strikes for one more step after meeting the terrain, so a hurtbox on that same wall, like the
# Shortcut's, still takes the hit.
func _test_stops_at_terrain() -> bool:
	var axe := _axe(1.0)
	var rock := StaticBody2D.new()
	(axe.get_node("TerrainSensor") as Area2D).body_entered.emit(rock)
	var valid := not axe.is_queued_for_deletion()
	valid = valid and (axe.get_node("Hitbox") as Hitbox).active
	var start := axe.position
	_steps(axe, 1)
	valid = valid and axe.is_queued_for_deletion() and axe.position == start
	axe.free()
	rock.free()
	return valid


func _test_gone_in_time() -> bool:
	var axe := _axe(1.0)
	_steps(axe, roundi(LIFETIME / FRAME) - 2)
	var valid := not axe.is_queued_for_deletion()
	_steps(axe, 3)
	valid = valid and axe.is_queued_for_deletion()
	axe.free()
	return valid


func _test_drawn_as_axe() -> bool:
	var valid := true
	for facing in [-1.0, 1.0]:
		var axe := _axe(facing)
		var sprite := axe.get_node_or_null("Sprite") as Sprite2D
		valid = valid and sprite != null
		if sprite != null:
			var texture := sprite.texture as AtlasTexture
			valid = valid and texture != null and texture.atlas.resource_path == AXE_SHEET_PATH
			valid = valid and texture.region == AXE_REGION
			valid = valid and sprite.modulate != Color.WHITE
			# The sheet's axe points left; facing right mirrors it.
			valid = valid and sprite.flip_h == (facing > 0.0)
		axe.free()
	return valid


func _axe(facing: float, damage: int = Hitbox.DEFAULT_DAMAGE * 2) -> Node2D:
	var axe := AXE_THROW_SCENE.instantiate() as Node2D
	axe.set("facing", facing)
	axe.set("damage", damage)
	axe.position = Vector2(200, 80)
	_root.add_child(axe)
	return axe


func _steps(axe: Node, count: int) -> void:
	for i in count:
		if axe.is_queued_for_deletion():
			return
		axe.call("_physics_process", FRAME)
