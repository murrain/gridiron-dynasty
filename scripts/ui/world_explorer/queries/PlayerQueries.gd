class_name PlayerQueries
extends RefCounted

## Static utility class for querying player data from world_state
##
## Provides functions to search, filter, and retrieve player data from various
## collections in the world_state (NFL rosters, college rosters, HS players, etc.)
##
## Dependencies:
## - StatQueries: for calculate_composite_rating() in sort_players_by_rating()

## Validate that a Dictionary has the minimum required fields for a player
##
## Checks for either "id" or "player_id" field.
## Logs warning if neither exists.
##
## Returns: true if valid, false if invalid
static func is_valid_player_dict(player: Dictionary) -> bool:
	if player.is_empty():
		return false

	# Must have either "id" or "player_id"
	if not player.has("id") and not player.has("player_id"):
		push_warning("PlayerQueries: Invalid player dict - missing 'id' or 'player_id' field")
		return false

	return true

## Get the player ID from a player Dictionary
##
## Handles both "id" and "player_id" key naming conventions.
## Returns empty string if neither exists.
static func get_player_id(player: Dictionary) -> String:
	if player.has("id"):
		return player.get("id", "")
	if player.has("player_id"):
		return player.get("player_id", "")
	return ""

## Get player by ID from any collection
##
## Searches all player collections (NFL rosters, college rosters, HS players,
## draft pool, retired) for a player matching the given ID.
##
## PERFORMANCE WARNING: O(N) linear search where N is total player count.
## For large worlds (10,000+ players), this can be slow.
## Avoid calling in tight loops. Consider batching queries if possible.
##
## Parameters:
## - world_state: The global world state Dictionary
## - player_id: The unique player identifier (string)
##
## Returns:
## - Dictionary: The player data if found
## - null: If no player exists with that ID (check console for warning)
##
## Example:
##     var player = PlayerQueries.get_player_by_id(world_state, "player_123")
##     if player:
##         print(PlayerQueries.get_player_name(player))
##     else:
##         print("Player not found")
static func get_player_by_id(world_state: Dictionary, player_id: String) -> Variant:
	if player_id.is_empty():
		push_warning("PlayerQueries.get_player_by_id: player_id is empty")
		return null

	# Search NFL rosters
	var nfl_rosters = world_state.get("nfl_rosters", {})
	for roster_data in nfl_rosters.values():
		var players = roster_data.get("players", [])
		for player in players:
			if get_player_id(player) == player_id:
				return player

	# Search college rosters
	var college_rosters = world_state.get("college_rosters", {})
	for roster_data in college_rosters.values():
		var players = roster_data.get("players", [])
		for player in players:
			if get_player_id(player) == player_id:
				return player

	# Search HS players
	var hs_players = world_state.get("hs_players", [])
	for player in hs_players:
		if get_player_id(player) == player_id:
			return player

	# Search draft pool
	var draft_pool = world_state.get("draft_pool", {})
	for year_players in draft_pool.values():
		for player in year_players:
			if get_player_id(player) == player_id:
				return player

	# Search retired
	var retired = world_state.get("retired_players", [])
	for player in retired:
		if get_player_id(player) == player_id:
			return player

	# If we get here, player not found
	push_warning("PlayerQueries.get_player_by_id: Player '%s' not found in any collection" % player_id)
	return null

## Get all NFL players from all teams
## Returns Array of player Dictionaries
static func get_all_nfl_players(world_state: Dictionary) -> Array:
	var all_players: Array = []
	var nfl_rosters = world_state.get("nfl_rosters", {})

	for roster_data in nfl_rosters.values():
		var players = roster_data.get("players", [])
		all_players.append_array(players)

	return all_players

## Get all college players from all colleges
## Returns Array of player Dictionaries
static func get_all_college_players(world_state: Dictionary) -> Array:
	var all_players: Array = []
	var college_rosters = world_state.get("college_rosters", {})

	for roster_data in college_rosters.values():
		var players = roster_data.get("players", [])
		all_players.append_array(players)

	return all_players

## Get all high school players
## Returns Array of player Dictionaries
static func get_all_hs_players(world_state: Dictionary) -> Array:
	return world_state.get("hs_players", [])

## Get all retired players
## Returns Array of player Dictionaries
static func get_retired_players(world_state: Dictionary) -> Array:
	return world_state.get("retired_players", [])

## Find players by name (case-insensitive substring match)
## Searches first name, last name, and full name
## Returns Array of matching player Dictionaries
static func find_players_by_name(world_state: Dictionary, search_text: String) -> Array:
	if search_text.is_empty():
		return []

	var results: Array = []
	var search_lower = search_text.to_lower()

	# Helper to check if player matches
	var matches = func(player: Dictionary) -> bool:
		# Handle both name formats: separate first/last or combined name field
		var search_name := ""
		if player.has("first_name") or player.has("last_name"):
			var first = player.get("first_name", "").to_lower()
			var last = player.get("last_name", "").to_lower()
			search_name = (first + " " + last).to_lower()
		elif player.has("name"):
			search_name = player.get("name", "").to_lower()
		return search_name.contains(search_lower)

	# Search all collections
	results.append_array(get_all_nfl_players(world_state).filter(matches))
	results.append_array(get_all_college_players(world_state).filter(matches))
	results.append_array(get_all_hs_players(world_state).filter(matches))
	results.append_array(get_retired_players(world_state).filter(matches))

	return results

## Filter players by position
## position: Position code (e.g., "QB", "RB") or "All" to return all players
## Returns filtered Array of player Dictionaries
static func get_players_by_position(players: Array, position: String) -> Array:
	if position == "All" or position.is_empty():
		return players

	return players.filter(func(p): return p.get("position", "") == position)

## Sort players by composite rating (descending by default)
##
## Parameters:
## - players: Array of player Dictionaries
## - ascending: If true, sort lowest to highest. Default false (highest first)
## - in_place: If true, modifies the original array. Default false (creates copy).
##             Only use true if you don't need the original order preserved!
##
## Returns: Sorted array (same as input if in_place=true)
static func sort_players_by_rating(players: Array, ascending: bool = false, in_place: bool = false) -> Array:
	var sorted = players if in_place else players.duplicate()
	sorted.sort_custom(func(a, b):
		var rating_a = StatQueries.calculate_composite_rating(a)
		var rating_b = StatQueries.calculate_composite_rating(b)
		return rating_a > rating_b if not ascending else rating_a < rating_b
	)
	return sorted

## Get player's full name
## Returns formatted "FirstName LastName" string
##
## Handles two name formats:
## 1. Separate fields: first_name + last_name (Player model format)
## 2. Combined field: name (PlayerGenerator format)
static func get_player_name(player: Dictionary) -> String:
	# Try separate first_name/last_name fields first (Player model format)
	if player.has("first_name") or player.has("last_name"):
		var first := String(player.get("first_name", ""))
		var last := String(player.get("last_name", ""))
		if not first.is_empty() or not last.is_empty():
			# Join parts with space, strip leading/trailing whitespace
			return (first + " " + last).strip_edges()

	# Fall back to combined name field (PlayerGenerator format)
	if player.has("name"):
		return String(player.get("name", ""))

	return "Unknown"
