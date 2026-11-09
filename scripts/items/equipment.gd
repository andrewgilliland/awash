extends RefCounted

# The Equipment the Player has in a Run, one piece per slot: the Weapon held, which is never
# empty, and the Armor worn, if any, whose Defense takes Health off each hit that lands.

const STARTING_WEAPON := &"short_sword"
const OATHBLADE := &"oathblade"
const STOUT_AXE := &"stout_axe"
# Every Weapon: its name, a description of two lines at most, its Attack (added to each hit it
# lands), its 8x8 icon, and the sheet it is drawn from in the Player's hand. One that chops breaks
# a cracked wall with a quick slash, and one with a charged scene looses it from a Charged Attack
# in place of a Sword Beam.
const WEAPONS := {
	STARTING_WEAPON:
	{
		name = "Short Sword",
		description = "A plain blade Mara pulled from the sand.",
		attack = 0,
		icon = "res://assets/items/short_sword.png",
		sheet = "res://assets/player/sword_1.png",
	},
	OATHBLADE:
	{
		name = "Oathblade",
		description = "A ceremonial blade a Wraith swore by. Attack 5.",
		attack = 5,
		icon = "res://assets/items/oathblade.png",
		sheet = "res://assets/player/oathblade.png",
	},
	STOUT_AXE:
	{
		name = "Stout Axe",
		description = "A shipwright's axe. Attack 6. Its slashes chop cracked walls.",
		attack = 6,
		icon = "res://assets/items/stout_axe.png",
		sheet = "res://assets/player/stout_axe.png",
		chops = true,
		charged_scene = "res://scenes/player/axe_throw.tscn",
	},
}
const STARTING_ARMOR := &"worn_leather_tunic"
const SCALE_MAIL := &"scale_mail"
# Every Armor: its name, a description of two lines at most, its Defense (the Health it takes
# off each hit), and its 8x8 icon.
const ARMOR := {
	STARTING_ARMOR:
	{
		name = "Worn Leather Tunic",
		description = "Faded by salt. Light, but gives no Defense.",
		defense = 0,
		icon = "res://assets/items/worn_leather_tunic.png",
	},
	SCALE_MAIL:
	{
		name = "Scale Mail",
		description = "A drowned warden's scale mail, green with rust. Defense 3.",
		defense = 3,
		icon = "res://assets/items/scale_mail.png",
	},
}
# What the Armor slot reads with nothing worn.
const NO_ARMOR := "None"
# The least Defense can bring a hit down to; a hit weaker than this costs what it is.
const MIN_HIT := 5

# Read-only for callers: change them through own_weapon() and hold(). The Weapon held, and every
# Weapon owned, in the order found.
var weapon: StringName = STARTING_WEAPON
var owned_weapons: Array[StringName] = [STARTING_WEAPON]
# Read-only for callers: change them through wear() and take_off(). The Armor worn, or &"" for
# none, and every Armor owned, in the order found.
var armor: StringName = STARTING_ARMOR
var owned: Array[StringName] = [STARTING_ARMOR]


# Starts from what the Run carried. Unknown Armor and Weapons are dropped, whatever is worn or
# held is owned, and a hand left without a known Weapon holds the Short Sword.
func _init(
	armor_id: StringName = STARTING_ARMOR,
	owned_ids: Array = [STARTING_ARMOR],
	weapon_id: StringName = STARTING_WEAPON,
	owned_weapon_ids: Array = [STARTING_WEAPON],
) -> void:
	owned = []
	for id: StringName in owned_ids:
		if ARMOR.has(id) and not owned.has(id):
			owned.append(id)
	armor = armor_id if ARMOR.has(armor_id) else &""
	if not armor.is_empty() and not owned.has(armor):
		owned.append(armor)
	owned_weapons = []
	for id: StringName in owned_weapon_ids:
		own_weapon(id)
	weapon = weapon_id if WEAPONS.has(weapon_id) else STARTING_WEAPON
	own_weapon(weapon)


# Owns a known Weapon not owned yet, and returns whether it did.
func own_weapon(weapon_id: StringName) -> bool:
	if not WEAPONS.has(weapon_id) or owns_weapon(weapon_id):
		return false
	owned_weapons.append(weapon_id)
	return true


func owns_weapon(weapon_id: StringName) -> bool:
	return owned_weapons.has(weapon_id)


# Takes up a Weapon the Player owns, and returns whether it could.
func hold(weapon_id: StringName) -> bool:
	if not owns_weapon(weapon_id):
		return false
	weapon = weapon_id
	return true


# Owns a known Armor not owned yet, without putting it on, and returns whether it did.
func own_armor(armor_id: StringName) -> bool:
	if not ARMOR.has(armor_id) or owns_armor(armor_id):
		return false
	owned.append(armor_id)
	return true


func owns_armor(armor_id: StringName) -> bool:
	return owned.has(armor_id)


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


# What the Weapon held adds to each hit it lands.
func attack() -> int:
	return attack_with(weapon)


func attack_with(weapon_id: StringName) -> int:
	return WEAPONS[weapon_id].attack


# Whether the Weapon held breaks a cracked wall with a quick slash.
func chops() -> bool:
	return WEAPONS[weapon].get("chops", false)


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
