extends Control

# The last line was read and the box closed.
signal closed
# A line carrying a cue just opened.
signal cued(cue: StringName)

const Dialogue := preload("res://scripts/ui/dialogue.gd")
const PLAYER_GROUP := &"player"
# Any of these finishes the line typing out, or moves to the next.
const ADVANCE_ACTIONS: Array[StringName] = [&"ui_accept", &"jump", &"interact"]
const NEXT_BLINK := 0.4
# The panel's top edge at the foot of the screen, and at the top when that would hide a talker.
const BOTTOM_Y := 98.0
const TOP_Y := 4.0
# How tall someone stands above their feet, on screen.
const TALKER_HEIGHT := 20.0

# Read-only for callers: the conversation being shown, or null.
var dialogue: Dialogue
var _blink_time: float = 0.0

@onready var _panel: Control = $Panel
@onready var _speaker: Label = %Speaker
@onready var _text: Label = %Text
@onready var _next: Label = %Next


func _ready() -> void:
	visible = false


# Opens on the first of [speaker, text] lines and holds the Player still until it closes. The
# one speaking, when given, is kept in view along with the Player.
func show_lines(lines: Array, speaker: Node2D = null) -> void:
	dialogue = Dialogue.new(lines)
	_set_player_locked(true)
	_place(speaker)
	visible = true
	_refresh()
	_call_out_cue()


func is_open() -> bool:
	return visible


func advance() -> void:
	if dialogue == null:
		return
	var to_next_line := dialogue.line_shown()
	dialogue.advance()
	if dialogue.finished():
		_close()
		return
	_refresh()
	if to_next_line:
		_call_out_cue()


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


# Sits at the foot of the screen unless that would cover someone talking and the top would not.
func _place(speaker: Node2D) -> void:
	var feet := _talkers_feet(speaker)
	var to_top := _covers(BOTTOM_Y, feet) and not _covers(TOP_Y, feet)
	var y := TOP_Y if to_top else BOTTOM_Y
	var shift := y - _panel.position.y
	_panel.position.y += shift
	_next.position.y += shift


func _covers(panel_y: float, feet: Array[float]) -> bool:
	var bottom := panel_y + _panel.size.y
	for feet_y in feet:
		if feet_y > panel_y and feet_y - TALKER_HEIGHT < bottom:
			return true
	return false


# Where each talker's feet are on screen.
func _talkers_feet(speaker: Node2D) -> Array[float]:
	var feet: Array[float] = []
	if speaker != null and speaker.is_inside_tree():
		feet.append(speaker.get_global_transform_with_canvas().origin.y)
	if not is_inside_tree():
		return feet
	for player in get_tree().get_nodes_in_group(PLAYER_GROUP):
		if player is Node2D:
			feet.append((player as Node2D).get_global_transform_with_canvas().origin.y)
	return feet


func _call_out_cue() -> void:
	var cue := dialogue.cue()
	if cue != &"":
		cued.emit(cue)


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
