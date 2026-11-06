extends RefCounted

# The Supplies the Player carries in a Run: how many of each kind, up to the carry limit.

const MEAT_PIE := &"meat_pie"
const BRINECAP := &"brinecap"
const GLOWROE := &"glowroe"
const MOURNING_SALT := &"mourning_salt"
# Every kind of Supply, in the order the Inventory lists them: its name, a description of two
# lines at most, and the Health it restores, either a set amount or a share of max Health.
const KINDS := {
	MEAT_PIE:
	{
		name = "Meat Pie",
		description = "A fisher's meat pie from Tidefen, still warm. Restores 20 Health.",
		restores = 20,
	},
	BRINECAP:
	{
		name = "Brinecap",
		description = "A salt-crusted cave mushroom. Restores 10 Health.",
		restores = 10,
	},
	GLOWROE:
	{
		name = "Glowroe",
		description = "Faintly glowing roe from an Undertow pool. Restores 20 Health.",
		restores = 20,
	},
	MOURNING_SALT:
	{
		name = "Mourning Salt",
		description = "Salt wept from a Wraith's robes. Restores half your Health.",
		restores_share = 0.5,
	},
}
# The most of any one kind the Player can carry.
const CARRY_LIMIT := 9

var _counts: Dictionary = {}


# The Health one of a kind restores for a Player whose max Health is the given amount; a share
# rounds down.
static func restores(kind: StringName, max_health: int) -> int:
	var supply: Dictionary = KINDS.get(kind, {})
	if supply.has("restores_share"):
		return floori(max_health * supply.restores_share)
	return supply.get("restores", 0)


# Starts from counts the Run carried; unknown kinds are dropped and counts held to the limit.
func _init(counts: Dictionary = {}) -> void:
	for kind in counts:
		if KINDS.has(kind):
			_counts[kind] = clampi(counts[kind], 0, CARRY_LIMIT)


# Carries one more, and returns whether there was room.
func add(kind: StringName) -> bool:
	if not KINDS.has(kind) or count(kind) >= CARRY_LIMIT:
		return false
	_counts[kind] = count(kind) + 1
	return true


# Carries one fewer, and returns whether there was one to spend.
func spend(kind: StringName) -> bool:
	if count(kind) <= 0:
		return false
	_counts[kind] = count(kind) - 1
	return true


func count(kind: StringName) -> int:
	return _counts.get(kind, 0)


# The kinds carried, in KINDS order.
func kinds() -> Array[StringName]:
	var carried: Array[StringName] = []
	for kind: StringName in KINDS:
		if count(kind) > 0:
			carried.append(kind)
	return carried


# The counts for the Run to carry: every kind carried, and how many.
func to_counts() -> Dictionary:
	var counts := {}
	for kind in kinds():
		counts[kind] = count(kind)
	return counts
