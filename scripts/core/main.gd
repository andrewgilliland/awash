extends Node2D

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const RunStateScript := preload("res://scripts/core/run_state.gd")

@onready var _player: CharacterBody2D = $Player
@onready var _entries: Node = $Entries
@onready var _canvas_layer: CanvasLayer = $CanvasLayer


func _ready() -> void:
	_ensure_pause_menu()
	_place_player_at_entry()


# The Run says which Entry the Player came through; this Room says where it is.
func _place_player_at_entry() -> void:
	var run := _get_run()
	var entry_id := run.entry_id if run != null else RunStateScript.DEFAULT_ENTRY_ID
	var entry := _entries.get_node_or_null(NodePath(entry_id)) as Marker2D
	if entry == null:
		var room_id := run.room_id if run != null else RunStateScript.FIRST_ROOM_ID
		push_error("Room '%s' has no Entry '%s'." % [room_id, entry_id])
		return

	_player.global_position = entry.global_position


# Null outside the tree or without the autoload (headless tests), which reads as a new Run.
func _get_run() -> RunStateScript:
	if not is_inside_tree():
		return null

	return get_node_or_null("/root/RunState") as RunStateScript


func _ensure_pause_menu() -> void:
	if _canvas_layer == null:
		return

	if _canvas_layer.get_node_or_null("PauseMenu") != null:
		return

	var pause_menu := PAUSE_MENU_SCENE.instantiate()
	pause_menu.name = "PauseMenu"
	_canvas_layer.add_child(pause_menu)
