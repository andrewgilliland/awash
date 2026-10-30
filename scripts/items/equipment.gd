extends RefCounted

# The Equipment the Player has in a Run, one piece per slot: the Weapon held, which is never
# empty, and the Armor worn, if any, whose Defense takes Health off each hit that lands.

const STARTING_WEAPON := &"short_sword"
# Every Weapon: its name and its 8x8 icon. None adds to a hit yet.
const WEAPONS := {
	STARTING_WEAPON:
	{
		name = "Short Sword",
		icon = "res://assets/sprites/items/short_sword.png",
	},
}
const STARTING_ARMOR := &"worn_leather_tunic"
# Every Armor: its name, its Defense (the Health it takes off each hit), and its 8x8 icon.
const ARMOR := {
	STARTING_ARMOR:
	{
		name = "Worn Leather Tunic",
		defense = 0,
		icon = "res://assets/sprites/items/worn_leather_tunic.png",
	},
}
# What the Armor slot reads with nothing worn.
const NO_ARMOR := "None"
# The least Defense can bring a hit down to; a hit weaker than this costs what it is.
const MIN_HIT := 5

# Read-only for callers. The Weapon held and every Weapon owned; only the Short Sword so far.
var weapon: StringName = STARTING_WEAPON
var owned_weapons: Array[StringName] = [STARTING_WEAPON]
# Read-only for callers: change them through wear() and take_off(). The Armor worn, or &"" for
# none, and every Armor owned, in the order found.
var armor: StringName = STARTING_ARMOR
var owned: Array[StringName] = [STARTING_ARMOR]


# Starts from what the Run carried. Unknown Armor is dropped, and whatever is worn is owned.
func _init(armor_id: StringName = STARTING_ARMOR, owned_ids: Array = [STARTING_ARMOR]) -> void:
	owned = []
	for id: StringName in owned_ids:
		if ARMOR.has(id) and not owned.has(id):
			owned.append(id)
	armor = armor_id if ARMOR.has(armor_id) else &""
	if not armor.is_empty() and not owned.has(armor):
		owned.append(armor)


# Puts on Armor the Player owns, and returns whether it could.
func wear(armor_id: StringName) -> bool:
	if not owned.has(armor_id):
		return false
	armor = armor_id
	return true


func take_off() -> void:
	armor = &""


func weapon_name() -> String:
	return WEAPONS[weapon].name


func armor_name() -> String:
	return ARMOR[armor].name if not armor.is_empty() else NO_ARMOR


func defense() -> int:
	return defense_with(armor)


# The Defense there would be with the given Armor worn, or none (&"").
func defense_with(armor_id: StringName) -> int:
	return ARMOR[armor_id].defense if not armor_id.is_empty() else 0


# What a hit of the given strength costs the Player in this Equipment.
func hit_cost(damage: int) -> int:
	return cost_after_defense(damage, defense())


static func cost_after_defense(damage: int, defense_value: int) -> int:
	return maxi(damage - defense_value, mini(damage, MIN_HIT))
