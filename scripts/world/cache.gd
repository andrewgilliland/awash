extends Node2D

# A Cache: a hidden spot holding Supplies, or a Sub Weapon such as Bombs, opened with Interact. It
# spills all it holds out as pickups, each taken once it lands, and is empty for the rest of the
# Run; while the Player has no room for any of it, it stays shut.

const RunStateScript := preload("res://scripts/core/run_state.gd")
const Pickups := preload("res://scripts/items/pickups.gd")
const INTERACTABLE_GROUP := &"interactable"
# Spilled pickups leave from inside the Cache, upward at this speed, and neighbours fly this much
# faster apart sideways, so they land spread out beside it.
const SPILL_FROM := Vector2(0.0, -16.0)
const SPILL_RISE := 180.0
const SPILL_SPREAD := 16.0

# The id the Run knows the Cache by.
@export var cache_id: StringName
@export var kind: StringName = &"brinecap"
@export var count: int = 2
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
	if _open or not by.has_method(&"has_room_for") or not by.call(&"has_room_for", kind):
		return
	var run := get_node_or_null("/root/RunState") as RunStateScript
	if run != null:
		run.take_cache(cache_id)
	_show(true)
	_spill()


func _spill() -> void:
	var scene := Pickups.scene(kind)
	if scene == null:
		return
	for i in count:
		var pickup := scene.instantiate() as CharacterBody2D
		pickup.set(&"wait_to_land", true)
		pickup.velocity = Vector2((i - (count - 1) / 2.0) * SPILL_SPREAD, -SPILL_RISE)
		get_parent().add_child(pickup)
		pickup.global_position = global_position + SPILL_FROM


# Open, it has nothing left to use: no prompt, and Interact passes it by.
func _show(open: bool) -> void:
	_open = open
	_sprite.region_rect = open_frame if open else shut_frame
	if open:
		_interactable.remove_from_group(INTERACTABLE_GROUP)
		_interactable.hide()
		_interactable.process_mode = Node.PROCESS_MODE_DISABLED
