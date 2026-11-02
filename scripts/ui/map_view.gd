extends Control

const World := preload("res://scripts/core/world.gd")
const MapLayout := preload("res://scripts/ui/map_layout.gd")
const MapDrawing := preload("res://scripts/ui/map_drawing.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const PLAYER_GROUP := &"player"
const BLINK_SECONDS := 0.4

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
	MapDrawing.draw(self, _layout(), _dot_lit())


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
	var rooms := {}
	var visited: Array = []
	for map_room_id in World.room_ids():
		rooms[map_room_id] = map_room(map_room_id)
		if map_room_id == room_id or (run != null and run.has_visited_room(map_room_id)):
			visited.append(map_room_id)
	return MapLayout.layout(rooms, room_id, visited, _player_position(), size)


# A Room as the Map lays it out, from the World.
static func map_room(room_id: StringName) -> Dictionary:
	return {
		cell = World.cell(room_id),
		size = World.size(room_id),
		region = World.region_name(room_id),
		colour = World.region_colour(room_id),
		exits = World.exits(room_id),
		markers = World.markers(room_id),
		planned = room_id in World.planned_ids(),
	}


# Null outside the tree or without the autoload (headless tests), which reads as a new Run.
func _get_run() -> RunStateScript:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/RunState") as RunStateScript


# Where the Player stands in the Room; the Room's middle when there is no Player.
func _player_position() -> Vector2:
	if not is_inside_tree():
		return World.SCREEN_SIZE / 2.0
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player == null:
		return World.SCREEN_SIZE / 2.0
	return player.position


func _dot_lit() -> bool:
	return fmod(_blink_time, BLINK_SECONDS * 2.0) < BLINK_SECONDS
