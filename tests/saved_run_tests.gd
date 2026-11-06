extends RefCounted

# The Saved Run: the Run as last written to disk, which CONTINUE picks up. Every part of the Run
# but the intro goes into it, as JSON, and comes back out the same.

const RunStateScript := preload("res://scripts/core/run_state.gd")
# Where these tests keep their Saved Run, clear of the player's own.
const TEST_PATH := "user://test_saved_run.json"


func get_tests() -> Array:
	return [
		["A Run written out and read back is the same Run", _test_round_trip],
		["A Saved Run of another version, missing a part, or lost Room is refused", _test_refuses],
		["Saving writes the Run to disk, and CONTINUE reads it back", _test_file],
		["A Run saved as the Player falls wakes where a defeat would", _test_saved_defeated],
		["A Saved Run that can't be read is no Saved Run, and is left alone", _test_unreadable],
	]


func _test_round_trip() -> bool:
	var run := _played_run()
	var data: Dictionary = JSON.parse_string(JSON.stringify(run.to_saved()))
	var restored := RunStateScript.new()
	var valid: bool = restored.restore(data)
	valid = valid and _same(run, restored)
	run.free()
	restored.free()
	return valid


func _test_refuses() -> bool:
	var good := _played_run()
	var newer: Dictionary = good.to_saved()
	newer.version = RunStateScript.SAVE_VERSION + 1
	var missing: Dictionary = good.to_saved()
	missing.erase("gold")
	var mistyped: Dictionary = good.to_saved()
	mistyped.visited_rooms = "tidefen_village_1"
	var misnamed: Dictionary = good.to_saved()
	misnamed.taken_caches = [3]
	var lost: Dictionary = good.to_saved()
	lost.room = "a_room_no_longer_in_the_world"
	var miscounted: Dictionary = good.to_saved()
	miscounted.supplies = {"brinecap": "two"}
	var run := RunStateScript.new()
	var valid := true
	for saved in [newer, missing, mistyped, misnamed, lost, miscounted, {}]:
		valid = valid and not run.restore(saved)
		valid = valid and run.room_id == RunStateScript.FIRST_ROOM_ID and run.player_gold == 0
	good.free()
	run.free()
	return valid


func _test_file() -> bool:
	DirAccess.remove_absolute(TEST_PATH)
	var run := _played_run()
	run.save_path = TEST_PATH
	var valid: bool = not run.has_saved_run() and run.save() and run.has_saved_run()
	valid = valid and not FileAccess.file_exists(TEST_PATH + ".tmp")
	var resumed := RunStateScript.new()
	resumed.save_path = TEST_PATH
	valid = valid and resumed.continue_saved_run() and _same(run, resumed)
	DirAccess.remove_absolute(TEST_PATH)
	valid = valid and not resumed.continue_saved_run()
	run.free()
	resumed.free()
	return valid


func _test_saved_defeated() -> bool:
	var run := _played_run()
	run.enter_room(&"undertow_1", &"west")
	run.player_health = 0
	var saved: Dictionary = run.to_saved()
	var valid: bool = saved.room == &"tidefen_village_1" and saved.entry == &"bell"
	valid = valid and saved.health == RunStateScript.FULL_HEALTH
	valid = valid and run.room_id == &"undertow_1" and run.player_health == 0
	var unrested := RunStateScript.new()
	unrested.player_health = 0
	unrested.enter_room(&"waking_coast_3", &"west")
	saved = unrested.to_saved()
	valid = valid and saved.room == RunStateScript.FIRST_ROOM_ID
	valid = valid and saved.entry == RunStateScript.DEFAULT_ENTRY_ID
	run.free()
	unrested.free()
	return valid


func _test_unreadable() -> bool:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	var run := RunStateScript.new()
	run.save_path = TEST_PATH
	var valid: bool = not run.has_saved_run() and not run.continue_saved_run()
	valid = valid and FileAccess.file_exists(TEST_PATH)
	DirAccess.remove_absolute(TEST_PATH)
	run.free()
	return valid


# A Run some way in: past the Warden, rested at the bell, carrying a little of everything.
static func _played_run() -> Node:
	var run := RunStateScript.new()
	run.enter_room(&"tidefen_village_1", &"west")
	run.player_health = 37
	run.player_experience = 120
	run.player_supplies = {&"brinecap": 2, &"meat_pie": 1}
	run.player_armor = &""
	run.player_owned_armor = [&"worn_leather_tunic"]
	run.player_weapon = &"oathblade"
	run.player_owned_weapons = [&"short_sword", &"oathblade"]
	run.player_sub_weapon = &"bomb"
	run.player_owned_sub_weapons = [&"bomb"]
	run.player_sub_weapon_counts = {&"bomb": 4}
	run.player_gold = 23
	run.rest_at(&"tidefen_village_1", &"bell")
	run.defeat_boss(&"nameless_warden")
	run.open_shortcut(&"sea_cave_wall")
	run.break_wall(&"sea_cave_rock")
	run.take_cache(&"wreck_cache")
	return run


static func _same(a: Node, b: Node) -> bool:
	var same: bool = a.room_id == b.room_id and a.entry_id == b.entry_id
	same = same and a.player_health == b.player_health
	same = same and a.player_experience == b.player_experience
	same = same and a.player_supplies == b.player_supplies
	same = same and a.player_armor == b.player_armor
	same = same and a.player_owned_armor == b.player_owned_armor
	same = same and a.player_weapon == b.player_weapon
	same = same and a.player_owned_weapons == b.player_owned_weapons
	same = same and a.player_sub_weapon == b.player_sub_weapon
	same = same and a.player_owned_sub_weapons == b.player_owned_sub_weapons
	same = same and a.player_sub_weapon_counts == b.player_sub_weapon_counts
	same = same and a.player_gold == b.player_gold
	same = same and a.rest_room_id == b.rest_room_id and a.rest_entry_id == b.rest_entry_id
	for id in [&"waking_coast_1", &"tidefen_village_1", &"undertow_1"]:
		same = same and a.has_visited_room(id) == b.has_visited_room(id)
	same = same and b.has_defeated_boss(&"nameless_warden")
	same = same and b.has_opened_shortcut(&"sea_cave_wall")
	same = same and b.has_broken_wall(&"sea_cave_rock")
	return same and b.has_taken_cache(&"wreck_cache") and not b.has_taken_cache(&"other")
