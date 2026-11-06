extends Control

# The held Sub Weapon on screen, under the Health bar: its icon and how many the Player carries.
# It hides when the Room has no Player, or the Player holds no Sub Weapon.

const SubWeapons := preload("res://scripts/items/sub_weapons.gd")
const PLAYER_GROUP := &"player"

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count


func _process(_delta: float) -> void:
	var sub_weapons := _sub_weapons()
	visible = sub_weapons != null and not sub_weapons.held.is_empty()
	if not visible:
		return
	var held: StringName = sub_weapons.held
	var icon_path: String = SubWeapons.KINDS[held].icon
	if _icon.texture == null or _icon.texture.resource_path != icon_path:
		_icon.texture = load(icon_path)
	_count.text = str(sub_weapons.count(held))


# The Sub Weapons the count shows, or null to hide it: the Player's.
func _sub_weapons() -> Object:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) if is_inside_tree() else null
	return player.get("sub_weapons") if player != null else null
