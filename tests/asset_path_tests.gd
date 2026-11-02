extends RefCounted

# Every res:// path written in the game's scenes, resources, scripts, tests and project settings
# names a file that exists, so a moved or deleted file never leaves a reference behind.

# Where the game's own files live, and the kinds of file that can name another.
const ROOTS := ["res://scenes", "res://scripts", "res://tests", "res://assets"]
const KINDS := ["tscn", "tres", "gd", "gdshader"]
const PROJECT := "res://project.godot"
# A path ends at a quote, a bracket or whitespace.
const PATH_PATTERN := "res://[^\"'\\s)\\]]+"


func get_tests() -> Array:
	return [
		["Every res:// path the game names exists", _test_every_path_exists],
	]


func _test_every_path_exists() -> bool:
	var pattern := RegEx.create_from_string(PATH_PATTERN)
	var missing: Array[String] = []
	var sources: Array[String] = [PROJECT]
	for root in ROOTS:
		sources.append_array(_files_under(root))
	for source in sources:
		var text := FileAccess.get_file_as_string(source)
		for found in pattern.search_all(text):
			var path := found.get_string()
			# A path built from parts at run time is not a file name on its own.
			if (
				path.contains("%")
				or path.contains("[")
				or path.ends_with("/")
				or path.contains("{")
			):
				continue
			if not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path):
				missing.append("%s names %s" % [source, path])
	for line in missing:
		push_error(line)
	return missing.is_empty() and sources.size() > 50


func _files_under(root: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return files
	for file in dir.get_files():
		if KINDS.has(file.get_extension()):
			files.append(root.path_join(file))
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			files.append_array(_files_under(root.path_join(sub)))
	return files
