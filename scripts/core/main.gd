extends Node2D

@onready var _world: Node = _resolve_world_node()
@onready var _player: CharacterBody2D = $Player


func _ready() -> void:
	if _world == null or _player == null:
		return

	var runtime_state := _get_runtime_state()
	if runtime_state != null:
		var last_position := runtime_state.get("last_player_position") as Vector2
		if last_position != Vector2.ZERO:
			_player.global_position = last_position
			return

	if _world.has_method("get_spawn_position"):
		_player.global_position = _world.call("get_spawn_position")
	elif _player.global_position == Vector2.ZERO:
		_player.global_position = Vector2(0.0, 96.0)


func _physics_process(_delta: float) -> void:
	if _world == null or _player == null:
		return

	_save_runtime_player_position()


func _save_runtime_player_position() -> void:
	var runtime_state := _get_runtime_state()
	if runtime_state != null and runtime_state.has_method("set_last_player_position"):
		runtime_state.call("set_last_player_position", _player.global_position)


func _get_runtime_state() -> Node:
	if not is_inside_tree():
		return null

	return get_node_or_null("/root/RuntimeState")


func _resolve_world_node() -> Node:
	for child in get_children():
		if child is TileMapLayer:
			return child

	return null
