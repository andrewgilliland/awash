---
name: Kestrel Blade
id: kestrel_blade
type: weapon
category: Equipment
item_type: Weapons
planned: true
legendary: false
weapon_class: Curved sword
region: High Canopy
description: A light curved blade from the canopy's hunters, balanced to strike at what flies past the platforms.
acquisition: Found in a Cache in a Hunter's blind high in the canopy, down a Branch.
trait: A hit on a flying enemy takes 50% more of its Health.
needs: Flying enemies told apart from those that walk, swim or burrow.
ranged_attack: false
forms:
  - name: Kestrel Blade
    attack: 14
    icon: res://assets/items/kestrel_blade.png
    in_game: "A canopy hunter's light blade. Attack 14. Hits on flying foes take 50% more Health."
    visual: A slim swept blade of pale steel with a falcon-feather wrap on the grip (`assets/items/kestrel_blade.aseprite`).
---

Found Weapon of the High Canopy: Attack 14, and its Weapon trait, a hit on a flying enemy takes 50% more of its Health. Like every Weapon, it is found as it is and never upgraded. Each Region's find gives a little more Attack than the last, and its trait is what keeps an older one worth holding. It swings like every Weapon, with the same reach and timing, and it has its own held sprite and Sword Beam. An enemy counts as flying when its doc's `movement` is Flying, not Floating.
