extends RefCounted

# The art checks on small made-up pictures, so each rule is pinned down before it is run over
# the real art.

const ArtChecks := preload("res://scripts/tools/art_checks.gd")
const DARK := Color8(30, 24, 40)
const MID := Color8(100, 90, 120)
const LIGHT := Color8(220, 210, 230)
const OFF := Color8(255, 0, 255)
const CLEAR := Color(0, 0, 0, 0)


func get_tests() -> Array:
	return [
		["Palette check counts colours off the palette", _test_off_palette],
		["Palette check reads a GIMP palette", _test_reads_palette],
		["A surface tile's lit top edge is found", _test_lit_top_edge],
		["A tile's art must reach its collision edge", _test_covers_top],
		["Value gap says whether a surface reads against what is behind", _test_value_gap],
		["Seam check flags a hard step across a tile edge", _test_seam],
		["Loop check flags a jump from the last frame to the first", _test_loop],
		["Silhouette check counts separate pieces", _test_silhouette],
	]


static func _image(width: int, height: int, colour: Color) -> Image:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	return image


func _test_off_palette() -> bool:
	var palette := {DARK.to_html(false): true, MID.to_html(false): true}
	var image := _image(4, 4, DARK)
	image.set_pixel(1, 1, MID)
	var valid: bool = ArtChecks.off_palette(image, palette).pixels == 0
	image.set_pixel(2, 2, OFF)
	image.set_pixel(3, 3, OFF)
	# Transparent pixels are not colours.
	image.set_pixel(0, 3, CLEAR)
	var result: Dictionary = ArtChecks.off_palette(image, palette)
	return valid and result.pixels == 2 and result.colours == [OFF.to_html(false)]


func _test_reads_palette() -> bool:
	var path := "user://art_checks_test.gpl"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(
		"GIMP Palette\nName: Test\nColumns: 2\n#\n 30  24  40\tInk 1\n255   0 255\tPink 1\n"
	)
	file.close()
	var palette: Dictionary = ArtChecks.load_palette(path)
	DirAccess.remove_absolute(path)
	return (
		palette.size() == 2 and palette.has(DARK.to_html(false)) and palette.has(OFF.to_html(false))
	)


func _test_lit_top_edge() -> bool:
	var tile := _image(16, 16, MID)
	var flat := not ArtChecks.has_lit_top_edge(tile, ArtChecks.SOLID_BODY)
	tile.fill_rect(Rect2i(0, 0, 16, 2), LIGHT)
	return flat and ArtChecks.has_lit_top_edge(tile, ArtChecks.SOLID_BODY)


func _test_covers_top() -> bool:
	var deck := _image(16, 16, CLEAR)
	var empty := not ArtChecks.covers_top(deck, ArtChecks.ONE_WAY_ROWS)
	# A plank 14 px wide across row 3 reaches the collision edge; a 6 px stub does not.
	deck.fill_rect(Rect2i(0, 3, 6, 1), MID)
	var stub := not ArtChecks.covers_top(deck, ArtChecks.ONE_WAY_ROWS)
	deck.fill_rect(Rect2i(0, 3, 14, 1), MID)
	return empty and stub and ArtChecks.covers_top(deck, ArtChecks.ONE_WAY_ROWS)


func _test_value_gap() -> bool:
	var valid := ArtChecks.reads_against(LIGHT, MID)
	valid = valid and not ArtChecks.reads_against(MID, MID.lightened(0.05))
	return valid and ArtChecks.reads_against(DARK, LIGHT)


func _test_seam() -> bool:
	# Two tiles of a smooth left-to-right ramp meet without a seam.
	var left := _image(16, 16, DARK)
	var right := _image(16, 16, DARK)
	for x in 16:
		left.fill_rect(Rect2i(x, 0, 1, 16), DARK.lerp(MID, x / 32.0))
		right.fill_rect(Rect2i(x, 0, 1, 16), DARK.lerp(MID, (x + 16) / 32.0))
	var smooth: Dictionary = ArtChecks.seam_across(left, right, true)
	var valid: bool = not ArtChecks.is_seam(smooth)
	# A flat dark tile beside a flat light one is all edge.
	var hard: Dictionary = ArtChecks.seam_across(_image(16, 16, DARK), _image(16, 16, LIGHT), true)
	valid = valid and ArtChecks.is_seam(hard)
	var below: Dictionary = ArtChecks.seam_across(
		_image(16, 16, DARK), _image(16, 16, LIGHT), false
	)
	return valid and ArtChecks.is_seam(below)


func _test_loop() -> bool:
	# A light sweeping across and back loops; one that sweeps and snaps back does not.
	var smooth: Array[Image] = []
	var snap: Array[Image] = []
	for step in [0, 1, 2, 1]:
		var frame := _image(16, 16, DARK)
		frame.fill_rect(Rect2i(step * 4, 0, 4, 16), LIGHT)
		smooth.append(frame)
	for step in [0, 1, 2, 3]:
		var frame := _image(16, 16, DARK)
		frame.fill_rect(Rect2i(0, 0, (step + 1) * 4, 16), LIGHT)
		snap.append(frame)
	return not ArtChecks.breaks_loop(smooth) and ArtChecks.breaks_loop(snap)


func _test_silhouette() -> bool:
	var figure := _image(8, 8, CLEAR)
	figure.fill_rect(Rect2i(2, 1, 3, 6), MID)
	var one: bool = ArtChecks.silhouette_parts(figure) == 1
	# A diagonal touch still joins; a gap splits.
	figure.set_pixel(5, 7, MID)
	var joined: bool = ArtChecks.silhouette_parts(figure) == 1
	figure.set_pixel(7, 0, MID)
	return one and joined and ArtChecks.silhouette_parts(figure) == 2
