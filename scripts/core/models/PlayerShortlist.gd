## PlayerShortlist - Tracks user's draft watchlist of players of interest
##
## Maintains a prioritized list of players the user wants to track during
## the draft. Provides alerts when shortlisted players are picked and
## visual indicators for availability.
##
## Features:
## - Add/remove players to shortlist with optional priority
## - Track availability status (available, drafted, by whom)
## - Alert generation when shortlisted players are picked
## - Persistence to/from save data
## - O(1) lookup for shortlist membership
##
## Usage:
##   var shortlist = PlayerShortlist.new()
##   shortlist.add_player("player_123", "John Smith", "QB")
##   if shortlist.is_shortlisted("player_123"):
##       # Show visual indicator
##   shortlist.mark_as_drafted("player_123", "team_phi")
##
extends RefCounted
class_name PlayerShortlist

## Maximum players allowed on shortlist
const MAX_SHORTLIST_SIZE: int = 50

## Priority levels for shortlist entries
enum Priority { HIGH = 1, MEDIUM = 2, LOW = 3 }

## Emitted when a shortlisted player is drafted by another team
signal shortlisted_player_drafted(player_id: String, player_name: String, position: String, team_id: String, pick_number: int)

## Emitted when shortlist changes (add/remove/reorder)
signal shortlist_changed()

## Internal storage - Array of shortlist entries sorted by priority then add order
## Entry format: {player_id, name, position, college, priority, added_at, status, drafted_by, drafted_at_pick}
var _entries: Array = []

## Fast lookup set for O(1) membership check
var _player_ids: Dictionary = {}

## Team ID this shortlist belongs to (for persistence)
var _team_id: String = ""


## Initialize with team ID for persistence
func initialize(team_id: String) -> void:
	_team_id = team_id
	_entries.clear()
	_player_ids.clear()


## Add a player to the shortlist
## Returns true if added, false if already present or list is full
func add_player(
	player_id: String,
	name: String,
	position: String,
	college: String = "",
	priority: int = Priority.MEDIUM
) -> bool:
	if player_id.is_empty():
		push_warning("[PlayerShortlist] Cannot add player with empty ID")
		return false

	if _player_ids.has(player_id):
		return false  # Already shortlisted

	if _entries.size() >= MAX_SHORTLIST_SIZE:
		push_warning("[PlayerShortlist] Shortlist is full (%d players)" % MAX_SHORTLIST_SIZE)
		return false

	var entry := {
		"player_id": player_id,
		"name": name,
		"position": position,
		"college": college,
		"priority": clampi(priority, Priority.HIGH, Priority.LOW),
		"added_at": Time.get_ticks_msec(),
		"status": "available",  # available, drafted
		"drafted_by": "",
		"drafted_at_pick": 0
	}

	_entries.append(entry)
	_player_ids[player_id] = true
	_sort_entries()

	shortlist_changed.emit()
	return true


## Remove a player from the shortlist
## Returns true if removed, false if not found
func remove_player(player_id: String) -> bool:
	if not _player_ids.has(player_id):
		return false

	# Find and remove entry
	for i in range(_entries.size()):
		if _entries[i].get("player_id") == player_id:
			_entries.remove_at(i)
			break

	_player_ids.erase(player_id)
	shortlist_changed.emit()
	return true


## Check if a player is on the shortlist
## O(1) lookup using hash set
func is_shortlisted(player_id: String) -> bool:
	return _player_ids.has(player_id)


## Get a player's shortlist entry
## Returns empty Dictionary if not found
func get_entry(player_id: String) -> Dictionary:
	if not _player_ids.has(player_id):
		return {}

	for entry in _entries:
		if entry.get("player_id") == player_id:
			return entry.duplicate()

	return {}


## Update a player's priority
func set_priority(player_id: String, priority: int) -> bool:
	if not _player_ids.has(player_id):
		return false

	for entry in _entries:
		if entry.get("player_id") == player_id:
			entry["priority"] = clampi(priority, Priority.HIGH, Priority.LOW)
			break

	_sort_entries()
	shortlist_changed.emit()
	return true


## Mark a player as drafted
## This is called when observing picks during the draft
## Emits shortlisted_player_drafted signal for UI alerts
func mark_as_drafted(player_id: String, team_id: String, pick_number: int) -> void:
	if not _player_ids.has(player_id):
		return

	for entry in _entries:
		if entry.get("player_id") == player_id:
			entry["status"] = "drafted"
			entry["drafted_by"] = team_id
			entry["drafted_at_pick"] = pick_number

			# Emit alert signal
			shortlisted_player_drafted.emit(
				player_id,
				String(entry.get("name", "")),
				String(entry.get("position", "")),
				team_id,
				pick_number
			)
			shortlist_changed.emit()
			break


## Get all shortlist entries
## Returns array sorted by priority then add order
func get_all_entries() -> Array:
	return _entries.duplicate(true)


## Get only available (not drafted) entries
func get_available_entries() -> Array:
	var available: Array = []
	for entry in _entries:
		if entry.get("status") == "available":
			available.append(entry.duplicate())
	return available


## Get only drafted entries
func get_drafted_entries() -> Array:
	var drafted: Array = []
	for entry in _entries:
		if entry.get("status") == "drafted":
			drafted.append(entry.duplicate())
	return drafted


## Get entries filtered by priority
func get_entries_by_priority(priority: int) -> Array:
	var filtered: Array = []
	for entry in _entries:
		if entry.get("priority") == priority:
			filtered.append(entry.duplicate())
	return filtered


## Get shortlist size
func size() -> int:
	return _entries.size()


## Get count of available players
func available_count() -> int:
	var count := 0
	for entry in _entries:
		if entry.get("status") == "available":
			count += 1
	return count


## Check if shortlist is empty
func is_empty() -> bool:
	return _entries.is_empty()


## Check if shortlist is full
func is_full() -> bool:
	return _entries.size() >= MAX_SHORTLIST_SIZE


## Clear all entries
func clear() -> void:
	_entries.clear()
	_player_ids.clear()
	shortlist_changed.emit()


## Promote player to higher priority
func promote(player_id: String) -> bool:
	var entry := get_entry(player_id)
	if entry.is_empty():
		return false

	var current_priority := int(entry.get("priority", Priority.MEDIUM))
	if current_priority > Priority.HIGH:  # Can promote
		return set_priority(player_id, current_priority - 1)
	return false


## Demote player to lower priority
func demote(player_id: String) -> bool:
	var entry := get_entry(player_id)
	if entry.is_empty():
		return false

	var current_priority := int(entry.get("priority", Priority.MEDIUM))
	if current_priority < Priority.LOW:  # Can demote
		return set_priority(player_id, current_priority + 1)
	return false


## Sort entries by priority (ascending) then by add time (ascending)
func _sort_entries() -> void:
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_pri := int(a.get("priority", Priority.MEDIUM))
		var b_pri := int(b.get("priority", Priority.MEDIUM))
		if a_pri != b_pri:
			return a_pri < b_pri  # Lower priority value = higher priority
		return int(a.get("added_at", 0)) < int(b.get("added_at", 0))
	)


## Serialize shortlist for persistence
func to_dict() -> Dictionary:
	return {
		"team_id": _team_id,
		"entries": _entries.duplicate(true),
		"version": 1
	}


## Restore shortlist from persistence data
func from_dict(data: Dictionary) -> void:
	_team_id = String(data.get("team_id", ""))
	_entries = (data.get("entries", []) as Array).duplicate(true)

	# Rebuild lookup set
	_player_ids.clear()
	for entry in _entries:
		var player_id := String(entry.get("player_id", ""))
		if not player_id.is_empty():
			_player_ids[player_id] = true


## Create a duplicate of this shortlist
func duplicate():  # Returns PlayerShortlist (type annotation removed due to circular reference)
	var script = get_script()
	var copy = script.new()
	copy._team_id = _team_id
	copy._entries = _entries.duplicate(true)
	copy._player_ids = _player_ids.duplicate()
	return copy


## Get string representation for debugging
func _to_string() -> String:
	return "PlayerShortlist(%s, %d entries, %d available)" % [
		_team_id, _entries.size(), available_count()
	]
