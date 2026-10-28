extends Node2D

# Mara Venn, the Tidefen salvager who finds Vael on the Waking Coast. She stands by the wreck;
# walking up to her and pressing Interact talks to her.

const SHEET := preload("res://assets/sprites/npcs/mara/mara_venn_1.png")
const FRAME_SIZE := Vector2i(16, 16)
const WALK_SPEED := 30.0
const DIALOGUE_GROUP := &"dialogue_box"
const PLAYER_GROUP := &"player"
# What she says when the Player talks to her again.
const REMINDER := [
	["MARA", "Tidefen is east, past the rune shore."],
	["MARA", "Mind the Scavengers in the shallows."],
]

var _player_near: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _zone: Area2D = $TalkZone


func _ready() -> void:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(&"walk"):
		_sprite.sprite_frames = _build_sprite_frames()
	_sprite.play(&"idle")
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_near or not event.is_action_pressed(&"interact") or event.is_echo():
		return
	var box := get_tree().get_first_node_in_group(DIALOGUE_GROUP)
	if box != null and not box.call("is_open"):
		box.call("show_lines", REMINDER)
		get_viewport().set_input_as_handled()


# Walks over to a Room x, then stands facing the way she walked.
func walk_to(x: float) -> void:
	var distance := x - position.x
	if is_zero_approx(distance):
		return
	_sprite.flip_h = distance > 0.0
	_sprite.play(&"walk")
	var walk := create_tween()
	walk.tween_property(self, ^"position:x", x, absf(distance) / WALK_SPEED)
	await walk.finished
	_sprite.play(&"idle")


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(PLAYER_GROUP):
		_player_near = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(PLAYER_GROUP):
		_player_near = false


# Her sheet holds a two-step walk; the first step doubles as standing still.
static func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for spec in [[&"idle", [0], 1.0], [&"walk", [0, 1], 6.0]]:
		frames.add_animation(spec[0])
		frames.set_animation_speed(spec[0], spec[2])
		frames.set_animation_loop(spec[0], true)
		for index in spec[1]:
			var frame := AtlasTexture.new()
			frame.atlas = SHEET
			frame.region = Rect2(Vector2(index * FRAME_SIZE.x, 0), Vector2(FRAME_SIZE))
			frames.add_frame(spec[0], frame)
	return frames
