extends Node

# The game's music, as the Music autoload: it outlives scene changes, so a Room asking for the
# track that is already playing lets it play on through an Exit.

const VOLUME_DB := -6.0
# A new track fades in from here.
const FADE_FROM_DB := -30.0
const FADE_IN := 0.6

# Read-only for callers: how many times a track has started from the top. A Room asking for
# the track already playing leaves it unchanged.
var tracks_started: int = 0
var _player: AudioStreamPlayer


func _init() -> void:
	# Music carries on under the Pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = &"Music"
	_player.volume_db = VOLUME_DB
	add_child(_player)


# Plays a track, fading it in; the track already playing just carries on.
func play(stream: AudioStream) -> void:
	if stream == null or (_player.playing and _player.stream == stream):
		return
	_player.stream = stream
	_player.volume_db = FADE_FROM_DB
	_player.play()
	tracks_started += 1
	create_tween().tween_property(_player, ^"volume_db", VOLUME_DB, FADE_IN)


func stop() -> void:
	_player.stop()


# The track playing now, or null.
func current() -> AudioStream:
	return _player.stream if _player.playing else null
