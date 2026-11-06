extends Node2D

# A Cache: a hidden spot holding Supplies, or a Sub Weapon such as Bombs, opened with Interact. It
# gives the Player what they have room for and is empty once taken, for the rest of the Run; with
# no room for any of it, it stays shut.

const RunStateScript := preload("res://scripts/core/run_state.gd")
const INTERACTABLE_GROUP := &"interactable"

# The id the Run knows the Cache by.
@export var cache_id: StringName
@export var kind: StringName = &"brinecap"
@export var count: int = 2
# The Player's method that takes one of what it holds: collect for a Supply, collect_sub_weapon
# for a Sub Weapon.
@export var collect_method: StringName = &"collect"
# Where on its sheet the Cache is drawn shut, and open and empty.
@export var shut_frame: Rect2
@export var open_frame: Rect2

var _open: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _interactable: Area2D = $Interactable


func _ready() -> void:
	var run := get_node_or_null("/root/RunState") as RunStateScript
	_show(run != null and run.has_taken_cache(cache_id))
	if not _interactable.is_connected(&"interacted", _on_interacted):
		_interactable.connect(&"interacted", _on_interacted)


func is_open() -> bool:
	return _open


func _on_interacted(by: Node) -> void:
	if _open or not by.has_method(collect_method):
		return
	var given := 0
	for i in count:
		if by.call(collect_method, kind):
			given += 1
	if given == 0:
		return
	var run := get_node_or_null("/root/RunState") as RunStateScript
	if run != null:
		run.take_cache(cache_id)
	_show(true)


# Open, it has nothing left to use: no prompt, and Interact passes it by.
func _show(open: bool) -> void:
	_open = open
	_sprite.region_rect = open_frame if open else shut_frame
	if open:
		_interactable.remove_from_group(INTERACTABLE_GROUP)
		_interactable.hide()
		_interactable.process_mode = Node.PROCESS_MODE_DISABLED
