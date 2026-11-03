extends RefCounted

# The World's Regions and Rooms live in a data file the World editor can write; the World reads
# it and answers from it. Vectors are [x, y], colours "#rrggbb", ids plain strings.

const World := preload("res://scripts/core/world.gd")
const DATA_PATH := "res://assets/world.json"


func get_tests() -> Array:
	return [
		["The World's data is a JSON file of Regions and Rooms", _test_data_file],
		["The World answers from its data file, Room by Room", _test_rooms_from_data],
		["The World answers from its data file, Region by Region", _test_regions_from_data],
		["A Region draws from its own tile folder, or the one it shares", _test_tile_folders],
	]


static func _data() -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


static func _vec(pair: Array) -> Vector2i:
	return Vector2i(int(pair[0]), int(pair[1]))


static func _exits(listed: Array) -> Array:
	return listed.map(
		func(exit: Dictionary) -> Dictionary:
			return {screen = _vec(exit.screen), side = StringName(exit.side)}
	)


func _test_data_file() -> bool:
	var data := _data()
	var regions: Variant = data.get("regions")
	var rooms: Variant = data.get("rooms")
	return (
		regions is Dictionary
		and not regions.is_empty()
		and rooms is Dictionary
		and not rooms.is_empty()
	)


func _test_rooms_from_data() -> bool:
	var rooms: Dictionary = _data().get("rooms", {})
	var valid := not rooms.is_empty()
	var ids: Array = World.room_ids() + World.planned_ids()
	valid = valid and ids.size() == rooms.size()
	for id: String in rooms:
		var record: Dictionary = rooms[id]
		var room_id := StringName(id)
		valid = valid and room_id in ids
		valid = valid and World.scene(room_id) == record.get("scene", "")
		valid = valid and World.cell(room_id) == _vec(record.cell)
		valid = valid and World.size(room_id) == _vec(record.size)
		valid = valid and World.region(room_id) == StringName(record.region)
		valid = valid and World.exits(room_id) == _exits(record.get("exits", []))
		if record.has("plan") and record.plan.has("cell"):
			valid = valid and World.planned(room_id).cell == _vec(record.plan.cell)
	return valid


func _test_regions_from_data() -> bool:
	var regions: Dictionary = _data().get("regions", {})
	var valid := not regions.is_empty()
	for id: String in regions:
		var record: Dictionary = regions[id]
		valid = valid and World.has_region(StringName(id))
		valid = valid and World.name_of_region(StringName(id)) == record.name
		valid = valid and World.colour_of_region(StringName(id)) == Color(record.colour)
	return valid


func _test_tile_folders() -> bool:
	var regions: Dictionary = _data().get("regions", {})
	var rooms: Dictionary = _data().get("rooms", {})
	var valid := not rooms.is_empty()
	for id: String in rooms:
		var record: Dictionary = rooms[id]
		if not record.has("scene"):
			continue
		var region: Dictionary = regions.get(record.region, {})
		var folder: String = region.get("tiles", record.region)
		valid = valid and World.tiles(StringName(id)) == "res://assets/regions/%s/tiles/" % folder
	return valid
