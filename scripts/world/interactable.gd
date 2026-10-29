extends Area2D

# Something the Player can use with Interact: an NPC to talk to, and later a sign, a chest or a
# lever. It only reports being used; what that does belongs to whatever owns it. While the
# Player is in range and free to act, a prompt bobs above it.

signal interacted(by: Node)

const PROMPT := preload("res://assets/ui/interact_prompt.png")
const GROUP := &"interactable"
const PLAYER_GROUP := &"player"
const TRIGGER_LAYER := 1 << 7
const PLAYER_LAYER := 1 << 1
const PROMPT_BOB := 1.0
const PROMPT_BOB_SPEED := 4.0

# Where the prompt floats, from this Interactable's origin.
@export var prompt_offset: Vector2 = Vector2(0, -22)

var _player: Node2D
var _prompt: Sprite2D
var _time: float = 0.0


func _init() -> void:
	collision_layer = TRIGGER_LAYER
	collision_mask = PLAYER_LAYER
	monitorable = false
	add_to_group(GROUP)
	_prompt = Sprite2D.new()
	_prompt.name = "Prompt"
	_prompt.texture = PROMPT
	_prompt.visible = false
	add_child(_prompt)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# Whether the given Player is close enough to use this.
func reaches(player: Node) -> bool:
	return _player != null and _player == player


func use(by: Node) -> void:
	interacted.emit(by)


func _process(delta: float) -> void:
	_time += delta
	_prompt.visible = _player != null and not _player.get("controls_locked")
	var bob := roundf(sin(_time * PROMPT_BOB_SPEED) * PROMPT_BOB)
	_prompt.position = prompt_offset + Vector2(0, bob)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(PLAYER_GROUP):
		_player = body


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
