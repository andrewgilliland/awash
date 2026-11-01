extends Node2D

# A Region's Background: layers that scroll slower the farther back they are. Each is set by
# where the Room showing it sits in the world, so it carries on across Exits.

# Where the Room showing this Background sits in the world; the Room tells it before it is added.
var room_origin := Vector2.ZERO


func _ready() -> void:
	for layer in get_children():
		if layer is Parallax2D:
			(layer as Parallax2D).scroll_offset = -room_origin * (layer as Parallax2D).scroll_scale
