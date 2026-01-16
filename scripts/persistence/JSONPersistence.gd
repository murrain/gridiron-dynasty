## JSON-based persistence backend
## Wraps existing file-based JSON save/load operations
## Provides backward compatibility during SQLite migration
extends RefCounted
class_name JSONPersistence

const SAVE_DIR = "user://saves/"

## Save complete world state to JSON file
## @param world_state: Dictionary containing all game entities
## @param save_name: Identifier for this save (filename without extension)
## @return: true on success, false on failure
func save_world_state(world_state: Dictionary, save_name: String) -> bool:
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var dir_result = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if dir_result != OK:
			push_error("JSONPersistence: Failed to create save directory: %s" % SAVE_DIR)
			return false

	var path = SAVE_DIR + save_name + ".json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var error_code = FileAccess.get_open_error()
		push_error("JSONPersistence: Failed to open file for writing: %s (error: %d)" % [path, error_code])
		return false

	# Serialize to JSON with pretty printing for human readability
	var json_string = JSON.stringify(world_state, "\t")
	file.store_string(json_string)
	file.close()

	print("JSONPersistence: Saved world state to %s (%d bytes)" % [path, json_string.length()])
	return true

## Load complete world state from JSON file
## @param save_name: Identifier for save to load (filename without extension)
## @return: World state dictionary (empty on failure)
func load_world_state(save_name: String) -> Dictionary:
	var path = SAVE_DIR + save_name + ".json"

	if not FileAccess.file_exists(path):
		push_error("JSONPersistence: Save file not found: %s" % path)
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		var error_code = FileAccess.get_open_error()
		push_error("JSONPersistence: Failed to open file for reading: %s (error: %d)" % [path, error_code])
		return {}

	var json_string = file.get_as_text()
	file.close()

	if json_string.is_empty():
		push_error("JSONPersistence: File is empty: %s" % path)
		return {}

	# Parse JSON
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("JSONPersistence: JSON parse error in %s at line %d: %s" %
			[path, json.get_error_line(), json.get_error_message()])
		return {}

	var data = json.data
	if not data is Dictionary:
		push_error("JSONPersistence: Loaded data is not a Dictionary: %s" % path)
		return {}

	print("JSONPersistence: Loaded world state from %s" % path)
	return data as Dictionary

## List available save files
## @return: Array of save names (without .json extension)
func list_saves() -> Array[String]:
	var saves: Array[String] = []

	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return saves

	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		push_error("JSONPersistence: Failed to open save directory: %s" % SAVE_DIR)
		return saves

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			# Remove .json extension
			saves.append(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()

	return saves

## Delete a save file
## @param save_name: Save identifier to delete
## @return: true on success, false on failure
func delete_save(save_name: String) -> bool:
	var path = SAVE_DIR + save_name + ".json"

	if not FileAccess.file_exists(path):
		push_warning("JSONPersistence: Save file not found for deletion: %s" % path)
		return false

	var result = DirAccess.remove_absolute(path)
	if result != OK:
		push_error("JSONPersistence: Failed to delete save file: %s (error: %d)" % [path, result])
		return false

	print("JSONPersistence: Deleted save file: %s" % path)
	return true
