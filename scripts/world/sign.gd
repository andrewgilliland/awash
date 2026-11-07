extends Node2D

# A Sign: something in a Room the Player looks at with Interact, such as a sealed door, which
# shows its few lines in the Dialogue box in its speaker's name.

const DIALOGUE_GROUP := &"dialogue_box"

# The name the Dialogue box shows, such as "???" for Vael's own thoughts.
@export var speaker: String
# What it shows, a line at a time, every time it is looked at.
@export var lines: PackedStringArray

@onready var _interactable: Area2D = $Interactable


func _ready() -> void:
	_interactable.connect(&"interacted", _on_interacted)


func _on_interacted(_by: Node) -> void:
	var box := get_tree().get_first_node_in_group(DIALOGUE_GROUP)
	if box == null or box.call("is_open"):
		return
	var pairs := []
	for line in lines:
		pairs.append([speaker, line])
	box.call("show_lines", pairs, self)
