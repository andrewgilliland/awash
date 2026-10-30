extends RefCounted

const WardenBrain := preload("res://scripts/enemies/warden_brain.gd")
# Each names an AudioStreamPlayer2D under the Warden's Sounds node.
const WINDUP := &"Windup"
const BASH := &"Bash"
const SLAM := &"Slam"
const CLANG := &"Clang"
const WARD_BREAK := &"WardBreak"
const HURT := &"Hurt"
const DEFEAT := &"Defeat"
# The sound of entering each state; the others are quiet. A hit's sound is the body's to play.
const ON_ENTER := {
	WardenBrain.State.WINDUP: WINDUP,
	WardenBrain.State.BASH: BASH,
	WardenBrain.State.SLAM: SLAM,
	WardenBrain.State.DEFEATED: DEFEAT,
}

var _players: Node


func _init(players: Node) -> void:
	_players = players


# The sound a state change makes, or none. Each slam of a pair booms, so a slam into a slam
# sounds too.
static func for_state_change(_previous: WardenBrain.State, next: WardenBrain.State) -> StringName:
	return ON_ENTER.get(next, &"")


func play(sound: StringName) -> void:
	if sound.is_empty() or _players == null:
		return
	var stream_player := _players.get_node_or_null(NodePath(sound)) as AudioStreamPlayer2D
	if stream_player != null:
		stream_player.play()
