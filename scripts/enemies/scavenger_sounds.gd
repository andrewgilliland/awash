extends RefCounted

const ScavengerBrain := preload("res://scripts/enemies/scavenger_brain.gd")
# Each names an AudioStreamPlayer2D under the Scavenger's Sounds node.
const WINDUP := &"Windup"
const LUNGE := &"Lunge"
const HURT := &"Hurt"
const DEFEAT := &"Defeat"
# The sound of entering each state; the others are quiet.
const ON_ENTER := {
	ScavengerBrain.State.WINDUP: WINDUP,
	ScavengerBrain.State.LUNGE: LUNGE,
	ScavengerBrain.State.HURT: HURT,
	ScavengerBrain.State.DEFEATED: DEFEAT,
}

var _players: Node


func _init(players: Node) -> void:
	_players = players


# The sound a state change makes, or none. The wind-up's growl is the Player's warning that a
# lunge is coming.
static func for_state_change(
	_previous: ScavengerBrain.State, next: ScavengerBrain.State
) -> StringName:
	return ON_ENTER.get(next, &"")


func play(sound: StringName) -> void:
	if sound.is_empty() or _players == null:
		return
	var stream_player := _players.get_node_or_null(NodePath(sound)) as AudioStreamPlayer2D
	if stream_player != null:
		stream_player.play()
