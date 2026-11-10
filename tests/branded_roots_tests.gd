extends RefCounted

const ROOTS_SCENE := preload("res://scenes/world/branded_roots.tscn")
const SHEET_PATH := "res://assets/enemies/rusk/branded_roots.png"
const WORLD_LAYER := 1 << 0
const WIDTH := 8.0
const HEIGHT := 112.0
const RISE_TIME := 0.4
const WITHER_TIME := 1.0

# Needs a root that is already in the tree: the roots' sounds play only inside it.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Branded roots stand 8 by 112 up from their foot, drawn from their sheet", _test_column],
		["Branded roots start down: no wall, unseen", _test_start_down],
		["Risen, branded roots stand solid, up out of the floor over 0.4 s", _test_rise],
		["Withered, branded roots sink away over 1 s and the way is open", _test_wither],
		["Branded roots creak as they rise and as they wither, on the SFX bus", _test_sounds],
	]


func _test_column() -> bool:
	var roots := _roots()
	var shape := roots.get_node("Shape") as CollisionShape2D
	var size := (shape.shape as RectangleShape2D).size
	var valid := roots.collision_layer == WORLD_LAYER
	valid = valid and size == Vector2(WIDTH, HEIGHT) and shape.position.y == -HEIGHT / 2.0
	var sprite := roots.get_node("Sprite2D") as Sprite2D
	valid = valid and sprite.texture.resource_path == SHEET_PATH
	roots.free()
	return valid


func _test_start_down() -> bool:
	var roots := _roots()
	var valid: bool = not roots.call("is_up") and _shape(roots).disabled and not roots.visible
	roots.free()
	return valid


func _test_rise() -> bool:
	var roots := _roots()
	var sprite := roots.get_node("Sprite2D") as Sprite2D
	roots.call("rise")
	var valid: bool = roots.call("is_up") and not _shape(roots).disabled and roots.visible
	roots.call("_process", RISE_TIME / 2.0)
	var halfway := sprite.position.y
	roots.call("_process", RISE_TIME)
	valid = valid and halfway < 0.0 and halfway > -HEIGHT
	valid = valid and is_equal_approx(sprite.position.y, -HEIGHT)
	roots.free()
	return valid


func _test_wither() -> bool:
	var roots := _roots()
	roots.call("rise")
	roots.call("_process", 1.0)
	roots.call("wither")
	roots.call("_process", WITHER_TIME / 2.0)
	var valid: bool = roots.visible and not roots.call("is_up")
	roots.call("_process", WITHER_TIME)
	valid = valid and _shape(roots).disabled and not roots.visible
	roots.free()
	return valid


func _test_sounds() -> bool:
	var roots := _roots()
	var valid := true
	for sound in [&"Rise", &"Wither"]:
		var player := roots.get_node_or_null("Sounds/%s" % sound) as AudioStreamPlayer2D
		valid = valid and player != null and player.stream != null and player.bus == &"SFX"
	roots.call("rise")
	valid = valid and (roots.get_node("Sounds/Rise") as AudioStreamPlayer2D).playing
	roots.call("wither")
	valid = valid and (roots.get_node("Sounds/Wither") as AudioStreamPlayer2D).playing
	roots.free()
	return valid


func _roots() -> StaticBody2D:
	var roots := ROOTS_SCENE.instantiate() as StaticBody2D
	_root.add_child(roots)
	return roots


func _shape(roots: Node) -> CollisionShape2D:
	return roots.get_node("Shape") as CollisionShape2D
