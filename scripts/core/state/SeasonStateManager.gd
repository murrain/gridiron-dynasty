extends RefCounted
class_name SeasonStateManager

## SeasonStateManager - Single interface for all season state mutations
##
## CRITICAL CONTRACT: ALL season state mutations MUST flow through this manager.
## This ensures atomic updates with automatic DataBus notifications.
##
## Core Principles:
## 1. Every mutation method calls pure functions from scripts/core/transformations/
## 2. Updates world_state atomically (all-or-nothing)
## 3. Emits appropriate DataBus signals automatically
## 4. Never mutates input parameters (except world_state itself)
## 5. Returns summary data for logging/debugging
##
## Usage:
##   # Record game result and update standings
##   var result := SeasonStateManager.record_game_result(
##       world_state,
##       ["nfl_standings", year],
##       game_result
##   )
##
##   # Advance season phase
##   var success := SeasonStateManager.advance_season_phase(
##       world_state,
##       ["nfl_season_state"],
##       SeasonStateMachine.SeasonPhase.REGULAR_SEASON,
##       SeasonStateMachine.SeasonPhase.PLAYOFFS
##   )
##
##   # Prepare roster for season
##   var prepared := SeasonStateManager.update_roster_for_season(
##       world_state,
##       ["nfl_rosters", team_id],
##       configs
##   )

const Player = preload("res://scripts/core/models/Player.gd")
const SeasonStateMachine = preload("res://scripts/core/state/SeasonStateMachine.gd")
const SeasonTransformations = preload("res://scripts/core/transformations/SeasonTransformations.gd")

# ============================================================================
# PUBLIC API - State Mutation Methods
# ============================================================================

## Record game result and update standings atomically.
##
## This is the primary method for recording game outcomes during season simulation.
## It calls SeasonTransformations.apply_game_result() (pure function), then updates
## world_state and notifies DataBus subscribers.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   standings_path: Path to standings in world_state (e.g., ["nfl_standings", 2033])
##   game_result: Game outcome data (home/away teams, scores, week, etc.)
##
## Returns:
##   Dictionary with result summary:
##   {
##     "success": bool,
##     "standings_updated": bool,
##     "home_team": String,
##     "away_team": String,
##     "winner": String
##   }
##
## Side Effects:
##   - Mutates world_state at standings_path
##   - Emits DataBus.collection_changed signal
static func record_game_result(
	world_state: Dictionary,
	standings_path: Array,
	game_result: Dictionary
) -> Dictionary:
	# Validate inputs
	if world_state == null or world_state.is_empty():
		push_error("SeasonStateManager.record_game_result: world_state is null or empty")
		return _error_result("world_state is null or empty")

	if standings_path.is_empty():
		push_error("SeasonStateManager.record_game_result: standings_path is empty")
		return _error_result("standings_path is empty")

	if game_result.is_empty():
		push_error("SeasonStateManager.record_game_result: game_result is empty")
		return _error_result("game_result is empty")

	# Extract current standings from world_state
	var current_standings: Variant = _extract_value(world_state, standings_path)
	if current_standings == null:
		# Initialize empty standings if path doesn't exist
		current_standings = {}

	# Apply game result using pure function
	# RNG consumption: NONE (deterministic)
	var new_standings := SeasonTransformations.apply_game_result(
		current_standings,
		game_result
	)

	# Update world_state atomically
	_replace_value(world_state, standings_path, new_standings)

	# Extract game info for logging
	var home_team := String(game_result.get("home_team_id", ""))
	var away_team := String(game_result.get("away_team_id", ""))
	var home_score: int = int(game_result.get("home_score", 0))
	var away_score: int = int(game_result.get("away_score", 0))
	var winner := ""
	if home_score > away_score:
		winner = home_team
	elif away_score > home_score:
		winner = away_team
	else:
		winner = "TIE"

	# Log for audit trail
	print_verbose("SeasonStateManager: Game result recorded - %s %d vs %s %d (Winner: %s)" % [
		home_team, home_score, away_team, away_score, winner
	])

	# Emit DataBus notification
	var collection_name := String(standings_path[0]) if not standings_path.is_empty() else "standings"
	_notify_collection_changed(collection_name, "update")

	return {
		"success": true,
		"standings_updated": true,
		"home_team": home_team,
		"away_team": away_team,
		"winner": winner,
		"home_score": home_score,
		"away_score": away_score
	}

## Record multiple game results in batch.
##
## Convenience method to record multiple games efficiently.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   standings_path: Path to standings in world_state
##   game_results: Array of game result dictionaries
##
## Returns:
##   Dictionary with summary:
##   {
##     "success": bool,
##     "games_recorded": int,
##     "results": Array[Dictionary]
##   }
static func record_game_results(
	world_state: Dictionary,
	standings_path: Array,
	game_results: Array
) -> Dictionary:
	# Validate inputs
	if world_state == null or world_state.is_empty():
		push_error("SeasonStateManager.record_game_results: world_state is null or empty")
		return {"success": false, "games_recorded": 0, "results": []}

	if standings_path.is_empty():
		push_error("SeasonStateManager.record_game_results: standings_path is empty")
		return {"success": false, "games_recorded": 0, "results": []}

	if game_results.is_empty():
		return {"success": true, "games_recorded": 0, "results": []}

	# Extract current standings
	var current_standings: Variant = _extract_value(world_state, standings_path)
	if current_standings == null:
		current_standings = {}

	# Apply all game results using pure function
	var new_standings := SeasonTransformations.apply_game_results(
		current_standings,
		game_results
	)

	# Update world_state atomically
	_replace_value(world_state, standings_path, new_standings)

	# Emit DataBus notification
	var collection_name := String(standings_path[0]) if not standings_path.is_empty() else "standings"
	_notify_collection_changed(collection_name, "bulk_update")

	print_verbose("SeasonStateManager: %d game results recorded" % game_results.size())

	return {
		"success": true,
		"games_recorded": game_results.size(),
		"results": game_results
	}

## Advance season phase with validation.
##
## Validates the transition using SeasonStateMachine, updates the season state,
## and emits DataBus notification.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   season_state_path: Path to season state (e.g., ["nfl_season_state"])
##   from_phase: Expected current phase (for validation)
##   to_phase: Target phase to transition to
##
## Returns:
##   bool: true if transition succeeded, false if validation failed
##
## Side Effects:
##   - Mutates season phase in world_state
##   - Emits DataBus.phase_completed signal
static func advance_season_phase(
	world_state: Dictionary,
	season_state_path: Array,
	from_phase: SeasonStateMachine.SeasonPhase,
	to_phase: SeasonStateMachine.SeasonPhase
) -> bool:
	# Validate inputs
	if world_state == null or world_state.is_empty():
		push_error("SeasonStateManager.advance_season_phase: world_state is null or empty")
		return false

	if season_state_path.is_empty():
		push_error("SeasonStateManager.advance_season_phase: season_state_path is empty")
		return false

	# Validate transition is legal
	if not SeasonStateMachine.can_transition(from_phase, to_phase):
		push_warning("SeasonStateManager.advance_season_phase: Invalid transition %s -> %s" % [
			SeasonStateMachine.get_phase_name(from_phase),
			SeasonStateMachine.get_phase_name(to_phase)
		])
		return false

	# Extract season state from world_state
	var season_state: Variant = _extract_value(world_state, season_state_path)
	if season_state == null:
		push_warning("SeasonStateManager.advance_season_phase: Season state not found at path %s" % str(season_state_path))
		return false

	if not season_state is Dictionary:
		push_error("SeasonStateManager.advance_season_phase: Season state is not a Dictionary")
		return false

	var current_phase: int = int(season_state.get("phase", -1))

	# Verify from_phase matches current phase
	if current_phase != from_phase:
		push_warning("SeasonStateManager.advance_season_phase: Phase mismatch. Expected %s, found %s" % [
			SeasonStateMachine.get_phase_name(from_phase),
			SeasonStateMachine.get_phase_name(current_phase)
		])
		return false

	# Create updated season state (pure function pattern)
	var new_season_state: Dictionary = season_state.duplicate(true)
	new_season_state["phase"] = to_phase
	new_season_state["phase_transition_timestamp"] = Time.get_ticks_msec()

	# Update world_state
	_replace_value(world_state, season_state_path, new_season_state)

	# Log transition for audit trail
	print_verbose("SeasonStateManager: Season phase transition %s -> %s" % [
		SeasonStateMachine.get_phase_name(from_phase),
		SeasonStateMachine.get_phase_name(to_phase)
	])

	# Emit DataBus notification
	var year: int = int(season_state.get("year", 0))
	_notify_phase_completed(SeasonStateMachine.get_phase_name(to_phase), year)

	return true

## Update roster for season simulation.
##
## Prepares a team's roster for season simulation by calling pure transformation
## functions to calculate derived stats, validate data, and add simulation context.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   roster_path: Path to roster in world_state (e.g., ["nfl_rosters", "SF"])
##   configs: Configuration dictionaries (positions, stats, etc.)
##
## Returns:
##   Dictionary with preparation summary:
##   {
##     "success": bool,
##     "roster_prepared": bool,
##     "players_count": int,
##     "team_id": String
##   }
##
## Side Effects:
##   - Mutates roster data in world_state
##   - Emits DataBus.collection_changed signal
static func update_roster_for_season(
	world_state: Dictionary,
	roster_path: Array,
	configs: Dictionary
) -> Dictionary:
	# Validate inputs
	if world_state == null or world_state.is_empty():
		push_error("SeasonStateManager.update_roster_for_season: world_state is null or empty")
		return _error_result("world_state is null or empty")

	if roster_path.is_empty():
		push_error("SeasonStateManager.update_roster_for_season: roster_path is empty")
		return _error_result("roster_path is empty")

	# Extract roster from world_state
	var roster: Variant = _extract_value(world_state, roster_path)
	if roster == null or not roster is Dictionary:
		push_error("SeasonStateManager.update_roster_for_season: Roster not found or invalid at path %s" % str(roster_path))
		return _error_result("Roster not found or invalid")

	# Prepare roster using pure function
	# RNG consumption: NONE (deterministic preparation)
	var prepared_roster := SeasonTransformations.prepare_roster(roster, configs)

	# Update world_state atomically
	_replace_value(world_state, roster_path, prepared_roster)

	# Extract info for logging
	var team_id := String(prepared_roster.get("team_id", "UNKNOWN"))
	var players: Array = prepared_roster.get("players", [])
	var players_count := players.size()

	# Log for audit trail
	print_verbose("SeasonStateManager: Roster prepared for %s (%d players)" % [team_id, players_count])

	# Emit DataBus notification
	var collection_name := String(roster_path[0]) if not roster_path.is_empty() else "rosters"
	_notify_collection_changed(collection_name, "update")

	return {
		"success": true,
		"roster_prepared": true,
		"players_count": players_count,
		"team_id": team_id
	}

## Process draft eligibility transitions.
##
## Takes college players and determines which ones become draft eligible based
## on eligibility rules (class year, age, opt-in decisions).
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   players_path: Path to players array (e.g., ["college_rosters", school_id, "players"])
##   eligibility_rules: Rules for draft eligibility
##   rng: RandomNumberGenerator for opt-in decisions
##
## Returns:
##   Dictionary with transition summary:
##   {
##     "success": bool,
##     "eligible_count": int,
##     "remaining_count": int,
##     "eligible_players": Array[Dictionary]
##   }
##
## Side Effects:
##   - Mutates player stages in world_state
##   - Potentially moves players to draft_pool collection
##   - Emits DataBus.collection_changed and DataBus.players_changed signals
static func process_draft_eligibility(
	world_state: Dictionary,
	players_path: Array,
	eligibility_rules: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	# Validate inputs
	if world_state == null or world_state.is_empty():
		push_error("SeasonStateManager.process_draft_eligibility: world_state is null or empty")
		return _error_result("world_state is null or empty")

	if players_path.is_empty():
		push_error("SeasonStateManager.process_draft_eligibility: players_path is empty")
		return _error_result("players_path is empty")

	if rng == null:
		push_error("SeasonStateManager.process_draft_eligibility: rng is null")
		return _error_result("rng is null")

	# Extract players from world_state
	var players: Variant = _extract_value(world_state, players_path)
	if players == null or not players is Array:
		push_warning("SeasonStateManager.process_draft_eligibility: Players not found at path %s" % str(players_path))
		return _error_result("Players not found or invalid")

	# Process eligibility using pure function
	# RNG consumption: 1 call per player (for opt-in decisions)
	var result := SeasonTransformations.transition_to_draft_eligible(
		players,
		eligibility_rules,
		rng
	)

	var eligible: Array = result.get("eligible", [])
	var remaining: Array = result.get("remaining", [])

	# Update world_state with remaining players
	_replace_value(world_state, players_path, remaining)

	# Add eligible players to draft pool (if path exists)
	if not eligible.is_empty() and world_state.has("draft_pool"):
		var draft_pool: Array = world_state.get("draft_pool", [])
		for player_dict in eligible:
			draft_pool.append(player_dict)
		world_state["draft_pool"] = draft_pool

	# Log for audit trail
	print_verbose("SeasonStateManager: Draft eligibility processed - %d eligible, %d remaining" % [
		eligible.size(),
		remaining.size()
	])

	# Emit DataBus notifications
	var collection_name := String(players_path[0]) if not players_path.is_empty() else "players"
	_notify_collection_changed(collection_name, "bulk_update")
	if not eligible.is_empty():
		_notify_collection_changed("draft_pool", "bulk_update")
		_notify_players_changed(Player.PlayerStage.DRAFT_ELIGIBLE, eligible.size())

	return {
		"success": true,
		"eligible_count": eligible.size(),
		"remaining_count": remaining.size(),
		"eligible_players": eligible.duplicate()  # Return copy for logging/tracking
	}

# ============================================================================
# INTERNAL HELPERS - State Access & Navigation
# ============================================================================

## Extract a value from world_state using a path.
##
## Parameters:
##   world_state: Global game state dictionary
##   path: Array of keys to navigate (e.g., ["nfl_rosters", "SF", "players"])
##
## Returns:
##   Variant: The value at the path, or null if path invalid
static func _extract_value(world_state: Dictionary, path: Array) -> Variant:
	if path.is_empty():
		return null

	var current: Variant = world_state
	for key in path:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return null

	return current

## Replace a value in world_state at a specific path.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   path: Array of keys to navigate
##   new_value: New value to set at the path
##
## Returns:
##   bool: true if replacement succeeded, false if path invalid
static func _replace_value(
	world_state: Dictionary,
	path: Array,
	new_value: Variant
) -> bool:
	if path.is_empty():
		return false

	# Navigate to parent of the target
	var current: Variant = world_state
	for i in range(path.size() - 1):
		var key = path[i]
		if current is Dictionary:
			# Create nested structure if it doesn't exist
			if not current.has(key):
				current[key] = {}
			current = current[key]
		else:
			return false

	# Set the value at the final key
	var final_key = path[-1]
	if current is Dictionary:
		current[final_key] = new_value
		return true

	return false

# ============================================================================
# INTERNAL HELPERS - DataBus Integration
# ============================================================================

## Helper to get DataBus autoload safely (returns null in headless mode).
## This avoids compile-time identifier resolution issues when running as -s script.
static func _get_databus() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var root := (main_loop as SceneTree).root
		if root.has_node("DataBus"):
			return root.get_node("DataBus")
	return null

## Notify DataBus that a collection has changed.
static func _notify_collection_changed(collection_name: String, operation: String) -> void:
	var databus := _get_databus()
	if databus:
		databus.notify_collection_changed(collection_name, operation)

## Notify DataBus that a phase has completed.
static func _notify_phase_completed(phase_id: String, year: int) -> void:
	var databus := _get_databus()
	if databus:
		databus.notify_phase_completed(phase_id, year)

## Notify DataBus that players have changed for a specific stage
static func _notify_players_changed(stage: Player.PlayerStage, count: int) -> void:
	var databus := _get_databus()
	if databus:
		databus.notify_players_changed(stage, count)

# ============================================================================
# INTERNAL HELPERS - Utilities
# ============================================================================

## Create error result dictionary
static func _error_result(error_message: String) -> Dictionary:
	return {
		"success": false,
		"error": error_message
	}
