extends RefCounted

const MusicScript := preload("res://scripts/core/music.gd")
const WorldMap := preload("res://scripts/core/world_map.gd")
const FIRST_ROOM := preload("res://scenes/rooms/waking_coast_1.tscn")
const COAST_THEME_PATH := "res://assets/audio/music/waking_coast_theme.wav"
const START_THEME_PATH := "res://assets/audio/music/start_theme.wav"

# Needs a root that is already in the tree: music only plays, and fades, inside it.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Music plays a track on the Music bus", _test_plays_on_music_bus],
		["Music keeps going when asked for the same track", _test_same_track_continues],
		["Music switches to a new track, and stops", _test_switches_and_stops],
		["Every Room's region has a looping theme", _test_regions_have_themes],
		["A Room starts its region's theme", _test_room_starts_theme],
	]


func _test_plays_on_music_bus() -> bool:
	var music := _music()
	music.play(load(COAST_THEME_PATH))
	var player := music.get_child(0) as AudioStreamPlayer
	var valid := player.playing and player.bus == &"Music"
	valid = valid and music.current().resource_path == COAST_THEME_PATH
	music.free()
	return valid


func _test_same_track_continues() -> bool:
	var music := _music()
	music.play(load(COAST_THEME_PATH))
	var player := music.get_child(0) as AudioStreamPlayer
	player.seek(5.0)
	var starts := music.tracks_started
	music.play(load(COAST_THEME_PATH))
	var valid := player.playing and player.get_playback_position() >= 5.0
	valid = valid and music.tracks_started == starts
	music.free()
	return valid


func _test_switches_and_stops() -> bool:
	var music := _music()
	music.play(load(COAST_THEME_PATH))
	music.play(load(START_THEME_PATH))
	var valid := music.current().resource_path == START_THEME_PATH
	music.stop()
	valid = valid and music.current() == null
	music.free()
	return valid


func _test_regions_have_themes() -> bool:
	var valid := true
	for room_id in WorldMap.ROOMS:
		var theme := load(WorldMap.music_for(room_id)) as AudioStreamWAV
		valid = valid and theme != null and theme.loop_mode == AudioStreamWAV.LOOP_FORWARD
	return valid


# The Room asks the game's Music autoload, live once the first frame has run.
func _test_room_starts_theme() -> bool:
	var music := _root.get_node_or_null("Music") as MusicScript
	if music == null:
		return false
	music.stop()
	var room := FIRST_ROOM.instantiate()
	_root.add_child(room)
	var valid := music.current() != null and music.current().resource_path == COAST_THEME_PATH
	room.free()
	music.stop()
	return valid


func _music() -> MusicScript:
	var music := MusicScript.new()
	_root.add_child(music)
	return music
