extends RefCounted

# The pickup each Supply, Sub Weapon, Weapon or Armor lies as in a Room, left where an enemy fell or
# spilled from a Cache.

const SCENES := {
	&"meat_pie": preload("res://scenes/items/meat_pie.tscn"),
	&"brinecap": preload("res://scenes/items/brinecap.tscn"),
	&"glowroe": preload("res://scenes/items/glowroe.tscn"),
	&"mourning_salt": preload("res://scenes/items/mourning_salt.tscn"),
	&"bomb": preload("res://scenes/items/bomb_pickup.tscn"),
	&"oathblade": preload("res://scenes/items/oathblade.tscn"),
	&"scale_mail": preload("res://scenes/items/scale_mail.tscn"),
	&"stout_axe": preload("res://scenes/items/stout_axe.tscn"),
}


# The pickup a kind lies as, or null for one with none.
static func scene(kind: StringName) -> PackedScene:
	return SCENES.get(kind)
