extends Node2D

# A Rest point's bell. Rung with Interact, it tolls and rests the Player, and a defeat wakes the
# Player at this Room's Entry beside it from then on. It can be rung again at any time.

const RunStateScript := preload("res://scripts/core/run_state.gd")

# The Room's Entry at the bell's foot, where a defeat wakes the Player.
@export var entry_id: StringName = &"bell"

@onready var _interactable: Area2D = $Interactable
@onready var _toll: AudioStreamPlayer = $Sounds/Toll


func _ready() -> void:
	_interactable.connect(&"interacted", _on_interacted)


func _on_interacted(by: Node) -> void:
	if not by.has_method(&"rest"):
		return
	by.call("rest")
	var run := get_node_or_null("/root/RunState") as RunStateScript
	if run != null:
		run.rest_at(run.room_id, entry_id)
	_toll.play()
