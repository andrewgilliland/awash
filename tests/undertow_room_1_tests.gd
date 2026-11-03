extends RefCounted

const ROOM_PATH := "res://scenes/rooms/undertow_1.tscn"
const RoomExitScript := preload("res://scripts/core/room_exit.gd")
const RoomReach := preload("res://tests/room_reach.gd")
# One screen wide and two tall: the shaft Tidefen's well drops into.
const ROOM_SIZE := Vector2i(160, 288)
const SCREEN_HEIGHT := 144
const TILE := 16
# Falling in at the top of the shaft, and landing on its floor two screens down.
const WELL_ENTRY := Vector2(80, 24)
const FLOOR := Vector2i(5, 15)
const WEST_ENTRY := Vector2(12, 240)
# Landmark cells: layer -> {cell: atlas coords}.
const LANDMARKS := {
	# an anchor sunk in the shaft's floor, and kelp beside it
	&"Props": {Vector2i(6, 13): Vector2i(1, 4), Vector2i(3, 13): Vector2i(1, 2)},
	&"Terrain":
	{
		# the shaft's walls and the sandy floor
		Vector2i(1, 4): Vector2i(5, 3),
		Vector2i(8, 4): Vector2i(1, 3),
		Vector2i(5, 15): Vector2i(4, 1),
	},
}


func get_tests() -> Array:
	return [
		["Well shaft lays out two screens tall", _test_lays_out],
		["Well shaft drops from Tidefen's well, too tall to climb back", _test_one_way],
		["Well shaft leads west to the tunnel from where the drop lands", _test_leads_west],
	]


static func _room() -> Node2D:
	if not ResourceLoader.exists(ROOM_PATH):
		return null
	return (load(ROOM_PATH) as PackedScene).instantiate() as Node2D


func _test_lays_out() -> bool:
	var room := _room()
	if room == null:
		return false
	var valid := true
	for layer_name in LANDMARKS:
		var layer := room.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		if layer == null:
			room.free()
			return false
		var cells: Dictionary = LANDMARKS[layer_name]
		for cell in cells:
			valid = valid and layer.get_cell_atlas_coords(cell) == cells[cell]
	room.free()
	return valid


# Open from the top down to the floor under the well, nothing to stand on above the floor that a
# jump from it reaches near the top, and no Exit up.
func _test_one_way() -> bool:
	var room := _room()
	if room == null:
		return false
	var entry := room.get_node_or_null("Entries/well") as Marker2D
	var valid := entry != null and entry.position == WELL_ENTRY
	var terrain := room.get_node("Terrain") as TileMapLayer
	var column := int(WELL_ENTRY.x / TILE)
	for row in range(FLOOR.y):
		valid = valid and terrain.get_cell_source_id(Vector2i(column, row)) == -1
	valid = valid and terrain.get_cell_source_id(Vector2i(column, FLOOR.y)) != -1
	var highest := FLOOR.y
	for span in RoomReach.reachable(terrain, FLOOR):
		highest = mini(highest, span.x)
	valid = valid and highest > SCREEN_HEIGHT / TILE
	for node in room.find_children("*", "Area2D", true, false):
		if node.get_script() == RoomExitScript:
			valid = valid and (node as Node2D).position.y > 0.0
	room.free()
	return valid


func _test_leads_west() -> bool:
	var room := _room()
	if room == null:
		return false
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, FLOOR)
	var valid := RoomReach.span_at(reached, Vector2i(WEST_ENTRY / TILE)) != null
	var entry := room.get_node_or_null("Entries/west") as Marker2D
	valid = valid and entry != null and entry.position == WEST_ENTRY
	var exit := room.get_node_or_null("Exits/west") as Area2D
	valid = valid and exit != null and exit.position.x < 0.0
	valid = valid and exit.get("room_id") == &"waking_coast_9" and exit.get("entry_id") == &"east"
	if valid:
		var edge := (exit.get_node("Edge") as CollisionShape2D).shape as RectangleShape2D
		valid = exit.position.y - edge.size.y / 2.0 >= SCREEN_HEIGHT
	room.free()
	return valid
