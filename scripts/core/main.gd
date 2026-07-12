extends Node2D

@export var transition_edge_margin: float = 4.0
@export var transition_cooldown_seconds: float = 0.2

var _active_room_id: StringName = &"room_1"
var _transition_lock_timer: float = 0.0

@onready var _world: Node2D = $WorldBiome01
@onready var _player: CharacterBody2D = $Player


func _ready() -> void:
	if _world == null or _player == null:
		return

	if _world.has_method("get_room_count") and _world.call("get_room_count") > 0:
		var runtime_state := _get_runtime_state()
		var runtime_room_id: StringName = &"room_1"
		if runtime_state != null:
			runtime_room_id = runtime_state.get("current_room_id") as StringName
		if runtime_room_id == StringName(""):
			runtime_room_id = &"room_1"

		_activate_room(runtime_room_id)
		if runtime_state != null:
			var last_position := runtime_state.get("last_player_position") as Vector2
			if last_position != Vector2.ZERO:
				_player.global_position = last_position
				return

		if _world.has_method("get_room_spawn_position"):
			_player.global_position = _world.call(
				"get_room_spawn_position", _active_room_id, &"center"
			)


func _physics_process(delta: float) -> void:
	if _world == null or _player == null:
		return

	_transition_lock_timer = maxf(0.0, _transition_lock_timer - delta)
	if _transition_lock_timer > 0.0:
		_save_runtime_player_position()
		return

	_check_room_transition()
	_save_runtime_player_position()


func _check_room_transition() -> void:
	if not _world.has_method("get_room_bounds"):
		return

	var bounds := _world.call("get_room_bounds", _active_room_id) as Rect2
	if bounds == Rect2():
		return

	if _player.global_position.x > bounds.position.x + bounds.size.x + transition_edge_margin:
		_try_transition(1)
		return

	if _player.global_position.x < bounds.position.x - transition_edge_margin:
		_try_transition(-1)


func _try_transition(direction: int) -> void:
	if not _world.has_method("get_adjacent_room_id"):
		return

	var next_room_id := (
		_world.call("get_adjacent_room_id", _active_room_id, direction) as StringName
	)
	if next_room_id == StringName(""):
		return

	var entry_side: StringName = &"left" if direction > 0 else &"right"
	if _world.has_method("get_room_spawn_position"):
		_player.global_position = _world.call("get_room_spawn_position", next_room_id, entry_side)

	_activate_room(next_room_id)
	_transition_lock_timer = transition_cooldown_seconds


func _activate_room(room_id: StringName) -> void:
	_active_room_id = room_id
	var runtime_state := _get_runtime_state()
	if runtime_state != null and runtime_state.has_method("set_current_room"):
		runtime_state.call("set_current_room", room_id)

	if _world.has_method("get_room_bounds") and _player.has_method("set_camera_room_bounds"):
		var room_bounds := _world.call("get_room_bounds", room_id) as Rect2
		_player.call("set_camera_room_bounds", room_bounds)


func _save_runtime_player_position() -> void:
	var runtime_state := _get_runtime_state()
	if runtime_state != null and runtime_state.has_method("set_last_player_position"):
		runtime_state.call("set_last_player_position", _player.global_position)


func _get_runtime_state() -> Node:
	return get_node_or_null("/root/RuntimeState")
