extends RefCounted

# Combat feel: a struck enemy's white flash, the hit-stop that freezes play for a few frames, the
# camera's whole-pixel shake, and HitFeel, which picks each for what happened.

const HIT_FLASH_PATH := "res://scripts/combat/hit_flash.gd"
const HIT_STOP_PATH := "res://scripts/combat/hit_stop.gd"
const CAMERA_SHAKE_PATH := "res://scripts/combat/camera_shake.gd"
const HIT_FEEL_PATH := "res://scripts/combat/hit_feel.gd"
const FRAME := 1.0 / 60.0

# Needs a root that is already in the tree: hit-stop and shake are found through their groups.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["A hit flash turns its sprite white for 0.08 seconds", _test_flash],
		["Hit-stop all but stops play for its frames, then lets it go", _test_hit_stop],
		["The longer hit-stop wins, and leaving the tree lets play go", _test_hit_stop_overlap],
		["Hit-stop counts frames from frame times slowed or not", _test_hit_stop_frames],
		["Screen shake moves the camera in whole pixels, then settles", _test_shake],
		["A struck enemy flashes and stops play 3 frames; a defeat, 5", _test_enemy_struck],
		["A hurt Player stops play 5 frames and shakes the camera 2 pixels", _test_player_hurt],
		["A Bomb's burst shakes 3, the Warden's slam 3, a wall crumbling 2", _test_shakes],
	]


func _test_flash() -> bool:
	if not _exists([HIT_FLASH_PATH]):
		return false
	var enemy := Node2D.new()
	var sprite := Sprite2D.new()
	var flash := _flash_on(enemy, sprite)
	var material := sprite.material as ShaderMaterial
	var valid := material != null and is_zero_approx(material.get_shader_parameter(&"flash"))
	flash.call("flash")
	valid = valid and flash.call("is_flashing") and material.get_shader_parameter(&"flash") == 1.0
	_process(flash, 4)
	valid = valid and flash.call("is_flashing")
	_process(flash, 2)
	valid = valid and not flash.call("is_flashing")
	valid = valid and is_zero_approx(material.get_shader_parameter(&"flash"))
	enemy.free()
	return valid


func _test_hit_stop() -> bool:
	if not _exists([HIT_STOP_PATH]):
		return false
	var stop := _hit_stop()
	stop.call("stop", 3)
	var valid: bool = stop.call("is_frozen") and Engine.time_scale <= 0.01
	_step(stop, 2)
	valid = valid and stop.call("is_frozen") and Engine.time_scale <= 0.01
	_step(stop, 1)
	valid = valid and Engine.time_scale == 1.0
	stop.free()
	return valid


func _test_hit_stop_overlap() -> bool:
	if not _exists([HIT_STOP_PATH]):
		return false
	var stop := _hit_stop()
	stop.call("stop", 5)
	_step(stop, 1)
	stop.call("stop", 3)
	var valid: bool = stop.call("frames_left") == 4
	stop.call("stop", 6)
	valid = valid and stop.call("frames_left") == 6
	stop.free()
	return valid and Engine.time_scale == 1.0


# The frame a blow lands in began at full speed; each frame after it runs slowed.
func _test_hit_stop_frames() -> bool:
	if not _exists([HIT_STOP_PATH]):
		return false
	var stop := _hit_stop()
	stop.call("stop", 3)
	stop.call("_process", FRAME)
	var valid: bool = stop.call("frames_left") == 2
	stop.call("_process", FRAME * Engine.time_scale)
	valid = valid and stop.call("frames_left") == 1
	stop.call("stop", 3)
	stop.call("_process", FRAME * Engine.time_scale)
	valid = valid and stop.call("frames_left") == 2
	stop.free()
	return valid


func _test_shake() -> bool:
	if not _exists([CAMERA_SHAKE_PATH]):
		return false
	var camera := _camera()
	var shake := camera.get_node("Shake")
	shake.call("shake", 3, 0.25)
	var moved := false
	var valid := true
	for i in 14:
		_process(shake, 1)
		var offset := camera.offset
		moved = moved or offset != Vector2.ZERO
		valid = valid and offset == offset.round() and absf(offset.x) <= 3.0
		valid = valid and absf(offset.y) <= 3.0
	_process(shake, 2)
	valid = valid and moved and camera.offset == Vector2.ZERO
	camera.free()
	return valid


func _test_enemy_struck() -> bool:
	if not _exists([HIT_FEEL_PATH, HIT_FLASH_PATH, HIT_STOP_PATH]):
		return false
	var hit_feel: GDScript = load(HIT_FEEL_PATH)
	var stop := _hit_stop()
	var enemy := Node2D.new()
	var flash := _flash_on(enemy, Sprite2D.new())
	hit_feel.call("enemy_struck", enemy, false)
	var valid: bool = flash.call("is_flashing") and stop.call("frames_left") == 3
	_step(stop, 4)
	hit_feel.call("enemy_struck", enemy, true)
	valid = valid and stop.call("frames_left") == 5
	enemy.free()
	stop.free()
	return valid


func _test_player_hurt() -> bool:
	if not _exists([HIT_FEEL_PATH, HIT_STOP_PATH, CAMERA_SHAKE_PATH]):
		return false
	var hit_feel: GDScript = load(HIT_FEEL_PATH)
	var stop := _hit_stop()
	var camera := _camera()
	hit_feel.call("player_hurt", camera)
	var shake := camera.get_node("Shake")
	var valid: bool = stop.call("frames_left") == 5 and shake.call("strength") == 2
	stop.free()
	camera.free()
	return valid


func _test_shakes() -> bool:
	if not _exists([HIT_FEEL_PATH, CAMERA_SHAKE_PATH]):
		return false
	var hit_feel: GDScript = load(HIT_FEEL_PATH)
	var valid := true
	for moment in [[&"bomb_burst", 3, 0.25], [&"slam", 3, 0.3], [&"wall_crumble", 2, 0.3]]:
		var camera := _camera()
		hit_feel.call(moment[0], camera)
		var shake := camera.get_node("Shake")
		valid = valid and shake.call("strength") == moment[1]
		valid = valid and is_equal_approx(shake.call("time_left"), moment[2])
		camera.free()
	return valid


# An enemy with its sprite and, beside it, a hit flash aimed at it as each enemy's is.
func _flash_on(enemy: Node2D, sprite: Sprite2D) -> Node:
	sprite.name = "AnimatedSprite2D"
	enemy.add_child(sprite)
	var flash := Node.new()
	flash.name = "HitFlash"
	flash.set_script(load(HIT_FLASH_PATH))
	enemy.add_child(flash)
	_root.add_child(enemy)
	return flash


func _hit_stop() -> Node:
	var stop := Node.new()
	stop.set_script(load(HIT_STOP_PATH))
	_root.add_child(stop)
	return stop


func _camera() -> Camera2D:
	var camera := Camera2D.new()
	var shake := Node.new()
	shake.name = "Shake"
	shake.set_script(load(CAMERA_SHAKE_PATH))
	camera.add_child(shake)
	_root.add_child(camera)
	return camera


static func _process(node: Node, frames: int) -> void:
	for i in frames:
		node.call("_process", FRAME)


# Lets a hit-stop run on by that many frames of play.
static func _step(stop: Node, frames: int) -> void:
	for i in frames:
		stop.call("step", FRAME)


static func _exists(paths: Array) -> bool:
	return paths.all(func(path: String) -> bool: return ResourceLoader.exists(path))
