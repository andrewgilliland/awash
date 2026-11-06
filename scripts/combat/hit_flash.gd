extends Node

# Turns a struck enemy's sprite white for a moment, so a hit that lands is seen to land.

const SHADER := preload("res://scripts/combat/hit_flash.gdshader")
const FLASH_TIME := 0.08

# The sprite it flashes.
@export var target: NodePath = ^"../AnimatedSprite2D"

var _left: float = 0.0
var _material: ShaderMaterial


func _ready() -> void:
	var sprite := get_node_or_null(target) as CanvasItem
	if sprite == null:
		return
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"flash", 0.0)
	sprite.material = _material


func flash() -> void:
	_left = FLASH_TIME
	_show()


func is_flashing() -> bool:
	return _left > 0.0


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	_show()


func _show() -> void:
	if _material != null:
		_material.set_shader_parameter(&"flash", 1.0 if _left > 0.0 else 0.0)
