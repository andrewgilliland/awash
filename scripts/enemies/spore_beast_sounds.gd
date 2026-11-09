extends RefCounted

const SporeBeastBrain := preload("res://scripts/enemies/spore_beast_brain.gd")
# Each names an AudioStreamPlayer2D under the Spore Beast's Sounds node.
const SNORT := &"Snort"
const HISS := &"Hiss"
const DEFEAT := &"Defeat"

var _players: Node


func _init(players: Node) -> void:
	_players = players


# The sound a state change makes, or none: a snort as it starts after the Player, a hiss as its
# spores vent, a groan at its defeat. A hit while it is still venting hisses on its own.
static func for_state_change(
	previous: SporeBeastBrain.State, next: SporeBeastBrain.State
) -> StringName:
	if next == SporeBeastBrain.State.DEFEATED:
		return DEFEAT
	if next == SporeBeastBrain.State.VENTING and previous != next:
		return HISS
	if next == SporeBeastBrain.State.LUMBERING and previous == SporeBeastBrain.State.IDLE:
		return SNORT
	return &""


func play(sound: StringName) -> void:
	if sound.is_empty() or _players == null:
		return
	var stream_player := _players.get_node_or_null(NodePath(sound)) as AudioStreamPlayer2D
	if stream_player != null:
		stream_player.play()
