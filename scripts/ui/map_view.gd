extends Control

const World := preload("res://scripts/core/world.gd")
const MapLayout := preload("res://scripts/ui/map_layout.gd")
const MapDrawing := preload("res://scripts/ui/map_drawing.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const PLAYER_GROUP := &"player"
const BLINK_SECONDS := 0.4
# How fast a held direction pans while exploring, in the Map's pixels a second, at every zoom: a
# Close screen every 0.15 seconds.
const PAN_SPEED := 20.0 / 0.15
# The directions that pan while exploring, and so no longer move the menu on.
const PAN_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"ui_left",
	&"ui_right",
	&"ui_up",
	&"ui_down",
]

# The zoom chosen last, kept while the game runs; the Map opens on the whole World.
static var _zoom: StringName = &"world"

# Shows the current Room's region name.
@export var region_label: Label
# Jump zooms in and Attack out while this, the Map's button, has focus; Interact there starts and
# stops exploring the Map.
@export var zoom_button: Control
# The Pause menu's frame: each time it opens, the Map is centred on the Player again.
@export var menu_panel: Control

var _blink_time: float = 0.0
var _exploring: bool = false
# How far the view looks from the middle of the Player's Room, in screens.
var _pan: Vector2 = Vector2.ZERO


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if menu_panel != null:
		menu_panel.visibility_changed.connect(_on_menu_shown)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _exploring and _zoom != &"world":
		_pan_by(_held_direction() * PAN_SPEED * delta)
	var was_lit := _dot_lit()
	_blink_time += delta
	if _dot_lit() != was_lit:
		queue_redraw()


# Ahead of the menu's buttons, which would take Jump's key as pressing them, and the directions
# as moving on.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or zoom_button == null or not zoom_button.has_focus():
		return
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_exploring = not _exploring
		queue_redraw()
		return
	if (
		_exploring
		and PAN_ACTIONS.any(func(action: StringName) -> bool: return event.is_action(action))
	):
		get_viewport().set_input_as_handled()
		return
	var step := 0
	if event.is_action_pressed(&"jump"):
		step = 1
	elif event.is_action_pressed(&"melee_attack"):
		step = -1
	else:
		return
	get_viewport().set_input_as_handled()
	var at := clampi(MapLayout.ZOOMS.find(_zoom) + step, 0, MapLayout.ZOOMS.size() - 1)
	_zoom = MapLayout.ZOOMS[at]
	queue_redraw()


func zoom() -> StringName:
	return _zoom


func is_exploring() -> bool:
	return _exploring


func pan() -> Vector2:
	return _pan


# The directions held, each axis from -1 to 1.
func _held_direction() -> Vector2:
	var strength := func(direction: String) -> float:
		return maxf(
			Input.get_action_strength("move_" + direction),
			Input.get_action_strength("ui_" + direction)
		)
	return Vector2(
		strength.call("right") - strength.call("left"), strength.call("down") - strength.call("up")
	)


# Pans by Map pixels, as far as the World's edge.
func _pan_by(pixels: Vector2) -> void:
	if pixels == Vector2.ZERO:
		return
	var room_id := _room_id()
	_pan = MapLayout.clamp_pan(_rooms(), room_id, _pan + pixels / MapLayout.cell_for(_zoom))
	queue_redraw()


func _on_menu_shown() -> void:
	if menu_panel.visible:
		_exploring = false
		_pan = Vector2.ZERO
		queue_redraw()


func _draw() -> void:
	MapDrawing.draw(self, _layout(), _dot_lit())
	if _exploring:
		var frame := Rect2(Vector2.ZERO, size)
		for edge: Rect2 in [
			Rect2(frame.position, Vector2(frame.size.x, 1)),
			Rect2(frame.position.x, frame.end.y - 1, frame.size.x, 1),
			Rect2(frame.position, Vector2(1, frame.size.y)),
			Rect2(frame.end.x - 1, frame.position.y, 1, frame.size.y),
		]:
			draw_rect(edge, MapDrawing.WALL)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		return
	_blink_time = 0.0
	var layout := _layout()
	if region_label != null and not layout.is_empty():
		region_label.text = layout.region
	queue_redraw()


func _layout() -> Dictionary:
	var room_id := _room_id()
	var run := _get_run()
	var visited: Array = []
	for map_room_id in World.room_ids():
		if map_room_id == room_id or (run != null and run.has_visited_room(map_room_id)):
			visited.append(map_room_id)
	return MapLayout.layout(_rooms(), room_id, visited, _player_position(), size, _zoom, _pan)


# The Room the Player is in: the first Room of a Run without one.
func _room_id() -> StringName:
	var run := _get_run()
	return run.room_id if run != null else RunStateScript.FIRST_ROOM_ID


# Every Room built in the World, as the Map lays it out.
static func _rooms() -> Dictionary:
	var rooms := {}
	for room_id in World.room_ids():
		rooms[room_id] = map_room(room_id)
	return rooms


# A Room as the Map lays it out, from the World: as it is, or as the World's plan lays it out.
static func map_room(room_id: StringName, as_planned := false) -> Dictionary:
	var room := World.planned(room_id)
	if not as_planned:
		room = {
			cell = World.cell(room_id),
			size = World.size(room_id),
			region = World.region(room_id),
			exits = World.exits(room_id),
			markers = World.markers(room_id),
		}
	room.colour = World.colour_of_region(room.region)
	room.region = World.name_of_region(room.region)
	room.planned = room_id in World.planned_ids()
	return room


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
