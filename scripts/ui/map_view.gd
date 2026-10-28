extends Control

const WorldMap := preload("res://scripts/core/world_map.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const PLAYER_GROUP := &"player"
const BLINK_SECONDS := 0.4
const VISITED_FILL := Color("183931")
const CURRENT_FILL := Color("52638c")
const OUTLINE := Color("94a5c6")
const DOT := Color("ffff8b")
const DOT_SIZE := Vector2(2, 2)

# Shows the current Room's region name.
@export var region_label: Label

var _blink_time: float = 0.0


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var was_lit := _dot_lit()
	_blink_time += delta
	if _dot_lit() != was_lit:
		queue_redraw()


func _draw() -> void:
	var layout := _layout()
	if layout.is_empty():
		return
	for block: Rect2 in layout.blocks:
		draw_rect(block, CURRENT_FILL if block == layout.current else VISITED_FILL)
		draw_rect(block.grow(-0.5), OUTLINE, false, 1.0)
	if _dot_lit():
		draw_rect(Rect2(layout.dot, DOT_SIZE), DOT)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		return
	_blink_time = 0.0
	var layout := _layout()
	if region_label != null and not layout.is_empty():
		region_label.text = layout.region
	queue_redraw()


func _layout() -> Dictionary:
	var room_id := RunStateScript.FIRST_ROOM_ID
	var run := _get_run()
	if run != null:
		room_id = run.room_id
	var visited: Array = []
	for map_room_id in WorldMap.ROOMS:
		if map_room_id == room_id or (run != null and run.has_visited_room(map_room_id)):
			visited.append(map_room_id)
	return WorldMap.layout(WorldMap.ROOMS, room_id, visited, _player_position(), size)


# Null outside the tree or without the autoload (headless tests), which reads as a new Run.
func _get_run() -> RunStateScript:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/RunState") as RunStateScript


# Where the Player stands in the Room; the Room's middle when there is no Player.
func _player_position() -> Vector2:
	if not is_inside_tree():
		return WorldMap.SCREEN_SIZE / 2.0
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player == null:
		return WorldMap.SCREEN_SIZE / 2.0
	return player.position


func _dot_lit() -> bool:
	return fmod(_blink_time, BLINK_SECONDS * 2.0) < BLINK_SECONDS
