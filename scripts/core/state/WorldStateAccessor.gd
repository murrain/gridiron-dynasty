extends RefCounted
class_name WorldStateAccessor

## WorldStateAccessor - Read-only access to world_state with query helpers
##
## Provides controlled read-only access to world_state to prevent accidental mutations.
## All methods return COPIES of data, never direct references.
##
## Core Principles:
## 1. Read-only - never mutates world_state
## 2. Returns copies - callers cannot accidentally mutate shared state
## 3. Query helpers - common queries encapsulated for reuse
## 4. Performance-conscious - uses shallow copies where deep copies aren't needed
##
## Usage:
##   # Get all draft-eligible players
##   var draft_players := WorldStateAccessor.get_players_by_stage(
##       world_state,
##       Player.PlayerStage.DRAFT_ELIGIBLE
##   )
##
##   # Get a specific player by ID
##   var player := WorldStateAccessor.get_player_by_id(world_state, "player_123")
##
##   # Get roster counts for all teams
##   var roster_counts := WorldStateAccessor.get_team_roster_counts(world_state)

const Player = preload("res://scripts/core/models/Player.gd")

# ============================================================================
# PUBLIC API - Query Methods (Read-Only)
# ============================================================================

## Get all players matching a lifecycle stage.
##
## Searches across all player collections and returns matching players.
##
## Parameters:
##   world_state: Global game state dictionary (not mutated)
##   stage: Player.PlayerStage enum value to filter by
##
## Returns:
##   Array of player dictionaries (immutable copies)
static func get_players_by_stage(
	world_state: Dictionary,
	stage: Player.PlayerStage
) -> Array:
	var results := []

	# Search high school players
	var hs_players: Array = world_state.get("hs_players", [])
	for player in hs_players:
		var p: Dictionary = player
		if int(p.get("stage", -1)) == stage:
			results.append(p.duplicate(true))

	# Search college rosters (nested: school_id -> players)
	var college_rosters: Dictionary = world_state.get("college_rosters", {})
	for school_id in college_rosters.keys():
		var roster: Dictionary = college_rosters[school_id]
		var players: Array = roster.get("players", [])
		for player in players:
			var p: Dictionary = player
			if int(p.get("stage", -1)) == stage:
				results.append(p.duplicate(true))

	# Search draft pool
	var draft_pool: Array = world_state.get("draft_pool", [])
	for player in draft_pool:
		var p: Dictionary = player
		if int(p.get("stage", -1)) == stage:
			results.append(p.duplicate(true))

	# Search NFL rosters (nested: team_id -> players)
	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {})
	for team_id in nfl_rosters.keys():
		var roster: Dictionary = nfl_rosters[team_id]
		var players: Array = roster.get("players", [])
		for player in players:
			var p: Dictionary = player
			if int(p.get("stage", -1)) == stage:
				results.append(p.duplicate(true))

	# Search free agents
	var free_agents: Array = world_state.get("free_agents", [])
	for player in free_agents:
		var p: Dictionary = player
		if int(p.get("stage", -1)) == stage:
			results.append(p.duplicate(true))

	return results


## Get a player by ID (immutable copy).
##
## Searches across all collections to find a player by their unique ID.
##
## Parameters:
##   world_state: Global game state dictionary (not mutated)
##   player_id: Unique identifier of the player to find
##
## Returns:
##   Player dictionary (immutable copy), or empty dictionary if not found
static func get_player_by_id(
	world_state: Dictionary,
	player_id: String
) -> Dictionary:
	var location := _find_player_location(world_state, player_id)
	if location.is_empty():
		return {}

	var player: Dictionary = location.player
	return player.duplicate(true)  # Return immutable copy


## Get all teams with roster counts.
##
## Calculates roster size for each NFL team.
##
## Parameters:
##   world_state: Global game state dictionary (not mutated)
##
## Returns:
##   Dictionary of team_id -> {name: String, roster_count: int, roster_limit: int}
static func get_team_roster_counts(world_state: Dictionary) -> Dictionary:
	var results := {}
	var rosters: Dictionary = world_state.get("nfl_rosters", {})

	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id]
		var players: Array = roster.get("players", [])
		results[team_id] = {
			"name": String(roster.get("name", team_id)),
			"roster_count": players.size(),
			"roster_limit": int(roster.get("roster_limit", 53))  # NFL standard roster limit
		}

	return results


## Get draft-eligible players sorted by composite score.
##
## Returns all players in the draft pool, sorted by their composite score
## in descending order (best players first).
##
## Parameters:
##   world_state: Global game state dictionary (not mutated)
##
## Returns:
##   Array of player dictionaries sorted descending by composite_score
static func get_draft_eligible_players_sorted(
	world_state: Dictionary
) -> Array:
	var draft_pool: Array = world_state.get("draft_pool", [])

	# Create a copy before sorting (don't mutate input)
	var sorted := draft_pool.duplicate(true)

	sorted.sort_custom(func(a, b):
		var score_a := float((a as Dictionary).get("composite_score", 0.0))
		var score_b := float((b as Dictionary).get("composite_score", 0.0))
		return score_a > score_b
	)

	return sorted


## Get all players in a specific collection.
##
## Generic accessor for any player collection in world_state.
##
## Parameters:
##   world_state: Global game state dictionary (not mutated)
##   collection_name: Name of the collection (e.g., "hs_players", "draft_pool")
##
## Returns:
##   Array of player dictionaries (immutable copies), or empty array if collection doesn't exist
static func get_collection(
	world_state: Dictionary,
	collection_name: String
) -> Array:
	var collection = world_state.get(collection_name, null)

	if collection == null:
		return []

	if collection is Array:
		return collection.duplicate(true)

	# Handle nested collections (rosters)
	if collection is Dictionary:
		var all_players := []
		for key in collection.keys():
			var roster: Dictionary = collection[key]
			var players: Array = roster.get("players", [])
			for player in players:
				all_players.append((player as Dictionary).duplicate(true))
		return all_players

	return []


## Get players from a specific team roster.
##
## Parameters:
##   world_state: Global game state dictionary (not mutated)
##   roster_type: Type of roster ("nfl_rosters" or "college_rosters")
##   team_id: ID of the team (e.g., "SF" for 49ers, "STANFORD" for Stanford)
##
## Returns:
##   Array of player dictionaries (immutable copies), or empty array if team not found
static func get_team_roster(
	world_state: Dictionary,
	roster_type: String,
	team_id: String
) -> Array:
	var rosters: Dictionary = world_state.get(roster_type, {})
	if not rosters.has(team_id):
		return []

	var roster: Dictionary = rosters[team_id]
	var players: Array = roster.get("players", [])

	# Return immutable copies
	var result := []
	for player in players:
		result.append((player as Dictionary).duplicate(true))

	return result


## Get summary statistics about all players in world_state.
##
## Parameters:
##   world_state: Global game state dictionary (not mutated)
##
## Returns:
##   Dictionary with counts by stage:
##   {
##     "total": int,
##     "by_stage": {
##       Player.PlayerStage.HIGH_SCHOOL: int,
##       Player.PlayerStage.COLLEGE: int,
##       ...
##     }
##   }
static func get_player_counts(world_state: Dictionary) -> Dictionary:
	var by_stage := {}
	var total := 0

	# Initialize all stages to 0
	for stage in [
		Player.PlayerStage.HIGH_SCHOOL,
		Player.PlayerStage.COLLEGE,
		Player.PlayerStage.DRAFT_ELIGIBLE,
		Player.PlayerStage.NFL_ROOKIE,
		Player.PlayerStage.NFL_VETERAN,
		Player.PlayerStage.NFL_FREE_AGENT,
		Player.PlayerStage.RETIRED
	]:
		by_stage[stage] = 0

	# Count players in each collection
	var collections := [
		"hs_players",
		"college_rosters",
		"draft_pool",
		"nfl_rosters",
		"free_agents"
	]

	for collection_name in collections:
		var collection = world_state.get(collection_name, null)
		if collection == null:
			continue

		match collection_name:
			"nfl_rosters", "college_rosters":
				# Nested structure: team_id -> roster -> players
				if collection is Dictionary:
					for team_id in collection.keys():
						var roster: Dictionary = collection[team_id]
						var players: Array = roster.get("players", [])
						for player in players:
							var p: Dictionary = player
							var stage: Player.PlayerStage = int(p.get("stage", -1))
							if by_stage.has(stage):
								by_stage[stage] += 1
							total += 1
			_:
				# Flat array of players
				if collection is Array:
					for player in collection:
						var p: Dictionary = player
						var stage: Player.PlayerStage = int(p.get("stage", -1))
						if by_stage.has(stage):
							by_stage[stage] += 1
						total += 1

	return {
		"total": total,
		"by_stage": by_stage
	}


## Check if a player exists in world_state.
##
## Parameters:
##   world_state: Global game state dictionary (not mutated)
##   player_id: Unique identifier of the player to check
##
## Returns:
##   bool: true if player exists, false otherwise
static func has_player(
	world_state: Dictionary,
	player_id: String
) -> bool:
	var location := _find_player_location(world_state, player_id)
	return not location.is_empty()


## Get a player's current location in world_state.
##
## Useful for understanding where a player is currently stored.
##
## Parameters:
##   world_state: Global game state dictionary (not mutated)
##   player_id: Unique identifier of the player
##
## Returns:
##   Dictionary with location metadata:
##   {
##     "collection_type": String,   # "hs_players", "college_rosters", "nfl_rosters", etc.
##     "team_id": String,            # Team ID (if in roster collection), empty otherwise
##     "index": int                  # Index in the collection
##   }
##   Empty dictionary if player not found
static func get_player_location(
	world_state: Dictionary,
	player_id: String
) -> Dictionary:
	var location := _find_player_location(world_state, player_id)
	if location.is_empty():
		return {}

	var collection_path: Array = location.collection_path
	var collection_type := String(collection_path[0])
	var team_id := ""

	# Extract team_id if in a roster collection
	if collection_path.size() >= 2 and collection_type in ["nfl_rosters", "college_rosters"]:
		team_id = String(collection_path[1])

	return {
		"collection_type": collection_type,
		"team_id": team_id,
		"index": location.index
	}


# ============================================================================
# INTERNAL HELPERS - Player Location
# ============================================================================

## Find player location in world_state.
##
## Internal helper used by public query methods.
##
## Returns:
##   Dictionary with location metadata:
##   {
##     "collection_path": Array,   # Path to collection (e.g., ["nfl_rosters", "SF", "players"])
##     "index": int,                # Index of player in collection
##     "player": Dictionary         # Reference to player dict (NOT a copy!)
##   }
##   Empty dictionary if player not found
static func _find_player_location(
	world_state: Dictionary,
	player_id: String
) -> Dictionary:
	# Search high school players
	var hs_players: Array = world_state.get("hs_players", [])
	for i in range(hs_players.size()):
		var p: Dictionary = hs_players[i]
		if String(p.get("id", "")) == player_id:
			return {
				"collection_path": ["hs_players"],
				"index": i,
				"player": p
			}

	# Search college rosters (nested: school_id -> players)
	var college_rosters: Dictionary = world_state.get("college_rosters", {})
	for school_id in college_rosters.keys():
		var roster: Dictionary = college_rosters[school_id]
		var players: Array = roster.get("players", [])
		for i in range(players.size()):
			var p: Dictionary = players[i]
			if String(p.get("id", "")) == player_id:
				return {
					"collection_path": ["college_rosters", school_id, "players"],
					"index": i,
					"player": p
				}

	# Search draft pool
	var draft_pool: Array = world_state.get("draft_pool", [])
	for i in range(draft_pool.size()):
		var p: Dictionary = draft_pool[i]
		if String(p.get("id", "")) == player_id:
			return {
				"collection_path": ["draft_pool"],
				"index": i,
				"player": p
			}

	# Search NFL rosters (nested: team_id -> players)
	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {})
	for team_id in nfl_rosters.keys():
		var roster: Dictionary = nfl_rosters[team_id]
		var players: Array = roster.get("players", [])
		for i in range(players.size()):
			var p: Dictionary = players[i]
			if String(p.get("id", "")) == player_id:
				return {
					"collection_path": ["nfl_rosters", team_id, "players"],
					"index": i,
					"player": p
				}

	# Search free agents
	var free_agents: Array = world_state.get("free_agents", [])
	for i in range(free_agents.size()):
		var p: Dictionary = free_agents[i]
		if String(p.get("id", "")) == player_id:
			return {
				"collection_path": ["free_agents"],
				"index": i,
				"player": p
			}

	# Player not found
	return {}
