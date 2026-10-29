extends SceneTree

# Runs the art checks from docs/art-style.md over the game's art and Rooms, and draws the Room
# contact sheet. Writes build/art-report/: report.json, contact_sheet.png (each Room flat at 1x,
# laid out as on the Map), contact_sheet_grey.png and contact_sheet_thumb.png (25%). Exits 1 when
# any check fails. Run it with scripts/quality/art.sh.

const ArtChecks := preload("res://scripts/tools/art_checks.gd")
const RoomRender := preload("res://scripts/tools/room_render.gd")
const WorldMap := preload("res://scripts/core/world_map.gd")
const PALETTE_PATH := "res://assets/palettes/awash_dusk.gpl"
const OUT_DIR := "res://build/art-report"
const TILE := 16
# The art a player sees, checked against the palette.
const ART := [
	"res://assets/tilesets/waking_coast_2.png",
	"res://assets/backgrounds/waking_coast_backdrop.png",
	"res://assets/backgrounds/waking_coast_2_backdrop.png",
	"res://assets/backgrounds/waking_coast_3_backdrop.png",
	"res://assets/sprites/player_1.png",
	"res://assets/sprites/weapons/sword_1.png",
	"res://assets/sprites/weapons/blacktide_stuck.png",
	"res://assets/sprites/npcs/mara/mara_venn_1.png",
	"res://assets/sprites/enemies/scavenger_1.png",
	"res://assets/sprites/props/tidefen_lantern.png",
	"res://assets/ui/awash_logo.png",
	"res://assets/ui/interact_prompt.png",
	"res://assets/fonts/awash_pixel_5x7.png",
]
# Characters: their sheet, frame size, the frames the game shows, the frames drawn in the air
# (whose feet may leave the bottom row), and the hurtbox height their figures are sized against.
const CHARACTERS := [
	["Vael", "res://assets/sprites/player_1.png", 16, [0, 1, 2, 3, 4, 5, 6], [2, 3, 4], 20],
	["Mara", "res://assets/sprites/npcs/mara/mara_venn_1.png", 16, [0, 1], [], 20],
	["Scavenger", "res://assets/sprites/enemies/scavenger_1.png", 16, [0, 1, 2, 3, 4], [], 20],
]
# A figure's height must be within this share of its hurtbox's.
const FIGURE_HEIGHT := Vector2(0.7, 1.25)
# The shallows stand the Player on sand under water, so they show no lit top edge.
const SHALLOWS := Vector2i(5, 5)

var _results: Array = []


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_check_palette()
	var rooms := _load_rooms()
	_check_tiles(rooms)
	_check_rooms(rooms)
	_check_loops(rooms)
	_check_characters()
	_draw_contact_sheet(rooms)
	for room in rooms:
		room.node.free()
	quit(_report())


func _add(check: String, subject: String, ok: bool, detail: String) -> void:
	_results.append({check = check, subject = subject, ok = ok, detail = detail})


func _check_palette() -> void:
	var palette := ArtChecks.load_palette(PALETTE_PATH)
	for path in ART:
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		image.convert(Image.FORMAT_RGBA8)
		var off: Dictionary = ArtChecks.off_palette(image, palette)
		var opaque := 0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a >= 0.5:
					opaque += 1
		var share: float = 100.0 * off.pixels / maxi(opaque, 1)
		_add(
			"palette",
			path.get_file(),
			off.pixels == 0,
			"%.0f%% of pixels off the palette, %d colours" % [share, off.colours.size()]
		)


# Every Room on the Map: its scene, its size, and where it sits on the Map in pixels.
func _load_rooms() -> Array:
	var rooms := []
	for room_id in WorldMap.ROOMS:
		var spec: Dictionary = WorldMap.ROOMS[room_id]
		var node := (load(spec.scene) as PackedScene).instantiate() as Node2D
		var size := Vector2i(Vector2(spec.size) * WorldMap.SCREEN_SIZE)
		rooms.append({id = room_id, node = node, size = size, cell = spec.cell})
	return rooms


# Tiles a Room stands the Player on must show it: solid surfaces a lit top edge, one-way ones
# a lit plank that reaches their collision.
func _check_tiles(rooms: Array) -> void:
	var surfaces := {}
	var tile_set: TileSet
	for room in rooms:
		var terrain := room.node.get_node_or_null("Terrain") as TileMapLayer
		if terrain == null:
			continue
		tile_set = terrain.tile_set
		for cell in terrain.get_used_cells():
			# The top row is the Room's edge, not ground.
			if cell.y > 0 and terrain.get_cell_source_id(cell + Vector2i.UP) == -1:
				surfaces[terrain.get_cell_atlas_coords(cell)] = true
	var source := tile_set.get_source(0) as TileSetAtlasSource
	for coords in surfaces:
		var data := source.get_tile_data(coords, 0)
		if data.get_collision_polygons_count(0) == 0 or coords == SHALLOWS:
			continue
		var tile := RoomRender.tile_image(tile_set, coords)
		var one_way := data.is_collision_polygon_one_way(0, 0)
		var body := ArtChecks.ONE_WAY_BODY if one_way else ArtChecks.SOLID_BODY
		var lit := ArtChecks.has_lit_top_edge(tile, body)
		var reaches := ArtChecks.covers_top(tile, ArtChecks.ONE_WAY_ROWS if one_way else 2)
		var kind := "one-way" if one_way else "solid"
		var detail := (
			"%s surface: %s, %s"
			% [
				kind,
				"lit top edge" if lit else "no lit top edge",
				"reaches its collision" if reaches else "falls short of its collision"
			]
		)
		_add("collision-art", "tile %s" % coords, lit and reaches, detail)


func _family(coords: Vector2i) -> String:
	if coords.y in [0, 1, 8] or coords == Vector2i(6, 5):
		return "sand"
	if coords.y in [2, 3] or coords in [Vector2i(0, 4), Vector2i(1, 4)]:
		return "rock"
	return ""


func _check_rooms(rooms: Array) -> void:
	for room in rooms:
		var terrain := room.node.get_node_or_null("Terrain") as TileMapLayer
		if terrain == null:
			continue
		var full := RoomRender.render(room.node, room.size)
		var behind := RoomRender.render(room.node, room.size, &"Terrain")
		var ground := RoomRender.render_layer(terrain, room.size)
		room.render = full
		var source := terrain.tile_set.get_source(0) as TileSetAtlasSource
		# Readability: each surface's top edge against what is just behind it.
		var surfaces := 0
		var readable := 0
		for cell in terrain.get_used_cells():
			var coords := terrain.get_cell_atlas_coords(cell)
			if terrain.get_cell_source_id(cell + Vector2i.UP) != -1 or cell.y == 0:
				continue
			if source.get_tile_data(coords, 0).get_collision_polygons_count(0) == 0:
				continue
			surfaces += 1
			var top := _mean_colour(full, Rect2i(cell * TILE, Vector2i(TILE, 2)))
			var back := _mean_colour(
				behind, Rect2i(cell * TILE - Vector2i(0, 3), Vector2i(TILE, 2))
			)
			if ArtChecks.reads_against(top, back):
				readable += 1
		_add(
			"readability",
			String(room.id),
			readable == surfaces,
			"%d of %d surfaces read against what is behind them" % [readable, surfaces]
		)
		# Seams: same-family tiles side by side or stacked.
		var pairs := 0
		var seams := 0
		for cell in terrain.get_used_cells():
			var family := _family(terrain.get_cell_atlas_coords(cell))
			if family == "":
				continue
			for next in [Vector2i.RIGHT, Vector2i.DOWN]:
				var other: Vector2i = cell + next
				if (
					terrain.get_cell_source_id(other) == -1
					or _family(terrain.get_cell_atlas_coords(other)) != family
				):
					continue
				pairs += 1
				var a := ground.get_region(Rect2i(cell * TILE, Vector2i(TILE, TILE)))
				var b := ground.get_region(Rect2i(other * TILE, Vector2i(TILE, TILE)))
				if ArtChecks.is_seam(ArtChecks.seam_across(a, b, next == Vector2i.RIGHT)):
					seams += 1
		_add(
			"seams",
			String(room.id),
			seams == 0,
			"%d seams in %d same-material joins" % [seams, pairs]
		)


func _mean_colour(image: Image, rect: Rect2i) -> Color:
	var total := Color(0, 0, 0, 0)
	var count := 0
	for y in range(maxi(rect.position.y, 0), mini(rect.end.y, image.get_height())):
		for x in range(maxi(rect.position.x, 0), mini(rect.end.x, image.get_width())):
			total += image.get_pixel(x, y)
			count += 1
	return total / maxf(count, 1)


# Animated tiles, backdrops and lanterns must loop without a jump.
func _check_loops(rooms: Array) -> void:
	var seen := {}
	var tile_set: TileSet = (rooms[0].node.get_node("Terrain") as TileMapLayer).tile_set
	var source := tile_set.get_source(0) as TileSetAtlasSource
	for i in source.get_tiles_count():
		var coords := source.get_tile_id(i)
		var count := source.get_tile_animation_frames_count(coords)
		if count < 2:
			continue
		var frames: Array[Image] = []
		for frame in count:
			frames.append(RoomRender.tile_image(tile_set, coords, frame))
		_add("loops", "tile %s" % coords, not ArtChecks.breaks_loop(frames), "%d frames" % count)
	for room in rooms:
		for node in room.node.find_children("*", "AnimatedSprite2D", true, false):
			var sprite := node as AnimatedSprite2D
			var frames := RoomRender.sprite_frames_images(sprite)
			if frames.size() < 2:
				continue
			var key := (
				(sprite.sprite_frames.get_frame_texture(sprite.animation, 0) as AtlasTexture)
				. atlas
				. resource_path
			)
			if seen.has(key):
				continue
			seen[key] = true
			_add(
				"loops",
				key.get_file(),
				not ArtChecks.breaks_loop(frames),
				"%d frames" % frames.size()
			)


# Each character frame: feet on the bottom row, one solid silhouette, a figure sized to its box.
func _check_characters() -> void:
	for spec in CHARACTERS:
		var sheet := Image.load_from_file(ProjectSettings.globalize_path(spec[1]))
		sheet.convert(Image.FORMAT_RGBA8)
		var size: int = spec[2]
		for index in spec[3]:
			var frame := sheet.get_region(Rect2i(index * size, 0, size, size))
			var used := frame.get_used_rect()
			var airborne: bool = index in spec[4]
			var feet: bool = used.end.y == size or airborne
			var parts := ArtChecks.silhouette_parts(frame)
			var share: float = float(used.size.y) / spec[5]
			var fits: bool = share >= FIGURE_HEIGHT.x and share <= FIGURE_HEIGHT.y
			var feet_at := "in the air" if airborne else "on the bottom row"
			if not feet:
				feet_at = "%d px up" % (size - used.end.y)
			var detail := (
				"feet %s, %d piece%s, %d px tall (%.0f%% of its box)"
				% [feet_at, parts, "" if parts == 1 else "s", used.size.y, share * 100.0]
			)
			_add(
				"characters", "%s frame %d" % [spec[0], index], feet and parts == 1 and fits, detail
			)


# Every Room flat at 1x, placed as on the Map; a greyscale copy and a 25% thumbnail.
func _draw_contact_sheet(rooms: Array) -> void:
	var low := Vector2i(1 << 20, 1 << 20)
	var high := Vector2i(-(1 << 20), -(1 << 20))
	var screen := Vector2i(WorldMap.SCREEN_SIZE)
	for room in rooms:
		var at: Vector2i = room.cell * screen
		low = Vector2i(mini(low.x, at.x), mini(low.y, at.y))
		high = Vector2i(maxi(high.x, at.x + room.size.x), maxi(high.y, at.y + room.size.y))
	var sheet := Image.create_empty(high.x - low.x, high.y - low.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(0, 40, 56))
	var layout := []
	for room in rooms:
		if not room.has("render"):
			continue
		var at: Vector2i = room.cell * screen - low
		sheet.blit_rect(room.render, Rect2i(Vector2i.ZERO, room.size), at)
		layout.append({id = String(room.id), x = at.x, y = at.y, w = room.size.x, h = room.size.y})
	var out := ProjectSettings.globalize_path(OUT_DIR)
	sheet.save_png(out + "/contact_sheet.png")
	var grey := sheet.duplicate() as Image
	for y in grey.get_height():
		for x in grey.get_width():
			var v := ArtChecks.value(grey.get_pixel(x, y)) / 255.0
			grey.set_pixel(x, y, Color(v, v, v))
	grey.save_png(out + "/contact_sheet_grey.png")
	var thumb := sheet.duplicate() as Image
	thumb.resize(sheet.get_width() / 4, sheet.get_height() / 4, Image.INTERPOLATE_BILINEAR)
	thumb.save_png(out + "/contact_sheet_thumb.png")
	var file := FileAccess.open(OUT_DIR + "/layout.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(layout, "  "))
	file.close()


# Prints a summary per check and writes report.json; 0 when every check passed.
func _report() -> int:
	var checks := ["palette", "readability", "seams", "loops", "collision-art", "characters"]
	var failed := 0
	print("Art report")
	for check in checks:
		var passed := 0
		var total := 0
		for r in _results:
			if r.check == check:
				total += 1
				passed += 1 if r.ok else 0
		failed += total - passed
		print("  %-14s %3d of %3d pass" % [check, passed, total])
		for r in _results:
			if r.check == check and not r.ok:
				print("    FAIL %s: %s" % [r.subject, r.detail])
	var file := FileAccess.open(OUT_DIR + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_results, "  "))
	file.close()
	print("Wrote %s" % ProjectSettings.globalize_path(OUT_DIR))
	return 1 if failed > 0 else 0
