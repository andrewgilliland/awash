extends RefCounted


# Builds default sprite frames.
func build_default_sprite_frames(config: Dictionary) -> SpriteFrames:
	var sprite_sheet := config["sprite_sheet"] as Texture2D
	var image := _create_runtime_sprite_sheet_image(
		sprite_sheet,
		config["sprite_background_key_color"] as Color,
		float(config["sprite_background_key_tolerance"])
	)
	return build_default_sprite_frames_from_image(image, config)


# Builds default sprite frames from image.
func build_default_sprite_frames_from_image(image: Image, config: Dictionary) -> SpriteFrames:
	var animation_frame_size := config["animation_frame_size"] as Vector2i
	var idle_animation_fps := float(config["idle_animation_fps"])
	var run_animation_fps := float(config["run_animation_fps"])
	var air_animation_fps := float(config["air_animation_fps"])
	var attack_animation_fps := float(config["attack_animation_fps"])
	var crouch_animation_fps := float(config["crouch_animation_fps"])
	var guard_animation_fps := float(config["guard_animation_fps"])
	var guard_from_attack_frame_index := int(config["guard_from_attack_frame_index"])
	var charge_from_attack_frame_index := int(config["charge_from_attack_frame_index"])
	var hurt_animation_fps := float(config["hurt_animation_fps"])
	var death_animation_fps := float(config["death_animation_fps"])
	var sprite_frames := SpriteFrames.new()
	var sheet_rows := _extract_sheet_rows(image)

	_add_animation_regions(
		sprite_frames,
		&"idle",
		_get_row_regions(sheet_rows, 0),
		idle_animation_fps,
		true,
		image,
		animation_frame_size
	)
	_add_animation_regions(
		sprite_frames,
		&"walk",
		_get_row_regions(sheet_rows, 0),
		run_animation_fps,
		true,
		image,
		animation_frame_size
	)
	_add_animation_regions(
		sprite_frames,
		&"run",
		_get_row_regions(sheet_rows, 1),
		run_animation_fps,
		true,
		image,
		animation_frame_size
	)
	_add_animation_regions(
		sprite_frames,
		&"jump_up",
		_get_regions_by_indices(sheet_rows, 2, [1, 2]),
		air_animation_fps,
		true,
		image,
		animation_frame_size
	)
	_add_animation_regions(
		sprite_frames,
		&"jump_down",
		_get_regions_by_indices(sheet_rows, 2, [2, 3]),
		air_animation_fps,
		true,
		image,
		animation_frame_size
	)
	_add_animation_regions(
		sprite_frames,
		&"attack",
		_get_row_regions(sheet_rows, 3),
		attack_animation_fps,
		false,
		image,
		animation_frame_size
	)
	_add_animation_regions(
		sprite_frames,
		&"crouch",
		_get_regions_by_indices(sheet_rows, 5, [1, 0]),
		crouch_animation_fps,
		false,
		image,
		animation_frame_size
	)
	_copy_single_frame_animation(
		sprite_frames,
		&"guard",
		&"crouch",
		guard_from_attack_frame_index,
		guard_animation_fps,
		false
	)
	_copy_single_frame_animation(
		sprite_frames,
		&"charge",
		&"attack",
		charge_from_attack_frame_index,
		guard_animation_fps,
		false
	)
	_add_animation_regions(
		sprite_frames,
		&"hurt",
		_get_regions_by_indices(sheet_rows, 5, [0, 1]),
		hurt_animation_fps,
		false,
		image,
		animation_frame_size
	)
	_add_animation_regions(
		sprite_frames,
		&"death",
		_get_regions_by_indices(sheet_rows, 5, [4, 5]),
		death_animation_fps,
		false,
		image,
		animation_frame_size
	)

	_ensure_animation_exists(sprite_frames, &"jump_up", &"idle")
	_ensure_animation_exists(sprite_frames, &"jump_down", &"jump_up")
	_ensure_animation_exists(sprite_frames, &"walk", &"idle")
	_ensure_animation_exists(sprite_frames, &"attack", &"idle")
	_ensure_animation_exists(sprite_frames, &"crouch", &"idle")
	_ensure_animation_exists(sprite_frames, &"guard", &"crouch")
	_ensure_animation_exists(sprite_frames, &"charge", &"guard")
	_ensure_animation_exists(sprite_frames, &"hurt", &"idle")
	_ensure_animation_exists(sprite_frames, &"death", &"hurt")

	return sprite_frames


# Creates runtime sprite sheet image.
func create_runtime_sprite_sheet_image(
	sprite_sheet: Texture2D, key_color: Color, key_tolerance: float
) -> Image:
	return _create_runtime_sprite_sheet_image(sprite_sheet, key_color, key_tolerance)


# Creates runtime sprite sheet image.
func _create_runtime_sprite_sheet_image(
	sprite_sheet: Texture2D, key_color: Color, key_tolerance: float
) -> Image:
	var image := sprite_sheet.get_image()
	if image == null:
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)

	image.convert(Image.FORMAT_RGBA8)

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if _is_background_pixel(pixel, key_color, key_tolerance):
				image.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, 0.0))

	return image


# Returns whether background pixel is true.
func _is_background_pixel(pixel: Color, key_color: Color, key_tolerance: float) -> bool:
	if pixel.a <= 0.0:
		return false

	return (
		absf(pixel.r - key_color.r) <= key_tolerance
		and absf(pixel.g - key_color.g) <= key_tolerance
		and absf(pixel.b - key_color.b) <= key_tolerance
	)


# Extracts sheet rows.
func _extract_sheet_rows(image: Image) -> Array:
	var row_bands: Array = []
	var band_start := -1

	for y in range(image.get_height()):
		var occupied := false
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				occupied = true
				break

		if occupied and band_start < 0:
			band_start = y
		elif not occupied and band_start >= 0:
			row_bands.append(Vector2i(band_start, y - 1))
			band_start = -1

	if band_start >= 0:
		row_bands.append(Vector2i(band_start, image.get_height() - 1))

	var sheet_rows: Array = []
	for row_band in row_bands:
		sheet_rows.append(_extract_row_regions(image, row_band.x, row_band.y))

	return sheet_rows


# Extracts row regions.
func _extract_row_regions(image: Image, top: int, bottom: int) -> Array:
	var column_bands: Array = []
	var band_start := -1

	for x in range(image.get_width()):
		var occupied := false
		for y in range(top, bottom + 1):
			if image.get_pixel(x, y).a > 0.0:
				occupied = true
				break

		if occupied and band_start < 0:
			band_start = x
		elif not occupied and band_start >= 0:
			column_bands.append(Vector2i(band_start, x - 1))
			band_start = -1

	if band_start >= 0:
		column_bands.append(Vector2i(band_start, image.get_width() - 1))

	var regions: Array = []
	for column_band in column_bands:
		regions.append(_trim_region(image, column_band.x, column_band.y, top, bottom))

	return regions


# Trims transparent bounds from a candidate frame region.
func _trim_region(image: Image, left: int, right: int, top: int, bottom: int) -> Rect2i:
	var min_x := right
	var min_y := bottom
	var max_x := left
	var max_y := top

	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			if image.get_pixel(x, y).a <= 0.0:
				continue

			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	return Rect2i(min_x, min_y, (max_x - min_x) + 1, (max_y - min_y) + 1)


# Returns row regions.
func _get_row_regions(sheet_rows: Array, row_index: int) -> Array:
	if row_index < 0 or row_index >= sheet_rows.size():
		return []

	return sheet_rows[row_index]


# Returns regions by indices.
func _get_regions_by_indices(sheet_rows: Array, row_index: int, indices: Array) -> Array:
	var selected_regions: Array = []
	if row_index < 0 or row_index >= sheet_rows.size():
		return selected_regions

	var row_regions: Array = sheet_rows[row_index]
	for index in indices:
		if index >= 0 and index < row_regions.size():
			selected_regions.append(row_regions[index])

	return selected_regions


# Adds aligned frame textures for each source region into an animation track.
func _add_animation_regions(
	sprite_frames: SpriteFrames,
	animation_name: StringName,
	regions: Array,
	fps: float,
	looped: bool,
	image: Image,
	animation_frame_size: Vector2i
) -> void:
	if regions.is_empty():
		return

	if not sprite_frames.has_animation(animation_name):
		sprite_frames.add_animation(animation_name)

	sprite_frames.set_animation_speed(animation_name, maxf(0.1, fps))
	sprite_frames.set_animation_loop(animation_name, looped)

	for region in regions:
		sprite_frames.add_frame(
			animation_name, _create_aligned_frame_texture(image, region, animation_frame_size)
		)


# Ensures animation exists.
func _ensure_animation_exists(
	sprite_frames: SpriteFrames, animation_name: StringName, fallback_name: StringName
) -> void:
	if sprite_frames.has_animation(animation_name):
		return

	if not sprite_frames.has_animation(fallback_name):
		return

	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(
		animation_name, sprite_frames.get_animation_speed(fallback_name)
	)
	sprite_frames.set_animation_loop(
		animation_name, sprite_frames.get_animation_loop(fallback_name)
	)

	for frame_index in range(sprite_frames.get_frame_count(fallback_name)):
		sprite_frames.add_frame(
			animation_name,
			sprite_frames.get_frame_texture(fallback_name, frame_index),
			sprite_frames.get_frame_duration(fallback_name, frame_index)
		)


# Copies single frame animation.
func _copy_single_frame_animation(
	sprite_frames: SpriteFrames,
	target_animation_name: StringName,
	source_animation_name: StringName,
	source_frame_index: int,
	fps: float,
	looped: bool
) -> void:
	if not sprite_frames.has_animation(source_animation_name):
		return

	var source_count := sprite_frames.get_frame_count(source_animation_name)
	if source_count <= 0:
		return

	if sprite_frames.has_animation(target_animation_name):
		sprite_frames.remove_animation(target_animation_name)

	sprite_frames.add_animation(target_animation_name)
	sprite_frames.set_animation_speed(target_animation_name, maxf(0.1, fps))
	sprite_frames.set_animation_loop(target_animation_name, looped)

	var clamped_index := clampi(source_frame_index, 0, source_count - 1)
	sprite_frames.add_frame(
		target_animation_name,
		sprite_frames.get_frame_texture(source_animation_name, clamped_index),
		sprite_frames.get_frame_duration(source_animation_name, clamped_index)
	)


# Creates aligned frame texture.
func _create_aligned_frame_texture(
	image: Image, region: Rect2i, animation_frame_size: Vector2i
) -> Texture2D:
	var frame_image := Image.create(
		animation_frame_size.x, animation_frame_size.y, false, Image.FORMAT_RGBA8
	)
	frame_image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var cropped_image := image.get_region(region)
	cropped_image.convert(Image.FORMAT_RGBA8)
	var destination := Vector2i(
		maxi(0, (animation_frame_size.x - region.size.x) >> 1),
		maxi(0, animation_frame_size.y - region.size.y)
	)
	frame_image.blit_rect(cropped_image, Rect2i(Vector2i.ZERO, region.size), destination)

	return ImageTexture.create_from_image(frame_image)
