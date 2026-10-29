extends RefCounted

const Level := preload("res://scripts/player/level.gd")


func get_tests() -> Array:
	return [
		["Level table starts at nothing and rises in tens", _test_table_rises_in_tens],
		["A new Run starts at Level 1", _test_starts_at_level_one],
		["Each Level gives its row's stats", _test_each_level_gives_its_row],
		["A Level is reached exactly at its threshold", _test_reached_at_threshold],
		["One gain can raise more than one Level", _test_gain_raises_many_levels],
		["Experience stops raising Levels at the highest", _test_stops_at_highest_level],
		["Experience to the next Level counts down", _test_experience_to_next_counts_down],
		["Level can start from a carried total", _test_starts_from_carried_total],
		["Only a positive gain counts", _test_only_positive_gain_counts],
	]


# Every row needs more Experience than the last, and Health and Strength stay in tens.
func _test_table_rises_in_tens() -> bool:
	var valid := Level.LEVELS.size() >= 2 and Level.LEVELS[0].experience == 0
	for index in Level.LEVELS.size():
		var row: Dictionary = Level.LEVELS[index]
		valid = valid and row.max_health % 10 == 0 and row.strength % 10 == 0
		if index > 0:
			var previous: Dictionary = Level.LEVELS[index - 1]
			valid = valid and row.experience > previous.experience
			valid = valid and row.max_health >= previous.max_health
			valid = valid and row.strength >= previous.strength
	return valid


func _test_starts_at_level_one() -> bool:
	var level := Level.new()
	return (
		level.level == 1
		and level.experience == 0
		and level.max_health() == 50
		and level.strength() == 0
	)


func _test_each_level_gives_its_row() -> bool:
	var valid := true
	for index in Level.LEVELS.size():
		var row: Dictionary = Level.LEVELS[index]
		var level := Level.new(row.experience)
		valid = valid and level.level == index + 1
		valid = valid and level.max_health() == row.max_health
		valid = valid and level.strength() == row.strength
	return valid


func _test_reached_at_threshold() -> bool:
	var level := Level.new()
	var short := level.gain(Level.LEVELS[1].experience - 1)
	var valid := short == 0 and level.level == 1
	var reached := level.gain(1)
	return valid and reached == 1 and level.level == 2


func _test_gain_raises_many_levels() -> bool:
	var level := Level.new()
	var gained := level.gain(Level.LEVELS[2].experience)
	return gained == 2 and level.level == 3


func _test_stops_at_highest_level() -> bool:
	var level := Level.new()
	var highest: int = Level.LEVELS.size()
	var gained := level.gain(Level.LEVELS[-1].experience + 1000)
	var valid := gained == highest - 1 and level.level == highest
	valid = valid and level.experience_to_next() == Level.AT_HIGHEST
	# Experience keeps counting there, though it raises nothing.
	valid = valid and level.gain(10) == 0 and level.level == highest
	return valid and level.experience == Level.LEVELS[-1].experience + 1010


func _test_experience_to_next_counts_down() -> bool:
	var level := Level.new()
	var needed: int = Level.LEVELS[1].experience
	var valid := level.experience_to_next() == needed
	level.gain(15)
	return valid and level.experience_to_next() == needed - 15


func _test_starts_from_carried_total() -> bool:
	var carried: int = Level.LEVELS[3].experience + 5
	var level := Level.new(carried)
	return level.level == 4 and level.experience == carried


func _test_only_positive_gain_counts() -> bool:
	var level := Level.new(20)
	var gained := level.gain(0) + level.gain(-30)
	return gained == 0 and level.experience == 20 and level.level == 1
