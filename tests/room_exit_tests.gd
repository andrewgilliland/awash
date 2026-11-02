extends RefCounted

const World := preload("res://scripts/core/world.gd")
const RoomExitScript := preload("res://scripts/core/room_exit.gd")


func get_tests() -> Array:
	return [
		["Waking Coast Rooms connect both ways", _test_waking_coast_connects],
	]


static func _load_room(room_id: StringName) -> Node2D:
	var path := World.scene(room_id)
	var packed_scene := load(path) as PackedScene if not path.is_empty() else null
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node2D


static func _exits(room: Node) -> Array:
	var exits: Array = []
	for node in room.find_children("*", "Area2D", true, false):
		if node.get_script() == RoomExitScript:
			exits.append(node)
	return exits


func _test_waking_coast_connects() -> bool:
	return (
		_leads_to(&"waking_coast_1", &"waking_coast_2", &"west")
		and _leads_to(&"waking_coast_2", &"waking_coast_1", &"east")
		and _leads_to(&"waking_coast_2", &"waking_coast_10", &"west")
		and _leads_to(&"waking_coast_10", &"waking_coast_2", &"east")
		and _leads_to(&"waking_coast_10", &"waking_coast_3", &"west")
		and _leads_to(&"waking_coast_3", &"waking_coast_10", &"east")
		and _leads_to(&"waking_coast_3", &"waking_coast_11", &"west")
		and _leads_to(&"waking_coast_11", &"waking_coast_3", &"east")
		and _leads_to(&"waking_coast_11", &"waking_coast_12", &"west")
		and _leads_to(&"waking_coast_12", &"waking_coast_11", &"east")
		and _leads_to(&"waking_coast_12", &"waking_coast_4", &"west")
		and _leads_to(&"waking_coast_4", &"waking_coast_12", &"east")
		and _leads_to(&"waking_coast_5", &"waking_coast_3", &"cave")
		and _leads_to(&"waking_coast_3", &"waking_coast_5", &"west")
		and _leads_to(&"waking_coast_4", &"waking_coast_6", &"west")
		and _leads_to(&"waking_coast_6", &"waking_coast_4", &"east")
		and _leads_to(&"waking_coast_6", &"waking_coast_7", &"west")
		and _leads_to(&"waking_coast_7", &"waking_coast_6", &"east")
		and _leads_to(&"waking_coast_7", &"waking_coast_8", &"west")
		and _leads_to(&"waking_coast_8", &"waking_coast_7", &"east")
		and _leads_to(&"waking_coast_8", &"waking_coast_9", &"well")
		and _leads_to(&"waking_coast_9", &"waking_coast_5", &"east")
		and _leads_to(&"waking_coast_5", &"waking_coast_9", &"west")
	)


static func _leads_to(room_id: StringName, to_room: StringName, to_entry: StringName) -> bool:
	var room := _load_room(room_id)
	if room == null:
		return false
	var found := false
	for exit in _exits(room):
		found = found or (exit.room_id == to_room and exit.entry_id == to_entry)
	room.free()
	return found
