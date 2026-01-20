extends RefCounted
class_name ContractStateManager

## ContractStateManager - Single interface for all contract state mutations
##
## CRITICAL CONTRACT: ALL contract state mutations MUST flow through this manager.
## This ensures atomic updates with automatic DataBus notifications and cap accounting.
##
## Core Principles:
## 1. Every mutation method calls pure functions from ContractTransformations
## 2. Updates world_state atomically (all-or-nothing)
## 3. Emits appropriate DataBus signals automatically
## 4. Never mutates input parameters (except world_state itself)
## 5. Returns summary data for logging/debugging
## 6. Maintains salary cap integrity across all operations
##
## Usage:
##   # Sign a free agent to a team
##   var result := ContractStateManager.execute_signing(
##       world_state,
##       player_id,
##       team_id,
##       offer,
##       2024
##   )
##
##   # Release a player from roster
##   var success := ContractStateManager.release_player(
##       world_state,
##       player_id,
##       team_id,
##       "roster_cut",
##       2024
##   )
##
##   # Apply franchise tag
##   var tag_result := ContractStateManager.apply_franchise_tag(
##       world_state,
##       player_id,
##       team_id,
##       "exclusive",
##       2024,
##       league_cfg
##   )

const ContractTransformations = preload("res://scripts/core/transformations/ContractTransformations.gd")
const ContractStateMachine = preload("res://scripts/core/state/ContractStateMachine.gd")

# ============================================================================
# PUBLIC API - State Mutation Methods
# ============================================================================

## Execute player signing (pure function pipeline + world_state mutation).
##
## This is the primary method for signing free agents. It:
## 1. Validates player exists and can be signed
## 2. Creates contract from offer (pure function)
## 3. Transitions contract to signed status (pure function)
## 4. Applies contract to player (pure function)
## 5. Updates team roster atomically
## 6. Updates team cap space
## 7. Emits DataBus notifications
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   player_id: Unique identifier of player to sign
##   team_id: Team identifier signing the player
##   offer: Contract offer dictionary (annual_value, years_total, etc.)
##   year: Current year
##
## Returns:
##   Dictionary with signing summary:
##   {
##     "success": bool,
##     "player_id": String,
##     "team_id": String,
##     "contract": Dictionary,
##     "cap_impact": float,
##     "previous_team": String
##   }
##
## Side Effects:
##   - Mutates world_state (adds player to team roster, removes from previous location)
##   - Mutates team cap_space
##   - Emits DataBus.collection_changed for rosters and contracts
static func execute_signing(
	world_state: Dictionary,
	player_id: String,
	team_id: String,
	offer: Dictionary,
	year: int
) -> Dictionary:
	# Validate inputs
	if world_state.is_empty():
		push_error("ContractStateManager.execute_signing: world_state is empty")
		return {"success": false, "error": "empty_world_state"}

	if player_id.is_empty() or team_id.is_empty():
		push_error("ContractStateManager.execute_signing: player_id or team_id is empty")
		return {"success": false, "error": "invalid_ids"}

	if offer.is_empty():
		push_error("ContractStateManager.execute_signing: offer is empty")
		return {"success": false, "error": "empty_offer"}

	# Find player in world_state
	var player_location := _find_player(world_state, player_id, year)
	if player_location.is_empty():
		push_error("ContractStateManager.execute_signing: Player %s not found" % player_id)
		return {"success": false, "error": "player_not_found"}

	var player: Dictionary = player_location.player
	var previous_team := String(player_location.get("team_id", ""))

	# Check if player already has active contract
	if ContractTransformations.has_active_contract(player):
		push_warning("ContractStateManager.execute_signing: Player %s already has active contract" % player_id)
		return {"success": false, "error": "already_signed"}

	# Validate team exists and has cap space
	var team := _find_team(world_state, team_id)
	if team.is_empty():
		push_error("ContractStateManager.execute_signing: Team %s not found" % team_id)
		return {"success": false, "error": "team_not_found"}

	var annual_value := float(offer.get("annual_value", 0.0))
	var cap_space := float(team.get("cap_space", 0.0))
	if annual_value > cap_space:
		push_warning("ContractStateManager.execute_signing: Team %s lacks cap space (need %.2fM, have %.2fM)" % [
			team_id, annual_value, cap_space
		])
		return {"success": false, "error": "insufficient_cap"}

	# === PURE FUNCTION PIPELINE ===

	# 1. Create contract from offer
	var contract := ContractTransformations.create_contract(offer, "free_agency_signed", year)
	if contract.is_empty():
		push_error("ContractStateManager.execute_signing: Failed to create contract")
		return {"success": false, "error": "contract_creation_failed"}

	# 2. Transition contract to signed status
	var transition := ContractTransformations.sign_contract(contract, "free_agency_signed", year)
	contract = transition["contract"]
	var cap_impact: Dictionary = transition.get("cap_impact", {})

	# 3. Apply contract to player (pure function - returns new player)
	var new_player := ContractTransformations.apply_signing(player, contract)

	# === WORLD STATE MUTATIONS ===

	# 4. Update player in world_state (atomic)
	if not _replace_player_in_location(world_state, player_location, new_player):
		push_error("ContractStateManager.execute_signing: Failed to update player in world_state")
		return {"success": false, "error": "update_failed"}

	# 5. Move player to new team roster
	if not _move_player_to_team(world_state, player_id, previous_team, team_id, year):
		push_error("ContractStateManager.execute_signing: Failed to move player to team")
		return {"success": false, "error": "roster_move_failed"}

	# 6. Update team cap space
	var cap_delta := float(cap_impact.get("annual_value_delta", 0.0))
	if not _update_team_cap_space(world_state, team_id, -cap_delta):
		push_error("ContractStateManager.execute_signing: Failed to update cap space")
		return {"success": false, "error": "cap_update_failed"}

	# === DATABUS NOTIFICATIONS ===

	_notify_collection_changed("contracts", "insert")
	_notify_collection_changed("nfl_rosters", "update")
	if not previous_team.is_empty():
		_notify_collection_changed("free_agents", "delete")

	# Log success
	print_verbose("ContractStateManager: Player %s signed to %s for $%.2fM AAV" % [
		player_id, team_id, annual_value
	])

	return {
		"success": true,
		"player_id": player_id,
		"team_id": team_id,
		"previous_team": previous_team,
		"contract": contract,
		"cap_impact": cap_delta,
		"annual_value": annual_value
	}


## Release player from team (pure function pipeline + world_state mutation).
##
## Removes player from roster, marks contract as released, calculates dead cap,
## and updates cap space accordingly.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   player_id: Unique identifier of player to release
##   team_id: Team releasing the player
##   trigger: Release reason ("roster_cut", "cap_casualty", etc.)
##   year: Current year
##
## Returns:
##   Dictionary with release summary:
##   {
##     "success": bool,
##     "player_id": String,
##     "team_id": String,
##     "cap_saved": float,
##     "dead_cap": float,
##     "net_savings": float
##   }
##
## Side Effects:
##   - Mutates world_state (removes player from roster, adds to FA pool)
##   - Mutates team cap_space (adds savings, subtracts dead cap)
##   - Emits DataBus.collection_changed for rosters, contracts, and free_agents
static func release_player(
	world_state: Dictionary,
	player_id: String,
	team_id: String,
	trigger: String,
	year: int
) -> Dictionary:
	# Validate inputs
	if world_state.is_empty():
		push_error("ContractStateManager.release_player: world_state is empty")
		return {"success": false, "error": "empty_world_state"}

	if player_id.is_empty() or team_id.is_empty():
		push_error("ContractStateManager.release_player: player_id or team_id is empty")
		return {"success": false, "error": "invalid_ids"}

	# Find player on team roster
	var player_location := _find_player_on_team(world_state, player_id, team_id)
	if player_location.is_empty():
		push_error("ContractStateManager.release_player: Player %s not found on team %s" % [player_id, team_id])
		return {"success": false, "error": "player_not_found"}

	var player: Dictionary = player_location.player

	# Validate player has releasable contract
	var contract: Dictionary = player.get("contract", {})
	if contract.is_empty():
		push_warning("ContractStateManager.release_player: Player %s has no contract" % player_id)
		return {"success": false, "error": "no_contract"}

	var contract_state_str := String(contract.get("status", "unsigned"))
	var contract_state := ContractStateMachine.string_to_contract_state(contract_state_str)
	if not ContractStateMachine.can_release_contract(contract_state):
		push_warning("ContractStateManager.release_player: Cannot release player in state %s" % contract_state_str)
		return {"success": false, "error": "invalid_contract_state"}

	# === PURE FUNCTION PIPELINE ===

	# Apply release transformation (returns new player with released contract)
	var release_result := ContractTransformations.apply_release(player, trigger, year)
	var new_player: Dictionary = release_result.player
	var cap_impact: Dictionary = release_result.cap_impact

	# Calculate cap changes
	var annual_value := float(contract.get("annual_value", 0.0))
	var dead_cap := float(cap_impact.get("dead_money_delta", 0.0))
	var net_savings := annual_value - dead_cap

	# === WORLD STATE MUTATIONS ===

	# Update player in world_state
	if not _replace_player_in_location(world_state, player_location, new_player):
		push_error("ContractStateManager.release_player: Failed to update player")
		return {"success": false, "error": "update_failed"}

	# Move player from team to free agent pool
	if not _move_player_to_free_agents(world_state, player_id, team_id, year):
		push_error("ContractStateManager.release_player: Failed to move player to FA pool")
		return {"success": false, "error": "roster_move_failed"}

	# Update team cap space (add savings, subtract dead cap)
	if not _update_team_cap_space(world_state, team_id, net_savings):
		push_error("ContractStateManager.release_player: Failed to update cap space")
		return {"success": false, "error": "cap_update_failed"}

	# === DATABUS NOTIFICATIONS ===

	_notify_collection_changed("contracts", "update")
	_notify_collection_changed("nfl_rosters", "update")
	_notify_collection_changed("free_agents", "insert")

	# Log success
	print_verbose("ContractStateManager: Player %s released from %s (saved $%.2fM, dead cap $%.2fM)" % [
		player_id, team_id, net_savings, dead_cap
	])

	return {
		"success": true,
		"player_id": player_id,
		"team_id": team_id,
		"cap_saved": annual_value,
		"dead_cap": dead_cap,
		"net_savings": net_savings
	}


## Apply franchise tag to player (pure function pipeline + world_state mutation).
##
## Applies a franchise tag to an eligible player, creating a 1-year guaranteed contract
## at the position's tag salary.
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   player_id: Player to tag
##   team_id: Team applying the tag
##   tag_type: Tag type ("exclusive", "non_exclusive", "transition")
##   year: Current year
##   league_cfg: League configuration for tag rules
##
## Returns:
##   Dictionary with tag summary:
##   {
##     "success": bool,
##     "player_id": String,
##     "team_id": String,
##     "tag_salary": float,
##     "tag_type": String,
##     "consecutive_years": int
##   }
##
## Side Effects:
##   - Mutates world_state (applies franchise tag contract to player)
##   - Mutates team cap_space
##   - Stores tag in world_state["franchise_tags"][year]
##   - Emits DataBus.collection_changed for contracts and franchise_tags
static func apply_franchise_tag(
	world_state: Dictionary,
	player_id: String,
	team_id: String,
	tag_type: String,
	year: int,
	league_cfg: Dictionary
) -> Dictionary:
	# Validate inputs
	if world_state.is_empty():
		push_error("ContractStateManager.apply_franchise_tag: world_state is empty")
		return {"success": false, "error": "empty_world_state"}

	if player_id.is_empty() or team_id.is_empty():
		push_error("ContractStateManager.apply_franchise_tag: player_id or team_id is empty")
		return {"success": false, "error": "invalid_ids"}

	# Check if team already used tag this year
	if not world_state.has("franchise_tags"):
		world_state["franchise_tags"] = {}

	var year_tags: Dictionary = world_state["franchise_tags"].get(year, {})
	if year_tags.has(team_id):
		push_warning("ContractStateManager.apply_franchise_tag: Team %s already used franchise tag in %d" % [team_id, year])
		return {"success": false, "error": "tag_already_used"}

	# Find player
	var player_location := _find_player(world_state, player_id, year)
	if player_location.is_empty():
		push_error("ContractStateManager.apply_franchise_tag: Player %s not found" % player_id)
		return {"success": false, "error": "player_not_found"}

	var player: Dictionary = player_location.player
	var position := String(player.get("position", ""))

	# Validate player is eligible for tag (unsigned or expired contract)
	var contract: Dictionary = player.get("contract", {})
	var contract_state := ContractStateMachine.ContractState.UNSIGNED
	if not contract.is_empty():
		contract_state = ContractStateMachine.string_to_contract_state(String(contract.get("status", "unsigned")))

	if not ContractStateMachine.is_eligible_for_franchise_tag(contract_state):
		push_warning("ContractStateManager.apply_franchise_tag: Player %s not eligible (state: %s)" % [
			player_id, ContractStateMachine.contract_state_to_string(contract_state)
		])
		return {"success": false, "error": "not_eligible"}

	# === CALCULATE TAG SALARY ===

	# Collect position salaries for tag calculation
	var position_salaries := _collect_position_salaries(world_state, position)
	var tag_salary := ContractTransformations.calculate_franchise_tag_salary(
		position,
		position_salaries,
		tag_type
	)

	# Check consecutive tag years (20% penalty per year)
	var consecutive_years := _get_consecutive_tag_years(world_state, player_id, year)
	if consecutive_years > 0:
		tag_salary *= (1.0 + (0.2 * float(consecutive_years)))

	# Validate team has cap space
	var team := _find_team(world_state, team_id)
	if team.is_empty():
		push_error("ContractStateManager.apply_franchise_tag: Team %s not found" % team_id)
		return {"success": false, "error": "team_not_found"}

	var cap_space := float(team.get("cap_space", 0.0))
	if tag_salary > cap_space:
		push_warning("ContractStateManager.apply_franchise_tag: Team %s lacks cap space (need %.2fM, have %.2fM)" % [
			team_id, tag_salary, cap_space
		])
		return {"success": false, "error": "insufficient_cap"}

	# === PURE FUNCTION PIPELINE ===

	# Apply franchise tag (returns new player with tag contract)
	var tagged_player := ContractTransformations.apply_franchise_tag(
		player,
		tag_salary,
		tag_type,
		year,
		consecutive_years
	)

	# === WORLD STATE MUTATIONS ===

	# Update player in world_state
	if not _replace_player_in_location(world_state, player_location, tagged_player):
		push_error("ContractStateManager.apply_franchise_tag: Failed to update player")
		return {"success": false, "error": "update_failed"}

	# Store franchise tag record
	if not world_state["franchise_tags"].has(year):
		world_state["franchise_tags"][year] = {}

	world_state["franchise_tags"][year][team_id] = {
		"player_id": player_id,
		"team_id": team_id,
		"tag_type": tag_type,
		"salary": tag_salary,
		"applied_year": year,
		"consecutive_years": consecutive_years + 1,
		"position": position
	}

	# Update team cap space
	if not _update_team_cap_space(world_state, team_id, -tag_salary):
		push_error("ContractStateManager.apply_franchise_tag: Failed to update cap space")
		return {"success": false, "error": "cap_update_failed"}

	# === DATABUS NOTIFICATIONS ===

	_notify_collection_changed("contracts", "insert")
	_notify_collection_changed("franchise_tags", "insert")

	# Log success
	print_verbose("ContractStateManager: Franchise tag applied to %s by %s ($%.2fM, %s)" % [
		player_id, team_id, tag_salary, tag_type
	])

	return {
		"success": true,
		"player_id": player_id,
		"team_id": team_id,
		"tag_salary": tag_salary,
		"tag_type": tag_type,
		"consecutive_years": consecutive_years + 1,
		"position": position
	}


## Update team cap space atomically.
##
## Simple atomic operation to add/subtract from team cap space.
## Positive delta = more cap space available
## Negative delta = less cap space available
##
## Parameters:
##   world_state: Global game state dictionary (will be mutated)
##   team_id: Team identifier
##   cap_delta: Change in cap space (positive or negative)
##
## Returns:
##   bool: True if update succeeded, false if team not found
##
## Side Effects:
##   - Mutates team["cap_space"] in world_state
##   - Emits DataBus.collection_changed("teams", "update")
static func update_cap_space(
	world_state: Dictionary,
	team_id: String,
	cap_delta: float
) -> bool:
	return _update_team_cap_space(world_state, team_id, cap_delta)


# ============================================================================
# INTERNAL HELPERS - State Access & Navigation
# ============================================================================

## Find a player by ID across all collections.
##
## Searches through world_state collections to locate a player.
## Checks: nfl_rosters, free_agents, undrafted_pool, college_rosters, draft_pool
##
## Returns:
##   Dictionary with location metadata:
##   {
##     "collection_path": Array,   # Path to the collection
##     "index": int,                # Index in collection (if array)
##     "team_id": String,           # Team ID (if on team roster)
##     "player": Dictionary,        # Reference to player dict (not a copy!)
##     "location_type": String      # "team_roster", "free_agent", "undrafted", etc.
##   }
##   Empty dictionary if player not found
static func _find_player(world_state: Dictionary, player_id: String, year: int = 0) -> Dictionary:
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
					"team_id": String(team_id),
					"player": p,
					"location_type": "team_roster"
				}

	# Search free agents
	var free_agents: Dictionary = world_state.get("free_agents", {})
	if year > 0 and free_agents.has(year):
		var year_fas: Array = free_agents[year]
		for i in range(year_fas.size()):
			var p: Dictionary = year_fas[i]
			if String(p.get("id", "")) == player_id:
				return {
					"collection_path": ["free_agents", year],
					"index": i,
					"team_id": "",
					"player": p,
					"location_type": "free_agent"
				}

	# Search undrafted pool (UDFAs)
	if year > 0:
		var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {})
		if undrafted_pool.has(year):
			var year_pool: Array = undrafted_pool[year]
			for i in range(year_pool.size()):
				var p: Dictionary = year_pool[i]
				if String(p.get("id", "")) == player_id:
					return {
						"collection_path": ["undrafted_pool", year],
						"index": i,
						"team_id": "",
						"player": p,
						"location_type": "undrafted"
					}

	# Player not found
	return {}


## Find player on specific team roster.
##
## More efficient than _find_player if you know the team.
##
## Returns: Same format as _find_player
static func _find_player_on_team(world_state: Dictionary, player_id: String, team_id: String) -> Dictionary:
	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {})
	if not nfl_rosters.has(team_id):
		return {}

	var roster: Dictionary = nfl_rosters[team_id]
	var players: Array = roster.get("players", [])

	for i in range(players.size()):
		var p: Dictionary = players[i]
		if String(p.get("id", "")) == player_id:
			return {
				"collection_path": ["nfl_rosters", team_id, "players"],
				"index": i,
				"team_id": team_id,
				"player": p,
				"location_type": "team_roster"
			}

	return {}


## Replace player in world_state at a specific location.
##
## Uses location metadata from _find_player to update the player.
##
## Returns: bool - true if replacement succeeded
static func _replace_player_in_location(
	world_state: Dictionary,
	location: Dictionary,
	new_player: Dictionary
) -> bool:
	var collection_path: Array = location.get("collection_path", [])
	var index: int = int(location.get("index", -1))

	if collection_path.is_empty() or index < 0:
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


## Find team by ID in world_state.
##
## Returns: Team dictionary, or empty {} if not found
static func _find_team(world_state: Dictionary, team_id: String) -> Dictionary:
	var nfl_teams: Array = world_state.get("nfl_teams", [])
	for team in nfl_teams:
		var t: Dictionary = team
		if String(t.get("id", "")) == team_id:
			return t
	return {}


## Update team cap space.
##
## Adds cap_delta to team's current cap_space.
## Positive delta = more cap space
## Negative delta = less cap space
##
## Returns: bool - true if update succeeded
static func _update_team_cap_space(
	world_state: Dictionary,
	team_id: String,
	cap_delta: float
) -> bool:
	var team := _find_team(world_state, team_id)
	if team.is_empty():
		return false

	var current_cap := float(team.get("cap_space", 0.0))
	team["cap_space"] = current_cap + cap_delta

	# Emit DataBus notification
	_notify_collection_changed("teams", "update")

	return true


## Move player from one team to another.
##
## Removes player from source roster and adds to destination roster.
## Handles special cases: free agents, undrafted pool
##
## Returns: bool - true if move succeeded
static func _move_player_to_team(
	world_state: Dictionary,
	player_id: String,
	from_team_id: String,
	to_team_id: String,
	year: int
) -> bool:
	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {})

	# Find player
	var player_location := _find_player(world_state, player_id, year)
	if player_location.is_empty():
		return false

	var player: Dictionary = player_location.player

	# Remove from source location
	match player_location.location_type:
		"team_roster":
			# Remove from team roster
			var from_roster: Dictionary = nfl_rosters.get(from_team_id, {})
			var from_players: Array = from_roster.get("players", [])
			var remove_index := int(player_location.index)
			if remove_index >= 0 and remove_index < from_players.size():
				from_players.remove_at(remove_index)

		"free_agent":
			# Remove from FA pool
			var free_agents: Dictionary = world_state.get("free_agents", {})
			if free_agents.has(year):
				var year_fas: Array = free_agents[year]
				var remove_index := int(player_location.index)
				if remove_index >= 0 and remove_index < year_fas.size():
					year_fas.remove_at(remove_index)

		"undrafted":
			# Remove from undrafted pool
			var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {})
			if undrafted_pool.has(year):
				var year_pool: Array = undrafted_pool[year]
				var remove_index := int(player_location.index)
				if remove_index >= 0 and remove_index < year_pool.size():
					year_pool.remove_at(remove_index)

	# Add to destination team roster
	if not nfl_rosters.has(to_team_id):
		nfl_rosters[to_team_id] = {"players": []}

	var to_roster: Dictionary = nfl_rosters.get(to_team_id, {})
	if not to_roster.has("players"):
		to_roster["players"] = []

	var to_players: Array = to_roster.get("players", [])
	to_players.append(player)

	return true


## Move player from team to free agent pool.
##
## Returns: bool - true if move succeeded
static func _move_player_to_free_agents(
	world_state: Dictionary,
	player_id: String,
	from_team_id: String,
	year: int
) -> bool:
	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {})

	# Find and remove player from team roster
	var player_location := _find_player_on_team(world_state, player_id, from_team_id)
	if player_location.is_empty():
		return false

	var player: Dictionary = player_location.player
	var from_roster: Dictionary = nfl_rosters.get(from_team_id, {})
	var from_players: Array = from_roster.get("players", [])
	var remove_index := int(player_location.index)

	if remove_index >= 0 and remove_index < from_players.size():
		from_players.remove_at(remove_index)
	else:
		return false

	# Add to free agent pool
	if not world_state.has("free_agents"):
		world_state["free_agents"] = {}

	var free_agents: Dictionary = world_state["free_agents"]
	if not free_agents.has(year):
		free_agents[year] = []

	var year_fas: Array = free_agents[year]
	year_fas.append(player)

	return true


## Collect all salaries for a position (for franchise tag calculation).
##
## Returns: Array of annual_value floats, sorted descending
static func _collect_position_salaries(world_state: Dictionary, position: String) -> Array:
	var salaries: Array = []
	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {})

	for team_id in nfl_rosters.keys():
		var roster: Dictionary = nfl_rosters[team_id]
		var players: Array = roster.get("players", [])

		for player in players:
			var p: Dictionary = player
			if String(p.get("position", "")) == position:
				var contract: Dictionary = p.get("contract", {})
				var annual_value := float(contract.get("annual_value", 0.0))
				if annual_value > 0.0:
					salaries.append(annual_value)

	# Sort descending
	salaries.sort()
	salaries.reverse()

	return salaries


## Get consecutive franchise tag years for player.
##
## Returns: int - number of consecutive years tagged (0 if not tagged before)
static func _get_consecutive_tag_years(world_state: Dictionary, player_id: String, current_year: int) -> int:
	var franchise_tags: Dictionary = world_state.get("franchise_tags", {})
	var consecutive := 0

	# Check previous years
	for check_year in range(current_year - 1, current_year - 5, -1):
		if not franchise_tags.has(check_year):
			break

		var year_tags: Dictionary = franchise_tags[check_year]
		var found := false

		for team_id in year_tags.keys():
			var tag: Dictionary = year_tags[team_id]
			if String(tag.get("player_id", "")) == player_id:
				consecutive += 1
				found = true
				break

		if not found:
			break  # Non-consecutive

	return consecutive


# ============================================================================
# INTERNAL HELPERS - DataBus Integration
# ============================================================================

## Notify DataBus that a collection has changed.
## DataBus is a global autoload and can be accessed directly by name.
static func _notify_collection_changed(collection_name: String, operation: String) -> void:
	if DataBus:
		DataBus.notify_collection_changed(collection_name, operation)
