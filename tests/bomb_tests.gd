extends RefCounted

const BOMB_SCENE := preload("res://scenes/items/bomb.tscn")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const PLAYER_HITBOX_LAYER := 1 << 2
const ENEMY_HITBOX_LAYER := 1 << 4
const WORLD_LAYER := 1 << 0
const FRAME := 1.0 / 60.0
const FUSE_TIME := 1.0
const BURST_TIME := 0.25
const BLAST_RADIUS := 24.0
const DAMAGE := 20

# Needs a root that is already in the tree: a Bomb falls in the world.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["A Bomb is lobbed along its facing, up and then down", _test_lobbed],
		["A Bomb lands on the world's terrain", _test_lands_on_terrain],
		["A Bomb's fuse sputters for 1 second, then it bursts where it is", _test_fuse],
		[
			"A Bomb's blast strikes enemies, charged and a blast, for 20, 24 pixels round",
			_test_blast
		],
		["A Bomb is gone once its burst has played", _test_gone_after_burst],
		["A Bomb hisses while its fuse burns, and booms as it bursts", _test_sounds],
	]


func _test_lobbed() -> bool:
	var valid := true
	for facing in [-1.0, 1.0]:
		var bomb := _bomb(facing)
		var start := bomb.position
		_steps(bomb, 6)
		var rising := bomb.position - start
		valid = valid and signf(rising.x) == facing and rising.y < 0.0
		var top := bomb.position.y
		_steps(bomb, 30)
		valid = valid and bomb.position.y > top and signf(bomb.position.x - start.x) == facing
		bomb.free()
	return valid


func _test_lands_on_terrain() -> bool:
	var bomb := _bomb(1.0)
	var body := bomb as CharacterBody2D
	var valid := body != null and body.collision_mask == WORLD_LAYER and body.collision_layer == 0
	bomb.free()
	return valid


func _test_fuse() -> bool:
	var bomb := _bomb(1.0)
	var sprite := bomb.get_node("Sprite") as AnimatedSprite2D
	var hitbox := bomb.get_node("Blast") as Hitbox
	var valid := sprite.animation == &"fuse" and not hitbox.active
	_steps(bomb, roundi(FUSE_TIME / FRAME) - 2)
	valid = valid and not bomb.call("has_burst") and not hitbox.active
	_steps(bomb, 3)
	valid = valid and bomb.call("has_burst") and hitbox.active and sprite.animation == &"burst"
	var at := bomb.position
	_steps(bomb, 3)
	valid = valid and bomb.position == at
	bomb.free()
	return valid


func _test_blast() -> bool:
	var bomb := _bomb(1.0)
	var hitbox := bomb.get_node_or_null("Blast") as Hitbox
	var valid := hitbox != null and hitbox.charged and hitbox.blast and hitbox.damage == DAMAGE
	if valid:
		# Enemies only: the Player's hurtbox is never in its mask.
		valid = hitbox.collision_layer == PLAYER_HITBOX_LAYER
		valid = valid and hitbox.collision_mask == ENEMY_HITBOX_LAYER
		var shape := hitbox.get_node("Shape") as CollisionShape2D
		var circle := shape.shape as CircleShape2D
		valid = valid and circle != null and is_equal_approx(circle.radius, BLAST_RADIUS)
	bomb.free()
	return valid


func _test_gone_after_burst() -> bool:
	var bomb := _bomb(1.0)
	_steps(bomb, roundi((FUSE_TIME + BURST_TIME) / FRAME) - 3)
	var valid := not bomb.is_queued_for_deletion()
	_steps(bomb, 5)
	valid = valid and bomb.is_queued_for_deletion()
	bomb.free()
	return valid


func _test_sounds() -> bool:
	var bomb := _bomb(1.0)
	var valid := _playing(bomb, &"Fuse") and not _playing(bomb, &"Burst")
	_steps(bomb, roundi(FUSE_TIME / FRAME) + 1)
	valid = valid and _playing(bomb, &"Burst") and not _playing(bomb, &"Fuse")
	bomb.free()
	return valid


func _bomb(facing: float) -> Node2D:
	var bomb := BOMB_SCENE.instantiate() as Node2D
	bomb.set("facing", facing)
	bomb.position = Vector2(200, 80)
	_root.add_child(bomb)
	return bomb


func _steps(bomb: Node, count: int) -> void:
	for i in count:
		if bomb.is_queued_for_deletion():
			return
		bomb.call("_physics_process", FRAME)


func _playing(bomb: Node, sound: StringName) -> bool:
	var stream_player := bomb.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer
	return stream_player != null and stream_player.stream != null and stream_player.playing
