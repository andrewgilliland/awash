extends RefCounted

# Read-only for callers: change them through hurt() and step().
var maximum: int
var current: int
var invulnerable_left: float = 0.0


func _init(starting_maximum: int) -> void:
	maximum = starting_maximum
	current = starting_maximum


# Takes a hit unless invulnerable or already defeated; a hit that lands starts a new
# invulnerable spell. Returns whether the hit landed.
func hurt(amount: int, invulnerable_for: float) -> bool:
	if is_defeated() or invulnerable_left > 0.0:
		return false
	current = maxi(current - amount, 0)
	invulnerable_left = invulnerable_for
	return true


func step(delta: float) -> void:
	invulnerable_left = maxf(invulnerable_left - delta, 0.0)


func is_defeated() -> bool:
	return current == 0
