extends Node

var current_room_id: StringName = &"room_1"
var visited_rooms: Dictionary = {&"room_1": true}
var last_player_position: Vector2 = Vector2.ZERO


func reset_run_state() -> void:
	current_room_id = &"room_1"
	visited_rooms.clear()
	visited_rooms[&"room_1"] = true
	last_player_position = Vector2.ZERO


func mark_room_visited(room_id: StringName) -> void:
	if room_id == StringName(""):
		return
	visited_rooms[room_id] = true


func has_visited_room(room_id: StringName) -> bool:
	return visited_rooms.has(room_id)


func set_current_room(room_id: StringName) -> void:
	if room_id == StringName(""):
		return
	current_room_id = room_id
	mark_room_visited(room_id)


func set_last_player_position(position_value: Vector2) -> void:
	last_player_position = position_value
