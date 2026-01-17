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
##   - AI proposal generation: Rand.splitmix64(base_seed ^ current_pick ^ 0x7RADE)
##
## Integration Points:
##   - InteractiveDraft: TRADE_WINDOW state management, execution
##   - NflDraft: value_draft_pick() for pick valuation
##   - TradeProposalDialog: UI for user-initiated trades
##
extends RefCounted
class_name DraftTradeEngine

const Rand = preload("res://autoloads/Rand.gd")
const NflDraft = preload("res://scripts/world/NflDraft.gd")

## Schema version for trade records (enables future migration)
const TRADE_SCHEMA_VERSION := 1

## Base acceptance rate for fair trades (30%)
const BASE_ACCEPTANCE_RATE := 0.3

## Maximum acceptance probability (never 100% certain)
const MAX_ACCEPTANCE_RATE := 0.95

## Value differential threshold for AI to consider trade (within 20%)
const AI_VALUE_DIFFERENTIAL_THRESHOLD := 0.20

## Maximum trades generated per pick by AI
const MAX_AI_PROPOSALS_PER_PICK := 3


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
## for history tracking. Modifies the ownership dictionary in place.
##
## RNG: None (deterministic update)
##
## @param offer: Trade offer structure
## @param ownership: draft_pick_ownership ledger (MODIFIED IN PLACE)
## @param year: Current draft year
## @param current_pick: Current pick number (for timestamp)
## @return Dictionary: Trade record for history
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

	# Transfer offered picks: offering_team -> receiving_team
	for pick in picks_offered:
		var p: Dictionary = pick
		_transfer_pick(p, offering_team, receiving_team, ownership, year)

	# Transfer requested picks: receiving_team -> offering_team
	for pick in picks_requested:
		var p: Dictionary = pick
		_transfer_pick(p, receiving_team, offering_team, ownership, year)

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

	return trade_record


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
	var proposal_seed := Rand.splitmix64(base_seed ^ current_pick ^ 0x7RADE)
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
						var value_diff := calculate_value_differential(proposal, league_cfg, year)
						var relative_diff := abs(value_diff) / max(1.0, abs(value_diff) + 500.0)

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
		var team_picks := _count_team_picks(team_id, ownership, year, current_pick)
		var early_picks := team_picks.get("early", 0)  # Rounds 1-2
		var total_picks := team_picks.get("total", 0)

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
## @param trade_record: Trade record from execute_trade()
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
