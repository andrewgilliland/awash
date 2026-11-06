extends RefCounted

# A JSON file on disk, written so that a crash part-way never leaves a broken one: each write
# goes to a file beside it, which is then renamed over it.

const TEMP_SUFFIX := ".tmp"


static func write(path: String, data: Dictionary) -> bool:
	var temp := path + TEMP_SUFFIX
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return DirAccess.rename_absolute(temp, path) == OK


# The file's object, or {} when it is missing or isn't a JSON object.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
