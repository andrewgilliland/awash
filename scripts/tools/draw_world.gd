extends SceneTree

# Draws the whole World as one picture: every Room drawn whole, camera off and clouds still, placed
# by its cell, outlined and named. Run it with scripts/tools/draw_world.sh, which needs a window to
# draw in (a headless Godot draws nothing).

const World := preload("res://scripts/core/world.gd")
const THEME := preload("res://assets/ui/awash_theme.tres")
const SCALE := 3
const BACKDROP := Color("14141c")
const OUTLINE := Color(1, 1, 1, 0.8)


# Where each Room sits in the picture, in pixels, with the World's top-left corner at the origin.
static func places() -> Dictionary:
	var corner := _corner()
	var result := {}
	for room_id in World.room_ids():
		var at := Vector2(World.cell(room_id) - corner) * World.SCREEN_SIZE
		var size := Vector2(World.size(room_id)) * World.SCREEN_SIZE
		result[room_id] = Rect2i(Vector2i(at), Vector2i(size))
	return result


static func image_size() -> Vector2i:
	var far := Vector2i.ZERO
	for place: Rect2i in places().values():
		far = far.max(place.end)
	return far


static func _corner() -> Vector2i:
	var corner := Vector2i.MAX
	for room_id in World.room_ids():
		corner = corner.min(World.cell(room_id))
	return corner


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_draw.call_deferred(args[0] if not args.is_empty() else "world.png")


func _draw(out_path: String) -> void:
	var image := Image.create_empty(image_size().x, image_size().y, false, Image.FORMAT_RGBA8)
	image.fill(BACKDROP)
	var place_of := places()
	for room_id: StringName in place_of:
		var place: Rect2i = place_of[room_id]
		var room := await _draw_room(room_id, place.size)
		image.blit_rect(room, Rect2i(Vector2i.ZERO, place.size), place.position)
	image.resize(image.get_width() * SCALE, image.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	for place: Rect2i in place_of.values():
		_outline(image, Rect2i(place.position * SCALE, place.size * SCALE))
	var error := image.save_png(out_path)
	if error != OK:
		push_error("Could not save the World map to '%s'." % out_path)
	else:
		print("World map saved to %s" % ProjectSettings.globalize_path(out_path))
	quit(error)


func _draw_room(room_id: StringName, size: Vector2i) -> Image:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var room := (load(World.scene(room_id)) as PackedScene).instantiate()
	# Entered as an Exit would enter it, so the Room sets itself up and finds its Entry.
	root.get_node("RunState").call(
		"enter_room", room_id, room.get_node("Entries").get_child(0).name
	)
	room.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(room)
	for camera: Camera2D in room.find_children("*", "Camera2D", true, false):
		camera.enabled = false
	for layer: Parallax2D in room.find_children("*", "Parallax2D", true, false):
		layer.autoscroll = Vector2.ZERO
	viewport.add_child(_name_tag(room_id))
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := viewport.get_texture().get_image()
	picture.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	return picture


static func _name_tag(room_id: StringName) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var tag := Label.new()
	tag.theme = THEME
	tag.text = String(room_id)
	tag.position = Vector2(3, 2)
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0, 0, 0, 0.6)
	backing.set_content_margin_all(1)
	tag.add_theme_stylebox_override("normal", backing)
	layer.add_child(tag)
	return layer


static func _outline(image: Image, rect: Rect2i) -> void:
	var edges := [
		Rect2i(rect.position, Vector2i(rect.size.x, SCALE)),
		Rect2i(rect.position + Vector2i(0, rect.size.y - SCALE), Vector2i(rect.size.x, SCALE)),
		Rect2i(rect.position, Vector2i(SCALE, rect.size.y)),
		Rect2i(rect.position + Vector2i(rect.size.x - SCALE, 0), Vector2i(SCALE, rect.size.y)),
	]
	for edge: Rect2i in edges:
		image.fill_rect(edge, OUTLINE)
