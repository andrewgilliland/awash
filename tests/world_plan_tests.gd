extends RefCounted

# The World's plan: the layout agreed for the Waking Coast, the Undertow and the Low Canopy Jungle,
# laid over today's World. Built Rooms that are to move carry where they go; Planned Rooms are all
# plan.

const World := preload("res://scripts/core/world.gd")
const BEACH := &"waking_coast_1"
const GRAVEYARD := &"waking_coast_4"
const SEA_CAVE := &"waking_coast_5"
const TIDEFEN := &"tidefen_village_1"
const UNDERTOW := &"undertow"
const JUNGLE := &"low_canopy_jungle"
const CAMP := &"shrinekeeper_camp"
const HARBOUR_TRAIL := &"low_canopy_jungle_1"
const JUNGLE_ROOMS := 7
const SIDES := {
	&"north": Vector2i.UP,
	&"east": Vector2i.RIGHT,
	&"south": Vector2i.DOWN,
	&"west": Vector2i.LEFT,
}
const OPPOSITE := {&"north": &"south", &"south": &"north", &"east": &"west", &"west": &"east"}


func get_tests() -> Array:
	return [
		["The plan lays out every Room, built and planned, none overlapping", _test_no_overlaps],
		[
			"Every planned Exit meets one back, but a Drop, which needs only a Room below",
			_test_exits_meet
		],
		["The plan climbs to the graveyard on the cliff tops, then down to Tidefen", _test_climb],
		["The planned Undertow lies beneath the coast, reached from Tidefen", _test_undertow],
		[
			"The planned jungle climbs east from Tidefen's harbour to the Shrinekeeper Camp",
			_test_jungle_climbs
		],
		["The jungle and its camp are reached only from Tidefen, for now", _test_jungle_way_in],
	]


static func _all_ids() -> Array[StringName]:
	return World.room_ids() + World.planned_ids()


# Which Room the plan puts on each screen of the World.
static func _screens() -> Dictionary:
	var owner := {}
	for room_id in _all_ids():
		var plan := World.planned(room_id)
		for y in range(plan.size.y):
			for x in range(plan.size.x):
				var at: Vector2i = plan.cell + Vector2i(x, y)
				if owner.has(at):
					push_error("%s and %s both plan %s" % [owner[at], room_id, at])
					return {}
				owner[at] = room_id
	return owner


func _test_no_overlaps() -> bool:
	var valid := not World.planned_ids().is_empty() and not _screens().is_empty()
	for room_id in _all_ids():
		valid = valid and World.has_region(World.planned(room_id).region)
	return valid


func _test_exits_meet() -> bool:
	var owner := _screens()
	var valid := not owner.is_empty()
	for room_id in _all_ids():
		var plan := World.planned(room_id)
		for exit: Dictionary in plan.exits:
			var beyond: Vector2i = plan.cell + exit.screen + SIDES[exit.side]
			var other: StringName = owner.get(beyond, &"")
			var met := false
			if not other.is_empty():
				var there := World.planned(other)
				var back := {screen = beyond - there.cell, side = OPPOSITE[exit.side]}
				# A Drop falls into the Room below, with no way back up.
				met = exit.side == &"south" or back in there.exits
			if not met:
				push_error("%s's %s Exit meets no Exit in %s" % [room_id, exit.side, other])
			valid = valid and met
	return valid


# Up and right from the beach, the graveyard after the cliff tops, then down to Tidefen.
func _test_climb() -> bool:
	var beach := World.planned(BEACH)
	var graveyard := World.planned(GRAVEYARD)
	var tidefen := World.planned(TIDEFEN)
	var valid: bool = graveyard.cell.y < beach.cell.y and tidefen.cell.y == beach.cell.y
	valid = valid and beach.cell.x < graveyard.cell.x and graveyard.cell.x < tidefen.cell.x
	return valid


# Below the beach, entered only by Tidefen's well and the sea cave's wall, which is the Undertow's
# Shortcut home.
func _test_undertow() -> bool:
	var owner := _screens()
	var valid := not owner.is_empty()
	var ways_in := {}
	for room_id in _all_ids():
		var plan := World.planned(room_id)
		if plan.region == UNDERTOW:
			valid = valid and plan.cell.y > World.planned(BEACH).cell.y
		for exit: Dictionary in plan.exits:
			var other: StringName = owner.get(plan.cell + exit.screen + SIDES[exit.side], &"")
			var crosses: bool = (
				(plan.region == UNDERTOW) != (World.planned(other).region == UNDERTOW)
			)
			if crosses:
				ways_in[other if plan.region == UNDERTOW else room_id] = true
	# Compared as a set: sorting ids would order them by where they sit in memory, not by name.
	return valid and ways_in.size() == 2 and ways_in.has(SEA_CAVE) and ways_in.has(TIDEFEN)


# Seven Rooms of jungle east of Tidefen, its harbour trail at sea level, climbing to the camp, the
# jungle's Safe spoke, on the canopy above.
func _test_jungle_climbs() -> bool:
	var tidefen := World.planned(TIDEFEN)
	var trail := World.planned(HARBOUR_TRAIL)
	var east_of_tidefen: int = tidefen.cell.x + tidefen.size.x
	var jungle := 0
	var camps: Array[StringName] = []
	var valid: bool = trail.region == JUNGLE and trail.cell == Vector2i(east_of_tidefen, 0)
	for room_id in _all_ids():
		var plan := World.planned(room_id)
		if plan.region == JUNGLE:
			jungle += 1
			valid = valid and plan.cell.x >= east_of_tidefen
		elif plan.region == CAMP:
			camps.append(room_id)
	valid = valid and jungle == JUNGLE_ROOMS and camps.size() == 1
	if valid:
		var camp := World.planned(camps[0])
		valid = camp.cell.y < trail.cell.y and camp.markers.has(&"rest")
	return valid


# Its only way in is off Tidefen's harbour; Smuggler Inlet beyond it is planned later.
func _test_jungle_way_in() -> bool:
	var owner := _screens()
	var valid := not owner.is_empty()
	var ways_in := {}
	for room_id in _all_ids():
		var plan := World.planned(room_id)
		var inside: bool = plan.region in [JUNGLE, CAMP]
		for exit: Dictionary in plan.exits:
			var other: StringName = owner.get(plan.cell + exit.screen + SIDES[exit.side], &"")
			if (World.planned(other).region in [JUNGLE, CAMP]) != inside:
				ways_in[room_id if not inside else other] = true
	return valid and ways_in.keys() == [TIDEFEN]
