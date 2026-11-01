extends Area2D

const World := preload("res://scripts/core/world.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const PLAYER_GROUP := &"player"

# The Room this Exit leads to, and the Entry the Player arrives at there.
@export var room_id: StringName
@export var entry_id: StringName


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(PLAYER_GROUP):
		return
	if not World.has_room(room_id):
		push_error("Exit leads to Room '%s', which is not on the Map." % room_id)
		return

	# One Exit per crossing: the Player may still overlap it until the scene swaps.
	set_deferred("monitoring", false)
	var run := get_node_or_null("/root/RunState") as RunStateScript
	if run != null:
		run.enter_room(room_id, entry_id)
	get_tree().change_scene_to_file.call_deferred(World.scene(room_id))
