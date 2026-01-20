extends RefCounted
class_name PlayerStateManager

## PlayerStateManager - Single interface for all player state mutations
##
## CRITICAL CONTRACT: ALL player state mutations MUST flow through this manager.
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
##   # Advance all players on a team by one year
##   var result := PlayerStateManager.advance_players_one_year(
##       world_state,
##       ["nfl_rosters", team_id, "players"],
##       context,
##       configs,
##       rng
##   )
##
##   # Transition a single player to new stage
##   var success := PlayerStateManager.transition_player_stage(
##       world_state,
##       player_id,
##       Player.PlayerStage.COLLEGE,
##       Player.PlayerStage.DRAFT_ELIGIBLE,
##       "pre_draft"
##   )

const Player = preload("res://scripts/core/models/Player.gd")
const PlayerLifecycleStateMachine = preload("res://scripts/world/PlayerLifecycleStateMachine.gd")
const StagePipeline = preload("res://scripts/core/transformations/StagePipeline.gd")
const Rand = preload("res://autoloads/Rand.gd")

# ============================================================================
# PUBLIC API - State Mutation Methods
# ============================================================================

## Advance multiple players by one year using pure lifecycle functions.
##
## This is the primary method for player development during season progression.
## It calls StagePipeline.advance_one_year() for each player (pure function),
## then updates world_state and notifies DataBus subscribers.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   collection_path: Path to player array in world_state (e.g., ["nfl_rosters", "SF", "players"])
##   context: Development context (program_quality, usage, coaching, etc.)
##   configs: Game configuration dictionaries (league rules, position configs, etc.)
##   rng: RandomNumberGenerator instance (for deterministic randomness)
##
## Returns:
##   Dictionary with summary stats:
##   {
##     "active_count": int,      # Players still active after advancement
##     "retired_count": int,     # Players who retired this year
##     "collection": String,     # Name of collection that was updated
##     "reports": Array          # Development reports (for debugging)
##   }
##
## Side Effects:
##   - Mutates world_state at collection_path
##   - Emits DataBus.collection_changed signal
static func advance_players_one_year(
	world_state: Dictionary,
	collection_path: Array,
	context: Dictionary,
	configs: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	# Validate inputs
	if world_state == null or world_state.is_empty():
		push_error("PlayerStateManager.advance_players_one_year: world_state is null or empty")
		return {"active_count": 0, "retired_count": 0, "collection": "", "reports": []}

	if collection_path.is_empty():
		push_error("PlayerStateManager.advance_players_one_year: collection_path is empty")
		return {"active_count": 0, "retired_count": 0, "collection": "", "reports": []}

	# Extract players from world_state
	var players := _extract_collection(world_state, collection_path)
	if players.is_empty():
		# No players to process (not an error - collection might be legitimately empty)
		return {"active_count": 0, "retired_count": 0, "collection": String(collection_path[0]), "reports": []}

	# Transform players using pure functions from StagePipeline
	# RNG consumption: ~20-30 calls per player per year (deterministic)
	var active := []
	var retired := []
	var reports := []

	# Process each player with deterministic seed derivation
	var base_seed := int(rng.seed)
	for i in range(players.size()):
		var player_dict: Dictionary = players[i]

		# Derive deterministic seed for this player (ensures reproducibility)
		var player_seed := Rand.splitmix64(base_seed + i)
		var player_rng := RandomNumberGenerator.new()
		player_rng.seed = player_seed

		# Merge global context with player-specific context
		# Player-specific values override global values
		var merged_context := context.duplicate()
		var player_context: Dictionary = player_dict.get("development_context", {}) as Dictionary
		for key in player_context.keys():
			merged_context[key] = player_context[key]

		# Apply pure transformation pipeline
		# RNG calls: ~20-30 per player (stats development + injury + retirement)
		var result := StagePipeline.advance_one_year(player_dict, merged_context, configs, player_rng)

		if result.get("retired", false):
			retired.append(result.player)
			reports.append({
				"player_id": result.player.get("id", ""),
				"retired": true,
				"report": result.get("report", {})
			})
		else:
			active.append(result.player)
			reports.append({
				"player_id": result.player.get("id", ""),
				"retired": false,
				"development": result.get("report", {})
			})

	# Update world_state atomically
	_replace_collection(world_state, collection_path, active)

	# Emit DataBus notification (automatic!)
	var collection_name := String(collection_path[0])
	_notify_collection_changed(collection_name, "bulk_update")

	# Return summary stats and retired players
	return {
		"active_count": active.size(),
		"retired_count": retired.size(),
		"collection": collection_name,
		"reports": reports,
		"retired": retired  # Return retired player dictionaries for tracking
	}


## Transition a single player to a new lifecycle stage.
##
## Validates the transition using PlayerLifecycleStateMachine, applies the
## transition using pure functions, updates world_state, and emits DataBus notification.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   player_id: Unique identifier of the player to transition
##   from_stage: Expected current stage (for validation)
##   to_stage: Target stage to transition to
##   phase_id: Identifier of the phase triggering this transition (for logging)
##
## Returns:
##   bool: true if transition succeeded, false if validation failed or player not found
##
## Side Effects:
##   - Mutates player's stage in world_state
##   - Emits DataBus.players_changed signal
static func transition_player_stage(
	world_state: Dictionary,
	player_id: String,
	from_stage: Player.PlayerStage,
	to_stage: Player.PlayerStage,
	phase_id: String
) -> bool:
	# Validate transition is legal
	if not PlayerLifecycleStateMachine.can_transition(from_stage, to_stage):
		push_warning("PlayerStateManager.transition_player_stage: Invalid transition %s -> %s for player %s (phase: %s)" % [
			_stage_to_string(from_stage),
			_stage_to_string(to_stage),
			player_id,
			phase_id
		])
		return false

	# Find player in world_state
	var location := _find_player(world_state, player_id)
	if location.is_empty():
		push_warning("PlayerStateManager.transition_player_stage: Player %s not found in world_state" % player_id)
		return false

	var player: Dictionary = location.player
	var current_stage: Player.PlayerStage = int(player.get("stage", -1))

	# Verify from_stage matches current stage
	if current_stage != from_stage:
		push_warning("PlayerStateManager.transition_player_stage: Player %s stage mismatch. Expected %s, found %s" % [
			player_id,
			_stage_to_string(from_stage),
			_stage_to_string(current_stage)
		])
		return false

	# TODO: Call TransitionFunctions.transition_stage(player, to_stage) when available
	# For now, create a copy and update stage (pure function pattern)
	var new_player := player.duplicate(true)
	new_player["stage"] = to_stage

	# Update player in world_state
	var success := _replace_player(world_state, location.collection_path, location.index, new_player)
	if not success:
		push_error("PlayerStateManager.transition_player_stage: Failed to update player %s in world_state" % player_id)
		return false

	# Log transition for audit trail
	print_verbose("PlayerStateManager: Player %s transitioned %s -> %s (phase: %s)" % [
		player_id,
		_stage_to_string(from_stage),
		_stage_to_string(to_stage),
		phase_id
	])

	# Emit DataBus notification
	_notify_players_changed(to_stage, 1)

	return true


## Update a single player's stats using pure stat functions.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   player_id: Unique identifier of the player to update
##   stat_changes: Dictionary of stat changes (e.g., {"speed": 85, "strength": 78})
##
## Returns:
##   Dictionary: Updated player dict (copy), or empty dict if player not found
##
## Side Effects:
##   - Mutates player's stats in world_state
##   - Emits DataBus.collection_changed signal
static func update_player_stats(
	world_state: Dictionary,
	player_id: String,
	stat_changes: Dictionary
) -> Dictionary:
	# Find player in world_state
	var location := _find_player(world_state, player_id)
	if location.is_empty():
		push_warning("PlayerStateManager.update_player_stats: Player %s not found in world_state" % player_id)
		return {}

	var player: Dictionary = location.player

	# TODO: Call StatFunctions.apply_stat_changes(player, stat_changes) when available
	# For now, apply changes directly (pure function pattern)
	var new_player := player.duplicate(true)
	var stats_profile: Dictionary = new_player.get("stats_profile", {})
	var current_stats: Dictionary = stats_profile.get("current", {})

	# Apply stat changes
	for stat_name in stat_changes.keys():
		current_stats[stat_name] = stat_changes[stat_name]

	stats_profile["current"] = current_stats
	new_player["stats_profile"] = stats_profile

	# Update player in world_state
	var success := _replace_player(world_state, location.collection_path, location.index, new_player)
	if not success:
		push_error("PlayerStateManager.update_player_stats: Failed to update player %s in world_state" % player_id)
		return {}

	# Emit DataBus notification
	var collection_name := String(location.collection_path[0])
	_notify_collection_changed(collection_name, "update")

	return new_player.duplicate(true)


# ============================================================================
# INTERNAL HELPERS - State Access & Navigation
# ============================================================================

## Find a player by ID across all collections.
##
## Searches through world_state collections to locate a player by their unique ID.
##
## Returns:
##   Dictionary with location metadata:
##   {
##     "collection_path": Array,   # Path to the collection (e.g., ["nfl_rosters", "SF", "players"])
##     "index": int,                # Index of player in the collection
##     "player": Dictionary         # Reference to the player dict (not a copy!)
##   }
##   Empty dictionary if player not found
static func _find_player(world_state: Dictionary, player_id: String) -> Dictionary:
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

	# Search college rosters (nested structure: school_id -> players)
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

	# Search NFL rosters (nested structure: team_id -> players)
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


## Replace a player in world_state at a specific location.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   collection_path: Path to the collection (e.g., ["nfl_rosters", "SF", "players"])
##   index: Index of the player in the collection
##   new_player: New player dictionary to replace the old one
##
## Returns:
##   bool: true if replacement succeeded, false if path invalid
static func _replace_player(
	world_state: Dictionary,
	collection_path: Array,
	index: int,
	new_player: Dictionary
) -> bool:
	if collection_path.is_empty():
		return false

	# Navigate to the collection
	var current: Variant = world_state
	for i in range(collection_path.size() - 1):
		var key = collection_path[i]
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return false

	# Get final key to the array
	var final_key = collection_path[-1]
	if current is Dictionary and current.has(final_key):
		var arr: Array = current[final_key]
		if index >= 0 and index < arr.size():
			arr[index] = new_player
			return true

	return false


## Extract a collection (array of players) from world_state using a path.
##
## Parameters:
##   world_state: Global game state dictionary
##   collection_path: Path to the collection (e.g., ["nfl_rosters", "SF", "players"])
##
## Returns:
##   Array: The collection array, or empty array if path invalid
static func _extract_collection(world_state: Dictionary, collection_path: Array) -> Array:
	if collection_path.is_empty():
		return []

	# Navigate to the collection
	var current: Variant = world_state
	for key in collection_path:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return []

	# Ensure we got an array
	if current is Array:
		return current

	return []


## Replace a collection (array of players) in world_state.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   collection_path: Path to the collection (e.g., ["nfl_rosters", "SF", "players"])
##   new_collection: New array to replace the old collection
static func _replace_collection(
	world_state: Dictionary,
	collection_path: Array,
	new_collection: Array
) -> void:
	if collection_path.is_empty():
		return

	# Navigate to parent of the collection
	var current: Variant = world_state
	for i in range(collection_path.size() - 1):
		var key = collection_path[i]
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return

	# Set the collection at the final key
	var final_key = collection_path[-1]
	if current is Dictionary:
		current[final_key] = new_collection


# ============================================================================
# INTERNAL HELPERS - DataBus Integration
# ============================================================================

## Notify DataBus that a collection has changed.
## DataBus is a global autoload and can be accessed directly by name.
static func _notify_collection_changed(collection_name: String, operation: String) -> void:
	# Access DataBus autoload directly - it's registered in project.godot
	# and available as a global variable
	if DataBus:
		DataBus.notify_collection_changed(collection_name, operation)


## Notify DataBus that players have changed for a specific stage
static func _notify_players_changed(stage: Player.PlayerStage, count: int) -> void:
	if DataBus:
		DataBus.notify_players_changed(stage, count)


# ============================================================================
# INTERNAL HELPERS - Utilities
# ============================================================================

## Convert PlayerStage enum to readable string
static func _stage_to_string(stage: Player.PlayerStage) -> String:
	match stage:
		Player.PlayerStage.HIGH_SCHOOL:
			return "HIGH_SCHOOL"
		Player.PlayerStage.COLLEGE:
			return "COLLEGE"
		Player.PlayerStage.DRAFT_ELIGIBLE:
			return "DRAFT_ELIGIBLE"
		Player.PlayerStage.NFL_ROOKIE:
			return "NFL_ROOKIE"
		Player.PlayerStage.NFL_VETERAN:
			return "NFL_VETERAN"
		Player.PlayerStage.NFL_FREE_AGENT:
			return "NFL_FREE_AGENT"
		Player.PlayerStage.RETIRED:
			return "RETIRED"
		_:
			return "UNKNOWN"
