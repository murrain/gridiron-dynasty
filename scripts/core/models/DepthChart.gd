@icon("res://icon.svg")
# res://scripts/core/models/DepthChart.gd
extends Resource
class_name DepthChart

## Maps position name to ordered array of player IDs (starter first)
## Structure: Dictionary[String, Array[String]]
## Example: {"QB": ["player_001", "player_002"], "RB": ["player_003"]}
@export var position_depths: Dictionary = {}

# --- Core Methods ---

## Get the starting player for a given position
## Returns the player_id of the starter, or empty string if no starter exists
func get_starter(position: String) -> String:
	var depth: Array = position_depths.get(position, [])
	if depth.is_empty():
		return ""
	return String(depth[0])

## Get the full depth chart array for a position
## Returns an array of player_ids in depth order
func get_depth(position: String) -> Array[String]:
	var depth_arr: Array = position_depths.get(position, [])
	var result: Array[String] = []
	for player_id in depth_arr:
		result.append(String(player_id))
	return result

## Set the complete depth chart for a position
## player_ids should be ordered from starter (index 0) to deepest backup
func set_depth(position: String, player_ids: Array[String]) -> void:
	if position.is_empty():
		push_warning("DepthChart.set_depth: position is empty")
		return
	position_depths[position] = player_ids.duplicate()

## Get a specific backup at the given depth index (0 = starter, 1 = first backup, etc.)
## Returns empty string if depth_index is out of bounds
func get_backup(position: String, depth_index: int) -> String:
	if depth_index < 0:
		push_warning("DepthChart.get_backup: depth_index cannot be negative")
		return ""

	var depth: Array = position_depths.get(position, [])
	if depth_index >= depth.size():
		return ""

	return String(depth[depth_index])

## Add a player to the depth chart at a specific position
## If depth_index is -1 or omitted, adds to the end of the depth chart
## If depth_index is specified, inserts at that position
func add_player(position: String, player_id: String, depth_index: int = -1) -> void:
	if position.is_empty() or player_id.is_empty():
		push_warning("DepthChart.add_player: position or player_id is empty")
		return

	if not position_depths.has(position):
		position_depths[position] = []

	var depth: Array = position_depths[position]

	# Remove player if already in depth chart (prevents duplicates)
	var existing_idx = depth.find(player_id)
	if existing_idx != -1:
		depth.remove_at(existing_idx)

	# Add at specified index or end
	if depth_index < 0 or depth_index >= depth.size():
		depth.append(player_id)
	else:
		depth.insert(depth_index, player_id)

	position_depths[position] = depth

## Remove a player from a specific position's depth chart
## Returns true if player was found and removed, false otherwise
func remove_player(position: String, player_id: String) -> bool:
	if not position_depths.has(position):
		return false

	var depth: Array = position_depths[position]
	var idx = depth.find(player_id)
	if idx == -1:
		return false

	depth.remove_at(idx)
	position_depths[position] = depth
	return true

## Remove a player from all positions in the depth chart
## Useful when a player is released, traded, or injured
## Returns the number of positions the player was removed from
func remove_player_from_all_positions(player_id: String) -> int:
	var removed_count: int = 0
	for position in position_depths.keys():
		if remove_player(position, player_id):
			removed_count += 1
	return removed_count

## Get all positions where a player appears in the depth chart
## Returns an array of position strings
func get_player_positions(player_id: String) -> Array[String]:
	var positions: Array[String] = []
	for position in position_depths.keys():
		var depth: Array = position_depths[position]
		if depth.has(player_id):
			positions.append(String(position))
	return positions

## Clear all depth chart data
func clear() -> void:
	position_depths.clear()

## Check if depth chart is empty
func is_empty() -> bool:
	return position_depths.is_empty()

## Get all positions that have at least one player
func get_filled_positions() -> Array[String]:
	var filled: Array[String] = []
	for position in position_depths.keys():
		var depth: Array = position_depths[position]
		if not depth.is_empty():
			filled.append(String(position))
	return filled

# --- Serialization ---

func to_dict() -> Dictionary:
	# Deep copy to avoid external mutations
	var depths_copy: Dictionary = {}
	for position in position_depths.keys():
		var depth_arr: Array = position_depths[position]
		depths_copy[position] = depth_arr.duplicate()

	return {
		"position_depths": depths_copy
	}

func from_dict(data: Dictionary) -> void:
	position_depths.clear()

	var depths_data: Dictionary = data.get("position_depths", {})
	for position in depths_data.keys():
		var depth_arr: Array = depths_data[position]
		var player_ids: Array[String] = []
		for player_id in depth_arr:
			player_ids.append(String(player_id))
		position_depths[position] = player_ids
