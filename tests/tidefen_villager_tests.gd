extends RefCounted

# Tidefen's villagers: four of them, each standing by a landmark of the village, talking in the
# name of what they do there.

const ROOM_PATH := "res://scenes/rooms/tidefen_village_1.tscn"
const VILLAGER_PATH := "res://scenes/npcs/villager.tscn"
# [node, speaker, sheet, west x, east x, floor y]: where each stands, its feet on the floor.
const VILLAGERS := [
	# In the shallows, beside the old well under the walkway (x 144 to 160).
	["Netter", "NETTER", "res://assets/npcs/netter/netter.png", 104.0, 140.0, 122.0],
	# On the log walkway, among the stilt houses.
	["KnotWeaver", "KNOT-WEAVER", "res://assets/npcs/knot_weaver/knot_weaver.png", 168, 264, 64],
	# On the market square's sand, by the village bell (x 528).
	["BellKeeper", "BELL-KEEPER", "res://assets/npcs/bell_keeper/bell_keeper.png", 488, 520, 112],
	# On the fishers' pier, east of the bomb crate (x 790).
	["Fisher", "FISHER", "res://assets/npcs/fisher/fisher.png", 820.0, 904.0, 80.0],
]


func get_tests() -> Array:
	return [
		["Tidefen has four Villagers, each talking in its own name", _test_four],
		["Each of Tidefen's Villagers is drawn from a sheet of its own", _test_sheets],
		["Each of Tidefen's Villagers stands by its landmark, on the floor", _test_places],
	]


func _test_four() -> bool:
	var room := _room()
	var group := room.get_node_or_null("Villagers")
	var valid := group != null and group.get_child_count() == VILLAGERS.size()
	for spec in VILLAGERS:
		var villager := room.get_node_or_null("Villagers/%s" % spec[0])
		valid = valid and villager != null and villager.scene_file_path == VILLAGER_PATH
		if valid:
			valid = villager.get("speaker") == spec[1]
			valid = valid and (villager.get("lines") as PackedStringArray).size() >= 2
	room.free()
	return valid


func _test_sheets() -> bool:
	var room := _room()
	var valid := true
	for spec in VILLAGERS:
		var villager := room.get_node_or_null("Villagers/%s" % spec[0])
		var sheet := villager.get("sheet") as Texture2D if villager != null else null
		valid = valid and sheet != null and sheet.resource_path == spec[2]
		valid = valid and sheet.get_size() == Vector2(32, 16)
	room.free()
	return valid


func _test_places() -> bool:
	var room := _room()
	var valid := true
	for spec in VILLAGERS:
		var villager := room.get_node_or_null("Villagers/%s" % spec[0]) as Node2D
		valid = valid and villager != null
		if valid:
			var at := villager.position
			valid = at.x >= spec[3] and at.x <= spec[4] and is_equal_approx(at.y, spec[5])
	room.free()
	return valid


func _room() -> Node:
	return (load(ROOM_PATH) as PackedScene).instantiate()
