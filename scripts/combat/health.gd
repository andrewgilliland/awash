extends RefCounted

# Read-only for callers: change them through hurt(), heal(), step() and raise_maximum().
var maximum: int
var current: int
var invulnerable_left: float = 0.0


# Starts full, or at a carried amount when one between 1 and the maximum is given.
func _init(starting_maximum: int, starting_current: int = -1) -> void:
	maximum = starting_maximum
	current = starting_maximum
	if starting_current > 0 and starting_current <= starting_maximum:
		current = starting_current


# Takes a hit unless invulnerable or already defeated; a hit that lands starts a new
# invulnerable spell. Returns whether the hit landed.
func hurt(amount: int, invulnerable_for: float) -> bool:
	if is_defeated() or invulnerable_left > 0.0:
		return false
	current = maxi(current - amount, 0)
	invulnerable_left = invulnerable_for
	return true


# Restores Health, up to the maximum. Defeated Health stays defeated.
func heal(amount: int) -> void:
	if amount <= 0 or is_defeated():
		return
	current = mini(current + amount, maximum)


# Raises the maximum, and what is left by as much: more room, not a refill. Defeated Health
# stays defeated.
func raise_maximum(by: int) -> void:
	if by <= 0:
		return
	maximum += by
	if not is_defeated():
		current += by


func step(delta: float) -> void:
	invulnerable_left = maxf(invulnerable_left - delta, 0.0)


func is_defeated() -> bool:
	return current == 0
