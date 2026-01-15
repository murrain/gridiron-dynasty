## Free Agency System
##
## Purpose: Simulate NFL free agency period where players with expired contracts
## sign with new teams based on team needs, cap space, and player preferences.
##
## Architecture:
## - Mutates world_state["nfl_rosters"] in-place (same pattern as TradeGenerator)
## - Franchise tags stored in world_state["franchise_tags"], NOT in Team.gd
## - Uses ContractNegotiation for offer generation and evaluation
## - Uses ContractLifecycle for contract transitions
##
## RNG Determinism:
## - Master FA seed: Rand.splitmix64(seed ^ 0xFAFA0001)
## - Team interest generation: 1 randf_range() per team-player pair (~6400 calls)
## - Player decision: 1 randf_range() per offer (~600 calls)
## - Total: ~7000 RNG calls per FA period (deterministic and bounded)
##
## Integration:
## - Depends on: ContractNegotiation, ContractLifecycle, PlayerValue
## - Soft dependency: TeamNeeds (stub provided if not available)
##
## UDFA LIFECYCLE POLICY:
##
## 1. Draft Phase (NflDraft.run):
##    - Creates world_state["undrafted_pool"][year] with ~150 college seniors
##    - Players have "player_id" field (matches draft pool format)
##    - Players stored with full attributes: position, age, composite_score, stats
##
## 2. Free Agency Phase (FreeAgency.collect_free_agents):
##    - UDFAs from current year added to FA pool automatically
##    - Marked with previous_team_id="UDFA" to distinguish from veteran FAs
##    - Tier assigned based on composite_score (typically depth/camp_body)
##    - Market value calculated like any other FA
##
## 3. Signing Phase (FreeAgency._execute_signing):
##    - UDFA moved from undrafted_pool to team roster
##    - Contract created (rookie minimum, 1-2 years typical)
##    - Player object transferred via _move_player_to_team()
##    - Uses _find_player_object() to locate player in undrafted_pool
##
## 4. Cleanup (End of year):
##    - Unsigned UDFAs remain in undrafted_pool[year]
##    - Historical record preserved for analysis
##    - Do NOT auto-retire - may sign in subsequent years
##    - Teams can sign UDFAs from previous years if still available
extends RefCounted
class_name FreeAgency

const Rand = preload("res://autoloads/Rand.gd")
const SimLogger = preload("res://autoloads/SimLogger.gd")
const ContractNegotiation = preload("res://scripts/world/ContractNegotiation.gd")
const ContractLifecycle = preload("res://scripts/world/ContractLifecycle.gd")
const RosterComposition = preload("res://scripts/core/roster/RosterComposition.gd")
const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")
const EvaluationModifierStack = preload("res://scripts/core/evaluation/EvaluationModifierStack.gd")


## Run complete free agency simulation for a given year.
##
## This orchestrates the entire free agency process:
## 1. Collect all free agents (expired contracts + UDFAs)
## 2. Apply franchise tags (if any)
## 3. Generate team interest scores for each free agent
## 4. Process signings by tier (elite → starter → depth → camp body)
## 5. Update rosters, contracts, and cap space
## 6. Record transaction history
##
## RNG Budget (with UDFA integration):
## - Team interest generation: ~32 teams × (220 veteran FAs + 150 UDFAs) = ~11,840 calls
## - Player decision-making: ~370 FAs × avg 3 offers × 1 call = ~1,110 calls
## - Total: ~12,950 RNG calls per FA period (was ~7,000 before UDFA integration)
##
## @param world_state: World state dictionary (MUTATED in-place)
##   Required keys:
##   - nfl_rosters: Dictionary of team rosters
##   - nfl_teams: Array of team dictionaries
##   - franchise_tags: Dictionary of franchise tags by year
##   - free_agent_pool: Dictionary of FA data by year
##   - contract_negotiation_history: History of all negotiations
##
## @param year: Current year (e.g., 2024)
##
## @param seed: RNG seed for deterministic simulation
##
## @param positions_cfg: Positions configuration (from positions.json)
##
## @param main_cfg: Main configuration (from main.json)
##
## @param stats_cfg: Stats configuration (from stats.json)
##
## @param league_cfg: League configuration (from league.json)
##
## @return: Dictionary summarizing FA results:
##   {
##     "year": int,
##     "signings": Array[{player_id, team_id, contract}],
##     "unsigned": Array[player_id],
##     "franchise_tags": Array[{team_id, player_id, salary}],
##     "total_spent": float
##   }
static func run_free_agency(
	world_state: Dictionary,
	year: int,
	seed: int,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	league_cfg: Dictionary
) -> Dictionary:
	SimLogger.info("Starting free agency (seed: %d)" % seed)

	# Initialize RNG with FA-specific seed
	# RNG PATTERN: Derive FA seed from master seed using XOR and splitmix64
	var fa_rng := RandomNumberGenerator.new()
	fa_rng.seed = Rand.splitmix64(seed ^ 0xFAFA0001)

	# 1. Collect free agents
	var free_agents := collect_free_agents(world_state, year, positions_cfg, main_cfg)
	SimLogger.info("Found %d free agents" % free_agents.size())

	# 2. Apply franchise tags (before FA market opens)
	var franchise_tagged := _apply_franchise_tags(world_state, year, free_agents, league_cfg)
	SimLogger.info("Applied %d franchise tags" % franchise_tagged.size())

	# Remove franchise-tagged players from FA pool
	free_agents = _remove_franchise_tagged(free_agents, franchise_tagged)
	SimLogger.info("%d players entering free agency" % free_agents.size())

	# 3. Generate team interest for all FA/team pairs
	# RNG: 1 randf_range() call per team-player pair
	var team_interest := generate_team_interest(world_state, year, free_agents, fa_rng, league_cfg)

	# 4. Process signings by tier (elite → depth)
	var signings: Array = []
	var tiers := ["elite", "starter", "depth", "camp_body"]
	var team_spending: Dictionary = {}  # team_id -> total_spent (float)

	for tier in tiers:
		var tier_players := _filter_by_tier(free_agents, tier)
		SimLogger.info("Processing %d %s players" % [tier_players.size(), tier])

		for fa_profile in tier_players:
			var player_id: String = fa_profile.get("player_id", "")

			# Generate offers from interested teams
			# RNG: player_chooses_team() uses 1 randf_range() per offer
			var offers := _generate_offers_for_player(
				fa_profile,
				team_interest,
				world_state,
				positions_cfg,
				main_cfg
			)

			if offers.is_empty():
				continue  # No teams interested or can afford

			# Player chooses best offer
			var chosen_team_id := player_chooses_team(
				player_id,
				team_interest,
				offers,
				fa_rng
			)

			if chosen_team_id.is_empty():
				continue  # Player declined all offers

			# Execute signing
			var chosen_offer := _find_offer(offers, chosen_team_id)
			var signing := _execute_signing(
				world_state,
				player_id,
				chosen_team_id,
				chosen_offer,
				year,
				team_spending
			)

			if not signing.is_empty():
				signings.append(signing)

	# 5. Track unsigned players
	var unsigned := _collect_unsigned(free_agents, signings)

	# 6. Fill rosters to minimum size (53 players) with UDFAs
	var roster_filler_signings := _fill_rosters_to_minimum(
		world_state,
		year,
		positions_cfg,
		main_cfg,
		league_cfg,
		fa_rng,
		team_spending
	)
	signings.append_array(roster_filler_signings)

	# 7. Store results in world state
	_store_fa_results(world_state, year, free_agents, signings, unsigned, franchise_tagged)

	# 8. Return summary
	var total_spent := _calculate_total_spent(signings)

	SimLogger.info("Completed: %d signings, %d unsigned, %.2fM spent" % [
		signings.size(),
		unsigned.size(),
		total_spent
	])

	# Log cap space impact summary
	if not team_spending.is_empty():
		SimLogger.info("Cap space impact:")
		var teams_by_spending: Array = []
		for tid in team_spending.keys():
			var spent: float = float(team_spending[tid])
			var team := _find_team(world_state, String(tid))
			var remaining: float = float(team.get("cap_space", 0.0))
			teams_by_spending.append({
				"team": String(tid),
				"spent": spent,
				"remaining": remaining
			})

		teams_by_spending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["spent"]) > float(b["spent"])
		)

		# Log top 5 spenders to avoid excessive output
		for i in range(mini(5, teams_by_spending.size())):
			var entry: Dictionary = teams_by_spending[i]
			SimLogger.info("  %s: $%.2fM spent, $%.2fM remaining" % [
				String(entry["team"]),
				float(entry["spent"]),
				float(entry["remaining"])
			])

	return {
		"year": year,
		"signings": signings,
		"unsigned": unsigned,
		"franchise_tags": franchise_tagged,
		"total_spent": total_spent
	}


## Collect all players eligible for free agency.
##
## Identifies players with expired contracts or no current team.
## Calculates market value and priority tier for each player.
##
## RNG: None (deterministic filtering)
##
## @param world_state: World state dictionary
## @param year: Current year
## @param positions_cfg: Positions configuration
## @param main_cfg: Main configuration
## @return: Array of FreeAgentProfile dictionaries
static func collect_free_agents(
	world_state: Dictionary,
	year: int,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Array:
	var free_agents: Array = []
	var nfl_rosters := world_state.get("nfl_rosters", {}) as Dictionary

	# Iterate through all NFL rosters
	for team_id in nfl_rosters.keys():
		var roster := nfl_rosters.get(team_id, {}) as Dictionary
		var players := roster.get("players", []) as Array

		for player in players:
			var contract := player.get("contract", {}) as Dictionary
			var contract_status := String(contract.get("status", ""))

			# Check if player is free agent eligible
			var is_expired := contract_status == "expired"
			var years_remaining := int(contract.get("years_remaining", 0))
			var is_contract_end := years_remaining <= 0

			if is_expired or is_contract_end:
				# Player is eligible for free agency
				var fa_profile := _create_fa_profile(
					player,
					team_id,
					positions_cfg,
					main_cfg
				)
				free_agents.append(fa_profile)

	# Add undrafted players from this year's draft class
	var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {})
	var year_undrafted: Array = undrafted_pool.get(year, [])

	for player in year_undrafted:
		var p: Dictionary = player
		# Create FA profile for UDFA
		var fa_profile := _create_udfa_fa_profile(p, year, positions_cfg, main_cfg)
		free_agents.append(fa_profile)

	return free_agents


## Generate team interest scores for each free agent.
##
## Calculates how interested each team is in each free agent based on:
## - Positional needs
## - Cap affordability
## - Team quality fit (contenders vs rebuilders)
## - Random variance
##
## RNG Pattern: 1 randf_range() call per team-player pair
## Expected calls: 32 teams * 200 FA ~= 6400 RNG calls
##
## @param world_state: World state dictionary
## @param year: Current year
## @param free_agents: Array of FreeAgentProfile dictionaries
## @param rng: RandomNumberGenerator for variance
## @param league_cfg: League configuration
## @return: Dictionary {team_id: {player_id: interest_score}}
static func generate_team_interest(
	world_state: Dictionary,
	year: int,
	free_agents: Array,
	rng: RandomNumberGenerator,
	league_cfg: Dictionary
) -> Dictionary:
	var team_interest := {}
	var nfl_teams := world_state.get("nfl_teams", []) as Array
	var nfl_rosters := world_state.get("nfl_rosters", {}) as Dictionary

	for team in nfl_teams:
		var team_id := String(team.get("id", ""))
		team_interest[team_id] = {}

		# Get team context
		var roster := nfl_rosters.get(team_id, {}) as Dictionary
		var cap_space := float(team.get("cap_space", 0.0))
		var team_needs := _assess_team_needs_stub(roster)

		for fa_profile in free_agents:
			var player_id := String(fa_profile.get("player_id", ""))
			var position := String(fa_profile.get("position", ""))
			var minimum_demand := float(fa_profile.get("minimum_demand", 0.0))

			# HARD CAP CHECK: Zero interest if position is at max capacity
			if RosterComposition.is_position_at_cap(roster, position):
				team_interest[team_id][player_id] = 0.0
				continue

			# Calculate interest components
			var need_match := _calculate_need_match(position, team_needs)
			var affordability := _calculate_affordability(minimum_demand, cap_space)
			var fit_mult := _calculate_team_fit(fa_profile, team, world_state)

			# RNG CALL: Add random variance (0.9 to 1.1)
			var variance := rng.randf_range(0.9, 1.1)

			# Final interest score
			var interest_score := need_match * affordability * fit_mult * variance

			team_interest[team_id][player_id] = interest_score

	return team_interest


## Player chooses team from competing offers.
##
## Simulates player decision-making based on:
## - Money (60% weight)
## - Contender status (20% weight)
## - Familiarity bonus (10% weight for previous team)
## - Random variance (10% weight)
##
## RNG Pattern: 1 randf_range() call per offer + potential tiebreaker
## Expected calls: ~3 offers per player * 200 FA ~= 600 RNG calls
##
## @param player_id: Player identifier
## @param team_interests: Team interest dictionary from generate_team_interest()
## @param offers: Array of ContractOffer dictionaries
## @param rng: RandomNumberGenerator for variance
## @return: Team ID of chosen team, or empty string if no offer accepted
static func player_chooses_team(
	player_id: String,
	team_interests: Dictionary,
	offers: Array,
	rng: RandomNumberGenerator
) -> String:
	if offers.is_empty():
		return ""

	# Find previous team (for familiarity bonus)
	var previous_team_id := ""
	for offer in offers:
		var offer_dict := offer as Dictionary
		if offer_dict.has("previous_team_id"):
			previous_team_id = String(offer_dict.get("previous_team_id", ""))
			break

	# Calculate decision score for each offer
	var best_team_id := ""
	var best_score := -1.0

	for offer in offers:
		var offer_dict := offer as Dictionary
		var team_id := String(offer_dict.get("team_id", ""))
		var offer_quality := float(offer_dict.get("offer_quality", 0.0))

		# Money weight: 60%
		var money_score := offer_quality * 0.6

		# Contender bonus: 20%
		# TODO: Get actual win% when available; stub with 0.5
		var win_pct := 0.5
		var contender_score := win_pct * 0.2

		# Familiarity bonus: 10%
		var familiarity_score := 0.1 if team_id == previous_team_id else 0.0

		# RNG CALL: Random variance: 10%
		var variance_score := rng.randf_range(0.0, 0.1)

		var total_score := money_score + contender_score + familiarity_score + variance_score

		if total_score > best_score:
			best_score = total_score
			best_team_id = team_id

	return best_team_id


## Apply franchise tag to a player.
##
## Prevents player from entering free agency by applying guaranteed 1-year
## contract at position average salary.
##
## CRITICAL: Franchise tags stored in world_state["franchise_tags"], NOT Team.gd
##
## RNG: None (deterministic calculation)
##
## @param world_state: World state dictionary (MUTATED)
## @param team_id: Team applying tag
## @param player_id: Player being tagged
## @param tag_type: "exclusive", "non_exclusive", or "transition"
## @param year: Current year
## @param config: League configuration
## @return: FranchiseTag dictionary, or empty dict if invalid
static func apply_franchise_tag(
	world_state: Dictionary,
	team_id: String,
	player_id: String,
	tag_type: String,
	year: int,
	config: Dictionary
) -> Dictionary:
	# Validate team hasn't already tagged a player this year
	if not world_state.has("franchise_tags"):
		world_state["franchise_tags"] = {}

	var year_tags := world_state["franchise_tags"].get(year, {}) as Dictionary
	if year_tags.has(team_id):
		SimLogger.error("Team %s already used franchise tag in %d" % [team_id, year])
		return {}

	# Get player information
	var player := _find_player_in_rosters(world_state, player_id)
	if player.is_empty():
		SimLogger.error("Player %s not found" % player_id)
		return {}

	var position := String(player.get("position", ""))

	# Calculate tag salary (top 5 position average)
	var tag_salary := _calculate_tag_salary(world_state, position, tag_type)

	# Check consecutive tags (20% penalty for 2nd year tag)
	var consecutive_years := _get_consecutive_tag_years(world_state, player_id, year)
	if consecutive_years > 0:
		tag_salary *= 1.2  # 20% penalty per consecutive year

	# Validate team has cap space
	var team := _find_team(world_state, team_id)
	var cap_space := float(team.get("cap_space", 0.0))
	if tag_salary > cap_space:
		SimLogger.error("Team %s cannot afford tag (%.2fM > %.2fM cap)" % [
			team_id, tag_salary, cap_space
		])
		return {}

	# Create franchise tag entry
	var franchise_tag := {
		"player_id": player_id,
		"team_id": team_id,
		"tag_type": tag_type,
		"salary": tag_salary,
		"applied_year": year,
		"consecutive_years": consecutive_years + 1
	}

	# Store in world_state (NOT in Team.gd)
	if not world_state["franchise_tags"].has(year):
		world_state["franchise_tags"][year] = {}

	world_state["franchise_tags"][year][team_id] = franchise_tag

	# Create 1-year contract for tagged player
	var contract := {
		"status": "signed",
		"annual_value": tag_salary,
		"years_total": 1,
		"years_remaining": 1,
		"base_salary": tag_salary * 0.8,
		"signing_bonus": tag_salary * 0.2,
		"guaranteed_value": tag_salary,  # Fully guaranteed
		"signed_year": year,
		"trigger": "franchise_tag"
	}

	player["contract"] = contract

	SimLogger.info("Applied %s franchise tag to %s: %.2fM" % [
		tag_type, player_id, tag_salary
	])

	return franchise_tag


## INTERNAL: Extract common profile fields from player data.
##
## Shared logic between veteran FA and UDFA profile creation:
## - Extracts player ID (handles both "id" and "player_id" fields)
## - Extracts position and age
## - Calculates contract demand
## - Determines priority tier
##
## @param player: Player dictionary
## @param rating_score: Overall rating (eval_score for veterans, composite_score for UDFAs)
## @param positions_cfg: Positions configuration
## @param main_cfg: Main configuration
## @return: Dictionary with common profile fields
static func _extract_profile_common_fields(
	player: Dictionary,
	rating_score: float,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var player_id := String(player.get("id", ""))
	var position := String(player.get("position", ""))
	var age := int(player.get("age", 22))

	# Calculate market value and demand
	var demand := ContractNegotiation.generate_player_demand(player, positions_cfg, main_cfg)
	var minimum_demand := float(demand.get("minimum_annual_value", 1.0))

	# Determine priority tier
	var priority_tier := _determine_priority_tier(rating_score)

	return {
		"player_id": player_id,
		"position": position,
		"age": age,
		"overall_rating": rating_score,
		"minimum_demand": minimum_demand,
		"priority_tier": priority_tier,
		"demand": demand
	}


## INTERNAL: Create free agent profile from player data.
static func _create_fa_profile(
	player: Dictionary,
	previous_team_id: String,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var eval_score := float(player.get("eval_score", 50.0))
	var profile := _extract_profile_common_fields(player, eval_score, positions_cfg, main_cfg)

	# Add veteran-specific fields
	profile["previous_team_id"] = previous_team_id
	profile["contract_expired"] = true

	return profile


## INTERNAL: Create FA profile for undrafted player.
##
## Creates a free agent profile for a UDFA, using composite_score as rating
## and marking them with from_team="UDFA" to distinguish from veteran FAs.
##
## RNG: None (deterministic profile creation)
##
## @param player: UDFA player dictionary from undrafted_pool
## @param year: Current year
## @param positions_cfg: Positions configuration
## @param main_cfg: Main configuration
## @return: FreeAgentProfile dictionary
static func _create_udfa_fa_profile(
	player: Dictionary,
	year: int,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var composite_score := float(player.get("composite_score", 50.0))
	var profile := _extract_profile_common_fields(player, composite_score, positions_cfg, main_cfg)

	# Add UDFA-specific fields
	profile["previous_team_id"] = "UDFA"  # Mark as undrafted
	profile["contract_expired"] = false  # Never had a contract

	return profile


## INTERNAL: Determine free agent priority tier from evaluation score.
static func _determine_priority_tier(eval_score: float) -> String:
	if eval_score >= 80.0:
		return "elite"
	elif eval_score >= 70.0:
		return "starter"
	elif eval_score >= 60.0:
		return "depth"
	else:
		return "camp_body"


## INTERNAL: Filter free agents by tier.
static func _filter_by_tier(free_agents: Array, tier: String) -> Array:
	var filtered: Array = []
	for fa_profile in free_agents:
		var profile_dict := fa_profile as Dictionary
		if profile_dict.get("priority_tier", "") == tier:
			filtered.append(fa_profile)
	return filtered


## INTERNAL: Assess team needs with position cap awareness.
##
## Returns array of position needs, but EXCLUDES positions at hard cap.
## Positions at/above max depth will NOT appear in the needs array.
static func _assess_team_needs_stub(roster: Dictionary) -> Array:
	var needs: Array = []
	var by_position := roster.get("by_position", {}) as Dictionary

	for position in RosterComposition.IDEAL_DEPTH.keys():
		var current: int = (by_position.get(position, []) as Array).size()
		var target: int = RosterComposition.get_ideal_depth(position)
		var max_allowed: int = RosterComposition.get_max_depth(position)

		# HARD CAP CHECK: Never show interest in capped positions
		if current >= max_allowed:
			continue

		# OVERSTOCKED CHECK: Don't flag as need if above ideal (even below cap)
		if current >= target:
			continue

		if current < target * 0.7:  # 70% threshold
			needs.append({
				"position": position,
				"priority": "high" if current < target * 0.5 else "medium",
				"at_cap": false
			})

	return needs


## INTERNAL: Calculate need match score.
##
## Returns:
##   - 2.0: Critical/high need
##   - 1.5: Medium need
##   - 0.3: No need (position at/above ideal) - very low interest
##   - 0.0: Position at cap (via _assess_team_needs_stub exclusion)
##
## NOTE: The baseline is now 0.3 instead of 1.0 to prevent teams from
## signing players at positions they don't need. This fixes the bug
## where teams accumulate 5+ QBs due to baseline interest.
static func _calculate_need_match(position: String, team_needs: Array) -> float:
	for need in team_needs:
		var need_dict := need as Dictionary
		if need_dict.get("position", "") == position:
			var priority := String(need_dict.get("priority", ""))
			if priority == "high":
				return 2.0  # Critical need
			elif priority == "medium":
				return 1.5  # Moderate need

	# No need for this position = very low interest (was 1.0, now 0.3)
	# This prevents accumulating players at positions team doesn't need
	return 0.3


## INTERNAL: Calculate affordability score.
static func _calculate_affordability(demand: float, cap_space: float) -> float:
	if cap_space <= 0.0:
		return 0.0  # No cap space

	var affordability_ratio := cap_space / demand if demand > 0.0 else 0.0

	if affordability_ratio >= 3.0:
		return 1.0  # Easily affordable
	elif affordability_ratio >= 1.5:
		return 0.8  # Affordable
	elif affordability_ratio >= 1.0:
		return 0.5  # Tight fit
	else:
		return 0.2  # Stretch


## INTERNAL: Calculate team fit multiplier based on scheme fit.
##
## Uses SchemeFitCalculator to determine how well a player fits
## the team's offensive/defensive scheme.
##
## Returns:
##   - 0.8-1.2: Scheme fit multiplier based on player/scheme compatibility
##   - 1.0: Neutral (special teams or unknown position)
static func _calculate_team_fit(fa_profile: Dictionary, team: Dictionary, world_state: Dictionary) -> float:
	var position := String(fa_profile.get("position", ""))
	var rating := float(fa_profile.get("rating", 50.0))

	# Get roster for this team
	var team_id := String(team.get("id", ""))
	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary
	var roster: Dictionary = nfl_rosters.get(team_id, {}) as Dictionary

	# Create evaluation context
	var player_data := {
		"player": fa_profile.get("player", {}),
		"position": position
	}

	var ctx := EvaluationContext.for_free_agency(
		player_data,                                    # player
		team,                                           # team
		roster,                                         # roster
		int(world_state.get("current_year", 2024)),    # year
		world_state.get("positions_cfg", {}),           # positions_cfg
		world_state.get("class_rules", {})              # class_rules
	)
	ctx.base_rating = rating

	# Create and apply FA modifier stack
	var stack := EvaluationModifierStack.create_free_agency_stack()
	var result := stack.evaluate(ctx)

	return result.final_multiplier


## Calculate coach mindset multiplier for FA interest.
##
## Similar to draft evaluation - coaches prefer players on their side of the ball.
## Effect is dampened compared to draft (max ±8% vs ±15%) since FA is more
## need-driven than draft.
##
## @param position: Player position
## @param player_rating: Player's overall rating
## @param coach: Coach dictionary with specialty_position
## @return float: Multiplier (0.95 to 1.08)
static func _calculate_coach_mindset_multiplier(
	position: String,
	player_rating: float,
	coach: Dictionary
) -> float:
	var specialty := String(coach.get("specialty_position", ""))

	# No specialty = neutral evaluation
	if specialty.is_empty():
		return 1.0

	# Define position groups
	var offensive_positions := ["QB", "RB", "WR", "TE", "OL"]
	var defensive_positions := ["DL", "EDGE", "LB", "CB", "S"]

	var is_offensive := position in offensive_positions
	var is_defensive := position in defensive_positions

	# Dampened effect for FA (need-driven, less coach preference)
	var base_boost := 1.0
	var elite_threshold := 78.0

	if specialty == "Defense":
		if is_defensive:
			base_boost = 1.05
			if player_rating >= elite_threshold:
				base_boost = 1.08
		elif is_offensive:
			base_boost = 0.98

	elif specialty == "Offense":
		if is_offensive:
			base_boost = 1.05
			if player_rating >= elite_threshold:
				base_boost = 1.08
		elif is_defensive:
			base_boost = 0.98

	else:
		# Position-specific specialty (e.g., "QB", "EDGE")
		if position == specialty:
			base_boost = 1.06
			if player_rating >= elite_threshold:
				base_boost = 1.10
		elif specialty in offensive_positions and is_offensive:
			base_boost = 1.02
		elif specialty in defensive_positions and is_defensive:
			base_boost = 1.02

	return base_boost


## INTERNAL: Generate offers for a specific player.
static func _generate_offers_for_player(
	fa_profile: Dictionary,
	team_interest: Dictionary,
	world_state: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Array:
	var offers: Array = []
	var player_id := String(fa_profile.get("player_id", ""))
	var demand := fa_profile.get("demand", {}) as Dictionary

	# Get top interested teams (max 5 offers per player)
	var interested_teams := _get_top_interested_teams(player_id, team_interest, 5)

	var nfl_teams := world_state.get("nfl_teams", []) as Array

	for team_id in interested_teams:
		var team := _find_team_by_id(nfl_teams, team_id)
		if team.is_empty():
			continue

		# Determine aggression based on interest level
		var interest_score := _get_team_interest_score(team_id, player_id, team_interest)
		var aggression := _calculate_aggression(interest_score)

		# Generate offer
		var player_dict := _build_player_dict_from_profile(fa_profile, world_state)
		var offer := ContractNegotiation.generate_offer(team, player_dict, demand, aggression)

		if not offer.is_empty():
			offer["previous_team_id"] = fa_profile.get("previous_team_id", "")
			offers.append(offer)

	return offers


## INTERNAL: Get top N most interested teams for a player.
static func _get_top_interested_teams(player_id: String, team_interest: Dictionary, max_offers: int) -> Array:
	var team_scores: Array = []

	for team_id in team_interest.keys():
		var team_interests_dict := team_interest.get(team_id, {}) as Dictionary
		var interest_score := float(team_interests_dict.get(player_id, 0.0))

		if interest_score > 0.5:  # Minimum interest threshold
			team_scores.append({
				"team_id": team_id,
				"score": interest_score
			})

	# Sort by interest score (descending)
	team_scores.sort_custom(func(a, b): return a["score"] > b["score"])

	# Return top N team IDs
	var top_teams: Array = []
	for i in range(mini(max_offers, team_scores.size())):
		top_teams.append(team_scores[i]["team_id"])

	return top_teams


## INTERNAL: Get team interest score for specific player.
static func _get_team_interest_score(team_id: String, player_id: String, team_interest: Dictionary) -> float:
	var team_dict := team_interest.get(team_id, {}) as Dictionary
	return float(team_dict.get(player_id, 0.0))


## INTERNAL: Calculate offer aggression from interest score.
static func _calculate_aggression(interest_score: float) -> float:
	if interest_score >= 2.0:
		return 1.2  # Very interested: aggressive offer
	elif interest_score >= 1.5:
		return 1.1  # Interested: slight premium
	elif interest_score >= 1.0:
		return 1.0  # Neutral: meet demand
	else:
		return 0.9  # Mild interest: below market


## INTERNAL: Build player dict from FA profile for contract generation.
static func _build_player_dict_from_profile(fa_profile: Dictionary, world_state: Dictionary) -> Dictionary:
	var player_id := String(fa_profile.get("player_id", ""))
	var player := _find_player_in_rosters(world_state, player_id)

	if player.is_empty():
		# Fallback: build from profile
		return {
			"id": player_id,
			"position": fa_profile.get("position", ""),
			"age": fa_profile.get("age", 22),
			"eval_score": fa_profile.get("overall_rating", 50.0)
		}

	return player


## INTERNAL: Find offer for specific team.
static func _find_offer(offers: Array, team_id: String) -> Dictionary:
	for offer in offers:
		var offer_dict := offer as Dictionary
		if offer_dict.get("team_id", "") == team_id:
			return offer_dict
	return {}


## INTERNAL: Execute player signing (mutate world_state).
##
## Handles signing for both veteran FAs and UDFAs.
## Uses _find_player_object() to locate player in either rosters or undrafted_pool.
##
## RNG: None (deterministic signing execution)
static func _execute_signing(
	world_state: Dictionary,
	player_id: String,
	team_id: String,
	offer: Dictionary,
	year: int,
	team_spending: Dictionary
) -> Dictionary:
	# Find player object (checks rosters first, then undrafted pool)
	var player := _find_player_object(world_state, player_id, year)
	if player.is_empty():
		SimLogger.error("Cannot find player %s for signing" % player_id)
		return {}

	# Determine previous team (empty for UDFAs)
	var previous_team_id := _find_player_team(world_state, player_id)

	# Create new contract from offer
	var contract := {
		"status": "signed",
		"annual_value": offer.get("annual_value", 0.0),
		"years_total": offer.get("years_total", 1),
		"years_remaining": offer.get("years_total", 1),
		"base_salary": offer.get("base_salary", 0.0),
		"signing_bonus": offer.get("signing_bonus", 0.0),
		"guaranteed_value": offer.get("guaranteed_value", 0.0),
		"cap_hit_year_1": offer.get("cap_hit_year_1", 0.0),
		"signed_year": year,
		"trigger": "free_agency_signed"
	}

	# Transition contract status
	var transition := ContractLifecycle.transition_unsigned_to_signed(
		contract,
		"free_agency_signed",
		year
	)

	player["contract"] = transition["contract"]

	# Move player to new team (pass year for UDFA pool lookup)
	_move_player_to_team(world_state, player_id, previous_team_id, team_id, year)

	# Update team cap space
	var team := _find_team(world_state, team_id)
	var cap_impact := float(transition.get("cap_impact", {}).get("annual_value_delta", 0.0))
	team["cap_space"] = float(team.get("cap_space", 0.0)) - cap_impact

	# Track spending for cap space summary
	var aav := float(contract.get("annual_value", 0.0))
	if not team_spending.has(team_id):
		team_spending[team_id] = 0.0
	team_spending[team_id] = float(team_spending[team_id]) + aav

	# Log signing with UDFA indicator
	var udfa_marker := " (UDFA)" if previous_team_id.is_empty() else ""
	SimLogger.info("Signed %s to %s for %.2fM AAV%s" % [
		player_id, team_id, aav, udfa_marker
	])

	return {
		"player_id": player_id,
		"team_id": team_id,
		"previous_team_id": previous_team_id if not previous_team_id.is_empty() else "UDFA",
		"contract": contract,
		"year": year
	}


## INTERNAL: Apply franchise tags (called before FA market).
static func _apply_franchise_tags(
	world_state: Dictionary,
	year: int,
	free_agents: Array,
	league_cfg: Dictionary
) -> Array:
	# TODO: Implement AI logic for which players teams should franchise tag
	# For now, return empty array (no tags applied automatically)
	# Tags would be applied manually or via AI decision-making

	return []


## INTERNAL: Remove franchise-tagged players from FA pool.
static func _remove_franchise_tagged(free_agents: Array, franchise_tagged: Array) -> Array:
	var tagged_player_ids := {}
	for tag in franchise_tagged:
		var tag_dict := tag as Dictionary
		tagged_player_ids[tag_dict.get("player_id", "")] = true

	var remaining: Array = []
	for fa_profile in free_agents:
		var profile_dict := fa_profile as Dictionary
		var player_id := String(profile_dict.get("player_id", ""))
		if not tagged_player_ids.has(player_id):
			remaining.append(fa_profile)

	return remaining


## INTERNAL: Calculate tag salary (top 5 position average).
static func _calculate_tag_salary(world_state: Dictionary, position: String, tag_type: String) -> float:
	# Collect all contracts for this position
	var position_salaries: Array = []
	var nfl_rosters := world_state.get("nfl_rosters", {}) as Dictionary

	for team_id in nfl_rosters.keys():
		var roster := nfl_rosters.get(team_id, {}) as Dictionary
		var players := roster.get("players", []) as Array

		for player in players:
			var player_dict := player as Dictionary
			if player_dict.get("position", "") == position:
				var contract := player_dict.get("contract", {}) as Dictionary
				var aav := float(contract.get("annual_value", 0.0))
				if aav > 0.0:
					position_salaries.append(aav)

	# Sort descending
	position_salaries.sort()
	position_salaries.reverse()

	# Get top 5 average
	var top_5_count := mini(5, position_salaries.size())
	if top_5_count == 0:
		return 10.0  # Default if no contracts found

	var sum := 0.0
	for i in range(top_5_count):
		sum += position_salaries[i]

	var average := sum / top_5_count

	# Apply tag type multiplier
	if tag_type == "exclusive":
		average *= 1.2  # 120% for exclusive tag
	elif tag_type == "non_exclusive":
		average *= 1.0  # 100% for non-exclusive
	elif tag_type == "transition":
		average *= 1.0  # 100% for transition tag

	return average


## INTERNAL: Get consecutive franchise tag years for player.
static func _get_consecutive_tag_years(world_state: Dictionary, player_id: String, current_year: int) -> int:
	var franchise_tags := world_state.get("franchise_tags", {}) as Dictionary
	var consecutive := 0

	# Check previous years
	for check_year in range(current_year - 1, current_year - 5, -1):
		if not franchise_tags.has(check_year):
			break

		var year_tags := franchise_tags.get(check_year, {}) as Dictionary
		var found := false

		for team_id in year_tags.keys():
			var tag := year_tags.get(team_id, {}) as Dictionary
			if tag.get("player_id", "") == player_id:
				consecutive += 1
				found = true
				break

		if not found:
			break  # Non-consecutive

	return consecutive


## INTERNAL: Collect unsigned players.
static func _collect_unsigned(free_agents: Array, signings: Array) -> Array:
	var signed_player_ids := {}
	for signing in signings:
		var signing_dict := signing as Dictionary
		signed_player_ids[signing_dict.get("player_id", "")] = true

	var unsigned: Array = []
	for fa_profile in free_agents:
		var profile_dict := fa_profile as Dictionary
		var player_id := String(profile_dict.get("player_id", ""))
		if not signed_player_ids.has(player_id):
			unsigned.append(player_id)

	return unsigned


## INTERNAL: Store FA results in world state.
static func _store_fa_results(
	world_state: Dictionary,
	year: int,
	free_agents: Array,
	signings: Array,
	unsigned: Array,
	franchise_tagged: Array
) -> void:
	if not world_state.has("free_agent_pool"):
		world_state["free_agent_pool"] = {}

	world_state["free_agent_pool"][year] = {
		"all": free_agents,
		"signed": signings,
		"unsigned": unsigned,
		"franchise_tags": franchise_tagged
	}


## INTERNAL: Calculate total money spent in FA.
static func _calculate_total_spent(signings: Array) -> float:
	var total := 0.0
	for signing in signings:
		var signing_dict := signing as Dictionary
		var contract := signing_dict.get("contract", {}) as Dictionary
		var aav := float(contract.get("annual_value", 0.0))
		total += aav
	return total


## INTERNAL: Find player in all rosters.
static func _find_player_in_rosters(world_state: Dictionary, player_id: String) -> Dictionary:
	var nfl_rosters := world_state.get("nfl_rosters", {}) as Dictionary

	for team_id in nfl_rosters.keys():
		var roster := nfl_rosters.get(team_id, {}) as Dictionary
		var players := roster.get("players", []) as Array

		for player in players:
			var player_dict := player as Dictionary
			if player_dict.get("id", "") == player_id:
				return player_dict

	return {}


## INTERNAL: Find player in undrafted pool by player_id.
##
## Searches the undrafted pool for a specific year to find a player.
## Returns player Dictionary or empty {} if not found.
##
## RNG: None (deterministic lookup)
##
## @param world_state: World state dictionary
## @param player_id: Player identifier to search for
## @param year: Year of the undrafted pool to search
## @return: Player dictionary or empty {} if not found
static func _find_player_in_undrafted_pool(
	world_state: Dictionary,
	player_id: String,
	year: int
) -> Dictionary:
	var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {})
	var year_pool: Array = undrafted_pool.get(year, [])

	for player in year_pool:
		var p: Dictionary = player
		var pid := String(p.get("id", ""))
		if pid == player_id:
			return p

	return {}


## INTERNAL: Find player object by ID, searching both rosters and undrafted pool.
##
## First searches all NFL rosters, then falls back to undrafted pool if not found.
## This enables UDFA signing by finding players not yet on any roster.
##
## VERIFICATION: This function enables UDFA integration by:
## 1. Searching rosters first for veteran FAs (normal path)
## 2. Falling back to undrafted_pool[year] for UDFAs (new path)
## 3. Returning player dict with "player_id" field (normalized in NflDraft)
##
## RNG: None (deterministic lookup)
##
## @param world_state: World state dictionary
## @param player_id: Player identifier to search for
## @param year: Year of the undrafted pool to search (if needed)
## @return: Player dictionary or empty {} if not found
static func _find_player_object(
	world_state: Dictionary,
	player_id: String,
	year: int
) -> Dictionary:
	# Try rosters first (veteran FAs)
	var player := _find_player_in_rosters(world_state, player_id)
	if not player.is_empty():
		return player

	# Try undrafted pool (UDFAs)
	return _find_player_in_undrafted_pool(world_state, player_id, year)


## INTERNAL: Find which team a player is on.
static func _find_player_team(world_state: Dictionary, player_id: String) -> String:
	var nfl_rosters := world_state.get("nfl_rosters", {}) as Dictionary

	for team_id in nfl_rosters.keys():
		var roster := nfl_rosters.get(team_id, {}) as Dictionary
		var players := roster.get("players", []) as Array

		for player in players:
			var player_dict := player as Dictionary
			if player_dict.get("id", "") == player_id:
				return team_id

	return ""


## INTERNAL: Find team by ID.
static func _find_team(world_state: Dictionary, team_id: String) -> Dictionary:
	var nfl_teams := world_state.get("nfl_teams", []) as Array
	return _find_team_by_id(nfl_teams, team_id)


## INTERNAL: Find team in array by ID.
static func _find_team_by_id(teams: Array, team_id: String) -> Dictionary:
	for team in teams:
		var team_dict := team as Dictionary
		if team_dict.get("id", "") == team_id:
			return team_dict
	return {}


## INTERNAL: Move player from one team to another.
##
## Supports moving players from:
## - Team roster to another team roster (normal FA/trade)
## - Undrafted pool to team roster (UDFA signing)
##
## RNG: None (deterministic move operation)
##
## @param world_state: World state dictionary (MUTATED in-place)
## @param player_id: Player identifier to move
## @param from_team_id: Source team ID (empty string for UDFA)
## @param to_team_id: Destination team ID
## @param year: Current year (for undrafted pool lookup, optional for backward compatibility)
static func _move_player_to_team(
	world_state: Dictionary,
	player_id: String,
	from_team_id: String,
	to_team_id: String,
	year: int = 0
) -> void:
	var nfl_rosters := world_state.get("nfl_rosters", {}) as Dictionary

	# Find player object (checks rosters first, then undrafted pool)
	var player := _find_player_object(world_state, player_id, year)
	if player.is_empty():
		SimLogger.error("Cannot find player %s" % player_id)
		return

	# Remove from old team (if from a team roster)
	if not from_team_id.is_empty() and nfl_rosters.has(from_team_id):
		var from_roster := nfl_rosters.get(from_team_id, {}) as Dictionary
		var from_players := from_roster.get("players", []) as Array

		for i in range(from_players.size()):
			var p := from_players[i] as Dictionary
			if p.get("id", "") == player_id:
				from_players.remove_at(i)
				break

	# Remove from undrafted pool if present
	if year > 0:
		var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {})
		if undrafted_pool.has(year):
			var year_pool: Array = undrafted_pool[year]
			for i in range(year_pool.size()):
				var p: Dictionary = year_pool[i]
				var pid := String(p.get("id", ""))
				if pid == player_id:
					year_pool.remove_at(i)
					break

	# Add to new team
	if not to_team_id.is_empty():
		if not nfl_rosters.has(to_team_id):
			nfl_rosters[to_team_id] = {"players": []}

		var to_roster := nfl_rosters.get(to_team_id, {}) as Dictionary
		if not to_roster.has("players"):
			to_roster["players"] = []

		var to_players := to_roster.get("players", []) as Array
		to_players.append(player)

## Fill team rosters to minimum size (53 players) with UDFAs using market dynamics
##
## After regular free agency, teams may still be below the 53-player minimum.
## This runs a competitive UDFA market where:
## 1. Teams generate interest in UDFAs based on positional needs
## 2. Teams make offers to players they want
## 3. Players choose best offer (considering money, playing time, team quality)
## 4. Market runs in rounds until teams reach 53 or UDFA pool exhausted
##
## RNG: 1 randf_range() call per team-player interest evaluation
##      + 1 randf_range() per player offer evaluation
##
## @param world_state: World state dictionary
## @param year: Current year
## @param positions_cfg: Positions configuration
## @param main_cfg: Main configuration
## @param league_cfg: League configuration (for roster limits)
## @param rng: RandomNumberGenerator for market dynamics
## @param team_spending: Dictionary tracking team spending (updated in place)
## @return: Array of signing dictionaries
static func _fill_rosters_to_minimum(
	world_state: Dictionary,
	year: int,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	league_cfg: Dictionary,
	rng: RandomNumberGenerator,
	team_spending: Dictionary
) -> Array:
	var roster_limits := league_cfg.get("roster_limits", {}) as Dictionary
	var min_roster_size := int(roster_limits.get("active", 53))
	var rosters := world_state.get("nfl_rosters", {}) as Dictionary
	var teams := world_state.get("nfl_teams", []) as Array
	var undrafted_pool := world_state.get("undrafted_pool", {}) as Dictionary
	var year_udfas: Array = undrafted_pool.get(year, []) as Array

	if year_udfas.is_empty():
		return []  # No UDFAs available

	# Create FA profiles for all UDFAs
	var udfa_profiles: Array = []
	for udfa in year_udfas:
		var profile := _create_udfa_fa_profile(udfa, year, positions_cfg, main_cfg)
		udfa_profiles.append(profile)

	var all_signings: Array = []
	var max_rounds := 10  # Prevent infinite loops
	var round_num := 0

	# Run market rounds until all teams have 53 players or no more UDFAs
	while round_num < max_rounds:
		round_num += 1

		# Check if any team still needs players
		var teams_needing_players := _get_teams_below_minimum(teams, rosters, min_roster_size)
		if teams_needing_players.is_empty():
			break  # All teams full

		if udfa_profiles.is_empty():
			break  # No more UDFAs available

		# Generate team interest for remaining UDFAs
		# CRITICAL: Weight heavily by positional need for roster-filling
		var team_interest := _generate_udfa_team_interest(
			world_state,
			udfa_profiles,
			teams_needing_players,
			rosters,
			min_roster_size,
			rng
		)

		# Process signings for this round
		var round_signings: Array = []
		var signed_this_round := {}

		for fa_profile in udfa_profiles:
			var player_id := String(fa_profile.get("player_id", ""))

			# Generate offers from interested teams
			var offers := _generate_offers_for_player(
				fa_profile,
				team_interest,
				world_state,
				positions_cfg,
				main_cfg
			)

			if offers.is_empty():
				continue  # No teams interested

			# Player chooses best offer
			var chosen_team_id := player_chooses_team(
				player_id,
				team_interest,
				offers,
				rng
			)

			if chosen_team_id.is_empty():
				continue  # Player declined all offers (shouldn't happen for UDFAs)

			# Execute signing
			var chosen_offer := _find_offer(offers, chosen_team_id)
			var signing := _execute_signing(
				world_state,
				player_id,
				chosen_team_id,
				chosen_offer,
				year,
				team_spending
			)

			if not signing.is_empty():
				round_signings.append(signing)
				signed_this_round[player_id] = true

		# Remove signed players from UDFA pool
		udfa_profiles = udfa_profiles.filter(func(profile):
			var pid := String(profile.get("player_id", ""))
			return not signed_this_round.has(pid)
		)

		all_signings.append_array(round_signings)

		if round_signings.is_empty():
			break  # No signings this round, market has cleared

	if all_signings.size() > 0:
		SimLogger.info("UDFA market completed in %d rounds: %d signings" % [
			round_num, all_signings.size()
		])

		# Log final roster sizes
		var teams_still_short := _get_teams_below_minimum(teams, rosters, min_roster_size)
		if teams_still_short.size() > 0:
			SimLogger.warn("%d teams still below 53 players" % teams_still_short.size())

	return all_signings


## INTERNAL: Get list of teams below minimum roster size
static func _get_teams_below_minimum(
	teams: Array,
	rosters: Dictionary,
	min_size: int
) -> Array:
	var teams_below: Array = []
	for team in teams:
		var team_id := String(team.get("id", ""))
		var roster := rosters.get(team_id, {}) as Dictionary
		var players := roster.get("players", []) as Array
		if players.size() < min_size:
			teams_below.append(team_id)
	return teams_below


## INTERNAL: Generate team interest for UDFAs with heavy positional need weighting
##
## Similar to regular generate_team_interest() but with critical differences:
## - Only evaluates teams that need players
## - Heavily weights positional need (3x multiplier for critical needs)
## - Lower interest threshold (teams more willing to sign UDFAs to fill rosters)
##
## RNG: 1 randf_range() call per team-player evaluation
static func _generate_udfa_team_interest(
	world_state: Dictionary,
	udfa_profiles: Array,
	teams_needing_players: Array,
	rosters: Dictionary,
	min_roster_size: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	var team_interest := {}
	var nfl_teams := world_state.get("nfl_teams", []) as Array

	# Filter to only teams that need players
	var active_teams: Array = []
	for team in nfl_teams:
		var team_id := String(team.get("id", ""))
		if teams_needing_players.has(team_id):
			active_teams.append(team)

	for team in active_teams:
		var team_id := String(team.get("id", ""))
		team_interest[team_id] = {}

		var roster := rosters.get(team_id, {}) as Dictionary
		var players := roster.get("players", []) as Array
		var cap_space := float(team.get("cap_space", 0.0))

		# Calculate positional deficits for heavy need weighting
		var position_deficits := _calculate_position_deficits(roster)

		for fa_profile in udfa_profiles:
			var player_id := String(fa_profile.get("player_id", ""))
			var position := String(fa_profile.get("position", ""))
			var minimum_demand := float(fa_profile.get("minimum_demand", 0.9))

			# HARD CAP CHECK: Zero interest if position is at max capacity
			if RosterComposition.is_position_at_cap(roster, position):
				team_interest[team_id][player_id] = 0.0
				continue

			# Base interest from positional need
			var deficit := int(position_deficits.get(position, 0))
			var need_score := 1.0
			if deficit > 0:
				need_score = 3.0  # Critical need (position below minimum)
			elif players.size() < min_roster_size - 5:
				# Only consider filling if position is below ideal (not overstocked)
				var current := (roster.get("by_position", {}).get(position, []) as Array).size()
				var ideal := RosterComposition.get_ideal_depth(position)
				if current < ideal:
					need_score = 2.0  # Position has room, helps fill roster
				else:
					need_score = 0.3  # Position overstocked, low interest

			# Affordability (UDFAs are cheap, so usually 1.0)
			var affordability := 1.0 if cap_space >= minimum_demand else 0.3

			# RNG CALL: Add variance
			var variance := rng.randf_range(0.85, 1.15)

			# Final interest score (need-driven)
			var interest_score := need_score * affordability * variance

			team_interest[team_id][player_id] = interest_score

	return team_interest


## INTERNAL: Calculate positional deficits vs minimum requirements
static func _calculate_position_deficits(roster: Dictionary) -> Dictionary:
	return RosterComposition.calculate_minimum_deficits(roster)

## Returns current timestamp in HH:MM:SS format
static func _get_timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [time["hour"], time["minute"], time["second"]]
