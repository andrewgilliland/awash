extends SceneTree

# Draws the whole World as the Map draws it, every Room shown, each Region named. With --plan it
# draws the World's plan instead, the Planned Rooms in outline: a picture to see the World's shape
# by before building it. Run it with scripts/tools/draw_map.sh, which needs a window to draw in
# (a headless Godot draws nothing).

const World := preload("res://scripts/core/world.gd")
const MapLayout := preload("res://scripts/ui/map_layout.gd")
const MapDrawing := preload("res://scripts/ui/map_drawing.gd")
const MapView := preload("res://scripts/ui/map_view.gd")
const THEME := preload("res://assets/ui/awash_compact_theme.tres")
const SCALE := 3
const BACKDROP := Color("0e0e16")


# The World as the Map lays it out: every built Room as it is today, or, as planned, every Room
# built and planned where the World's plan puts it.
static func map_rooms(as_planned: bool) -> Dictionary:
	var rooms := {}
	var ids := World.room_ids() + World.planned_ids() if as_planned else World.room_ids()
	for room_id in ids:
		rooms[room_id] = MapView.map_room(room_id, as_planned)
	return rooms


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var as_planned := args.has("--plan")
	args.erase("--plan")
	_draw.call_deferred(args[0] if not args.is_empty() else "map.png", as_planned)


func _draw(out_path: String, as_planned: bool) -> void:
	var layout := MapLayout.whole(map_rooms(as_planned))
	var size := Vector2i(layout.size)
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.size = Vector2(size)
	viewport.add_child(backdrop)
	var canvas := Node2D.new()
	canvas.draw.connect(
		func() -> void:
			MapDrawing.draw(canvas, layout, false, THEME.default_font, THEME.default_font_size)
	)
	viewport.add_child(canvas)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(size.x * SCALE, size.y * SCALE, Image.INTERPOLATE_NEAREST)
	var error := image.save_png(out_path)
	if error != OK:
		push_error("Could not save the Map to '%s'." % out_path)
	else:
		print("Map saved to %s" % ProjectSettings.globalize_path(out_path))
	quit(error)
