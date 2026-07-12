extends Area2D

signal projectile_hit(target: Node)

@export var speed: float = 420.0
@export var lifetime_seconds: float = 1.1
@export var damage: int = 1
@export var knockback: Vector2 = Vector2(95.0, -25.0)

var _direction: float = 1.0
var _time_left: float = 0.0
var _has_resolved_hit: bool = false


func _ready() -> void:
	_time_left = lifetime_seconds
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if _has_resolved_hit:
		return

	_time_left = maxf(0.0, _time_left - delta)
	if _time_left <= 0.0:
		queue_free()
		return

	global_position += Vector2(speed * _direction * delta, 0.0)


func initialize(direction_sign: float, source: Node = null) -> void:
	_direction = 1.0 if direction_sign >= 0.0 else -1.0
	set_meta("source", source)


func _on_body_entered(body: Node2D) -> void:
	_resolve_hit(body)


func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return

	if area.get_parent() != null:
		_resolve_hit(area.get_parent())


func _resolve_hit(target: Node) -> void:
	if _has_resolved_hit:
		return

	if target == null:
		return

	var source: Variant = get_meta("source", null)
	if target == source:
		return

	_has_resolved_hit = true

	if target.has_method("take_damage"):
		var hit_knockback := Vector2(knockback.x * _direction, knockback.y)
		target.call("take_damage", damage, hit_knockback)

	emit_signal("projectile_hit", target)
	queue_free()
