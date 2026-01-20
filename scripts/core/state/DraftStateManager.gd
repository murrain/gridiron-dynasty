extends RefCounted
class_name DraftStateManager

## DraftStateManager - Single interface for all draft state mutations
##
## CRITICAL CONTRACT: ALL draft state mutations MUST flow through this manager.
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
##   # Initialize draft structures
##   var result := DraftStateManager.initialize_draft(
##       world_state,
##       teams,
##       year,
##       league_cfg,
##       class_rules,
##       seed
##   )
##
##   # Execute a draft pick
##   var pick_result := DraftStateManager.execute_pick(
##       world_state,
##       player_id,
##       team_id,
##       draft_info,
##       contract,
##       year
##   )
##
##   # Trade a draft pick
##   var trade_result := DraftStateManager.execute_trade(
##       world_state,
##       year,
##       round_num,
##       original_team_id,
##       new_owner_id
##   )
##
##   # Record draft history at end of draft
##   DraftStateManager.record_draft_history(world_state, picks, year)

const DraftTransformations = preload("res://scripts/core/transformations/DraftTransformations.gd")
const DraftStateMachine = preload("res://scripts/core/state/DraftStateMachine.gd")

# ============================================================================
# PUBLIC API - State Mutation Methods
# ============================================================================

## Initialize draft structures for a given year.
##
## This is the first method called to set up a draft. It:
## - Initializes pick ownership ledger (who owns which picks)
## - Generates team scouting quality metrics (cached for consistency)
## - Sets draft state to INITIALIZING
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   teams: Array of team dictionaries with "id" fields
##   year: Draft year to initialize
##   league_cfg: League configuration with draft settings
##   class_rules: Class rules configuration with team quality tiers
##   seed: RNG seed for deterministic scouting quality generation
##
## Returns:
##   Dictionary with initialization summary:
##   {
##     "year": int,
##     "teams_count": int,
##     "rounds": int,
##     "scouting_initialized": bool,
##     "picks_allocated": bool,
##     "state": DraftStateMachine.State
##   }
##
## Side Effects:
##   - Mutates world_state["draft_pick_ownership"]
##   - Mutates world_state["nfl_scouting_quality"] (if not already present)
##   - Mutates world_state["draft_state"] (if not present)
##   - Emits DataBus.collection_changed("draft_pick_ownership", "initialize")
##   - Emits DataBus.collection_changed("nfl_scouting_quality", "initialize")
static func initialize_draft(
	world_state: Dictionary,
	teams: Array,
	year: int,
	league_cfg: Dictionary,
	class_rules: Dictionary,
	seed: int
) -> Dictionary:
	# Validate inputs
	if world_state == null or world_state.is_empty():
		push_error("DraftStateManager.initialize_draft: world_state is null or empty")
		return _empty_init_result()

	if teams.is_empty():
		push_error("DraftStateManager.initialize_draft: teams array is empty")
		return _empty_init_result()

	# Initialize draft state tracking if not present
	if not world_state.has("draft_state"):
		world_state["draft_state"] = {
			"state": DraftStateMachine.State.NOT_STARTED,
			"current_year": year,
			"current_round": 0,
			"current_pick": 0
		}

	var draft_state: Dictionary = world_state["draft_state"]

	# Validate state transition
	var current_state: DraftStateMachine.State = int(draft_state.get("state", DraftStateMachine.State.NOT_STARTED))
	if not DraftStateMachine.can_initialize(current_state):
		push_warning("DraftStateManager.initialize_draft: Cannot initialize draft in state %s" %
			DraftStateMachine._state_to_string(current_state))
		return _empty_init_result()

	# Transition to INITIALIZING
	DraftStateMachine.transition_state(draft_state, DraftStateMachine.State.INITIALIZING, "draft_setup")

	var draft_cfg: Dictionary = league_cfg.get("draft", {})
	var rounds := int(draft_cfg.get("rounds", 7))

	# Initialize pick ownership if not present
	var picks_allocated := false
	if not world_state.has("draft_pick_ownership"):
		var ownership := DraftTransformations.allocate_draft_picks(teams, year, rounds)
		world_state["draft_pick_ownership"] = ownership
		picks_allocated = true
		_notify_collection_changed("draft_pick_ownership", "initialize")

	# Initialize team scouting quality (once per world, cached)
	var scouting_initialized := false
	if not world_state.has("nfl_scouting_quality"):
		var scouting_quality := DraftTransformations.generate_scouting_quality(
			teams, class_rules, seed
		)
		world_state["nfl_scouting_quality"] = scouting_quality
		scouting_initialized = true
		_notify_collection_changed("nfl_scouting_quality", "initialize")

	# Update draft state
	draft_state["current_year"] = year
	draft_state["current_round"] = 0
	draft_state["current_pick"] = 0

	# Log initialization
	print_verbose("DraftStateManager: Initialized draft for year %d (%d teams, %d rounds)" % [
		year, teams.size(), rounds
	])

	return {
		"year": year,
		"teams_count": teams.size(),
		"rounds": rounds,
		"scouting_initialized": scouting_initialized,
		"picks_allocated": picks_allocated,
		"state": draft_state["state"]
	}


## Execute a draft pick atomically.
##
## This method:
## - Validates draft state allows pick execution
## - Removes player from draft pool using pure transformation
## - Adds player to team roster with contract and draft info
## - Updates world_state atomically
## - Emits DataBus notifications
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   player_id: ID of player being drafted
##   team_id: ID of team making the pick
##   draft_info: Dictionary with pick metadata (year, round, pick, team_id)
##   contract: Contract dictionary for the drafted player
##   year: Draft year
##
## Returns:
##   Dictionary with pick summary:
##   {
##     "success": bool,
##     "player_id": String,
##     "team_id": String,
##     "round": int,
##     "pick": int,
##     "pool_remaining": int
##   }
##
## Side Effects:
##   - Mutates world_state["draft_pool"][year] (removes drafted player)
##   - Mutates world_state["nfl_rosters"][team_id] (adds player)
##   - Mutates world_state["draft_state"]["current_pick"]
##   - Emits DataBus.collection_changed("draft_pool", "update")
##   - Emits DataBus.collection_changed("nfl_rosters", "update")
static func execute_pick(
	world_state: Dictionary,
	player_id: String,
	team_id: String,
	draft_info: Dictionary,
	contract: Dictionary,
	year: int
) -> Dictionary:
	# Validate inputs
	if world_state == null or world_state.is_empty():
		push_error("DraftStateManager.execute_pick: world_state is null or empty")
		return _empty_pick_result()

	# Validate draft state
	var draft_state: Dictionary = world_state.get("draft_state", {})
	var current_state: DraftStateMachine.State = int(draft_state.get("state", DraftStateMachine.State.NOT_STARTED))

	if not DraftStateMachine.can_execute_pick(current_state):
		push_warning("DraftStateManager.execute_pick: Cannot execute pick in state %s" %
			DraftStateMachine._state_to_string(current_state))
		return _empty_pick_result()

	# Extract draft pool for this year
	var draft_pool_all: Dictionary = world_state.get("draft_pool", {})
	var draft_pool: Array = draft_pool_all.get(year, [])

	if draft_pool.is_empty():
		push_warning("DraftStateManager.execute_pick: Draft pool is empty for year %d" % year)
		return _empty_pick_result()

	# Extract rosters
	var rosters: Dictionary = world_state.get("nfl_rosters", {})

	# Apply pure transformation
	var result := DraftTransformations.apply_draft_pick(
		draft_pool,
		rosters,
		player_id,
		team_id,
		draft_info,
		contract
	)

	if result["drafted_player"].is_empty():
		push_error("DraftStateManager.execute_pick: Failed to draft player %s" % player_id)
		return _empty_pick_result()

	# Update world_state atomically
	draft_pool_all[year] = result["updated_pool"]
	world_state["draft_pool"] = draft_pool_all
	world_state["nfl_rosters"] = result["updated_rosters"]

	# Update draft state progress
	var current_pick := int(draft_state.get("current_pick", 0))
	draft_state["current_pick"] = current_pick + 1

	# Emit DataBus notifications
	_notify_collection_changed("draft_pool", "update")
	_notify_collection_changed("nfl_rosters", "update")

	# Log pick
	var round_num := int(draft_info.get("round", 0))
	var pick_num := int(draft_info.get("pick", 0))
	print_verbose("DraftStateManager: Pick %d (Rd %d) - %s drafted %s" % [
		pick_num, round_num, team_id, player_id
	])

	return {
		"success": true,
		"player_id": player_id,
		"team_id": team_id,
		"round": round_num,
		"pick": pick_num,
		"pool_remaining": result["updated_pool"].size()
	}


## Execute a draft pick trade atomically.
##
## This method:
## - Validates the trade is legal
## - Updates pick ownership using pure transformation
## - Updates world_state atomically
## - Emits DataBus notifications
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   year: Draft year of the pick
##   round_num: Round number (1-7)
##   original_team_id: Team that originally owned the pick
##   new_owner_id: Team that now owns the pick
##
## Returns:
##   Dictionary with trade summary:
##   {
##     "success": bool,
##     "year": int,
##     "round": int,
##     "original_owner": String,
##     "new_owner": String
##   }
##
## Side Effects:
##   - Mutates world_state["draft_pick_ownership"]
##   - Emits DataBus.collection_changed("draft_pick_ownership", "update")
static func execute_trade(
	world_state: Dictionary,
	year: int,
	round_num: int,
	original_team_id: String,
	new_owner_id: String
) -> Dictionary:
	# Validate inputs
	if world_state == null or world_state.is_empty():
		push_error("DraftStateManager.execute_trade: world_state is null or empty")
		return {
			"success": false,
			"year": year,
			"round": round_num,
			"original_owner": original_team_id,
			"new_owner": new_owner_id
		}

	# Extract current ownership
	var ownership: Dictionary = world_state.get("draft_pick_ownership", {})

	# Apply pure transformation
	var new_ownership := DraftTransformations.apply_pick_trade(
		ownership,
		year,
		round_num,
		original_team_id,
		new_owner_id
	)

	# Update world_state atomically
	world_state["draft_pick_ownership"] = new_ownership

	# Emit DataBus notification
	_notify_collection_changed("draft_pick_ownership", "update")

	# Log trade
	print_verbose("DraftStateManager: Pick traded - %d Rd %d from %s to %s" % [
		year, round_num, original_team_id, new_owner_id
	])

	return {
		"success": true,
		"year": year,
		"round": round_num,
		"original_owner": original_team_id,
		"new_owner": new_owner_id
	}


## Record draft history at completion of draft.
##
## This method:
## - Generates draft history from picks array using pure transformation
## - Stores history in world_state
## - Transitions draft state to COMPLETED
## - Emits DataBus notifications
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   picks: Array of pick dictionaries from draft execution
##   year: Draft year
##
## Returns:
##   Dictionary with history summary:
##   {
##     "year": int,
##     "picks_recorded": int,
##     "state": DraftStateMachine.State
##   }
##
## Side Effects:
##   - Mutates world_state["draft_history"][year]
##   - Mutates world_state["draft_state"]["state"]
##   - Emits DataBus.collection_changed("draft_history", "insert")
##   - Emits DataBus.phase_completed("nfl_draft", year)
static func record_draft_history(
	world_state: Dictionary,
	picks: Array,
	year: int
) -> Dictionary:
	# Validate inputs
	if world_state == null or world_state.is_empty():
		push_error("DraftStateManager.record_draft_history: world_state is null or empty")
		return {"year": year, "picks_recorded": 0, "state": DraftStateMachine.State.NOT_STARTED}

	# Extract rosters for player lookup
	var rosters: Dictionary = world_state.get("nfl_rosters", {})

	# Generate history using pure transformation
	var history_entries := DraftTransformations.generate_draft_history(picks, rosters, year)

	# Store in world_state
	if not world_state.has("draft_history"):
		world_state["draft_history"] = {}

	var draft_history: Dictionary = world_state["draft_history"]
	draft_history[year] = history_entries
	world_state["draft_history"] = draft_history

	# Transition draft state to COMPLETED
	var draft_state: Dictionary = world_state.get("draft_state", {})
	DraftStateMachine.transition_state(draft_state, DraftStateMachine.State.COMPLETED, "draft_finished")

	# Emit DataBus notifications
	_notify_collection_changed("draft_history", "insert")
	_notify_phase_completed("nfl_draft", year)

	# Log history recording
	print_verbose("DraftStateManager: Recorded draft history for %d (%d picks)" % [
		year, history_entries.size()
	])

	return {
		"year": year,
		"picks_recorded": history_entries.size(),
		"state": draft_state["state"]
	}


## Store undrafted players at end of draft.
##
## This method:
## - Stores remaining draft pool as undrafted free agents
## - Updates world_state atomically
## - Emits DataBus notifications
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   remaining_players: Array of player dictionaries not drafted
##   year: Draft year
##
## Returns:
##   Dictionary with summary:
##   {
##     "year": int,
##     "undrafted_count": int
##   }
##
## Side Effects:
##   - Mutates world_state["undrafted_pool"][year]
##   - Emits DataBus.collection_changed("undrafted_pool", "insert")
static func store_undrafted_players(
	world_state: Dictionary,
	remaining_players: Array,
	year: int
) -> Dictionary:
	# Validate inputs
	if world_state == null or world_state.is_empty():
		push_error("DraftStateManager.store_undrafted_players: world_state is null or empty")
		return {"year": year, "undrafted_count": 0}

	# Store undrafted pool
	if not world_state.has("undrafted_pool"):
		world_state["undrafted_pool"] = {}

	var undrafted_pool: Dictionary = world_state["undrafted_pool"]
	undrafted_pool[year] = remaining_players.duplicate(true)
	world_state["undrafted_pool"] = undrafted_pool

	# Emit DataBus notification
	_notify_collection_changed("undrafted_pool", "insert")

	# Log undrafted count
	print_verbose("DraftStateManager: Stored %d undrafted players for year %d" % [
		remaining_players.size(), year
	])

	return {
		"year": year,
		"undrafted_count": remaining_players.size()
	}


## Start draft execution (transition from INITIALIZING to RUNNING).
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   year: Draft year
##   round_num: Starting round (typically 1)
##
## Returns:
##   bool: True if transition succeeded
##
## Side Effects:
##   - Mutates world_state["draft_state"]
static func start_draft(
	world_state: Dictionary,
	year: int,
	round_num: int = 1
) -> bool:
	if world_state == null or world_state.is_empty():
		push_error("DraftStateManager.start_draft: world_state is null or empty")
		return false

	var draft_state: Dictionary = world_state.get("draft_state", {})
	var success := DraftStateMachine.transition_state(
		draft_state,
		DraftStateMachine.State.RUNNING,
		"start_draft"
	)

	if success:
		draft_state["current_round"] = round_num
		print_verbose("DraftStateManager: Started draft for year %d, round %d" % [year, round_num])

	return success


## Pause draft execution.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##
## Returns:
##   bool: True if transition succeeded
##
## Side Effects:
##   - Mutates world_state["draft_state"]
static func pause_draft(world_state: Dictionary) -> bool:
	if world_state == null or world_state.is_empty():
		push_error("DraftStateManager.pause_draft: world_state is null or empty")
		return false

	var draft_state: Dictionary = world_state.get("draft_state", {})
	return DraftStateMachine.transition_state(draft_state, DraftStateMachine.State.PAUSED, "user_pause")


## Resume paused draft.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##
## Returns:
##   bool: True if transition succeeded
##
## Side Effects:
##   - Mutates world_state["draft_state"]
static func resume_draft(world_state: Dictionary) -> bool:
	if world_state == null or world_state.is_empty():
		push_error("DraftStateManager.resume_draft: world_state is null or empty")
		return false

	var draft_state: Dictionary = world_state.get("draft_state", {})
	return DraftStateMachine.transition_state(draft_state, DraftStateMachine.State.RUNNING, "user_resume")


# ============================================================================
# INTERNAL HELPERS - DataBus Integration
# ============================================================================

## Notify DataBus that a collection has changed.
## DataBus is a global autoload and can be accessed directly by name.
static func _notify_collection_changed(collection_name: String, operation: String) -> void:
	if DataBus:
		DataBus.notify_collection_changed(collection_name, operation)


## Notify DataBus that a phase has completed
static func _notify_phase_completed(phase_id: String, year: int) -> void:
	if DataBus:
		DataBus.notify_phase_completed(phase_id, year)


# ============================================================================
# INTERNAL HELPERS - Result Builders
# ============================================================================

static func _empty_init_result() -> Dictionary:
	return {
		"year": 0,
		"teams_count": 0,
		"rounds": 0,
		"scouting_initialized": false,
		"picks_allocated": false,
		"state": DraftStateMachine.State.NOT_STARTED
	}


static func _empty_pick_result() -> Dictionary:
	return {
		"success": false,
		"player_id": "",
		"team_id": "",
		"round": 0,
		"pick": 0,
		"pool_remaining": 0
	}
