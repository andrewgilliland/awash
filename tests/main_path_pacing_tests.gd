extends RefCounted

# Pacing on the main path: one pass of the Waking Coast's Rooms, defeating each enemy once, earns
# enough Experience to meet the Nameless Warden at Level 3.

const Level := preload("res://scripts/player/level.gd")
const World := preload("res://scripts/core/world.gd")
# The main path from where Vael wakes to the Warden's arena, the Warden's own Room left out.
const BEFORE_WARDEN: Array[StringName] = [
	&"waking_coast_1",
	&"waking_coast_2",
	&"waking_coast_10",
	&"waking_coast_3",
	&"waking_coast_11",
	&"waking_coast_12",
	&"waking_coast_4",
	&"waking_coast_13",
	&"waking_coast_6",
]
const WARDEN_LEVEL := 3


func get_tests() -> Array:
	return [
		["One pass of the main path reaches Level 3 before the Warden", _test_reaches_level],
	]


func _test_reaches_level() -> bool:
	var experience := 0
	for room_id in BEFORE_WARDEN:
		var room := (load(World.scene(room_id)) as PackedScene).instantiate()
		var enemies := room.get_node_or_null("Enemies")
		if enemies != null:
			for enemy in enemies.get_children():
				var script := enemy.get_script() as Script
				if script != null:
					experience += int(script.get_script_constant_map().get("EXPERIENCE", 0))
		room.free()
	return Level.new(experience).level >= WARDEN_LEVEL
