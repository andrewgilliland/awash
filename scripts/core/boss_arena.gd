extends Node2D

# A Boss's arena, with walls the Boss raises to shut the Player in: its children that rise and
# wither. As the Boss wakes the camera holds on the arena and the Room's theme falls silent; as
# the walls rise the Boss's own theme plays; once he is beaten the Run remembers, and as he goes
# the walls wither and all lets go. With the Boss beaten this Run, the Room opens without him.

const RunStateScript := preload("res://scripts/core/run_state.gd")

# The Boss, and the id the Run knows his fight by.
@export var boss: Node2D
@export var boss_id: StringName
@export var theme: AudioStream
# The camera's left and right limits from the Boss waking until he goes.
@export var hold_left: int = 0
@export var hold_right: int = 0

# The track that was playing as the Boss woke, played again once he goes.
var _before: AudioStream
var _limits: Vector2i = Vector2i.ZERO


func _ready() -> void:
	var run := get_node_or_null("/root/RunState") as RunStateScript
	if run != null and run.has_defeated_boss(boss_id):
		if boss != null:
			boss.queue_free()
		return
	if boss == null:
		return
	boss.connect(&"woke", _on_woke)
	boss.connect(&"fight_began", _on_fight_began)
	boss.connect(&"defeated", _on_defeated)
	boss.connect(&"retreated", _on_retreated)


func _on_woke() -> void:
	var camera := _camera()
	if camera != null:
		_limits = Vector2i(camera.limit_left, camera.limit_right)
		camera.limit_left = hold_left
		camera.limit_right = hold_right
	var music := _music()
	if music != null:
		_before = music.call("current")
		music.call("stop")


func _on_fight_began() -> void:
	for wall in _walls():
		wall.call("rise")
	var music := _music()
	if music != null:
		music.call("play", theme)


func _on_defeated(_experience: int) -> void:
	var run := get_node_or_null("/root/RunState") as RunStateScript
	if run != null:
		run.defeat_boss(boss_id)


func _on_retreated() -> void:
	for wall in _walls():
		wall.call("wither")
	var camera := _camera()
	if camera != null and _limits != Vector2i.ZERO:
		camera.limit_left = _limits.x
		camera.limit_right = _limits.y
	var music := _music()
	if music != null and _before != null:
		music.call("play", _before)


func _walls() -> Array[Node]:
	return get_children().filter(func(child: Node) -> bool: return child.has_method("rise"))


func _camera() -> Camera2D:
	return get_parent().get_node_or_null("Player/Camera2D") as Camera2D


func _music() -> Node:
	return get_node_or_null("/root/Music")
