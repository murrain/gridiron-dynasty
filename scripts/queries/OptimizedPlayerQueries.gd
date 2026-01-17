class_name OptimizedPlayerQueries
extends RefCounted

## In-memory indexed player queries for runtime performance
##
## This is the PRIMARY query system during gameplay.
## - O(1) lookups via pre-built indexes
## - No I/O during gameplay - operates on in-memory WorldState
## - Rebuilt from WorldState after each simulation tick
## - Player-coach filters results by scouting knowledge post-query
## - AI coaches use results directly (true stats)
##
## Usage:
##   var queries = OptimizedPlayerQueries.new()
##   queries.rebuild_indexes(world_state)
##   var fast_cbs = queries.by_position("CB").filter(func(p): return p.stats.speed >= 90)
##
## RNG: This class does NOT consume RNG. All operations are pure data access functions.

# Preload Player model for type checking
const Player = preload("res://scripts/core/models/Player.gd")

# Position group constants for categorization
const OFFENSIVE_POSITIONS := ["QB", "RB", "FB", "WR", "TE", "OT", "OG", "C", "OL"]
const DEFENSIVE_POSITIONS := ["DT", "DE", "DL", "EDGE", "ILB", "OLB", "LB", "CB", "FS", "SS", "S"]
const SPECIAL_TEAMS_POSITIONS := ["K", "P", "LS"]

# Age bucket thresholds for categorization
const AGE_YOUNG_MAX := 24
const AGE_PRIME_MAX := 30

# Primary indexes - rebuilt after each tick
var _player_by_id: Dictionary = {}        # id -> Player or Dictionary
var _players_by_position: Dictionary = {} # position -> Array[Player or Dictionary]
var _players_by_team: Dictionary = {}     # team_id -> Array[Player or Dictionary]
var _players_by_stage: Dictionary = {}    # PlayerStage -> Array[Player or Dictionary]

# Secondary indexes for common queries
var _free_agents: Array = []              # Players without team
var _draft_eligible: Array = []           # Players eligible for draft
var _players_by_age_bucket: Dictionary = {} # "young"|"prime"|"veteran" -> Array

signal indexes_rebuilt


## Rebuild all indexes from world state
## Call this after simulation tick or when world state changes
## @param world_state: Dictionary containing nfl_rosters, college_rosters, free_agents, etc.
func rebuild_indexes(world_state: Dictionary) -> void:
	_clear_indexes()

	# Index NFL players from rosters
	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {})
	for team_id in nfl_rosters.keys():
		var roster_data = nfl_rosters[team_id]
		var players: Array = []

		# Handle both dictionary with "players" key and direct array
		if roster_data is Dictionary:
			players = roster_data.get("players", [])
		elif roster_data is Array:
			players = roster_data

		for player in players:
			_index_player(player, team_id)

	# Index college players from rosters
	var college_rosters: Dictionary = world_state.get("college_rosters", {})
	for college_id in college_rosters.keys():
		var roster_data = college_rosters[college_id]
		var players: Array = []

		# Handle both dictionary with "players" key and direct array
		if roster_data is Dictionary:
			players = roster_data.get("players", [])
		elif roster_data is Array:
			players = roster_data

		for player in players:
			_index_player(player, college_id)

	# Index free agents
	var free_agents: Array = world_state.get("free_agents", [])
	for player in free_agents:
		_index_player(player, "")
		_free_agents.append(player)

	# Index draft eligible players (if stored separately)
	var draft_pool: Array = world_state.get("draft_pool", [])
	for player in draft_pool:
		_index_player(player, "")
		_draft_eligible.append(player)

	indexes_rebuilt.emit()


## Clear all indexes for rebuild
func _clear_indexes() -> void:
	_player_by_id.clear()
	_players_by_position.clear()
	_players_by_team.clear()
	_players_by_stage.clear()
	_players_by_age_bucket.clear()
	_free_agents.clear()
	_draft_eligible.clear()


## Index a single player into all relevant indexes
## @param player: Player resource or Dictionary containing player data
## @param team_id: Team ID string (empty for free agents/draft eligible)
func _index_player(player: Variant, team_id: String) -> void:
	var id: String = _get_player_field(player, "id", "")
	var position: String = _get_player_field(player, "position", "")
	var stage: int = _get_player_field(player, "stage", 0)
	var age: int = _get_player_field(player, "age", 0)

	# Skip invalid players
	if id.is_empty():
		return

	# Primary index: by ID
	_player_by_id[id] = player

	# Primary index: by position
	if not position.is_empty():
		if not _players_by_position.has(position):
			_players_by_position[position] = []
		_players_by_position[position].append(player)

	# Primary index: by team
	if not team_id.is_empty():
		if not _players_by_team.has(team_id):
			_players_by_team[team_id] = []
		_players_by_team[team_id].append(player)

	# Primary index: by stage
	if not _players_by_stage.has(stage):
		_players_by_stage[stage] = []
	_players_by_stage[stage].append(player)

	# Secondary index: age bucket
	var bucket := _get_age_bucket(age)
	if not _players_by_age_bucket.has(bucket):
		_players_by_age_bucket[bucket] = []
	_players_by_age_bucket[bucket].append(player)

	# Secondary index: draft eligible (check stage)
	if stage == Player.PlayerStage.DRAFT_ELIGIBLE:
		if player not in _draft_eligible:
			_draft_eligible.append(player)


## Get player field value, handling both Player resource and Dictionary
## @param player: Player resource or Dictionary
## @param field: Field name to retrieve
## @param default: Default value if field not found
## @return: Field value or default
func _get_player_field(player: Variant, field: String, default: Variant) -> Variant:
	if player is Player:
		match field:
			"id":
				return player.id
			"position":
				return player.position
			"stage":
				return int(player.stage)
			"age":
				return player.age
			_:
				return default
	elif player is Dictionary:
		return player.get(field, default)
	return default


## Categorize age into bucket for indexing
## @param age: Player age in years
## @return: "young", "prime", or "veteran"
func _get_age_bucket(age: int) -> String:
	if age <= AGE_YOUNG_MAX:
		return "young"
	elif age <= AGE_PRIME_MAX:
		return "prime"
	else:
		return "veteran"


# =========================
# Primary Query Methods (O(1) lookups)
# =========================

## O(1) lookup by player ID
## @param player_id: Unique player identifier
## @return: Player resource/Dictionary or null if not found
func by_id(player_id: String) -> Variant:
	return _player_by_id.get(player_id, null)


## O(1) lookup by position
## @param pos: Position string (e.g., "QB", "CB", "OL")
## @return: Array of players at that position (empty array if none)
func by_position(pos: String) -> Array:
	return _players_by_position.get(pos, [])


## O(1) lookup by team
## @param team_id: Team identifier
## @return: Array of players on that team (empty array if none)
func by_team(team_id: String) -> Array:
	return _players_by_team.get(team_id, [])


## O(1) lookup by player stage
## @param stage: PlayerStage enum value
## @return: Array of players at that stage (empty array if none)
func by_stage(stage: int) -> Array:
	return _players_by_stage.get(stage, [])


# =========================
# Secondary Query Methods
# =========================

## Get all free agents
## @return: Array of free agent players
func get_free_agents() -> Array:
	return _free_agents


## Get all draft-eligible players
## @return: Array of draft-eligible players
func get_draft_eligible() -> Array:
	return _draft_eligible


## Get players by age category
## @param bucket: "young", "prime", or "veteran"
## @return: Array of players in that age bucket (empty array if none)
func by_age_bucket(bucket: String) -> Array:
	return _players_by_age_bucket.get(bucket, [])


# =========================
# Position Group Queries
# =========================

## Get all quarterbacks
## @return: Array of QB players
func get_quarterbacks() -> Array:
	return by_position("QB")


## Get all offensive line players (OT, OG, C, OL)
## @return: Array of offensive line players
func get_offensive_line() -> Array:
	var result: Array = []
	for pos in ["OT", "OG", "C", "OL"]:
		result.append_array(by_position(pos))
	return result


## Get all defensive line players (DT, DE, DL)
## @return: Array of defensive line players
func get_defensive_line() -> Array:
	var result: Array = []
	for pos in ["DT", "DE", "DL"]:
		result.append_array(by_position(pos))
	return result


## Get all linebackers (ILB, OLB, LB, EDGE)
## @return: Array of linebacker players
func get_linebackers() -> Array:
	var result: Array = []
	for pos in ["ILB", "OLB", "LB", "EDGE"]:
		result.append_array(by_position(pos))
	return result


## Get all secondary players (CB, FS, SS, S)
## @return: Array of secondary/defensive back players
func get_secondary() -> Array:
	var result: Array = []
	for pos in ["CB", "FS", "SS", "S"]:
		result.append_array(by_position(pos))
	return result


## Get all skill position players (QB, RB, WR, TE)
## @return: Array of skill position players
func get_skill_positions() -> Array:
	var result: Array = []
	for pos in ["QB", "RB", "FB", "WR", "TE"]:
		result.append_array(by_position(pos))
	return result


## Get all special teams players (K, P, LS)
## @return: Array of special teams players
func get_special_teams() -> Array:
	var result: Array = []
	for pos in SPECIAL_TEAMS_POSITIONS:
		result.append_array(by_position(pos))
	return result


## Get all offensive players
## @return: Array of all offensive position players
func get_offense() -> Array:
	var result: Array = []
	for pos in OFFENSIVE_POSITIONS:
		result.append_array(by_position(pos))
	return result


## Get all defensive players
## @return: Array of all defensive position players
func get_defense() -> Array:
	var result: Array = []
	for pos in DEFENSIVE_POSITIONS:
		result.append_array(by_position(pos))
	return result


# =========================
# Team Roster Queries
# =========================

## Get team roster with position grouping
## @param team_id: Team identifier
## @return: Dictionary with "offense", "defense", "special_teams" arrays
func get_team_roster_by_group(team_id: String) -> Dictionary:
	var roster := by_team(team_id)
	var result := {
		"offense": [],
		"defense": [],
		"special_teams": []
	}

	for player in roster:
		var pos: String = _get_player_field(player, "position", "")
		if pos in OFFENSIVE_POSITIONS:
			result["offense"].append(player)
		elif pos in DEFENSIVE_POSITIONS:
			result["defense"].append(player)
		elif pos in SPECIAL_TEAMS_POSITIONS:
			result["special_teams"].append(player)

	return result


## Get team roster at specific position
## @param team_id: Team identifier
## @param position: Position to filter by
## @return: Array of players on team at that position
func get_team_position(team_id: String, position: String) -> Array:
	var roster := by_team(team_id)
	var result: Array = []

	for player in roster:
		var pos: String = _get_player_field(player, "position", "")
		if pos == position:
			result.append(player)

	return result


# =========================
# Aggregate Methods
# =========================

## Get all indexed players (for iteration)
## @return: Array of all indexed players
func all_players() -> Array:
	return _player_by_id.values()


## Get total indexed player count
## @return: Number of indexed players
func count() -> int:
	return _player_by_id.size()


## Get count by position
## @param pos: Position string
## @return: Number of players at that position
func count_by_position(pos: String) -> int:
	return by_position(pos).size()


## Get count by team
## @param team_id: Team identifier
## @return: Number of players on that team
func count_by_team(team_id: String) -> int:
	return by_team(team_id).size()


## Get all indexed positions
## @return: Array of position strings that have indexed players
func get_indexed_positions() -> Array:
	return _players_by_position.keys()


## Get all indexed team IDs
## @return: Array of team ID strings that have indexed players
func get_indexed_teams() -> Array:
	return _players_by_team.keys()


# =========================
# Filter Utilities
# =========================

## Filter players by minimum age
## @param players: Array of players to filter
## @param min_age: Minimum age (inclusive)
## @return: Filtered array
func filter_by_min_age(players: Array, min_age: int) -> Array:
	var result: Array = []
	for player in players:
		var age: int = _get_player_field(player, "age", 0)
		if age >= min_age:
			result.append(player)
	return result


## Filter players by maximum age
## @param players: Array of players to filter
## @param max_age: Maximum age (inclusive)
## @return: Filtered array
func filter_by_max_age(players: Array, max_age: int) -> Array:
	var result: Array = []
	for player in players:
		var age: int = _get_player_field(player, "age", 0)
		if age <= max_age:
			result.append(player)
	return result


## Filter players by age range
## @param players: Array of players to filter
## @param min_age: Minimum age (inclusive)
## @param max_age: Maximum age (inclusive)
## @return: Filtered array
func filter_by_age_range(players: Array, min_age: int, max_age: int) -> Array:
	var result: Array = []
	for player in players:
		var age: int = _get_player_field(player, "age", 0)
		if age >= min_age and age <= max_age:
			result.append(player)
	return result


## Filter players by stage
## @param players: Array of players to filter
## @param stage: PlayerStage enum value
## @return: Filtered array
func filter_by_stage(players: Array, stage: int) -> Array:
	var result: Array = []
	for player in players:
		var player_stage: int = _get_player_field(player, "stage", -1)
		if player_stage == stage:
			result.append(player)
	return result
