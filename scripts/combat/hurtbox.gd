extends Area2D

# Where a body can be struck; its owner decides what a hit does.
signal hit(hitbox: Area2D)


func _init() -> void:
	monitoring = false
	monitorable = true


func take_hit(hitbox: Area2D) -> void:
	hit.emit(hitbox)
