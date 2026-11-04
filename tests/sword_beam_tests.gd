extends RefCounted

const SWORD_BEAM_SCENE := preload("res://scenes/player/sword_beam.tscn")
const SWORD_SHEET_PATH := "res://assets/player/sword_1.png"
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_HITBOX_LAYER := 1 << 4
const WORLD_LAYER := 1 << 0
const FRAME := 1.0 / 60.0
const SPEED := 240.0
const RANGE := 240.0
# The blade's cell on the sword sheet: held straight out.
const BLADE_REGION := Rect2(16, 0, 16, 16)

# Needs a root that is already in the tree: a beam flies in the world.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Sword Beam strikes enemies, charged, for the cost it carries", _test_strikes_charged],
		["Sword Beam flies along its facing at 240 pixels a second", _test_flies_along_facing],
		["Sword Beam is gone at the end of its range", _test_gone_at_range],
		["Sword Beam stops at the first thing it strikes", _test_stops_at_first_strike],
		["Sword Beam stops at the world's terrain", _test_stops_at_terrain],
		["Sword Beam is drawn as the sword's blade, lit, facing its way", _test_drawn_as_blade],
	]


func _test_strikes_charged() -> bool:
	var beam := _beam(-1.0, 40)
	var hitbox := beam.get_node_or_null("Hitbox") as Hitbox
	var valid := hitbox != null and hitbox.charged and hitbox.damage == 40 and hitbox.active
	if valid:
		valid = hitbox.collision_layer == PLAYER_HITBOX_LAYER
		valid = valid and hitbox.collision_mask == ENEMY_HITBOX_LAYER
		var sensor := beam.get_node_or_null("TerrainSensor") as Area2D
		valid = valid and sensor != null and sensor.collision_mask == WORLD_LAYER
	beam.free()
	return valid


func _test_flies_along_facing() -> bool:
	var valid := true
	for facing in [-1.0, 1.0]:
		var beam := _beam(facing)
		var start := beam.position
		_steps(beam, 30)
		var moved := beam.position - start
		valid = valid and absf(moved.x - facing * SPEED * 0.5) < 0.5 and moved.y == 0.0
		valid = valid and not beam.is_queued_for_deletion()
		beam.free()
	return valid


func _test_gone_at_range() -> bool:
	var beam := _beam(1.0)
	_steps(beam, roundi(RANGE / SPEED / FRAME) - 2)
	var valid := not beam.is_queued_for_deletion()
	_steps(beam, 3)
	valid = valid and beam.is_queued_for_deletion()
	beam.free()
	return valid


func _test_stops_at_first_strike() -> bool:
	var beam := _beam(1.0)
	var hitbox := beam.get_node("Hitbox") as Hitbox
	var target := Area2D.new()
	hitbox.struck.emit(target)
	var valid := not hitbox.active and beam.is_queued_for_deletion()
	beam.free()
	target.free()
	return valid


# It strikes for one more step after meeting the terrain, so a hurtbox on that same wall, like the
# Shortcut's, still takes the hit.
func _test_stops_at_terrain() -> bool:
	var beam := _beam(1.0)
	var rock := StaticBody2D.new()
	(beam.get_node("TerrainSensor") as Area2D).body_entered.emit(rock)
	var valid := not beam.is_queued_for_deletion()
	valid = valid and (beam.get_node("Hitbox") as Hitbox).active
	var start := beam.position
	_steps(beam, 1)
	valid = valid and beam.is_queued_for_deletion() and beam.position == start
	beam.free()
	rock.free()
	return valid


func _test_drawn_as_blade() -> bool:
	var valid := true
	for facing in [-1.0, 1.0]:
		var beam := _beam(facing)
		var sprite := beam.get_node_or_null("Sprite") as Sprite2D
		valid = valid and sprite != null
		if sprite != null:
			var texture := sprite.texture as AtlasTexture
			valid = valid and texture != null and texture.atlas.resource_path == SWORD_SHEET_PATH
			valid = valid and texture.region == BLADE_REGION
			valid = valid and sprite.modulate != Color.WHITE
			# The sheet's blade points left; facing right mirrors it.
			valid = valid and sprite.flip_h == (facing > 0.0)
		beam.free()
	return valid


func _beam(facing: float, damage: int = Hitbox.DEFAULT_DAMAGE * 2) -> Node2D:
	var beam := SWORD_BEAM_SCENE.instantiate() as Node2D
	beam.set("facing", facing)
	beam.set("damage", damage)
	beam.position = Vector2(200, 80)
	_root.add_child(beam)
	return beam


func _steps(beam: Node, count: int) -> void:
	for i in count:
		if beam.is_queued_for_deletion():
			return
		beam.call("_physics_process", FRAME)
