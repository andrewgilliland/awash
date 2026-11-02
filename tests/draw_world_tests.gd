extends RefCounted

const World := preload("res://scripts/core/world.gd")
const DrawWorld := preload("res://scripts/tools/draw_world.gd")
const DrawMap := preload("res://scripts/tools/draw_map.gd")


func get_tests() -> Array:
	return [
		["The World map places each Room by its cell and size", _test_places_by_cell],
		["The World map is just big enough to hold every Room", _test_fits_rooms],
		["The Map's picture of the World holds every Room, planned ones too", _test_map_rooms],
	]


func _test_places_by_cell() -> bool:
	var places := DrawWorld.places()
	var first: StringName = World.room_ids()[0]
	var valid := places.size() == World.room_ids().size()
	for room_id in World.room_ids():
		var place: Rect2i = places.get(room_id, Rect2i())
		var screens := Vector2(World.cell(room_id) - World.cell(first))
		var offset := Vector2i(screens * World.SCREEN_SIZE)
		valid = valid and place.position - places[first].position == offset
		valid = valid and place.size == Vector2i(Vector2(World.size(room_id)) * World.SCREEN_SIZE)
	return valid


func _test_fits_rooms() -> bool:
	var bounds := Rect2i(Vector2i.ZERO, DrawWorld.image_size())
	var touched := Rect2i()
	if DrawWorld.places().is_empty():
		return false
	for place: Rect2i in DrawWorld.places().values():
		if not bounds.encloses(place):
			return false
		touched = place if touched.size == Vector2i.ZERO else touched.merge(place)
	return touched == bounds


func _test_map_rooms() -> bool:
	var rooms := DrawMap.map_rooms()
	var valid := rooms.size() == World.room_ids().size() + World.planned_ids().size()
	for room_id: StringName in rooms:
		valid = valid and rooms[room_id].planned == (room_id in World.planned_ids())
	return valid
