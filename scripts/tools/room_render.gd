extends RefCounted

# Draws a Room flat into an Image, headless: its backdrop, tile layers and sprites in the order
# the scene draws them, each at its first frame, straight from the source PNGs. Characters,
# whose frames are built when they enter the tree, are left out.


# The whole Room, or only the layers drawn before stop_before when it is given.
static func render(room: Node2D, size: Vector2i, stop_before: StringName = &"") -> Image:
	var canvas := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for child in room.get_children():
		if stop_before != &"" and child.name == stop_before:
			break
		_draw(child, canvas, Vector2.ZERO)
	return canvas


# Just one tile layer, on a clear canvas.
static func render_layer(layer: TileMapLayer, size: Vector2i) -> Image:
	var canvas := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	_draw(layer, canvas, Vector2.ZERO)
	return canvas


# A tile's picture at an animation frame, from its atlas.
static func tile_image(tile_set: TileSet, coords: Vector2i, frame: int = 0) -> Image:
	var source := tile_set.get_source(0) as TileSetAtlasSource
	return source_image(source.texture).get_region(source.get_tile_texture_region(coords, frame))


# The first frame of an AnimatedSprite2D, or every frame of its current animation.
static func sprite_frames_images(sprite: AnimatedSprite2D) -> Array[Image]:
	var images: Array[Image] = []
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):
		return images
	for i in sprite.sprite_frames.get_frame_count(sprite.animation):
		images.append(texture_image(sprite.sprite_frames.get_frame_texture(sprite.animation, i)))
	return images


# A texture's pixels, read from its source file so nothing is compressed or filtered.
static func texture_image(texture: Texture2D) -> Image:
	var atlas := texture as AtlasTexture
	if atlas != null:
		return source_image(atlas.atlas).get_region(Rect2i(atlas.region))
	return source_image(texture)


static func source_image(texture: Texture2D) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(texture.resource_path))
	image.convert(Image.FORMAT_RGBA8)
	return image


static func _draw(node: Node, canvas: Image, origin: Vector2) -> void:
	var item := node as CanvasItem
	if item != null and not item.visible:
		return
	var position := origin + ((node as Node2D).position if node is Node2D else Vector2.ZERO)
	if node is TileMapLayer:
		var layer := node as TileMapLayer
		if layer.tile_set != null:
			for cell in layer.get_used_cells():
				var tile := tile_image(layer.tile_set, layer.get_cell_atlas_coords(cell))
				_blend(canvas, tile, Vector2i(position) + cell * layer.tile_set.tile_size)
		return
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		var frames := sprite_frames_images(sprite)
		if not frames.is_empty():
			var image := frames[0]
			var top_left := position + sprite.offset
			if sprite.centered:
				top_left -= Vector2(image.get_size()) / 2.0
			_blend(canvas, image, Vector2i(top_left.round()))
		return
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null:
			var image := texture_image(sprite.texture)
			if sprite.region_enabled:
				image = image.get_region(Rect2i(sprite.region_rect))
			var top_left := position + sprite.offset
			if sprite.centered:
				top_left -= Vector2(image.get_size()) / 2.0
			_blend(canvas, image, Vector2i(top_left.round()))
		return
	# Containers, such as a Room's Lanterns, draw their children.
	if node is Node2D and not node is CollisionObject2D:
		for child in node.get_children():
			_draw(child, canvas, position)


static func _blend(canvas: Image, image: Image, at: Vector2i) -> void:
	canvas.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), at)
