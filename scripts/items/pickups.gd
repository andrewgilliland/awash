extends RefCounted

# The pickup each Supply, Sub Weapon or Weapon lies as in a Room, left where an enemy fell or
# spilled from a Cache.

const SCENES := {
	&"meat_pie": preload("res://scenes/items/meat_pie.tscn"),
	&"brinecap": preload("res://scenes/items/brinecap.tscn"),
	&"glowroe": preload("res://scenes/items/glowroe.tscn"),
	&"mourning_salt": preload("res://scenes/items/mourning_salt.tscn"),
	&"bomb": preload("res://scenes/items/bomb_pickup.tscn"),
	&"oathblade": preload("res://scenes/items/oathblade.tscn"),
}


# The pickup a kind lies as, or null for one with none.
static func scene(kind: StringName) -> PackedScene:
	return SCENES.get(kind)
