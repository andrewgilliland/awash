extends RefCounted

# Checks the jungle's Room tests share: a Room's scene, an Entry standing on its ground with the
# Exit beside it leading on, and where the Player can get to from where.

const RoomReach := preload("res://tests/room_reach.gd")
const World := preload("res://scripts/core/world.gd")
const TILE := 16


static func load_room(path: String) -> Node2D:
	var packed_scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	return packed_scene.instantiate() as Node2D if packed_scene != null else null


# The Entry at a point with ground under it and room above, and the Exit on its side, past the
# Room's edge on the same screen, leading to the Entry of the Room next door.
static func entry_leads(
	room: Node2D, side: StringName, at: Vector2, to: StringName, entry_id: StringName
) -> bool:
	var terrain := room.get_node("Terrain") as TileMapLayer
	var entry := room.get_node_or_null(NodePath("Entries/%s" % side)) as Marker2D
	var valid := entry != null and entry.position == at
	var below := Vector2i(at / TILE)
	valid = valid and terrain.get_cell_source_id(below) != -1
	valid = valid and terrain.get_cell_source_id(below + Vector2i.UP) == -1
	var exit := room.get_node_or_null(NodePath("Exits/%s" % side)) as Area2D
	var width := float(terrain.get_used_rect().end.x * TILE)
	var outside := exit != null and (exit.position.x < 0.0 or exit.position.x > width)
	valid = valid and outside and exit.get("room_id") == to and exit.get("entry_id") == entry_id
	var same_screen := (
		exit != null
		and floori(exit.position.y / World.SCREEN_SIZE.y) == floori(at.y / World.SCREEN_SIZE.y)
	)
	return valid and same_screen


# Whether a walk, jumps and drops take the Player from one point to stand at another.
static func reaches(room: Node2D, from: Vector2, to: Vector2) -> bool:
	var terrain := room.get_node("Terrain") as TileMapLayer
	var reached := RoomReach.reachable(terrain, Vector2i(from / TILE))
	return RoomReach.span_at(reached, Vector2i(to / TILE)) != null
