extends Control

# The last line was read and the box closed.
signal closed

const Dialogue := preload("res://scripts/ui/dialogue.gd")
const PLAYER_GROUP := &"player"
# Any of these finishes the line typing out, or moves to the next.
const ADVANCE_ACTIONS: Array[StringName] = [&"ui_accept", &"jump", &"interact"]
const NEXT_BLINK := 0.4

# Read-only for callers: the conversation being shown, or null.
var dialogue: Dialogue
var _blink_time: float = 0.0

@onready var _speaker: Label = %Speaker
@onready var _text: Label = %Text
@onready var _next: Label = %Next


func _ready() -> void:
	visible = false


# Opens on the first of [speaker, text] lines and holds the Player still until it closes.
func show_lines(lines: Array) -> void:
	dialogue = Dialogue.new(lines)
	_set_player_locked(true)
	visible = true
	_refresh()


func is_open() -> bool:
	return visible


func advance() -> void:
	if dialogue == null:
		return
	dialogue.advance()
	if dialogue.finished():
		_close()
	else:
		_refresh()


func _process(delta: float) -> void:
	if dialogue == null:
		return
	dialogue.step(delta)
	_blink_time += delta
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	for action in ADVANCE_ACTIONS:
		if event.is_action_pressed(action) and not event.is_echo():
			advance()
			get_viewport().set_input_as_handled()
			return


func _refresh() -> void:
	_speaker.text = dialogue.speaker()
	_text.text = dialogue.visible_text()
	_next.visible = dialogue.line_shown() and fmod(_blink_time, NEXT_BLINK * 2.0) < NEXT_BLINK


func _close() -> void:
	dialogue = null
	visible = false
	closed.emit()
	# The press that closed the box must not also move the Player, so wait a frame.
	if is_inside_tree():
		await get_tree().physics_frame
	_set_player_locked(false)


func _set_player_locked(locked: bool) -> void:
	if not is_inside_tree():
		return
	for player in get_tree().get_nodes_in_group(PLAYER_GROUP):
		player.set("controls_locked", locked)
