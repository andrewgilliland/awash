extends Area2D

# What strikes: while active, it hits each hurtbox it overlaps. Hitboxes are never hit back,
# so one on the same layer as a hurtbox does not trigger it.

# It struck a hurtbox.
signal struck(hurtbox: Area2D)

# What one hit costs. Health counts in tens, so a hit is 10.
const DEFAULT_DAMAGE := 10

@export var damage: int = DEFAULT_DAMAGE

var active: bool = false:
	set(value):
		active = value
		set_deferred("monitoring", value)


func _init() -> void:
	monitoring = false
	monitorable = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if active and area.has_method("take_hit"):
		area.call("take_hit", self)
		struck.emit(area)
