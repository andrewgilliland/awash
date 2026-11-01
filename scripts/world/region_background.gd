extends Node2D

# A Region's Background: layers that scroll slower the farther back they are. Each is set by
# where the Room showing it sits in the world, so it carries on across Exits.

const World := preload("res://scripts/core/world.gd")


func _ready() -> void:
	var origin := room_origin()
	for layer in get_children():
		if layer is Parallax2D:
			(layer as Parallax2D).scroll_offset = -origin * (layer as Parallax2D).scroll_scale


# Where the Room showing this Background sits in the world, from its place on the Map.
func room_origin() -> Vector2:
	var room_id := World.room_for_scene(owner.scene_file_path if owner != null else "")
	if room_id.is_empty():
		return Vector2.ZERO
	return Vector2(World.cell(room_id)) * World.SCREEN_SIZE
