## DraftTradeEngine - Draft Pick Trading System
##
## Purpose: Core trade validation, evaluation, and execution logic for draft day trading.
## Enables AI teams and users to propose and execute trades during the live draft.
##
## Design Philosophy:
##   - Stateless service (all context passed as parameters)
##   - Deterministic via explicit RNG seeding from context
##   - Pure functions with no world_state access
##   - Configuration-driven value calculations
##
## RNG Pattern:
##   - Trade acceptance: Rand.splitmix64(base_seed ^ hash(receiving_team_id) ^ year ^ current_pick)
##   - AI proposal generation: Rand.splitmix64(base_seed ^ current_pick ^ 0x7ADE00)
##   - QB urgency check: Rand.splitmix64(base_seed ^ hash(team_id) ^ 0xQB00)
##
## Integration Points:
##   - InteractiveDraft: TRADE_WINDOW state management, execution
##   - NflDraft: value_draft_pick() for pick valuation
##   - EvaluationContext: QB urgency checks
##   - TradeProposalDialog: UI for user-initiated trades
##
## QB Urgency Integration:
##   Teams with QB urgency level "desperate" (2.8x multiplier) are aggressive traders:
##   - 70%+ of QB-desperate teams propose trades when elite QB (75+) available
##   - QB urgency boosts acceptance rate for trades that move up for QB
##   - Target: 15-25 trades per draft year (realistic NFL range)
##
extends RefCounted
class_name DraftTradeEngine

const Rand = preload("res://autoloads/Rand.gd")
const NflDraft = preload("res://scripts/world/NflDraft.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

## Schema version for trade records (enables future migration)
const TRADE_SCHEMA_VERSION := 1

## Base acceptance rate for fair trades (30%)
const BASE_ACCEPTANCE_RATE := 0.3

## Maximum acceptance probability (never 100% certain)
const MAX_ACCEPTANCE_RATE := 0.90

## Minimum acceptance probability (always some chance)
const MIN_ACCEPTANCE_RATE := 0.10

## Value differential threshold for AI to consider trade (within 20%)
const AI_VALUE_DIFFERENTIAL_THRESHOLD := 0.20

## Maximum trades generated per pick by AI
const MAX_AI_PROPOSALS_PER_PICK := 3

## QB urgency multiplier for trade aggression (from PR #149)
const QB_DESPERATE_MULTIPLIER := 2.8
const QB_MODERATE_MULTIPLIER := 1.6

## Threshold for elite QB prospects that trigger trade-up behavior
const ELITE_QB_THRESHOLD := 75.0

## Probability that QB-desperate team proposes trade when elite QB available
const QB_DESPERATE_TRADE_PROBABILITY := 0.70


## Validate trade legality
##
## Checks that a trade offer is structurally valid and legal:
##   1. Both teams exist (IDs are non-empty)
##   2. All picks offered are owned by the offering team
##   3. All picks requested are owned by the receiving team
##   4. No duplicate picks in the same offer
##   5. Pick numbers are valid (round 1-7, pick 1-32 per round)
##   6. No trading picks already used (pick < current_pick)
##
## RNG: None (pure validation)
##
## @param offer: Trade offer structure
## @param ownership: draft_pick_ownership ledger
## @param year: Current draft year
## @param current_pick: Current overall pick number (for used pick check)
## @return Dictionary: {valid: bool, reason: String}
static func validate_trade(
	offer: Dictionary,
	ownership: Dictionary,
	year: int,
	current_pick: int = 0
) -> Dictionary:
	var offering_team := String(offer.get("offering_team_id", ""))
	var receiving_team := String(offer.get("receiving_team_id", ""))

	# Check 1: Both teams exist
	if offering_team.is_empty():
		return {"valid": false, "reason": "Offering team ID is empty"}
	if receiving_team.is_empty():
		return {"valid": false, "reason": "Receiving team ID is empty"}
	if offering_team == receiving_team:
		return {"valid": false, "reason": "Cannot trade with yourself"}

	var picks_offered: Array = offer.get("picks_offered", []) as Array
	var picks_requested: Array = offer.get("picks_requested", []) as Array

	# Check: At least some exchange
	if picks_offered.is_empty() and picks_requested.is_empty():
		return {"valid": false, "reason": "Trade must include at least one pick on each side"}
	if picks_offered.is_empty():
		return {"valid": false, "reason": "Must offer at least one pick"}
	if picks_requested.is_empty():
		return {"valid": false, "reason": "Must request at least one pick"}

	# Check duplicates
	var offered_ids := {}
	for pick in picks_offered:
		var p: Dictionary = pick
		var pick_id := _get_pick_id(p, year)
		if offered_ids.has(pick_id):
			return {"valid": false, "reason": "Duplicate pick in offer: %s" % pick_id}
		offered_ids[pick_id] = true

	var requested_ids := {}
	for pick in picks_requested:
		var p: Dictionary = pick
		var pick_id := _get_pick_id(p, year)
		if requested_ids.has(pick_id):
			return {"valid": false, "reason": "Duplicate pick in request: %s" % pick_id}
		if offered_ids.has(pick_id):
			return {"valid": false, "reason": "Same pick in offer and request: %s" % pick_id}
		requested_ids[pick_id] = true

	# Validate each offered pick
	for pick in picks_offered:
		var p: Dictionary = pick
		var validation := _validate_pick(p, offering_team, ownership, year, current_pick, "offered")
		if not bool(validation.get("valid")):
			return validation

	# Validate each requested pick
	for pick in picks_requested:
		var p: Dictionary = pick
		var validation := _validate_pick(p, receiving_team, ownership, year, current_pick, "requested")
		if not bool(validation.get("valid")):
			return validation

	return {"valid": true, "reason": ""}


## Validate a single pick in a trade offer
static func _validate_pick(
	pick: Dictionary,
	expected_owner: String,
	ownership: Dictionary,
	year: int,
	current_pick: int,
	direction: String
) -> Dictionary:
	var pick_year := int(pick.get("year", year))
	var round_num := int(pick.get("round", 0))
	var pick_in_round := int(pick.get("pick_in_round", 0))

	# Check valid round and pick
	if round_num < 1 or round_num > 7:
		return {"valid": false, "reason": "Invalid round number %d in %s pick" % [round_num, direction]}
	if pick_in_round < 1 or pick_in_round > 32:
		return {"valid": false, "reason": "Invalid pick number %d in %s pick" % [pick_in_round, direction]}

	# Calculate overall pick number
	var overall := (round_num - 1) * 32 + pick_in_round

	# Check if pick already used (only for current year)
	if pick_year == year and overall <= current_pick:
		return {"valid": false, "reason": "Cannot trade pick #%d - already used" % overall}

	# Check ownership
	var year_ownership: Dictionary = ownership.get(pick_year, {}) as Dictionary
	var round_ownership: Dictionary = year_ownership.get(round_num, {}) as Dictionary

	# Find the original team that had this pick position
	var found_owner := ""
	for orig_team_id in round_ownership.keys():
		var current_owner := String(round_ownership.get(orig_team_id, ""))
		# The pick_in_round corresponds to original draft order position
		# We need to check if expected_owner currently owns this pick
		if current_owner == expected_owner:
			found_owner = expected_owner
			break

	if found_owner != expected_owner:
		return {"valid": false, "reason": "Team %s does not own %s pick Rd%d #%d" % [
			expected_owner, direction, round_num, pick_in_round
		]}

	return {"valid": true, "reason": ""}


## Get unique identifier for a pick
static func _get_pick_id(pick: Dictionary, default_year: int) -> String:
	var pick_year := int(pick.get("year", default_year))
	var round_num := int(pick.get("round", 0))
	var pick_in_round := int(pick.get("pick_in_round", 0))
	return "%d_%d_%d" % [pick_year, round_num, pick_in_round]


## Calculate trade value differential
##
## Calculates the value difference between picks offered and picks requested.
## Uses NflDraft.value_draft_pick() for individual pick values.
##
## Positive differential = receiving team gets more value
## Negative differential = offering team gets more value
##
## RNG: None (pure calculation)
##
## @param offer: Trade offer structure
## @param league_cfg: Configuration with pick value chart
## @param current_year: Current year (for future pick discount)
## @return float: Value differential (positive = receiving team benefits)
static func calculate_value_differential(
	offer: Dictionary,
	league_cfg: Dictionary,
	current_year: int
) -> float:
	var picks_offered: Array = offer.get("picks_offered", []) as Array
	var picks_requested: Array = offer.get("picks_requested", []) as Array

	# Sum value of picks being offered TO receiving team
	var offered_value := 0.0
	for pick in picks_offered:
		var p: Dictionary = pick
		var pick_year := int(p.get("year", current_year))
		var round_num := int(p.get("round", 1))
		var pick_in_round := int(p.get("pick_in_round", 1))
		offered_value += NflDraft.value_draft_pick(
			pick_year, round_num, pick_in_round, current_year, league_cfg
		)

	# Sum value of picks being requested FROM receiving team
	var requested_value := 0.0
	for pick in picks_requested:
		var p: Dictionary = pick
		var pick_year := int(p.get("year", current_year))
		var round_num := int(p.get("round", 1))
		var pick_in_round := int(p.get("pick_in_round", 1))
		requested_value += NflDraft.value_draft_pick(
			pick_year, round_num, pick_in_round, current_year, league_cfg
		)

	# Positive = receiving team gets more (offered > requested)
	return offered_value - requested_value


## Determine if receiving team accepts trade
##
## Uses a probability-based acceptance model with factors:
##   - base_rate: 30% base acceptance for fair trades
##   - value_multiplier: Higher value differential increases acceptance
##   - need_multiplier: Filling position needs increases acceptance
##   - desperation_multiplier: Teams wanting to move up pay premium
##
## Acceptance probability is capped at 95% (never 100% certain).
##
## RNG consumption:
##   - 1 randf() call per trade evaluation (deterministic via context-derived seed)
##
## @param offer: Trade offer structure
## @param receiving_team_id: Team evaluating offer
## @param receiving_roster: Team's current roster (for need calculation)
## @param receiving_needs: Position needs dictionary
## @param year: Current draft year
## @param current_pick: Current pick number in draft
## @param base_seed: Draft seed for determinism
## @param league_cfg: Configuration
## @return bool: true if accepted
static func should_accept_trade(
	offer: Dictionary,
	receiving_team_id: String,
	receiving_roster: Dictionary,
	receiving_needs: Dictionary,
	year: int,
	current_pick: int,
	base_seed: int,
	league_cfg: Dictionary
) -> bool:
	# Calculate value differential
	var value_diff := calculate_value_differential(offer, league_cfg, year)

	# Calculate acceptance probability
	var acceptance_prob := _calculate_acceptance_probability(
		value_diff,
		receiving_needs,
		offer,
		year
	)

	# Create deterministic RNG from context
	# Seed derived from (year, team, pick) ensures same decision for same context
	var trade_seed := Rand.splitmix64(base_seed ^ hash(receiving_team_id) ^ year ^ current_pick)
	var rng := RandomNumberGenerator.new()
	rng.seed = trade_seed

	# RNG consumption: 1 randf() call
	return rng.randf() < acceptance_prob


## Calculate acceptance probability for a trade
static func _calculate_acceptance_probability(
	value_diff: float,
	receiving_needs: Dictionary,
	offer: Dictionary,
	year: int
) -> float:
	# Start with base rate
	var acceptance := BASE_ACCEPTANCE_RATE

	# Value multiplier: More value = more likely to accept
	# Scale: +100 pts = +20% acceptance, +500 pts = +100% (capped)
	var value_multiplier := 1.0 + (value_diff / 500.0)
	value_multiplier = clamp(value_multiplier, 0.2, 2.5)

	# Need multiplier: Getting picks that help fill needs
	# For simplicity, we boost if receiving more early picks
	var picks_offered: Array = offer.get("picks_offered", []) as Array
	var early_picks := 0
	for pick in picks_offered:
		var p: Dictionary = pick
		if int(p.get("round", 7)) <= 2:
			early_picks += 1

	var need_multiplier := 1.0 + (float(early_picks) / 5.0)
	need_multiplier = clamp(need_multiplier, 0.8, 1.5)

	# Calculate final probability
	acceptance = acceptance * value_multiplier * need_multiplier

	# Cap at maximum
	return clamp(acceptance, 0.05, MAX_ACCEPTANCE_RATE)


## Execute trade (update ownership ledger)
##
## Transfers pick ownership between teams and creates a trade record
## for history tracking. Returns both the trade record and updated ownership.
##
## STATELESS: Does not modify input parameters. Returns updated ownership.
##
## RNG: None (deterministic update)
##
## @param offer: Trade offer structure
## @param ownership: draft_pick_ownership ledger (NOT modified)
## @param year: Current draft year
## @param current_pick: Current pick number (for timestamp)
## @return Dictionary: {trade_record: Dictionary, updated_ownership: Dictionary}
static func execute_trade(
	offer: Dictionary,
	ownership: Dictionary,
	year: int,
	current_pick: int = 0
) -> Dictionary:
	var offering_team := String(offer.get("offering_team_id", ""))
	var receiving_team := String(offer.get("receiving_team_id", ""))
	var picks_offered: Array = offer.get("picks_offered", []) as Array
	var picks_requested: Array = offer.get("picks_requested", []) as Array

	# Create a deep copy of ownership to avoid mutating input
	var updated_ownership := ownership.duplicate(true)

	# Transfer offered picks: offering_team -> receiving_team
	for pick in picks_offered:
		var p: Dictionary = pick
		_transfer_pick(p, offering_team, receiving_team, updated_ownership, year)

	# Transfer requested picks: receiving_team -> offering_team
	for pick in picks_requested:
		var p: Dictionary = pick
		_transfer_pick(p, receiving_team, offering_team, updated_ownership, year)

	# Create trade record
	var trade_record := {
		"version": TRADE_SCHEMA_VERSION,
		"timestamp": current_pick,  # Pick number when executed
		"year": year,
		"offering_team_id": offering_team,
		"receiving_team_id": receiving_team,
		"picks_offered": picks_offered.duplicate(true),
		"picks_requested": picks_requested.duplicate(true),
		"initiated_by": String(offer.get("initiated_by", "ai"))
	}

	return {
		"trade_record": trade_record,
		"updated_ownership": updated_ownership
	}


## Transfer a single pick's ownership
static func _transfer_pick(
	pick: Dictionary,
	from_team: String,
	to_team: String,
	ownership: Dictionary,
	default_year: int
) -> void:
	var pick_year := int(pick.get("year", default_year))
	var round_num := int(pick.get("round", 1))

	# Ensure year structure exists
	if not ownership.has(pick_year):
		ownership[pick_year] = {}
	var year_ownership: Dictionary = ownership[pick_year]

	# Ensure round structure exists
	if not year_ownership.has(round_num):
		year_ownership[round_num] = {}
	var round_ownership: Dictionary = year_ownership[round_num]

	# Find and update the pick ownership
	# The ownership maps original_team_id -> current_owner_id
	# We need to find the pick currently owned by from_team
	for orig_team_id in round_ownership.keys():
		if String(round_ownership[orig_team_id]) == from_team:
			round_ownership[orig_team_id] = to_team
			break


## Get AI-initiated trade proposals for current pick
##
## Generates potential trade offers based on team needs and value opportunities.
## AI teams may propose trades when:
##   - They want to move up for an elite player
##   - They have multiple early picks and want to consolidate/expand
##   - Value differential is within acceptable range (±20%)
##
## RNG consumption:
##   - Multiple randf() calls for proposal generation (seeded from current_pick)
##
## @param current_pick: Current pick number
## @param teams: All NFL teams
## @param rosters: Team rosters
## @param ownership: Pick ownership ledger
## @param available_players: Current draft pool
## @param year: Draft year
## @param base_seed: Draft seed
## @param league_cfg: Configuration
## @return Array[Dictionary]: Potential trade offers
static func generate_ai_trade_proposals(
	current_pick: int,
	teams: Array,
	rosters: Dictionary,
	ownership: Dictionary,
	available_players: Array,
	year: int,
	base_seed: int,
	league_cfg: Dictionary
) -> Array:
	var proposals: Array = []

	# Create deterministic RNG for proposal generation
	var proposal_seed := Rand.splitmix64(base_seed ^ current_pick ^ 0x7ADE00)
	var rng := RandomNumberGenerator.new()
	rng.seed = proposal_seed

	# Only generate trades occasionally (20% of picks)
	if rng.randf() > 0.20:
		return proposals

	# Find teams that might want to trade
	var trade_candidates := _find_trade_candidates(
		current_pick, teams, rosters, ownership, year, rng
	)

	# Generate proposals between candidates
	var proposal_count := 0
	for candidate in trade_candidates:
		if proposal_count >= MAX_AI_PROPOSALS_PER_PICK:
			break

		var c: Dictionary = candidate
		var team_id := String(c.get("team_id", ""))
		var wants_to := String(c.get("wants_to", ""))  # "trade_up" or "trade_down"

		# Find trade partners
		for partner_candidate in trade_candidates:
			if proposal_count >= MAX_AI_PROPOSALS_PER_PICK:
				break

			var pc: Dictionary = partner_candidate
			var partner_id := String(pc.get("team_id", ""))
			var partner_wants := String(pc.get("wants_to", ""))

			# Skip same team
			if team_id == partner_id:
				continue

			# Match: one wants up, other wants down
			if wants_to == "trade_up" and partner_wants == "trade_down":
				var proposal := _create_trade_proposal(
					team_id,  # Team moving up (offering more picks)
					partner_id,  # Team moving down (receiving more picks)
					ownership,
					year,
					current_pick,
					league_cfg,
					rng
				)

				if not proposal.is_empty():
					# Validate the proposal
					var validation := validate_trade(proposal, ownership, year, current_pick)
					if bool(validation.get("valid")):
						# Check value differential is reasonable
						var value_diff: float = calculate_value_differential(proposal, league_cfg, year)
						var relative_diff: float = abs(value_diff) / max(1.0, abs(value_diff) + 500.0)

						if relative_diff <= AI_VALUE_DIFFERENTIAL_THRESHOLD:
							proposals.append(proposal)
							proposal_count += 1

	return proposals


## Find teams that might want to trade
static func _find_trade_candidates(
	current_pick: int,
	teams: Array,
	rosters: Dictionary,
	ownership: Dictionary,
	year: int,
	rng: RandomNumberGenerator
) -> Array:
	var candidates: Array = []

	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		var roster: Dictionary = rosters.get(team_id, {}) as Dictionary

		# Count team's remaining picks in this draft
		var team_picks: Dictionary = _count_team_picks(team_id, ownership, year, current_pick)
		var early_picks: int = int(team_picks.get("early", 0))  # Rounds 1-2
		var total_picks: int = int(team_picks.get("total", 0))

		# Determine trade intent
		var wants_to := ""

		# Teams with no early picks might want to trade up
		if early_picks == 0 and total_picks >= 2:
			if rng.randf() < 0.3:  # 30% chance to consider trading up
				wants_to = "trade_up"

		# Teams with multiple early picks might trade down
		elif early_picks >= 2:
			if rng.randf() < 0.25:  # 25% chance to consider trading down
				wants_to = "trade_down"

		if not wants_to.is_empty():
			candidates.append({
				"team_id": team_id,
				"wants_to": wants_to,
				"early_picks": early_picks,
				"total_picks": total_picks
			})

	return candidates


## Count a team's remaining picks
static func _count_team_picks(
	team_id: String,
	ownership: Dictionary,
	year: int,
	current_pick: int
) -> Dictionary:
	var early := 0
	var total := 0

	var year_ownership: Dictionary = ownership.get(year, {}) as Dictionary

	for round_num in range(1, 8):
		var round_ownership: Dictionary = year_ownership.get(round_num, {}) as Dictionary

		for orig_team_id in round_ownership.keys():
			var owner := String(round_ownership.get(orig_team_id, ""))
			if owner == team_id:
				# Calculate overall pick number
				var pick_in_round := 1  # Simplified - would need draft order
				var overall := (round_num - 1) * 32 + pick_in_round

				if overall > current_pick:
					total += 1
					if round_num <= 2:
						early += 1

	return {"early": early, "total": total}


## Create a trade proposal between two teams
static func _create_trade_proposal(
	trading_up_team: String,
	trading_down_team: String,
	ownership: Dictionary,
	year: int,
	current_pick: int,
	league_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	# Find picks owned by each team
	var up_team_picks := _get_team_picks(trading_up_team, ownership, year, current_pick)
	var down_team_picks := _get_team_picks(trading_down_team, ownership, year, current_pick)

	if up_team_picks.is_empty() or down_team_picks.is_empty():
		return {}

	# Team trading up wants an early pick from team trading down
	# Find earliest available pick from trading_down_team
	var target_pick: Dictionary = {}
	for pick in down_team_picks:
		var p: Dictionary = pick
		if int(p.get("round", 7)) <= 2:
			target_pick = p
			break

	if target_pick.is_empty():
		# No early pick to trade for
		return {}

	# Calculate value needed to offer
	var target_value := NflDraft.value_draft_pick(
		int(target_pick.get("year", year)),
		int(target_pick.get("round", 1)),
		int(target_pick.get("pick_in_round", 1)),
		year,
		league_cfg
	)

	# Select picks from trading_up_team to offer
	var picks_to_offer: Array = []
	var offered_value := 0.0

	# Sort by value (highest first) and select enough to match
	var sorted_picks := up_team_picks.duplicate()
	sorted_picks.sort_custom(func(a, b):
		var a_val := NflDraft.value_draft_pick(
			int((a as Dictionary).get("year", year)),
			int((a as Dictionary).get("round", 1)),
			int((a as Dictionary).get("pick_in_round", 1)),
			year, league_cfg
		)
		var b_val := NflDraft.value_draft_pick(
			int((b as Dictionary).get("year", year)),
			int((b as Dictionary).get("round", 1)),
			int((b as Dictionary).get("pick_in_round", 1)),
			year, league_cfg
		)
		return a_val > b_val
	)

	for pick in sorted_picks:
		var p: Dictionary = pick
		var pick_value := NflDraft.value_draft_pick(
			int(p.get("year", year)),
			int(p.get("round", 1)),
			int(p.get("pick_in_round", 1)),
			year,
			league_cfg
		)

		picks_to_offer.append(p)
		offered_value += pick_value

		# Stop when we've matched or exceeded target value
		if offered_value >= target_value * 0.95:
			break

		# Don't offer more than 3 picks
		if picks_to_offer.size() >= 3:
			break

	# Only create proposal if value is reasonable
	if offered_value < target_value * 0.80 or offered_value > target_value * 1.30:
		return {}

	return {
		"offering_team_id": trading_up_team,
		"receiving_team_id": trading_down_team,
		"picks_offered": picks_to_offer,
		"picks_requested": [target_pick],
		"initiated_by": "ai"
	}


## Get all picks owned by a team
static func _get_team_picks(
	team_id: String,
	ownership: Dictionary,
	year: int,
	current_pick: int
) -> Array:
	var picks: Array = []

	var year_ownership: Dictionary = ownership.get(year, {}) as Dictionary

	for round_num in range(1, 8):
		var round_ownership: Dictionary = year_ownership.get(round_num, {}) as Dictionary
		var pick_in_round := 1

		for orig_team_id in round_ownership.keys():
			var owner := String(round_ownership.get(orig_team_id, ""))
			if owner == team_id:
				# Calculate overall pick number
				var overall := (round_num - 1) * 32 + pick_in_round

				if overall > current_pick:
					picks.append({
						"year": year,
						"round": round_num,
						"pick_in_round": pick_in_round,
						"original_team_id": orig_team_id,
						"pick_id": "%d_%d_%d" % [year, round_num, pick_in_round]
					})

			pick_in_round += 1

	return picks


## Get detailed trade summary for logging/display
##
## RNG: None (pure string generation)
##
## @param trade_record: Trade record from execute_trade()["trade_record"]
## @param league_cfg: Configuration for value calculation
## @return String: Formatted trade summary
static func format_trade_summary(
	trade_record: Dictionary,
	league_cfg: Dictionary
) -> String:
	var offering := String(trade_record.get("offering_team_id", ""))
	var receiving := String(trade_record.get("receiving_team_id", ""))
	var year := int(trade_record.get("year", 0))
	var picks_offered: Array = trade_record.get("picks_offered", []) as Array
	var picks_requested: Array = trade_record.get("picks_requested", []) as Array

	var offered_str := ""
	for pick in picks_offered:
		var p: Dictionary = pick
		offered_str += "Rd%d #%d, " % [int(p.get("round", 0)), int(p.get("pick_in_round", 0))]
	offered_str = offered_str.trim_suffix(", ")

	var requested_str := ""
	for pick in picks_requested:
		var p: Dictionary = pick
		requested_str += "Rd%d #%d, " % [int(p.get("round", 0)), int(p.get("pick_in_round", 0))]
	requested_str = requested_str.trim_suffix(", ")

	return "[TRADE] %s sends (%s) to %s for (%s)" % [
		offering, offered_str, receiving, requested_str
	]


# =============================================================================
# PHASE 3A API: QB URGENCY-AWARE TRADING
# =============================================================================

## Generate AI trade proposals for current pick (DRAFT-001 API)
##
## This is the main entry point for AI trade proposal generation.
## Integrates with QB urgency system (PR #149) to create realistic draft behavior:
##   - QB-desperate teams (2.8x urgency) propose trades 70%+ of the time when elite QB available
##   - Teams trade up when (target_player_value - cost_to_trade_up) > threshold
##   - Limited to 3 proposals per pick to prevent runaway complexity
##
## RNG consumption pattern:
##   - Seed: Rand.splitmix64(base_seed ^ hash(team_id) ^ year ^ pick_number)
##   - 1 randf() per team for trade consideration
##   - 1-3 randf() calls per actual proposal generation
##
## @param draft_context: Dictionary containing:
##   - year: int - Draft year
##   - teams: Array - All NFL teams
##   - rosters: Dictionary - Team rosters (team_id -> roster)
##   - ownership: Dictionary - draft_pick_ownership ledger
##   - league_cfg: Dictionary - League configuration
##   - positions_cfg: Dictionary - Position configuration
##   - class_rules: Dictionary - Class rules with draft_qb_urgency section
## @param current_pick: int - Current overall pick number (1-224)
## @param picking_team: String - Team currently on the clock
## @param available_players: Array - Remaining draft pool
## @param base_seed: int - Seed for deterministic generation
## @return Array[Dictionary]: Array of trade offers (max 3)
static func generate_trade_proposals(
	draft_context: Dictionary,
	current_pick: int,
	picking_team: String,
	available_players: Array,
	base_seed: int
) -> Array:
	var proposals: Array = []

	var year := int(draft_context.get("year", 2025))
	var teams: Array = draft_context.get("teams", []) as Array
	var rosters: Dictionary = draft_context.get("rosters", {}) as Dictionary
	var ownership: Dictionary = draft_context.get("ownership", {}) as Dictionary
	var league_cfg: Dictionary = draft_context.get("league_cfg", {}) as Dictionary
	var positions_cfg: Dictionary = draft_context.get("positions_cfg", {}) as Dictionary
	var class_rules: Dictionary = draft_context.get("class_rules", {}) as Dictionary

	# Find elite QBs available in the pool
	var elite_qbs := _find_elite_qbs_in_pool(available_players, positions_cfg, class_rules)
	var has_elite_qb := not elite_qbs.is_empty()

	# Get top prospect at current pick (BPA)
	var top_prospect: Dictionary = {}
	if not available_players.is_empty():
		top_prospect = available_players[0] as Dictionary

	# Analyze each team's trade interest
	for team in teams:
		if proposals.size() >= MAX_AI_PROPOSALS_PER_PICK:
			break

		var t: Dictionary = team
		var team_id := String(t.get("id", ""))

		# Skip the team currently on the clock (they don't need to trade up)
		if team_id == picking_team:
			continue

		var roster: Dictionary = rosters.get(team_id, {}) as Dictionary

		# Create deterministic RNG for this team's trade consideration
		# RNG seed: base_seed XOR team_id hash XOR year XOR current_pick
		var team_seed := Rand.splitmix64(base_seed ^ hash(team_id) ^ year ^ current_pick)
		var rng := RandomNumberGenerator.new()
		rng.seed = team_seed

		# Evaluate QB urgency for this team
		var qb_urgency := _evaluate_qb_urgency_for_trading(roster, positions_cfg, class_rules)
		var urgency_level := String(qb_urgency.get("level", "stable"))
		var urgency_multiplier := float(qb_urgency.get("multiplier", 1.0))

		# Determine if team wants to trade
		var trade_probability := _calculate_trade_probability(
			team_id,
			picking_team,
			urgency_level,
			has_elite_qb,
			top_prospect,
			current_pick,
			ownership,
			year
		)

		# RNG consumption: 1 randf() to decide if team considers trading
		if rng.randf() > trade_probability:
			continue

		# Team wants to trade - generate a proposal
		var proposal := _generate_urgency_aware_proposal(
			team_id,
			picking_team,
			ownership,
			year,
			current_pick,
			urgency_level,
			urgency_multiplier,
			elite_qbs,
			league_cfg,
			rng
		)

		if not proposal.is_empty():
			# Validate proposal before adding
			var validation := validate_trade(proposal, ownership, year, current_pick)
			if bool(validation.get("valid")):
				# Check value differential is acceptable
				var value_diff: float = calculate_value_differential(proposal, league_cfg, year)
				# More generous threshold for QB-desperate teams
				var threshold: float = AI_VALUE_DIFFERENTIAL_THRESHOLD
				if urgency_level == "desperate":
					threshold = 0.35  # Desperate teams accept worse deals

				var relative_diff: float = abs(value_diff) / max(1.0, abs(value_diff) + 500.0)
				if relative_diff <= threshold:
					proposal["qb_urgency_level"] = urgency_level
					proposal["target_player_type"] = "elite_qb" if has_elite_qb else "bpa"
					proposals.append(proposal)

	return proposals


## Calculate trade value using Jimmy Johnson chart (DRAFT-001 API)
##
## Wrapper around NflDraft.value_draft_pick() for array of picks.
## Accounts for future year discounting (already in value_draft_pick).
##
## RNG: None (pure calculation)
##
## @param picks_array: Array[Dictionary] - Each: {year, round, pick_number}
## @param current_year: int - Current simulation year
## @return float: Total trade value points
static func calculate_trade_value(
	picks_array: Array,
	current_year: int
) -> float:
	var total_value := 0.0
	var config := {}  # Empty config uses default chart values

	for pick in picks_array:
		var p: Dictionary = pick
		var pick_year := int(p.get("year", current_year))
		var round_num := int(p.get("round", 1))
		var pick_in_round := int(p.get("pick_number", p.get("pick_in_round", 1)))

		total_value += NflDraft.value_draft_pick(
			pick_year, round_num, pick_in_round, current_year, config
		)

	return total_value


## Evaluate if receiving team accepts trade offer (DRAFT-001 API)
##
## Enhanced acceptance logic that integrates QB urgency from PR #149:
##   - Base formula: BASE_ACCEPTANCE_RATE + (value_difference * 0.5)
##   - QB urgency modifier for receiving team (if giving up pick for QB-needy team)
##   - Cap at 0.90 (always some chance of rejection)
##   - Floor at 0.10 (always some chance of acceptance)
##
## RNG consumption:
##   - 1 randf() call per evaluation (deterministic via seed)
##
## @param trade_offer: Dictionary - Trade offer structure
## @param receiving_team: String - Team evaluating offer
## @param draft_context: Dictionary - Context including rosters, configs
## @param base_seed: int - Seed for determinism
## @return bool: True if trade accepted
static func evaluate_trade_acceptance(
	trade_offer: Dictionary,
	receiving_team: String,
	draft_context: Dictionary,
	base_seed: int
) -> bool:
	var year := int(draft_context.get("year", 2025))
	var current_pick := int(draft_context.get("current_pick", 0))
	var rosters: Dictionary = draft_context.get("rosters", {}) as Dictionary
	var league_cfg: Dictionary = draft_context.get("league_cfg", {}) as Dictionary
	var positions_cfg: Dictionary = draft_context.get("positions_cfg", {}) as Dictionary
	var class_rules: Dictionary = draft_context.get("class_rules", {}) as Dictionary

	var roster: Dictionary = rosters.get(receiving_team, {}) as Dictionary

	# Calculate value differential (positive = receiving team benefits)
	var value_diff := calculate_value_differential(trade_offer, league_cfg, year)

	# Evaluate receiving team's QB urgency (affects their willingness to trade away picks)
	var qb_urgency := _evaluate_qb_urgency_for_trading(roster, positions_cfg, class_rules)
	var urgency_level := String(qb_urgency.get("level", "stable"))

	# Calculate acceptance probability
	var acceptance_prob := _calculate_enhanced_acceptance_probability(
		value_diff,
		urgency_level,
		trade_offer,
		year
	)

	# Create deterministic RNG
	# Seed pattern: base_seed XOR receiving_team hash XOR year XOR current_pick
	var accept_seed := Rand.splitmix64(base_seed ^ hash(receiving_team) ^ year ^ current_pick)
	var rng := RandomNumberGenerator.new()
	rng.seed = accept_seed

	# RNG consumption: 1 randf() call
	return rng.randf() < acceptance_prob


# =============================================================================
# PRIVATE HELPERS: QB URGENCY INTEGRATION
# =============================================================================

## Find elite QB prospects in the draft pool
##
## Returns QBs with overall rating >= ELITE_QB_THRESHOLD (75.0)
## These are the prospects that trigger QB-desperate teams to trade up.
##
## RNG: None (pure filtering)
static func _find_elite_qbs_in_pool(
	available_players: Array,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> Array:
	var elite_qbs: Array = []

	for player in available_players:
		var p: Dictionary = player
		var position := String(p.get("position", ""))

		if position != "QB":
			continue

		var rating := PlayerRatingCalculator.calculate_overall_rating(
			p, positions_cfg, class_rules
		)

		if rating >= ELITE_QB_THRESHOLD:
			elite_qbs.append({
				"player": p,
				"rating": rating,
				"player_id": String(p.get("player_id", p.get("id", "")))
			})

	return elite_qbs


## Evaluate QB urgency for trade decision-making
##
## Simplified version of NflDraft._evaluate_qb_urgency() for trading context.
## Returns urgency level and multiplier that affects trade aggression.
##
## RNG: None (pure analysis)
static func _evaluate_qb_urgency_for_trading(
	roster: Dictionary,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> Dictionary:
	var qb_cfg: Dictionary = class_rules.get("draft_qb_urgency", {}) as Dictionary
	if not bool(qb_cfg.get("enabled", true)):
		return {"level": "stable", "multiplier": 1.0}

	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var qb_ids: Array = by_position.get("QB", []) as Array
	var all_players: Array = roster.get("players", []) as Array

	# No QB = desperate
	if qb_ids.is_empty():
		return {
			"level": "desperate",
			"multiplier": float(qb_cfg.get("desperate_multiplier", QB_DESPERATE_MULTIPLIER)),
			"reason": "no_qb"
		}

	# Find best QB
	var best_rating := 0.0
	var best_age := 40

	for player in all_players:
		var p: Dictionary = player
		var pid := String(p.get("player_id", p.get("id", "")))
		if pid not in qb_ids:
			continue

		var rating := PlayerRatingCalculator.calculate_overall_rating(
			p, positions_cfg, class_rules
		)
		var age := int(p.get("age", 25))

		if rating > best_rating:
			best_rating = rating
			best_age = age

	var franchise_threshold := float(qb_cfg.get("franchise_qb_threshold", 65.0))
	var aging_threshold := int(qb_cfg.get("aging_qb_age", 32))

	# No franchise QB = desperate
	if best_rating < franchise_threshold:
		return {
			"level": "desperate",
			"multiplier": float(qb_cfg.get("desperate_multiplier", QB_DESPERATE_MULTIPLIER)),
			"reason": "no_franchise_qb"
		}

	# Aging QB without young backup = moderate
	if best_age >= aging_threshold:
		return {
			"level": "moderate",
			"multiplier": float(qb_cfg.get("moderate_multiplier", QB_MODERATE_MULTIPLIER)),
			"reason": "aging_qb"
		}

	return {"level": "stable", "multiplier": 1.0, "reason": "qb_set"}


## Calculate probability that a team wants to make a trade
##
## Factors:
##   - QB urgency level (desperate teams trade more)
##   - Elite QB availability
##   - Pick position relative to team's current pick
##   - Number of picks team already has
##
## RNG: None (pure calculation)
static func _calculate_trade_probability(
	team_id: String,
	picking_team: String,
	urgency_level: String,
	has_elite_qb: bool,
	top_prospect: Dictionary,
	current_pick: int,
	ownership: Dictionary,
	year: int
) -> float:
	# Base probability starts low
	var probability := 0.08  # 8% base chance

	# QB-desperate teams with elite QB available are aggressive
	if urgency_level == "desperate" and has_elite_qb:
		probability = QB_DESPERATE_TRADE_PROBABILITY  # 70%
	elif urgency_level == "desperate":
		probability = 0.35  # 35% even without elite QB
	elif urgency_level == "moderate" and has_elite_qb:
		probability = 0.40  # 40% moderate urgency + elite QB
	elif urgency_level == "moderate":
		probability = 0.20  # 20% moderate urgency

	# Early round picks are more valuable - trade probability drops later
	if current_pick > 64:  # After round 2
		probability *= 0.7
	if current_pick > 128:  # After round 4
		probability *= 0.5

	# If team has multiple early picks, they might trade down
	var team_picks := _count_team_picks(team_id, ownership, year, current_pick)
	if int(team_picks.get("early", 0)) >= 2:
		probability += 0.10  # More likely to be willing to trade

	return clamp(probability, 0.0, 0.95)


## Generate a trade proposal with QB urgency awareness
##
## QB-desperate teams will overpay to move up for elite QBs.
## This creates realistic draft behavior where teams sacrifice future picks.
##
## RNG consumption:
##   - 0-2 randf() calls depending on proposal complexity
static func _generate_urgency_aware_proposal(
	trading_team: String,  # Team wanting to trade up
	on_clock_team: String,  # Team currently picking
	ownership: Dictionary,
	year: int,
	current_pick: int,
	urgency_level: String,
	urgency_multiplier: float,
	elite_qbs: Array,
	league_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	# Get picks owned by each team
	var up_team_picks := _get_team_picks(trading_team, ownership, year, current_pick)
	var clock_team_picks := _get_team_picks(on_clock_team, ownership, year, current_pick)

	if up_team_picks.is_empty() or clock_team_picks.is_empty():
		return {}

	# Find the current pick (the one we want to trade for)
	var target_pick: Dictionary = {}
	for pick in clock_team_picks:
		var p: Dictionary = pick
		var overall := (int(p.get("round", 1)) - 1) * 32 + int(p.get("pick_in_round", 1))
		if overall == current_pick or overall == current_pick + 1:
			target_pick = p
			break

	if target_pick.is_empty():
		# Fall back to earliest available
		target_pick = clock_team_picks[0] if not clock_team_picks.is_empty() else {}

	if target_pick.is_empty():
		return {}

	# Calculate value needed
	var target_value := NflDraft.value_draft_pick(
		int(target_pick.get("year", year)),
		int(target_pick.get("round", 1)),
		int(target_pick.get("pick_in_round", 1)),
		year,
		league_cfg
	)

	# QB-desperate teams overpay - multiply target value by urgency factor
	var overpay_factor := 1.0
	if urgency_level == "desperate" and not elite_qbs.is_empty():
		overpay_factor = 1.15 + (rng.randf() * 0.15)  # 15-30% overpay
	elif urgency_level == "moderate":
		overpay_factor = 1.05 + (rng.randf() * 0.10)  # 5-15% overpay

	var target_to_offer := target_value * overpay_factor

	# Select picks to offer (sorted by value, highest first)
	var picks_to_offer: Array = []
	var offered_value := 0.0

	var sorted_picks := up_team_picks.duplicate()
	sorted_picks.sort_custom(func(a, b):
		var a_val := NflDraft.value_draft_pick(
			int((a as Dictionary).get("year", year)),
			int((a as Dictionary).get("round", 1)),
			int((a as Dictionary).get("pick_in_round", 1)),
			year, league_cfg
		)
		var b_val := NflDraft.value_draft_pick(
			int((b as Dictionary).get("year", year)),
			int((b as Dictionary).get("round", 1)),
			int((b as Dictionary).get("pick_in_round", 1)),
			year, league_cfg
		)
		return a_val > b_val
	)

	for pick in sorted_picks:
		var p: Dictionary = pick
		var pick_value := NflDraft.value_draft_pick(
			int(p.get("year", year)),
			int(p.get("round", 1)),
			int(p.get("pick_in_round", 1)),
			year,
			league_cfg
		)

		picks_to_offer.append(p)
		offered_value += pick_value

		# Stop when we've reached target value
		if offered_value >= target_to_offer * 0.95:
			break

		# Don't offer more than 4 picks (realistic limit)
		if picks_to_offer.size() >= 4:
			break

	# Only create proposal if value is reasonable
	if offered_value < target_value * 0.80:
		return {}  # Can't afford it

	return {
		"offering_team_id": trading_team,
		"receiving_team_id": on_clock_team,
		"picks_offered": picks_to_offer,
		"picks_requested": [target_pick],
		"initiated_by": "ai"
	}


## Calculate enhanced acceptance probability with QB urgency
##
## Base formula: BASE_ACCEPTANCE_RATE + (value_difference * 0.5)
## Modified by:
##   - QB urgency of receiving team (QB-desperate teams less willing to trade down)
##   - Position of picks being traded (early picks = harder to give up)
##
## RNG: None (pure calculation)
static func _calculate_enhanced_acceptance_probability(
	value_diff: float,
	receiving_urgency_level: String,
	offer: Dictionary,
	year: int
) -> float:
	# Start with base rate
	var acceptance := BASE_ACCEPTANCE_RATE

	# Value multiplier: More value = more likely to accept
	# Scale: +100 pts = +10% acceptance, +500 pts = +50%
	var value_multiplier := 1.0 + (value_diff / 1000.0)
	value_multiplier = clamp(value_multiplier, 0.3, 2.5)

	# QB urgency penalty: QB-desperate teams are LESS willing to trade down
	# (they want to keep their pick to select a QB)
	var urgency_penalty := 1.0
	if receiving_urgency_level == "desperate":
		urgency_penalty = 0.5  # 50% less likely to accept
	elif receiving_urgency_level == "moderate":
		urgency_penalty = 0.75  # 25% less likely

	# Early pick bonus: Getting early picks makes trade more attractive
	var picks_offered: Array = offer.get("picks_offered", []) as Array
	var early_pick_bonus := 1.0
	for pick in picks_offered:
		var p: Dictionary = pick
		if int(p.get("round", 7)) <= 2:
			early_pick_bonus += 0.15  # +15% per early round pick
	early_pick_bonus = clamp(early_pick_bonus, 1.0, 1.6)

	# Calculate final probability
	acceptance = acceptance * value_multiplier * urgency_penalty * early_pick_bonus

	# Apply floor and ceiling
	return clamp(acceptance, MIN_ACCEPTANCE_RATE, MAX_ACCEPTANCE_RATE)
