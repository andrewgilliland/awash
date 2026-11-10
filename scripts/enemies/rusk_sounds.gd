extends RefCounted

const RuskBrain := preload("res://scripts/enemies/rusk_brain.gd")
# Each names an AudioStreamPlayer2D under Rusk's Sounds node.
const ROAR := &"Roar"
const STAMP := &"Stamp"
const CRASH := &"Crash"
const WHOOSH := &"Whoosh"
const BOOM := &"Boom"
const CLANG := &"Clang"
const GRUNT := &"Grunt"
const CRY := &"Cry"
# The sound of entering each state; the others are quiet. A hit's sound, and his charge's crash,
# are the body's to play.
const ON_ENTER := {
	RuskBrain.State.SUMMONING: ROAR,
	RuskBrain.State.TELL: STAMP,
	RuskBrain.State.WIND_UP: WHOOSH,
	RuskBrain.State.SLAM: BOOM,
	RuskBrain.State.LEAP: CRY,
}

var _players: Node


func _init(players: Node) -> void:
	_players = players


# The sound a state change makes, or none.
static func for_state_change(_previous: RuskBrain.State, next: RuskBrain.State) -> StringName:
	return ON_ENTER.get(next, &"")


func play(sound: StringName) -> void:
	if sound.is_empty() or _players == null:
		return
	var stream_player := _players.get_node_or_null(NodePath(sound)) as AudioStreamPlayer2D
	if stream_player != null:
		stream_player.play()
