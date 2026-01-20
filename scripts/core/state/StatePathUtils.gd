extends RefCounted
class_name StatePathUtils

## StatePathUtils - Shared utilities for navigating nested world_state structures
##
## Provides common path navigation operations used across all state managers.
## These utilities handle the nested dictionary/array structures in world_state
## (e.g., world_state["nfl_rosters"]["SF"]["players"][0]).
##
## Core Functions:
## - extract_value() - Get value at a path (read-only)
## - extract_array() - Get array at a path with type safety
## - replace_value() - Set value at a path (creates structure if needed)
## - replace_array() - Set array at a path
## - has_path() - Check if a path exists
##
## Usage:
##   # Get nested value
##   var players := StatePathUtils.extract_array(
##       world_state,
##       ["nfl_rosters", "SF", "players"]
##   )
##
##   # Set nested value (creates structure if needed)
##   StatePathUtils.replace_value(
##       world_state,
##       ["draft", "current_pick"],
##       42
##   )
##
## Path Format:
##   Paths are arrays of String or int keys for navigating nested structures.
##   - String keys access Dictionary entries
##   - Int keys access Array indices
##
##   Examples:
##   - ["nfl_rosters", "SF", "players"] -> world_state["nfl_rosters"]["SF"]["players"]
##   - ["draft_pool", 0] -> world_state["draft_pool"][0]

# ============================================================================
# PUBLIC API - Read Operations (Non-mutating)
# ============================================================================

## Extract a value from world_state at a specific path.
##
## Navigates through nested dictionaries/arrays to retrieve the value
## at the specified path. Returns null if any part of the path is invalid.
##
## Parameters:
##   state: Dictionary to navigate (not mutated)
##   path: Array of keys to navigate (e.g., ["nfl_rosters", "SF", "players"])
##
## Returns:
##   Variant: The value at the path, or null if path is invalid
##
## Examples:
##   var roster := StatePathUtils.extract_value(world_state, ["nfl_rosters", "SF"])
##   var player := StatePathUtils.extract_value(world_state, ["draft_pool", 0])
static func extract_value(state: Dictionary, path: Array) -> Variant:
	if path.is_empty():
		return null

	var current: Variant = state
	for key in path:
		if current is Dictionary and current.has(key):
			current = current[key]
		elif current is Array and key is int and key >= 0 and key < current.size():
			current = current[key]
		else:
			return null

	return current


## Extract an array from world_state at a specific path.
##
## Type-safe wrapper around extract_value() that ensures the result is an Array.
## Returns empty array if path is invalid or value is not an array.
##
## Parameters:
##   state: Dictionary to navigate (not mutated)
##   path: Array of keys to navigate to the array
##
## Returns:
##   Array: The array at the path, or empty array if path invalid or not an array
##
## Example:
##   var players := StatePathUtils.extract_array(world_state, ["nfl_rosters", "SF", "players"])
static func extract_array(state: Dictionary, path: Array) -> Array:
	var value := extract_value(state, path)
	if value is Array:
		return value
	return []


## Extract a dictionary from world_state at a specific path.
##
## Type-safe wrapper around extract_value() that ensures the result is a Dictionary.
## Returns empty dictionary if path is invalid or value is not a dictionary.
##
## Parameters:
##   state: Dictionary to navigate (not mutated)
##   path: Array of keys to navigate to the dictionary
##
## Returns:
##   Dictionary: The dictionary at the path, or empty dict if path invalid or not a dict
##
## Example:
##   var roster := StatePathUtils.extract_dict(world_state, ["nfl_rosters", "SF"])
static func extract_dict(state: Dictionary, path: Array) -> Dictionary:
	var value := extract_value(state, path)
	if value is Dictionary:
		return value
	return {}


## Check if a path exists in the state.
##
## Parameters:
##   state: Dictionary to check (not mutated)
##   path: Array of keys to check
##
## Returns:
##   bool: true if the path exists, false otherwise
##
## Example:
##   if StatePathUtils.has_path(world_state, ["franchise_tags", year]):
##       # Path exists
static func has_path(state: Dictionary, path: Array) -> bool:
	return extract_value(state, path) != null


# ============================================================================
# PUBLIC API - Write Operations (Mutating)
# ============================================================================

## Replace a value in state at a specific path.
##
## Navigates to the parent of the target location and sets the value.
## Creates intermediate dictionaries if they don't exist (auto-vivification).
##
## Parameters:
##   state: Dictionary to modify (WILL be mutated)
##   path: Array of keys to navigate
##   new_value: Value to set at the path
##
## Returns:
##   bool: true if replacement succeeded, false if path navigation failed
##
## Side Effects:
##   - Mutates state at the specified path
##   - Creates intermediate dictionaries if needed
##
## Example:
##   StatePathUtils.replace_value(world_state, ["draft", "state"], DraftState.RUNNING)
static func replace_value(state: Dictionary, path: Array, new_value: Variant) -> bool:
	if path.is_empty():
		return false

	# Navigate to parent of the target
	var current: Variant = state
	for i in range(path.size() - 1):
		var key = path[i]
		if current is Dictionary:
			# Create nested structure if it doesn't exist
			if not current.has(key):
				current[key] = {}
			current = current[key]
		elif current is Array and key is int and key >= 0 and key < current.size():
			current = current[key]
		else:
			return false

	# Set the value at the final key
	var final_key = path[-1]
	if current is Dictionary:
		current[final_key] = new_value
		return true
	elif current is Array and final_key is int and final_key >= 0 and final_key < current.size():
		current[final_key] = new_value
		return true

	return false


## Replace an array in state at a specific path.
##
## Convenience wrapper for replace_value() with array type.
## Creates intermediate dictionaries if needed.
##
## Parameters:
##   state: Dictionary to modify (WILL be mutated)
##   path: Array of keys to navigate
##   new_array: Array to set at the path
##
## Returns:
##   bool: true if replacement succeeded, false if path navigation failed
##
## Example:
##   StatePathUtils.replace_array(world_state, ["draft_pool"], new_draft_pool)
static func replace_array(state: Dictionary, path: Array, new_array: Array) -> bool:
	return replace_value(state, path, new_array)


## Ensure a path exists, creating intermediate structures as needed.
##
## Creates empty dictionaries along the path if they don't exist.
## Useful for initializing nested structures before populating them.
##
## Parameters:
##   state: Dictionary to modify (WILL be mutated)
##   path: Array of keys to ensure exist
##
## Returns:
##   bool: true if path now exists (created or already existed), false on error
##
## Example:
##   StatePathUtils.ensure_path(world_state, ["franchise_tags", year])
##   world_state["franchise_tags"][year][team_id] = tag_data
static func ensure_path(state: Dictionary, path: Array) -> bool:
	if path.is_empty():
		return true

	var current: Variant = state
	for key in path:
		if current is Dictionary:
			if not current.has(key):
				current[key] = {}
			current = current[key]
		else:
			return false

	return true


# ============================================================================
# PUBLIC API - Array Operations (Mutating)
# ============================================================================

## Append a value to an array at a specific path.
##
## Navigates to the array and appends the value.
## Does NOT create the array if it doesn't exist (returns false).
##
## Parameters:
##   state: Dictionary to modify (WILL be mutated)
##   path: Array of keys to navigate to the target array
##   value: Value to append to the array
##
## Returns:
##   bool: true if append succeeded, false if path invalid or not an array
##
## Example:
##   StatePathUtils.append_to_array(world_state, ["draft_history"], pick_record)
static func append_to_array(state: Dictionary, path: Array, value: Variant) -> bool:
	var arr := extract_array(state, path)
	if arr.is_empty() and not has_path(state, path):
		return false

	# Get direct reference to array (not a copy)
	var current: Variant = state
	for key in path:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return false

	if current is Array:
		current.append(value)
		return true

	return false


## Remove a value from an array at a specific path by index.
##
## Parameters:
##   state: Dictionary to modify (WILL be mutated)
##   path: Array of keys to navigate to the target array
##   index: Index of element to remove
##
## Returns:
##   Variant: The removed value, or null if operation failed
##
## Example:
##   var removed := StatePathUtils.remove_from_array_at(world_state, ["draft_pool"], 0)
static func remove_from_array_at(state: Dictionary, path: Array, index: int) -> Variant:
	# Get direct reference to array
	var current: Variant = state
	for key in path:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return null

	if current is Array and index >= 0 and index < current.size():
		var removed = current[index]
		current.remove_at(index)
		return removed

	return null


# ============================================================================
# PUBLIC API - Utility Functions
# ============================================================================

## Get the size of a collection at a path.
##
## Works with both arrays and dictionaries.
##
## Parameters:
##   state: Dictionary to navigate (not mutated)
##   path: Array of keys to navigate
##
## Returns:
##   int: Size of the collection, or 0 if path invalid or not a collection
##
## Example:
##   var roster_size := StatePathUtils.get_size(world_state, ["nfl_rosters", "SF", "players"])
static func get_size(state: Dictionary, path: Array) -> int:
	var value := extract_value(state, path)
	if value is Array:
		return value.size()
	elif value is Dictionary:
		return value.size()
	return 0


## Deep copy a value at a path.
##
## Returns an immutable copy of the value at the path.
## Useful when you need to work with data without risk of mutation.
##
## Parameters:
##   state: Dictionary to navigate (not mutated)
##   path: Array of keys to navigate
##
## Returns:
##   Variant: Deep copy of value at path, or null if path invalid
##
## Example:
##   var player_copy := StatePathUtils.deep_copy_at(world_state, ["nfl_rosters", "SF", "players", 0])
static func deep_copy_at(state: Dictionary, path: Array) -> Variant:
	var value := extract_value(state, path)
	if value == null:
		return null

	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	elif value is Array:
		return (value as Array).duplicate(true)
	else:
		return value  # Primitives are copied by value


## Build a path string for debugging/logging.
##
## Converts a path array to a human-readable string representation.
##
## Parameters:
##   path: Array of keys
##
## Returns:
##   String: Dot-notation path string (e.g., "nfl_rosters.SF.players[0]")
##
## Example:
##   print("Accessing: " + StatePathUtils.path_to_string(["nfl_rosters", "SF", "players", 0]))
##   # Output: "Accessing: nfl_rosters.SF.players[0]"
static func path_to_string(path: Array) -> String:
	if path.is_empty():
		return "(root)"

	var parts := []
	for key in path:
		if key is int:
			# Array index - append to previous part
			if parts.size() > 0:
				parts[-1] = parts[-1] + "[%d]" % key
			else:
				parts.append("[%d]" % key)
		else:
			parts.append(String(key))

	return ".".join(parts)
