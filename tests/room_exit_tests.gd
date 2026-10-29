extends RefCounted

const WorldMap := preload("res://scripts/core/world_map.gd")
const RoomExitScript := preload("res://scripts/core/room_exit.gd")
const TRIGGER_LAYER := 1 << 7
const PLAYER_LAYER := 1 << 1


func get_tests() -> Array:
	return [
		["Every Room on the Map has a scene", _test_rooms_have_scenes],
		["Every Exit leads to an Entry on the Map", _test_exits_lead_to_entries],
		["Waking Coast Rooms connect both ways", _test_waking_coast_connects],
	]


static func _load_room(room_id: StringName) -> Node2D:
	var room: Dictionary = WorldMap.ROOMS.get(room_id, {})
	var packed_scene := load(room.get("scene", "")) as PackedScene if room.has("scene") else null
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node2D


static func _exits(room: Node) -> Array:
	var exits: Array = []
	for node in room.find_children("*", "Area2D", true, false):
		if node.get_script() == RoomExitScript:
			exits.append(node)
	return exits


func _test_rooms_have_scenes() -> bool:
	var valid := not WorldMap.ROOMS.is_empty()
	for room_id in WorldMap.ROOMS:
		var room := _load_room(room_id)
		valid = valid and room != null
		if room != null:
			room.free()
	return valid


func _test_exits_lead_to_entries() -> bool:
	var valid := true
	for room_id in WorldMap.ROOMS:
		var room := _load_room(room_id)
		if room == null:
			return false
		for exit in _exits(room):
			var area := exit as Area2D
			valid = valid and area.collision_layer == TRIGGER_LAYER
			valid = valid and area.collision_mask == PLAYER_LAYER
			var target := _load_room(exit.room_id)
			valid = valid and target != null
			if target != null:
				valid = valid and target.get_node_or_null("Entries/%s" % exit.entry_id) is Marker2D
				target.free()
		room.free()
	return valid


func _test_waking_coast_connects() -> bool:
	return (
		_leads_to(&"waking_coast_1", &"waking_coast_2", &"west")
		and _leads_to(&"waking_coast_2", &"waking_coast_1", &"east")
		and _leads_to(&"waking_coast_2", &"waking_coast_3", &"west")
		and _leads_to(&"waking_coast_3", &"waking_coast_2", &"east")
		and _leads_to(&"waking_coast_3", &"waking_coast_4", &"west")
		and _leads_to(&"waking_coast_4", &"waking_coast_3", &"east")
		and _leads_to(&"waking_coast_4", &"waking_coast_5", &"shaft")
		and _leads_to(&"waking_coast_5", &"waking_coast_3", &"cave")
		and _leads_to(&"waking_coast_3", &"waking_coast_5", &"west")
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
