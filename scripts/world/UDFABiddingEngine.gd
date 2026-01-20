## UDFABiddingEngine - Stateless service for undrafted free agent signing
##
## ARCHITECTURAL PATTERN: Stateless RefCounted Service
##
## This service manages the UDFA signing period after the NFL draft.
## It processes user priority targets first, then AI teams bid on
## remaining undrafted players based on team needs.
##
## Key Design Decisions:
## - User selects 3-5 priority targets BEFORE AI bidding
## - User gets first claim on their priority targets
## - AI teams sign 1-2 UDFAs each based on position needs
## - Top 50 UDFAs by talent are eligible for signing (rest go to camp invites)
## - All contract creation uses RookieWageScale for consistency
##
## RNG Usage:
## - Seed derived from base seed ^ 0x0DFA0001
## - RNG calls: 1 per AI team (randi_range for sign count)
## - RNG must be passed explicitly through call chain
##
## Usage:
##   var results = UDFABiddingEngine.run(
##       world_state, year, seed, user_team_id, user_targets,
##       league_cfg, positions_cfg, main_cfg
##   )
##
extends RefCounted
class_name UDFABiddingEngine

const Rand = preload("res://autoloads/Rand.gd")
const RookieWageScale = preload("res://scripts/core/contracts/RookieWageScale.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const RosterComposition = preload("res://scripts/core/roster/RosterComposition.gd")
const ContractStateManager = preload("res://scripts/core/state/ContractStateManager.gd")

# Configuration constants
const MAX_UDFAS_TO_SIGN := 50       # Top 50 UDFAs are eligible for signing
const MAX_USER_TARGETS := 5         # User can select up to 5 priority targets
const MIN_USER_TARGETS := 0         # User can skip UDFA phase entirely
const AI_SIGN_MIN := 1              # AI teams sign at least 1 UDFA
const AI_SIGN_MAX := 2              # AI teams sign at most 2 UDFAs
const RNG_SEED_SUFFIX: int = 0x0DFA0001 # Seed suffix for determinism (UDFA -> 0DFA)


## Run the UDFA bidding process
##
## @param world_state: Full world state dictionary (will be mutated)
## @param year: Current year
## @param seed: Base RNG seed for determinism
## @param user_team_id: User's team ID (empty string if simulating)
## @param user_priority_targets: Array of player_id strings (user's picks)
## @param league_cfg: League configuration (for cap limit)
## @param positions_cfg: Position configuration
## @param main_cfg: Main configuration (for class rules)
## @return: Dictionary with user_signings, ai_signings, unsigned
static func run(
	world_state: Dictionary,
	year: int,
	seed: int,
	user_team_id: String,
	user_priority_targets: Array,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	# Initialize RNG with deterministic seed
	# RNG Call Pattern: splitmix64 for seed derivation (1 call)
	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(seed ^ RNG_SEED_SUFFIX)

	# Get undrafted pool for this year
	var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {})
	var undrafted: Array = (undrafted_pool.get(year, []) as Array).duplicate()

	if undrafted.is_empty():
		return {
			"user_signings": [],
			"ai_signings": [],
			"unsigned": [],
			"error": null
		}

	var class_rules: Dictionary = main_cfg.get("class_rules", {})
	var cap_limit := float(league_cfg.get("cap_limit", 200.0))

	# Step 1: Rank UDFAs by talent (deterministic - no RNG)
	var ranked_udfas := _rank_udfas(undrafted, positions_cfg, class_rules)

	# Step 2: Limit to top N eligible for signing
	var eligible_udfas := ranked_udfas.slice(0, mini(MAX_UDFAS_TO_SIGN, ranked_udfas.size()))

	# Build lookup dictionary for O(1) access
	var udfa_by_id: Dictionary = {}
	for udfa in eligible_udfas:
		var u: Dictionary = udfa
		var player_id := String(u.get("player_id", u.get("id", "")))
		udfa_by_id[player_id] = u

	# Step 3: Process user priority targets FIRST (user gets first claim)
	var user_signings: Array = []
	var signed_player_ids: Dictionary = {}

	if not user_team_id.is_empty() and not user_priority_targets.is_empty():
		user_signings = _process_user_targets(
			user_priority_targets,
			udfa_by_id,
			user_team_id,
			year,
			cap_limit,
			signed_player_ids
		)

	# Step 4: AI teams bid on remaining UDFAs (need-based)
	var teams: Array = world_state.get("nfl_teams", [])
	var rosters: Dictionary = world_state.get("nfl_rosters", {})

	var ai_signings := _process_ai_bidding(
		eligible_udfas,
		teams,
		rosters,
		user_team_id,
		year,
		cap_limit,
		positions_cfg,
		class_rules,
		signed_player_ids,
		rng
	)

	# Step 5: Update world state with signings
	_update_world_state(world_state, year, user_signings, ai_signings)

	# Calculate unsigned (eligible but not signed)
	var unsigned: Array = []
	for udfa in eligible_udfas:
		var u: Dictionary = udfa
		var player_id := String(u.get("player_id", u.get("id", "")))
		if not signed_player_ids.has(player_id):
			unsigned.append(u)

	return {
		"user_signings": user_signings,
		"ai_signings": ai_signings,
		"unsigned": unsigned,
		"total_eligible": eligible_udfas.size(),
		"total_signed": user_signings.size() + ai_signings.size(),
		"error": null
	}


## Rank UDFAs by overall talent (deterministic, no RNG)
##
## Uses BPA approach - sorts all undrafted players by overall rating.
## Tiebreaker is player_id for determinism.
static func _rank_udfas(
	undrafted: Array,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> Array:
	var ranked := undrafted.duplicate()

	ranked.sort_custom(func(a, b):
		var a_rating := PlayerRatingCalculator.calculate_overall_rating(
			a as Dictionary, positions_cfg, class_rules
		)
		var b_rating := PlayerRatingCalculator.calculate_overall_rating(
			b as Dictionary, positions_cfg, class_rules
		)

		# If ratings are close (within 0.01), use player_id as tiebreaker
		if abs(a_rating - b_rating) < 0.01:
			var a_id := String((a as Dictionary).get("player_id", (a as Dictionary).get("id", "")))
			var b_id := String((b as Dictionary).get("player_id", (b as Dictionary).get("id", "")))
			return a_id < b_id

		return a_rating > b_rating
	)

	return ranked


## Process user priority targets (user gets first claim)
##
## User targets are processed in order - first target has highest priority.
## Returns array of signing records.
static func _process_user_targets(
	user_targets: Array,
	udfa_by_id: Dictionary,
	user_team_id: String,
	year: int,
	cap_limit: float,
	signed_player_ids: Dictionary
) -> Array:
	var signings: Array = []

	for target in user_targets:
		var player_id := String(target)

		# Check if player is eligible (in the UDFA pool)
		if not udfa_by_id.has(player_id):
			continue  # Player not in eligible pool - skip silently

		# Check if player already signed (shouldn't happen for user targets)
		if signed_player_ids.has(player_id):
			continue

		var udfa: Dictionary = udfa_by_id[player_id]
		var contract := RookieWageScale.create_udfa_contract(year, cap_limit)

		# Create signing record
		var signing := {
			"player_id": player_id,
			"team_id": user_team_id,
			"contract": contract,
			"player": udfa,
			"priority_rank": signings.size() + 1
		}

		signings.append(signing)
		signed_player_ids[player_id] = true

		# Stop if we've signed max targets
		if signings.size() >= MAX_USER_TARGETS:
			break

	return signings


## Process AI team bidding (need-based selection)
##
## Each AI team evaluates available UDFAs by position need and signs 1-2.
## RNG is used to determine how many UDFAs each team signs.
##
## RNG Call Pattern: 1 call per AI team (randi_range for sign count)
static func _process_ai_bidding(
	eligible_udfas: Array,
	teams: Array,
	rosters: Dictionary,
	user_team_id: String,
	year: int,
	cap_limit: float,
	positions_cfg: Dictionary,
	class_rules: Dictionary,
	signed_player_ids: Dictionary,
	rng: RandomNumberGenerator
) -> Array:
	var signings: Array = []

	# Build list of available UDFAs (not yet signed)
	var available: Array = []
	for udfa in eligible_udfas:
		var u: Dictionary = udfa
		var player_id := String(u.get("player_id", u.get("id", "")))
		if not signed_player_ids.has(player_id):
			available.append(u)

	# Process each AI team
	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))

		# Skip user team and empty team IDs
		if team_id.is_empty() or team_id == user_team_id:
			continue

		if available.is_empty():
			break

		var roster: Dictionary = rosters.get(team_id, {})
		var needs := _calculate_position_needs(roster, positions_cfg)

		# Score each available UDFA by need fit
		var scored_udfas: Array = []
		for udfa in available:
			var u: Dictionary = udfa
			var position := String(u.get("position", ""))
			var need_mult := float(needs.get(position, 1.0))
			var talent := PlayerRatingCalculator.calculate_overall_rating(
				u, positions_cfg, class_rules
			)

			scored_udfas.append({
				"udfa": u,
				"score": talent * need_mult,
				"talent": talent,
				"need_mult": need_mult
			})

		# Sort by score (highest first)
		scored_udfas.sort_custom(func(a, b):
			if abs(float(a.get("score", 0)) - float(b.get("score", 0))) < 0.01:
				# Tiebreaker: player_id
				var a_id := String((a.get("udfa", {}) as Dictionary).get("player_id", ""))
				var b_id := String((b.get("udfa", {}) as Dictionary).get("player_id", ""))
				return a_id < b_id
			return float(a.get("score", 0)) > float(b.get("score", 0))
		)

		# RNG Call: Determine how many UDFAs this team signs (1-2)
		var sign_count := rng.randi_range(AI_SIGN_MIN, AI_SIGN_MAX)

		# Sign top N UDFAs
		for i in range(mini(sign_count, scored_udfas.size())):
			var entry: Dictionary = scored_udfas[i]
			var udfa: Dictionary = entry.get("udfa", {})
			var player_id := String(udfa.get("player_id", udfa.get("id", "")))

			var contract := RookieWageScale.create_udfa_contract(year, cap_limit)

			var signing := {
				"player_id": player_id,
				"team_id": team_id,
				"contract": contract,
				"player": udfa,
				"score": entry.get("score", 0),
				"need_mult": entry.get("need_mult", 1.0)
			}

			signings.append(signing)
			signed_player_ids[player_id] = true

			# Remove from available pool
			available.erase(udfa)

	return signings


## Calculate position needs for a team
##
## Returns a dictionary mapping position -> need multiplier.
## Higher multiplier = greater need.
static func _calculate_position_needs(
	roster: Dictionary,
	positions_cfg: Dictionary
) -> Dictionary:
	var by_position: Dictionary = roster.get("by_position", {})
	var needs: Dictionary = {}

	for pos in positions_cfg.keys():
		var current_count: int = (by_position.get(pos, []) as Array).size()
		var ideal: int = RosterComposition.get_ideal_depth(pos)

		if current_count == 0:
			needs[pos] = 2.0  # Critical need
		elif current_count < ideal:
			var deficit := ideal - current_count
			needs[pos] = 1.0 + (float(deficit) / float(ideal)) * 0.5
		else:
			needs[pos] = 0.8  # Position filled

	return needs


## Update world state with UDFA signings (via ContractStateManager)
##
## CRITICAL: All contract mutations flow through ContractStateManager for atomicity.
## This ensures:
## - DataBus notifications fire automatically
## - UI components auto-refresh during UDFA bidding
## - Cap space is tracked correctly
## - Contract state transitions are valid
##
## - Executes each signing through ContractStateManager
## - Records UDFA history for the year
static func _update_world_state(
	world_state: Dictionary,
	year: int,
	user_signings: Array,
	ai_signings: Array
) -> void:
	# Combine all signings
	var all_signings := user_signings + ai_signings

	# Execute each signing through ContractStateManager (handles all mutations atomically)
	for signing in all_signings:
		var s: Dictionary = signing
		var team_id := String(s.get("team_id", ""))
		var player_id := String(s.get("player_id", ""))
		var contract: Dictionary = s.get("contract", {})

		if team_id.is_empty() or player_id.is_empty() or contract.is_empty():
			push_warning("UDFABiddingEngine: Invalid signing record, skipping: %s" % str(s))
			continue

		# Convert UDFA contract to offer format for ContractStateManager
		# ContractStateManager.execute_signing() expects an offer dictionary with:
		# - annual_value, years_total, signing_bonus, guarantee_amount, base_salary
		var offer := {
			"team_id": team_id,
			"annual_value": contract.get("annual_value", 0.0),
			"years_total": contract.get("years_remaining", 1),
			"signing_bonus": contract.get("signing_bonus", 0.0),
			"guarantee_amount": contract.get("guarantee_amount", 0.0),
			"base_salary": contract.get("base_salary", 0.0)
		}

		# Execute signing through ContractStateManager (handles all mutations atomically)
		# This:
		# 1. Validates player exists in undrafted_pool[year]
		# 2. Creates and signs contract
		# 3. Moves player from undrafted_pool to team roster
		# 4. Updates team cap space
		# 5. Emits DataBus notifications
		var signing_result := ContractStateManager.execute_signing(
			world_state,
			player_id,
			team_id,
			offer,
			year
		)

		# Check if signing succeeded
		if not signing_result.get("success", false):
			var error_msg := String(signing_result.get("error", "unknown"))
			push_error("UDFABiddingEngine: Failed to sign player %s to %s: %s" % [
				player_id, team_id, error_msg
			])
			continue

		# Log successful signing
		var annual_value := float(signing_result.get("annual_value", 0.0))
		print_verbose("UDFABiddingEngine: Signed %s to %s for $%.2fM AAV" % [
			player_id, team_id, annual_value
		])

	# Record UDFA history (this is history/analytics data, not core state)
	if not world_state.has("udfa_history"):
		world_state["udfa_history"] = {}
	var udfa_history := world_state.get("udfa_history", {}) as Dictionary

	var user_signing_records: Array = []
	for s in user_signings:
		user_signing_records.append({
			"player_id": s.get("player_id", ""),
			"team_id": s.get("team_id", ""),
			"priority_rank": s.get("priority_rank", 0)
		})

	var ai_signing_records: Array = []
	for s in ai_signings:
		ai_signing_records.append({
			"player_id": s.get("player_id", ""),
			"team_id": s.get("team_id", "")
		})

	udfa_history[year] = {
		"user_signings": user_signing_records,
		"ai_signings": ai_signing_records,
		"total_signed": all_signings.size(),
		"unsigned_count": MAX_UDFAS_TO_SIGN - all_signings.size()
	}


## Get eligible UDFA pool for UI display
##
## Returns ranked list of eligible UDFAs with contract previews.
static func get_eligible_udfas(
	world_state: Dictionary,
	year: int,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	league_cfg: Dictionary
) -> Array:
	var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {})
	var undrafted: Array = (undrafted_pool.get(year, []) as Array).duplicate()

	if undrafted.is_empty():
		return []

	var class_rules: Dictionary = main_cfg.get("class_rules", {})
	var cap_limit := float(league_cfg.get("cap_limit", 200.0))

	# Rank by talent
	var ranked := _rank_udfas(undrafted, positions_cfg, class_rules)

	# Limit to eligible
	var eligible := ranked.slice(0, mini(MAX_UDFAS_TO_SIGN, ranked.size()))

	# Add contract preview and overall rating
	var result: Array = []
	for udfa in eligible:
		var u: Dictionary = udfa
		var overall := PlayerRatingCalculator.calculate_overall_rating(
			u, positions_cfg, class_rules
		)
		var contract := RookieWageScale.create_udfa_contract(year, cap_limit)

		result.append({
			"player": u,
			"player_id": String(u.get("player_id", u.get("id", ""))),
			"name": String(u.get("name", "Unknown")),
			"position": String(u.get("position", "")),
			"overall": overall,
			"contract_preview": contract
		})

	return result


## Validate user target selection
##
## Returns validation result with any errors.
static func validate_user_targets(
	targets: Array,
	world_state: Dictionary,
	year: int
) -> Dictionary:
	if targets.size() > MAX_USER_TARGETS:
		return {
			"valid": false,
			"error": "Maximum %d targets allowed, got %d" % [MAX_USER_TARGETS, targets.size()]
		}

	# Check for duplicates
	var seen: Dictionary = {}
	for target in targets:
		var player_id := String(target)
		if seen.has(player_id):
			return {
				"valid": false,
				"error": "Duplicate target: %s" % player_id
			}
		seen[player_id] = true

	# Check all targets exist in undrafted pool
	var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {})
	var undrafted: Array = undrafted_pool.get(year, [])
	var undrafted_ids: Dictionary = {}
	for u in undrafted:
		var player_id := String((u as Dictionary).get("player_id", (u as Dictionary).get("id", "")))
		undrafted_ids[player_id] = true

	for target in targets:
		var player_id := String(target)
		if not undrafted_ids.has(player_id):
			return {
				"valid": false,
				"error": "Target %s is not in undrafted pool" % player_id
			}

	return {"valid": true, "error": null}


## Check if UDFA phase can be skipped
##
## UDFA phase is skippable and non-blocking for season advancement.
static func can_skip() -> bool:
	return true


## Get UDFA phase summary for display
static func get_phase_summary(world_state: Dictionary, year: int) -> Dictionary:
	var udfa_history: Dictionary = world_state.get("udfa_history", {})
	var year_data: Dictionary = udfa_history.get(year, {})

	return {
		"year": year,
		"completed": not year_data.is_empty(),
		"user_signed": (year_data.get("user_signings", []) as Array).size(),
		"ai_signed": (year_data.get("ai_signings", []) as Array).size(),
		"total_signed": year_data.get("total_signed", 0),
		"unsigned_count": year_data.get("unsigned_count", 0)
	}
