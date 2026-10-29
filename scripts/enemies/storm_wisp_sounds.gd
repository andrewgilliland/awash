extends RefCounted

const StormWispBrain := preload("res://scripts/enemies/storm_wisp_brain.gd")
# Each names an AudioStreamPlayer2D under the Storm Wisp's Sounds node.
const CRACKLE := &"Crackle"
const ZAP := &"Zap"
const HURT := &"Hurt"
const DEFEAT := &"Defeat"
# The sound of entering each state; the others are quiet.
const ON_ENTER := {
	StormWispBrain.State.CRACKLE: CRACKLE,
	StormWispBrain.State.ARC: ZAP,
	StormWispBrain.State.HURT: HURT,
	StormWispBrain.State.DEFEATED: DEFEAT,
}

var _players: Node


func _init(players: Node) -> void:
	_players = players


# The sound a state change makes, or none. The crackle is the Player's warning that an arc is
# coming.
static func for_state_change(
	_previous: StormWispBrain.State, next: StormWispBrain.State
) -> StringName:
	return ON_ENTER.get(next, &"")


func play(sound: StringName) -> void:
	if sound.is_empty() or _players == null:
		return
	var stream_player := _players.get_node_or_null(NodePath(sound)) as AudioStreamPlayer2D
	if stream_player != null:
		stream_player.play()
