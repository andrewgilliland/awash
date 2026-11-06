extends Node2D

# A Villager: someone who stands in a Room, idling, and talks when Interact uses them. Each one
# placed is set up with its own speaker, lines and sheet. It turns to face whoever talks to it.

const FRAME_SIZE := Vector2i(16, 16)
const IDLE_FPS := 2.0
const DIALOGUE_GROUP := &"dialogue_box"

# The name the Dialogue box shows, such as the trade they keep.
@export var speaker: String
# What they say, a line at a time, every time they are talked to.
@export var lines: PackedStringArray
# Two frames side by side, facing west: standing, and breathing.
@export var sheet: Texture2D

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _interactable: Area2D = $Interactable


func _ready() -> void:
	if sheet != null:
		_sprite.sprite_frames = _build_sprite_frames(sheet)
		_sprite.play(&"idle")
	_interactable.connect(&"interacted", _on_interacted)


# Their lines as the Dialogue box takes them: [speaker, text] pairs.
func conversation() -> Array:
	var pairs := []
	for line in lines:
		pairs.append([speaker, line])
	return pairs


func _on_interacted(by: Node) -> void:
	if by is Node2D:
		var dx := (by as Node2D).global_position.x - global_position.x
		if not is_zero_approx(dx):
			_sprite.flip_h = dx > 0.0
	var box := get_tree().get_first_node_in_group(DIALOGUE_GROUP)
	if box != null and not box.call("is_open"):
		box.call("show_lines", conversation())


static func _build_sprite_frames(texture: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", IDLE_FPS)
	frames.set_animation_loop(&"idle", true)
	for index in 2:
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(Vector2(index * FRAME_SIZE.x, 0), Vector2(FRAME_SIZE))
		frames.add_frame(&"idle", frame)
	return frames
