extends RefCounted

# The Equipment the Player has in a Run, one piece per slot. For now that is the Armor slot,
# never empty, whose Defense takes Health off each hit that lands.

const STARTING_ARMOR := &"worn_leather_tunic"
# Every Armor: its name, and its Defense, the Health it takes off each hit.
const ARMOR := {
	STARTING_ARMOR: {name = "Worn Leather Tunic", defense = 0},
}
# The least Defense can bring a hit down to; a hit weaker than this costs what it is.
const MIN_HIT := 5

# Read-only for callers: what the Player wears.
var armor: StringName = STARTING_ARMOR


# Starts in the Armor the Run carried; an unknown one is the Worn Leather Tunic.
func _init(armor_id: StringName = STARTING_ARMOR) -> void:
	armor = armor_id if ARMOR.has(armor_id) else STARTING_ARMOR


func armor_name() -> String:
	return ARMOR[armor].name


func defense() -> int:
	return ARMOR[armor].defense


# What a hit of the given strength costs the Player in this Equipment.
func hit_cost(damage: int) -> int:
	return cost_after_defense(damage, defense())


static func cost_after_defense(damage: int, defense_value: int) -> int:
	return maxi(damage - defense_value, mini(damage, MIN_HIT))
