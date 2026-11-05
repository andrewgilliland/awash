extends RefCounted

# How far the Player has grown in a Run: its Level, read from the Run's total Experience against
# the declared table below.

# experience_to_next() at the highest Level.
const AT_HIGHEST := -1
# One row per Level, from Level 1: the total Experience that reaches it, and the maximum Health
# and Strength it gives. Each Level raises Health by 10 and Strength by 5, and each takes about
# half again the Experience of the last; the last row is the highest Level.
const LEVELS := [
	{experience = 0, max_health = 50, strength = 0},
	{experience = 40, max_health = 60, strength = 5},
	{experience = 100, max_health = 70, strength = 10},
	{experience = 180, max_health = 80, strength = 15},
	{experience = 300, max_health = 90, strength = 20},
	{experience = 450, max_health = 100, strength = 25},
	{experience = 650, max_health = 110, strength = 30},
	{experience = 900, max_health = 120, strength = 35},
	{experience = 1200, max_health = 130, strength = 40},
	{experience = 1600, max_health = 140, strength = 45},
]

# Read-only for callers: change them through gain().
var experience: int = 0
var level: int = 1


func _init(starting_experience: int = 0) -> void:
	gain(starting_experience)


# Adds Experience, and returns how many Levels it raised. Past the highest Level it still
# counts, but raises nothing.
func gain(amount: int) -> int:
	if amount <= 0:
		return 0
	experience += amount
	var reached := level
	while reached < LEVELS.size() and experience >= LEVELS[reached].experience:
		reached += 1
	var gained := reached - level
	level = reached
	return gained


# The Experience still needed for the next Level, or AT_HIGHEST.
func experience_to_next() -> int:
	if level >= LEVELS.size():
		return AT_HIGHEST
	return LEVELS[level].experience - experience


func max_health() -> int:
	return LEVELS[level - 1].max_health


func strength() -> int:
	return LEVELS[level - 1].strength
