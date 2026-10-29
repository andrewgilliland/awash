extends RefCounted

const Dialogue := preload("res://scripts/ui/dialogue.gd")
const LINES := [["MARA", "You're breathing."], ["???", "Where am I?"]]


func get_tests() -> Array:
	return [
		["Dialogue types a line out over time", _test_types_line_out],
		["Advancing mid-line shows the whole line", _test_advance_mid_line],
		["Advancing a shown line moves to the next", _test_advance_to_next],
		["Dialogue finishes after its last line", _test_finishes],
		["A line can carry a cue for the scene", _test_cue],
	]


func _test_types_line_out() -> bool:
	var dialogue := Dialogue.new(LINES)
	var valid := dialogue.speaker() == "MARA" and dialogue.visible_text() == ""
	dialogue.step(4.0 / Dialogue.CHARACTERS_PER_SECOND)
	valid = valid and dialogue.visible_text() == "You'" and not dialogue.line_shown()
	dialogue.step(10.0)
	return valid and dialogue.visible_text() == "You're breathing." and dialogue.line_shown()


func _test_advance_mid_line() -> bool:
	var dialogue := Dialogue.new(LINES)
	dialogue.step(0.05)
	dialogue.advance()
	return dialogue.visible_text() == "You're breathing." and dialogue.speaker() == "MARA"


func _test_advance_to_next() -> bool:
	var dialogue := Dialogue.new(LINES)
	dialogue.advance()
	dialogue.advance()
	var valid := dialogue.speaker() == "???" and dialogue.visible_text() == ""
	return valid and not dialogue.finished()


func _test_finishes() -> bool:
	var dialogue := Dialogue.new(LINES)
	for i in 4:
		dialogue.advance()
	return dialogue.finished()


func _test_cue() -> bool:
	var dialogue := Dialogue.new([["MARA", "Here."], ["MARA", "It's yours.", &"hand_over"]])
	var valid := dialogue.cue() == &""
	dialogue.advance()
	dialogue.advance()
	valid = valid and dialogue.cue() == &"hand_over"
	dialogue.advance()
	dialogue.advance()
	return valid and dialogue.cue() == &""
