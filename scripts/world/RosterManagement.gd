## Roster Management System
##
## Purpose: Manage NFL team rosters by releasing underperforming veterans to
## create cap space for free agency. Teams identify inefficient contracts based
## on cap hit vs player value, then release players to reach target FA budget.
##
## Architecture:
## - Runs BEFORE free agency phase (tick 9 in calendar)
## - Mutates world_state["nfl_rosters"] in-place
## - Tracks releases in world_state["player_releases"][year]
## - Moves released players to world_state["free_agents"][year] pool
## - Uses stats-based eval_score (avoids circular dependency with contracts)
##
## RNG Determinism:
## - Master RM seed: Rand.splitmix64(seed ^ 0x0570C001)
## - Deterministic sorting (no RNG for player evaluation)
## - Total: Minimal RNG usage (< 100 calls for tie-breaking if needed)
##
## Integration:
## - Runs after NFL Draft (tick 8)
## - Runs before NFL Free Agency (tick 10)
## - Dependencies: None (uses existing player stats and contracts)
##
extends RefCounted
class_name RosterManagement

const Rand = preload("res://autoloads/Rand.gd")
const SimLogger = preload("res://autoloads/SimLogger.gd")


## Run roster management for all NFL teams.
##
## This orchestrates the roster management process:
## 1. Calculate current cap space for each team
## 2. Determine target free agency budget from config
## 3. Evaluate each player's cap efficiency (annual_value vs player value)
## 4. Release players until target budget is reached
## 5. Move released players to free agent pool
## 6. Track releases for historical record
##
## @param world_state: World state dictionary (MUTATED in-place)
##   Required keys:
##   - nfl_rosters: Dictionary of team rosters
##   - nfl_teams: Array of team dictionaries
##   - league: Dictionary with cap_limit
##
## @param year: Current year (e.g., 2024)
##
## @param seed: RNG seed for deterministic simulation
##
## @param main_cfg: Main configuration (from main.json)
##   Required keys:
##   - roster_management: Configuration section
##
## @return: Dictionary summarizing roster management results:
##   {
##     "year": int,
##     "teams_processed": int,
##     "total_releases": int,
##     "total_cap_saved": float,
##     "releases_by_team": Dictionary {team_id: int}
##   }
static func run(
	world_state: Dictionary,
	year: int,
	seed: int,
	main_cfg: Dictionary
) -> Dictionary:
	SimLogger.info("Starting roster management (seed: %d)" % seed)

	# Initialize RNG with RM-specific seed
	var rm_rng := RandomNumberGenerator.new()
	rm_rng.seed = Rand.splitmix64(seed ^ 0x0570C001)

	# Get configuration
	var rm_cfg: Dictionary = main_cfg.get("roster_management", {})
	if not rm_cfg.get("enabled", true):
		SimLogger.info("Roster management disabled in config")
		return {
			"year": year,
			"teams_processed": 0,
			"total_releases": 0,
			"total_cap_saved": 0.0,
			"releases_by_team": {}
		}

	var target_fa_budget_min := float(rm_cfg.get("target_fa_budget_min", 30.0))
	var target_fa_budget_max := float(rm_cfg.get("target_fa_budget_max", 50.0))
	var value_threshold := float(rm_cfg.get("value_threshold", 1.5))
	var age_decline_factor := float(rm_cfg.get("age_decline_factor", 0.02))
	var min_roster_size := int(rm_cfg.get("min_roster_size", 45))

	# Get league cap limit
	var league_state: Dictionary = world_state.get("league", {})
	var league_cfg: Dictionary = main_cfg.get("league", {})
	var cap_limit := float(league_state.get("cap_limit", league_cfg.get("cap_limit", 180.0)))

	# Initialize tracking
	var total_releases := 0
	var total_cap_saved := 0.0
	var releases_by_team := {}
	var all_releases: Array = []

	# Process each team
	var nfl_teams := world_state.get("nfl_teams", []) as Array
	var nfl_rosters := world_state.get("nfl_rosters", {}) as Dictionary

	for team in nfl_teams:
		var team_id := String(team.get("id", ""))
		if team_id.is_empty():
			continue

		# Calculate target FA budget for this team (randomized within range)
		var target_budget := rm_rng.randf_range(target_fa_budget_min, target_fa_budget_max)

		# Process team roster
		var team_result := _process_team_roster(
			world_state,
			team_id,
			year,
			cap_limit,
			target_budget,
			value_threshold,
			age_decline_factor,
			min_roster_size
		)

		var team_releases := int(team_result.get("releases", 0))
		var team_cap_saved := float(team_result.get("cap_saved", 0.0))

		if team_releases > 0:
			releases_by_team[team_id] = team_releases
			total_releases += team_releases
			total_cap_saved += team_cap_saved
			all_releases.append_array(team_result.get("released_players", []))

	# Store releases in world state
	_store_releases(world_state, year, all_releases)

	SimLogger.info("Completed: %d teams processed, %d releases, $%.2fM cap saved" % [
		nfl_teams.size(),
		total_releases,
		total_cap_saved
	])

	return {
		"year": year,
		"teams_processed": nfl_teams.size(),
		"total_releases": total_releases,
		"total_cap_saved": total_cap_saved,
		"releases_by_team": releases_by_team
	}


## Process roster management for a single team.
##
## Identifies underperforming veterans and releases them to create cap space
## for free agency. Uses a value-based approach: compare cap hit to player
## value (eval_score * threshold) and release worst offenders first.
##
## @param world_state: World state dictionary
## @param team_id: Team identifier
## @param year: Current year
## @param cap_limit: League salary cap limit
## @param target_budget: Target FA budget for this team
## @param value_threshold: Multiplier for eval_score when comparing to cap hit
## @param age_decline_factor: Additional penalty per year over 30
## @param min_roster_size: Minimum roster size (don't release below this)
##
## @return: Dictionary with team results
static func _process_team_roster(
	world_state: Dictionary,
	team_id: String,
	year: int,
	cap_limit: float,
	target_budget: float,
	value_threshold: float,
	age_decline_factor: float,
	min_roster_size: int
) -> Dictionary:
	var nfl_rosters := world_state.get("nfl_rosters", {}) as Dictionary
	var roster: Dictionary = nfl_rosters.get(team_id, {})
	var players: Array = roster.get("players", [])

	if players.is_empty():
		return {
			"releases": 0,
			"cap_saved": 0.0,
			"released_players": []
		}

	# Calculate current cap space
	var current_cap_used := _calculate_team_cap_usage(players)
	var current_cap_space := cap_limit - current_cap_used

	# Check if we need to release players
	if current_cap_space >= target_budget:
		# Team already has enough cap space
		return {
			"releases": 0,
			"cap_saved": 0.0,
			"released_players": []
		}

	var needed_cap := target_budget - current_cap_space

	# Evaluate all players for release consideration
	var release_candidates := _identify_release_candidates(
		players,
		value_threshold,
		age_decline_factor,
		year
	)

	# Sort by cap inefficiency (worst first)
	release_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_ineff := float(a.get("cap_inefficiency", 0.0))
		var b_ineff := float(b.get("cap_inefficiency", 0.0))
		if abs(a_ineff - b_ineff) < 0.001:
			# Tie-breaker: older players first
			var a_age := int(a.get("age", 22))
			var b_age := int(b.get("age", 22))
			return a_age > b_age
		return a_ineff > b_ineff
	)

	# Release players until target budget reached
	var released_players: Array = []
	var cap_saved := 0.0
	var remaining_roster_size := players.size()

	for candidate in release_candidates:
		# Stop if we've reached target budget
		if cap_saved >= needed_cap:
			break

		# Don't release below minimum roster size
		if remaining_roster_size <= min_roster_size:
			break

		# Release this player
		var player_id := String(candidate.get("player_id", ""))
		var player: Dictionary = candidate.get("player", {})
		var cap_hit := float(candidate.get("cap_hit", 0.0))

		# Calculate dead cap (placeholder for now - full implementation later)
		var dead_cap := _calculate_dead_cap(player)
		var net_cap_saved := cap_hit - dead_cap

		# Only release if it saves cap space
		if net_cap_saved > 0.0:
			released_players.append({
				"player_id": player_id,
				"team_id": team_id,
				"year": year,
				"reason": "cap_efficiency",
				"cap_hit": cap_hit,
				"dead_cap": dead_cap,
				"net_savings": net_cap_saved,
				"eval_score": float(candidate.get("eval_score", 50.0)),
				"age": int(candidate.get("age", 22)),
				"position": String(candidate.get("position", "")),
				"name": String(player.get("name", "Unknown"))
			})

			cap_saved += net_cap_saved
			remaining_roster_size -= 1

	# Execute releases (remove from roster, add to FA pool)
	_execute_releases(world_state, team_id, released_players, year)

	return {
		"releases": released_players.size(),
		"cap_saved": cap_saved,
		"released_players": released_players
	}


## Calculate total cap usage for a team's roster.
##
## @param players: Array of player dictionaries
## @return: Total cap hit (float)
static func _calculate_team_cap_usage(players: Array) -> float:
	var total := 0.0
	for player in players:
		var p: Dictionary = player
		var contract: Dictionary = p.get("contract", {})
		if contract.is_empty():
			continue
		total += float(contract.get("annual_value", 0.0))
	return total


## Identify release candidates based on cap inefficiency.
##
## Cap inefficiency = annual_value / (eval_score * threshold * age_factor)
## Higher values = worse value for money = higher priority for release
##
## @param players: Array of player dictionaries
## @param value_threshold: Threshold multiplier for eval_score
## @param age_decline_factor: Penalty per year over 30
## @param year: Current year
## @return: Array of candidate dictionaries with inefficiency scores
static func _identify_release_candidates(
	players: Array,
	value_threshold: float,
	age_decline_factor: float,
	year: int
) -> Array:
	var candidates: Array = []

	for player in players:
		var p: Dictionary = player
		var contract: Dictionary = p.get("contract", {})

		# Skip players without contracts
		if contract.is_empty():
			continue

		# Skip rookie contracts (draft picks protected for first 3 years)
		var signed_year := int(contract.get("signed_year", 0))
		var draft_year := int(p.get("draft_year", 0))
		var is_rookie := (signed_year == draft_year)
		var years_since_draft := year - draft_year
		if is_rookie and years_since_draft < 3:
			continue

		var cap_hit := float(contract.get("annual_value", 0.0))
		var eval_score := float(p.get("eval_score", 50.0))
		var age := int(p.get("age", 22))

		# Calculate age penalty (players over 30 penalized)
		var age_penalty := 1.0
		if age > 30:
			age_penalty = 1.0 + (float(age - 30) * age_decline_factor)

		# Calculate expected value
		var expected_value := (eval_score / 100.0) * value_threshold

		# Calculate cap inefficiency
		var cap_inefficiency := 0.0
		if expected_value > 0.0:
			cap_inefficiency = (cap_hit / expected_value) * age_penalty

		# Only consider players with poor value (inefficiency > 1.0)
		if cap_inefficiency > 1.0:
			candidates.append({
				"player": p,
				"player_id": String(p.get("id", p.get("player_id", ""))),
				"cap_hit": cap_hit,
				"eval_score": eval_score,
				"age": age,
				"position": String(p.get("position", "")),
				"cap_inefficiency": cap_inefficiency,
				"expected_value": expected_value
			})

	return candidates


## Calculate dead cap charge for releasing a player.
##
## PLACEHOLDER: Currently returns 0.0. Full implementation will account for:
## - Guaranteed money remaining
## - Signing bonus proration
## - Restructure bonuses
##
## @param player: Player dictionary with contract
## @return: Dead cap charge (float)
static func _calculate_dead_cap(player: Dictionary) -> float:
	# Placeholder implementation
	# TODO: Implement dead cap calculation based on:
	# - contract["guaranteed_remaining"]
	# - contract["signing_bonus_remaining"]
	# - contract["restructure_bonus_remaining"]
	return 0.0


## Execute player releases by removing from roster and adding to FA pool.
##
## @param world_state: World state dictionary (MUTATED)
## @param team_id: Team identifier
## @param released_players: Array of release dictionaries
## @param year: Current year
static func _execute_releases(
	world_state: Dictionary,
	team_id: String,
	released_players: Array,
	year: int
) -> void:
	if released_players.is_empty():
		return

	var nfl_rosters := world_state.get("nfl_rosters", {}) as Dictionary
	var roster: Dictionary = nfl_rosters.get(team_id, {})
	var players: Array = roster.get("players", [])

	# Build set of released player IDs for fast lookup
	var released_ids := {}
	for release in released_players:
		var pid := String(release.get("player_id", ""))
		released_ids[pid] = true

	# Remove released players from roster
	var remaining_players: Array = []
	var released_player_objects: Array = []

	for player in players:
		var p: Dictionary = player
		var player_id := String(p.get("id", p.get("player_id", "")))

		if released_ids.has(player_id):
			# Mark contract as released
			var contract: Dictionary = p.get("contract", {})
			if not contract.is_empty():
				contract["status"] = "released"
				contract["released_year"] = year

			# Store player data for FA pool
			p["last_team_id"] = team_id
			p["release_year"] = year
			released_player_objects.append(p)
		else:
			remaining_players.append(p)

	# Update roster
	roster["players"] = remaining_players
	nfl_rosters[team_id] = roster
	world_state["nfl_rosters"] = nfl_rosters

	# Add released players to free agent pool
	var fa_pool: Dictionary = world_state.get("free_agents", {})
	var year_fas: Array = fa_pool.get(year, [])
	year_fas.append_array(released_player_objects)
	fa_pool[year] = year_fas
	world_state["free_agents"] = fa_pool


## Store release records in world state for historical tracking.
##
## @param world_state: World state dictionary (MUTATED)
## @param year: Current year
## @param releases: Array of release dictionaries
static func _store_releases(
	world_state: Dictionary,
	year: int,
	releases: Array
) -> void:
	if not world_state.has("player_releases"):
		world_state["player_releases"] = {}

	var release_history: Dictionary = world_state["player_releases"]
	release_history[year] = releases
	world_state["player_releases"] = release_history
