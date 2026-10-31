extends RefCounted

const ReefbackBrain := preload("res://scripts/enemies/reefback_brain.gd")
# Each names an AudioStreamPlayer2D under the Reefback's Sounds node.
const ROAR := &"Roar"
const CHARGE := &"Charge"
const SWIPE := &"Swipe"
const POUND := &"Pound"
const LEAP := &"Leap"
const LAND := &"Land"
const THROW := &"Throw"
const BEAT := &"Beat"
const CLANG := &"Clang"
const WARD_BREAK := &"WardBreak"
const HURT := &"Hurt"
const DEFEAT := &"Defeat"
# The sound of entering each state; the others are quiet. A hit's sound is the body's to play.
const ON_ENTER := {
	ReefbackBrain.State.TELL: ROAR,
	ReefbackBrain.State.CHARGE: CHARGE,
	ReefbackBrain.State.SWIPE: SWIPE,
	ReefbackBrain.State.POUND: POUND,
	ReefbackBrain.State.LEAP: LEAP,
	ReefbackBrain.State.LAND: LAND,
	ReefbackBrain.State.THROW: THROW,
	ReefbackBrain.State.CHEST_BEAT: BEAT,
	ReefbackBrain.State.DEFEATED: DEFEAT,
}

var _players: Node


func _init(players: Node) -> void:
	_players = players


# The sound a state change makes, or none. Every Tell roars, so each attack is heard coming.
static func for_state_change(
	_previous: ReefbackBrain.State, next: ReefbackBrain.State
) -> StringName:
	return ON_ENTER.get(next, &"")


func play(sound: StringName) -> void:
	if sound.is_empty() or _players == null:
		return
	var stream_player := _players.get_node_or_null(NodePath(sound)) as AudioStreamPlayer2D
	if stream_player != null:
		stream_player.play()
