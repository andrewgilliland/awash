extends Label

# LEVEL UP over the Player when it reaches a Level, with what the Level raised beneath it: it
# rises and fades away without pausing play, and sits inside the screen edges so it is never cut
# off.

const RISE := 10.0
const TIME := 1.0
# The gap it keeps from the screen edges, in pixels.
const EDGE := 1.0

var _start: Vector2
var _tween: Tween

@onready var _gains: Label = get_node_or_null("Gains")


func _ready() -> void:
	_start = position
	hide()


# Shows it again from the start, even if the last one has not faded yet, with how much maximum
# Health and Strength the Level raised.
func flash(health_gain: int = 0, strength_gain: int = 0) -> void:
	if _tween != null:
		_tween.kill()
	if _gains != null:
		var parts: Array[String] = []
		if health_gain > 0:
			parts.append("HP +%d" % health_gain)
		if strength_gain > 0:
			parts.append("STR +%d" % strength_gain)
		_gains.text = "  ".join(parts)
	position = _start
	var left := get_global_transform_with_canvas().origin.x
	var screen_width := get_viewport_rect().size.x
	position.x += clampf(left, EDGE, screen_width - size.x - EDGE) - left
	modulate.a = 1.0
	show()
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "position:y", _start.y - RISE, TIME)
	_tween.tween_property(self, "modulate:a", 0.0, TIME)
	_tween.chain().tween_callback(hide)
