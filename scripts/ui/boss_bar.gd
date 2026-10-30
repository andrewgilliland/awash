extends "res://scripts/ui/health_bar.gd"

# A Boss's Health on screen while it fights: a wide bar along the bottom of the screen with its
# name above, draining like the Player's own. It hides while no Boss is awake, and once the Boss
# falls.

const BOSS_GROUP := &"boss"
const BOSS_FILL_SIZE := Vector2(120, 3)

@onready var _name: Label = $Name


func _ready() -> void:
	fill_size = BOSS_FILL_SIZE
	super._ready()


func _health() -> Object:
	var boss := get_tree().get_first_node_in_group(BOSS_GROUP) if is_inside_tree() else null
	if boss == null or not boss.call("is_fighting"):
		return null
	_name.text = boss.get_script().get_script_constant_map().get("BOSS_NAME", "")
	return boss.get("health")
