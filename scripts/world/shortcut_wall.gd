extends StaticBody2D

# One side of a Shortcut's wall. On the Shortcut's near side it is cracked, and a Charged Attack
# or a quick slash that chops breaks it; any other quick one glances off. On the far side it is
# plain rock with nothing to strike. Once broken the Run remembers, and both sides open without
# it.

const RunStateScript := preload("res://scripts/core/run_state.gd")
const Hitbox := preload("res://scripts/combat/hitbox.gd")

# The id the Run knows the Shortcut by, shared by both its sides.
@export var shortcut_id: StringName

# Only the near side has one.
@onready var _hurtbox: Area2D = get_node_or_null("Hurtbox")


func _ready() -> void:
	var run := get_node_or_null("/root/RunState") as RunStateScript
	if run != null and run.has_opened_shortcut(shortcut_id):
		_open()
		return
	if _hurtbox != null and not _hurtbox.is_connected(&"hit", _on_hurtbox_hit):
		_hurtbox.connect(&"hit", _on_hurtbox_hit)


func _on_hurtbox_hit(hitbox: Area2D) -> void:
	var breaks: bool = (hitbox.charged or hitbox.chops) if hitbox is Hitbox else false
	if not breaks:
		return
	var run := get_node_or_null("/root/RunState") as RunStateScript
	if run != null:
		run.open_shortcut(shortcut_id)
	_open()


# Hidden at once; the shapes stop blocking once the physics step that broke it is done.
func _open() -> void:
	for shape: CollisionShape2D in find_children("*", "CollisionShape2D", false, false):
		shape.set_deferred("disabled", true)
	if _hurtbox != null:
		_hurtbox.set_deferred("monitorable", false)
	hide()
