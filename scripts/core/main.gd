extends Node2D

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const DIALOGUE_BOX_SCENE := preload("res://scenes/ui/dialogue_box.tscn")
const HEALTH_BAR_SCENE := preload("res://scenes/ui/health_bar.tscn")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const WorldMap := preload("res://scripts/core/world_map.gd")
const ENEMY_GROUP := &"enemy"
# Long enough to see the Player fall and hear the defeat sound before the Room is replaced.
const DEFEAT_PAUSE := 1.2

@onready var _player: CharacterBody2D = $Player
@onready var _entries: Node = $Entries
@onready var _canvas_layer: CanvasLayer = $CanvasLayer


func _ready() -> void:
	_ensure_pause_menu()
	_ensure_dialogue_box()
	_ensure_health_bar()
	_place_player_at_entry()
	_play_region_music()
	if _player != null and not _player.is_connected(&"defeated", _on_player_defeated):
		_player.connect(&"defeated", _on_player_defeated)
	_hand_enemy_defeats_to_player()


# Every enemy defeated in this Room earns the Player its Experience, whatever struck it down.
func _hand_enemy_defeats_to_player() -> void:
	if _player == null or not is_inside_tree():
		return
	for enemy in get_tree().get_nodes_in_group(ENEMY_GROUP):
		if is_ancestor_of(enemy) and not enemy.is_connected(&"defeated", _on_enemy_defeated):
			enemy.connect(&"defeated", _on_enemy_defeated)


func _on_enemy_defeated(experience: int) -> void:
	_player.call("gain_experience", experience)


# After a beat to see it fall, a defeated Player wakes in the first Room with full Health; the
# Run carries on.
func _on_player_defeated() -> void:
	await get_tree().create_timer(DEFEAT_PAUSE).timeout
	var run := _get_run()
	if run != null:
		run.recover_from_defeat()
	var first_room: Dictionary = WorldMap.ROOMS[RunStateScript.FIRST_ROOM_ID]
	get_tree().change_scene_to_file.call_deferred(first_room.scene)


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


# Asks the Music autoload for this Room's region theme; the same theme plays on unbroken.
func _play_region_music() -> void:
	if not is_inside_tree():
		return
	var music := get_node_or_null("/root/Music")
	var run := _get_run()
	var room_id := run.room_id if run != null else RunStateScript.FIRST_ROOM_ID
	var theme := WorldMap.music_for(room_id)
	if music != null and not theme.is_empty():
		music.call("play", load(theme))


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


# The Health bar sits under the Pause menu and the dialogue box, so both draw over it.
func _ensure_health_bar() -> void:
	if _canvas_layer == null or _canvas_layer.get_node_or_null("HealthBar") != null:
		return
	var bar := HEALTH_BAR_SCENE.instantiate()
	bar.name = "HealthBar"
	_canvas_layer.add_child(bar)
	_canvas_layer.move_child(bar, 0)


func _ensure_dialogue_box() -> void:
	if _canvas_layer == null or _canvas_layer.get_node_or_null("DialogueBox") != null:
		return
	var box := DIALOGUE_BOX_SCENE.instantiate()
	box.name = "DialogueBox"
	_canvas_layer.add_child(box)
