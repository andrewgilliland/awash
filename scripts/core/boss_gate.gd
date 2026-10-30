extends StaticBody2D

# A Gate a Boss holds shut: a column of rune light across the road. Defeating the Boss records it
# in the Run, and once the Boss has faded the light dissolves and the way is open. With the Boss
# already defeated this Run, the Room opens without it.

const RunStateScript := preload("res://scripts/core/run_state.gd")
# How long the light waits for the Boss to fade, then how long it takes to dissolve.
const WAIT_TIME := 1.5
const DISSOLVE_TIME := 0.8
const WIDTH := 8.0
const SHIMMER_TIME := 0.12
const LIGHT := Color(0.59, 0.89, 0.94, 0.35)
const BRIGHT := Color(0.94, 0.99, 1.0, 0.9)

# The Boss that holds it, and the id the Run knows that Boss by.
@export var boss: Node2D
@export var boss_id: StringName
# From the floor it stands on up.
@export var height: float = 112.0

# Counts down once the Boss is defeated; negative until then.
var _dissolve_left: float = -1.0
var _clock: float = 0.0

@onready var _shape: CollisionShape2D = $Shape


func _ready() -> void:
	var run := get_node_or_null("/root/RunState") as RunStateScript
	if run != null and run.has_defeated_boss(boss_id):
		if boss != null:
			boss.queue_free()
		_open()
		return
	if boss != null and not boss.is_connected(&"defeated", _on_boss_defeated):
		boss.connect(&"defeated", _on_boss_defeated)


func _on_boss_defeated(_experience: int) -> void:
	var run := get_node_or_null("/root/RunState") as RunStateScript
	if run != null:
		run.defeat_boss(boss_id)
	_dissolve_left = WAIT_TIME + DISSOLVE_TIME


func _process(delta: float) -> void:
	_clock += delta
	if _dissolve_left >= 0.0:
		_dissolve_left -= delta
		modulate.a = clampf(_dissolve_left / DISSOLVE_TIME, 0.0, 1.0)
		if _dissolve_left <= 0.0:
			_open()
	queue_redraw()


func _open() -> void:
	_dissolve_left = -1.0
	_shape.disabled = true
	hide()
	set_process(false)


# Pale light with bright motes drifting up through it, between two bright edges.
func _draw() -> void:
	draw_rect(Rect2(-WIDTH / 2.0, -height, WIDTH, height), LIGHT)
	draw_rect(Rect2(-WIDTH / 2.0, -height, 1.0, height), BRIGHT)
	draw_rect(Rect2(WIDTH / 2.0 - 1.0, -height, 1.0, height), BRIGHT)
	var shimmer := int(_clock / SHIMMER_TIME)
	for row in range(0, int(height), 4):
		var column := (row / 4 + shimmer) % 3
		draw_rect(Rect2(-WIDTH / 2.0 + 1.0 + column * 2.0, -row - 2.0, 2.0, 2.0), BRIGHT)
