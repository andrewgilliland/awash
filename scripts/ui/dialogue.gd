extends RefCounted

# One conversation: its lines, each typed out a character at a time.
const CHARACTERS_PER_SECOND := 40.0

# [speaker, text] pairs, in order.
var _lines: Array
var _index: int = 0
var _revealed: float = 0.0


func _init(lines: Array) -> void:
	_lines = lines


func step(delta: float) -> void:
	if finished():
		return
	_revealed = minf(_revealed + delta * CHARACTERS_PER_SECOND, _text().length())


# Shows the rest of a line still typing out; on a shown line, moves to the next.
func advance() -> void:
	if finished():
		return
	if not line_shown():
		_revealed = _text().length()
		return
	_index += 1
	_revealed = 0.0


func line_shown() -> bool:
	return finished() or int(_revealed) >= _text().length()


func finished() -> bool:
	return _index >= _lines.size()


func speaker() -> String:
	return "" if finished() else _lines[_index][0]


func visible_text() -> String:
	return "" if finished() else _text().left(int(_revealed))


func _text() -> String:
	return _lines[_index][1]
