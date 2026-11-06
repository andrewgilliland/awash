@tool
extends StaticBody2D

# A Breakable wall: cracked rock across a way, sized in tiles down and right of its corner. Only a
# Bomb's blast breaks it; a sword's hit, quick or charged, knocks hollow off it. It crumbles as it
# breaks, and the Run remembers. Across a Shortcut, breaking it opens the Shortcut too, and an
# open Shortcut leaves it broken. Set it in a Room ahead of the Room's terrain, so the ground is
# drawn over the rubble that falls past it.

const RunStateScript := preload("res://scripts/core/run_state.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")
const TILES := preload("res://assets/world/breakable_wall.png")
const TILE := 16
# The cracked blocks side by side in its sheet; each tile draws one.
const VARIANTS := 3
# Chunks of rubble thrown out for each tile it covers.
const RUBBLE_PER_TILE := 4

# The id the Run knows it by.
@export var wall_id: StringName
# The Shortcut it stands across, if any.
@export var shortcut_id: StringName
@export var size: Vector2i = Vector2i.ONE:
	set(value):
		size = value.max(Vector2i.ONE)
		if is_node_ready() and not Engine.is_editor_hint():
			_fit()
		queue_redraw()

var _broken: bool = false

@onready var _shape: CollisionShape2D = $Shape
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _hurtbox_shape: CollisionShape2D = $Hurtbox/Shape
@onready var _rubble: CPUParticles2D = $Rubble
@onready var _dust: CPUParticles2D = $Dust
@onready var _knock: AudioStreamPlayer = $Sounds/Knock
@onready var _crumble: AudioStreamPlayer = $Sounds/Crumble


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_fit()
	var run := get_node_or_null("/root/RunState") as RunStateScript
	if run != null and _remembered_broken(run):
		_open()
		hide()
		return
	if not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)


func is_broken() -> bool:
	return _broken


func _draw() -> void:
	if _broken:
		return
	for y in size.y:
		for x in size.x:
			var variant := (x * 2 + y + x * y) % VARIANTS
			var at := Rect2(x * TILE, y * TILE, TILE, TILE)
			draw_texture_rect_region(TILES, at, Rect2(variant * TILE, 0, TILE, TILE))


func _remembered_broken(run: RunStateScript) -> bool:
	if run.has_broken_wall(wall_id):
		return true
	return not shortcut_id.is_empty() and run.has_opened_shortcut(shortcut_id)


func _on_hurtbox_hit(hitbox: Area2D) -> void:
	if _broken:
		return
	var blast: bool = hitbox.blast if hitbox is Hitbox else false
	if not blast:
		_knock.play()
		return
	var run := get_node_or_null("/root/RunState") as RunStateScript
	if run != null:
		run.break_wall(wall_id)
		if not shortcut_id.is_empty():
			run.open_shortcut(shortcut_id)
	_open()
	_rubble.restart()
	_dust.restart()
	_crumble.play()


# Its shapes and its rubble cover every tile it stands across.
func _fit() -> void:
	var extent := Vector2(size * TILE)
	for shape: CollisionShape2D in [_shape, _hurtbox_shape]:
		var rect := RectangleShape2D.new()
		rect.size = extent
		shape.shape = rect
		shape.position = extent / 2.0
	for particles: CPUParticles2D in [_rubble, _dust]:
		particles.position = extent / 2.0
		particles.emission_rect_extents = extent / 2.0
	_rubble.amount = size.x * size.y * RUBBLE_PER_TILE


# Drawn no more; the shapes stop blocking once the physics step that broke it is done.
func _open() -> void:
	_broken = true
	_shape.set_deferred("disabled", true)
	_hurtbox_shape.set_deferred("disabled", true)
	_hurtbox.set_deferred("monitorable", false)
	queue_redraw()
