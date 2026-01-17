## DraftDecisionEngine - Underclassman Draft Declaration Processing
##
## Purpose: Process underclassman draft declarations for college players.
## Determines which eligible college players declare for the NFL draft
## versus returning to school for another season.
##
## Design Philosophy:
##   - Stateless service (all context passed as parameters)
##   - Deterministic via explicit RNG seeding
##   - Configuration-driven probability thresholds
##   - Pure functions receiving all context
##
## RNG Pattern:
##   - Declaration decisions: 1 randf() call per underclassman
##   - Seed derivation: Rand.splitmix64(base_seed ^ 0xDEC1A4E)
##
## Integration Points:
##   - WorldCalendar: Runs during draft_declaration phase (tick 7)
##   - Player.gd: Uses years_remaining and declared_for_draft fields
##   - PreDraftProcess: Filters to only declared players
##
extends RefCounted
class_name DraftDecisionEngine

const Rand = preload("res://autoloads/Rand.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

## Declaration probability thresholds (used when config not available)
const DEFAULT_ELITE_THRESHOLD := 85.0
const DEFAULT_ELITE_DECLARE_RATE := 0.90
const DEFAULT_HIGH_THRESHOLD := 75.0
const DEFAULT_HIGH_DECLARE_RATE := 0.65
const DEFAULT_MID_THRESHOLD := 65.0
const DEFAULT_MID_DECLARE_RATE := 0.35
const DEFAULT_LOW_DECLARE_RATE := 0.15

## Years remaining multipliers for underclassmen
const JUNIOR_YEARS_MULTIPLIER := 1.0    # Full probability (1 year left)
const SOPHOMORE_YEARS_MULTIPLIER := 0.7  # 30% less likely (2 years left)
const FRESHMAN_YEARS_MULTIPLIER := 0.4   # 60% less likely (3+ years left)


## Process draft declarations for all college players.
##
## Iterates through all college players and determines who declares for the draft.
## Seniors (years_remaining = 0) auto-declare with no choice.
## Underclassmen make probabilistic decision based on draft projection.
##
## Side effects:
##   - Sets declared_for_draft = true on declaring players (modifies in place)
##   - Sets declaration_year on declaring players
##   - Decrements years_remaining on returning players
##
## RNG consumption pattern:
##   - 1 randf() call per underclassman (players with years_remaining > 0)
##   - Seniors consume no RNG (auto-declare)
##
## @param college_players: Array of college player dictionaries
## @param year: Current simulation year (for declaration_year tracking)
## @param seed: Base RNG seed for determinism
## @param config: Configuration with draft_declaration section (optional)
## @param positions_cfg: Position configuration for rating calculation
## @param class_rules: Class rules for rating calculation
## @return Dictionary: {
##     year: int,
##     declared_count: int,
##     returning_count: int,
##     declared_players: Array[Dictionary],
##     returning_players: Array[Dictionary]
## }
static func process_declarations(
	college_players: Array,
	year: int,
	seed: int,
	config: Dictionary,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> Dictionary:
	# Create RNG with stable seed derived from base seed
	# RNG consumption: randf() calls are made per underclassman below
	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(seed ^ 0xDEC1A4E)

	var declared: Array = []
	var returning: Array = []

	for player in college_players:
		var p: Dictionary = player
		var years_left := int(p.get("years_remaining", 0))

		# Seniors (years_remaining = 0) auto-declare - no choice, no RNG consumed
		if years_left <= 0:
			_declare_player(p, year)
			declared.append(p)
			continue

		# Underclassmen make decision based on draft projection
		# RNG consumption: 1 randf() call per underclassman
		var declare_prob := calculate_declaration_probability(
			p, positions_cfg, class_rules, config
		)

		if rng.randf() < declare_prob:
			# Player declares for draft
			_declare_player(p, year)
			declared.append(p)
		else:
			# Player returns to school - decrement eligibility for next year
			p["years_remaining"] = years_left - 1
			returning.append(p)

	return {
		"year": year,
		"declared_count": declared.size(),
		"returning_count": returning.size(),
		"declared_players": declared,
		"returning_players": returning
	}


## Calculate probability of underclassman declaring for draft.
##
## Uses draft grade (overall rating) as primary factor.
## Applies years_remaining modifier (earlier declaration = lower probability).
##
## Probability tiers by rating:
##   - Elite (85+): ~90% base declaration rate (1st round projection)
##   - High (75-85): ~65% base declaration rate (2nd-3rd round projection)
##   - Mid (65-75): ~35% base declaration rate (Day 3 projection)
##   - Low (<65): ~15% base declaration rate (undrafted projection)
##
## Years remaining modifier:
##   - Junior (1 year): 1.0x (full probability)
##   - Sophomore (2 years): 0.7x (30% less likely)
##   - Freshman (3+ years): 0.4x (60% less likely - very rare)
##
## RNG: None (pure calculation)
##
## @param player: Player dictionary with stats for rating calculation
## @param positions_cfg: Position configuration
## @param class_rules: Class rules
## @param config: Configuration with draft_declaration.probability_curves section
## @return float: Probability 0.0-1.0
static func calculate_declaration_probability(
	player: Dictionary,
	positions_cfg: Dictionary,
	class_rules: Dictionary,
	config: Dictionary
) -> float:
	# Calculate draft projection (overall rating)
	var overall_rating := PlayerRatingCalculator.calculate_overall_rating(
		player, positions_cfg, class_rules
	)

	# Get probability thresholds from config, with defaults
	var prob_cfg: Dictionary = config.get("draft_declaration", {}).get("probability_curves", {})

	# Determine base probability by draft grade tier
	var base_prob: float = 0.0

	var elite_threshold := float(prob_cfg.get("elite_threshold", DEFAULT_ELITE_THRESHOLD))
	var high_threshold := float(prob_cfg.get("high_threshold", DEFAULT_HIGH_THRESHOLD))
	var mid_threshold := float(prob_cfg.get("mid_threshold", DEFAULT_MID_THRESHOLD))

	if overall_rating >= elite_threshold:
		# Elite prospect (1st round projection) - very likely to declare
		base_prob = float(prob_cfg.get("elite_declare_rate", DEFAULT_ELITE_DECLARE_RATE))
	elif overall_rating >= high_threshold:
		# High prospect (2nd-3rd round projection) - likely to declare
		base_prob = float(prob_cfg.get("high_declare_rate", DEFAULT_HIGH_DECLARE_RATE))
	elif overall_rating >= mid_threshold:
		# Mid prospect (Day 3 projection) - might declare
		base_prob = float(prob_cfg.get("mid_declare_rate", DEFAULT_MID_DECLARE_RATE))
	else:
		# Low prospect (undrafted projection) - unlikely to declare
		base_prob = float(prob_cfg.get("low_declare_rate", DEFAULT_LOW_DECLARE_RATE))

	# Adjust probability by years remaining
	# Earlier declaration (more years left) = lower probability
	var years_left := int(player.get("years_remaining", 4))
	var years_multiplier: float = 1.0

	if years_left == 1:
		# Junior (1 year of eligibility remaining) - full probability
		years_multiplier = JUNIOR_YEARS_MULTIPLIER
	elif years_left == 2:
		# Sophomore (2 years remaining) - 30% less likely
		years_multiplier = SOPHOMORE_YEARS_MULTIPLIER
	elif years_left >= 3:
		# Freshman or redshirt (3+ years remaining) - 60% less likely (very rare)
		years_multiplier = FRESHMAN_YEARS_MULTIPLIER

	# Calculate final probability, clamped to valid range
	var final_prob := clamp(base_prob * years_multiplier, 0.0, 1.0)

	return final_prob


## Declare player for draft (update player state).
##
## Sets the declaration flags on the player dictionary.
## Does NOT modify stage - WorldCalendar will transition stage in next phase.
##
## Modifications made (in place):
##   - declared_for_draft: true
##   - declaration_year: year parameter
##
## RNG: None (pure mutation)
##
## @param player: Player dictionary (MODIFIED IN PLACE)
## @param year: Current simulation year
static func _declare_player(player: Dictionary, year: int) -> void:
	player["declared_for_draft"] = true
	player["declaration_year"] = year
	# NOTE: Do NOT modify stage here - WorldCalendar will transition stage
	# during the draft_prep or nfl_draft phase. This separation allows
	# the declaration decision to be logged before stage transition.


## Calculate expected draft pool size variance.
##
## Utility function to estimate the range of draft pool sizes
## given a college player population and probability configuration.
##
## Uses the probability distribution to calculate expected values:
##   - Seniors: 100% declare (auto-entry)
##   - Juniors: ~50-60% declare (weighted average of tiers)
##   - Sophomores: ~35-40% declare (tier rate * 0.7)
##   - Freshmen: ~20-25% declare (tier rate * 0.4)
##
## RNG: None (pure calculation)
##
## @param senior_count: Number of senior college players
## @param junior_count: Number of junior college players
## @param sophomore_count: Number of sophomore college players
## @param config: Configuration with probability curves
## @return Dictionary: {expected_min: int, expected_max: int, expected_avg: float}
static func estimate_draft_pool_size(
	senior_count: int,
	junior_count: int,
	sophomore_count: int,
	config: Dictionary
) -> Dictionary:
	var prob_cfg: Dictionary = config.get("draft_declaration", {}).get("probability_curves", {})

	# Seniors always declare
	var senior_declares := float(senior_count)

	# Estimate average declaration rate across tiers
	# Assume normal distribution: 20% elite, 30% high, 30% mid, 20% low
	var elite_rate := float(prob_cfg.get("elite_declare_rate", DEFAULT_ELITE_DECLARE_RATE))
	var high_rate := float(prob_cfg.get("high_declare_rate", DEFAULT_HIGH_DECLARE_RATE))
	var mid_rate := float(prob_cfg.get("mid_declare_rate", DEFAULT_MID_DECLARE_RATE))
	var low_rate := float(prob_cfg.get("low_declare_rate", DEFAULT_LOW_DECLARE_RATE))

	var weighted_avg_rate := (0.2 * elite_rate) + (0.3 * high_rate) + (0.3 * mid_rate) + (0.2 * low_rate)

	# Apply years multipliers
	var junior_declares := float(junior_count) * weighted_avg_rate * JUNIOR_YEARS_MULTIPLIER
	var sophomore_declares := float(sophomore_count) * weighted_avg_rate * SOPHOMORE_YEARS_MULTIPLIER

	var expected_avg := senior_declares + junior_declares + sophomore_declares

	# Variance: min is ~70% of expected (if RNG unfavorable), max is ~130%
	var expected_min := int(expected_avg * 0.7)
	var expected_max := int(expected_avg * 1.3)

	return {
		"expected_min": expected_min,
		"expected_max": expected_max,
		"expected_avg": expected_avg
	}


## Validate player eligibility for declaration processing.
##
## Checks if a player is valid for inclusion in declaration processing:
##   - Must have valid position
##   - Must have stage = COLLEGE (or equivalent)
##   - Must have valid years_remaining field
##
## RNG: None (pure validation)
##
## @param player: Player dictionary to validate
## @return Dictionary: {valid: bool, reason: String}
static func validate_player_eligibility(player: Dictionary) -> Dictionary:
	# Check required fields
	if not player.has("position") or String(player.get("position", "")).is_empty():
		return {"valid": false, "reason": "Missing or empty position field"}

	# Check stage (should be college)
	var stage = player.get("stage")
	if stage != null:
		# If stage field exists, validate it's COLLEGE (value 1)
		var stage_val := int(stage)
		if stage_val != 1:  # PlayerStage.COLLEGE = 1
			return {"valid": false, "reason": "Player stage is not COLLEGE"}

	# Check years_remaining is valid
	var years := player.get("years_remaining")
	if years != null:
		var years_val := int(years)
		if years_val < 0:
			return {"valid": false, "reason": "Negative years_remaining value"}

	return {"valid": true, "reason": ""}


## Get declaration summary for logging/debugging.
##
## Creates a human-readable summary of declaration decisions.
##
## RNG: None (pure string generation)
##
## @param result: Result dictionary from process_declarations()
## @return String: Formatted summary string
static func format_declaration_summary(result: Dictionary) -> String:
	var year := int(result.get("year", 0))
	var declared := int(result.get("declared_count", 0))
	var returning := int(result.get("returning_count", 0))
	var total := declared + returning

	var pct := 0.0
	if total > 0:
		pct = (float(declared) / float(total)) * 100.0

	return "[DraftDecisions %d] %d declared, %d returning (%.1f%% declaration rate)" % [
		year, declared, returning, pct
	]
