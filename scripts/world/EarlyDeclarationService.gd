extends RefCounted
class_name EarlyDeclarationService

## Early Declaration Advisory Service
##
## Purpose: Simulates NFL Draft Advisory Board system that influences when college
## players declare for the draft, including agent influence and return-to-school decisions.
##
## Key Features:
##   1. NFL advisory grade calculation based on player rating
##   2. Agent contact simulation based on player projection
##   3. Multi-factor declaration decision (grade, financial need, injury risk)
##   4. Return-to-school development bonus for players who stay
##
## Design Principles:
##   - Stateless service with pure functions
##   - Configuration-driven behavior for tuning
##   - Explicit RNG passing for determinism
##   - Minimal data persistence (only essential state)
##
## RNG Pattern: Explicit RNG parameter in all probabilistic functions
## Integration Points: CollegeSeason (declaration decisions), PreDraftProcess (advisory grade usage)

const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")


## Main entry point for advisory process
##
## Called from CollegeSeason for each junior player to determine declaration.
## This is the public API - all other functions are internal implementation details.
##
## Algorithm:
##   1. Calculate NFL advisory grade based on overall rating
##   2. Simulate agent contact (probability based on rating)
##   3. Calculate declaration probability from multiple factors
##   4. Roll for final declaration decision
##   5. Apply return-to-school bonus if player stays
##
## RNG Consumption:
##   - 1 randf() for agent contact
##   - 1 randf() for declaration decision
##   Total: 2 randf() calls per eligible player
##
## @param player: Player dictionary (will be modified in-place for advisory data)
## @param year: Current season year
## @param positions_cfg: Position configuration
## @param main_cfg: Main game configuration
## @param config: Early declaration configuration
## @param rng: RandomNumberGenerator (caller-controlled)
## @return bool: True if player declares for draft, False if returning to school
static func simulate_declaration_decision(
	player: Dictionary,
	year: int,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> bool:
	# Feature flag check
	if not bool(config.get("enabled", true)):
		# Fallback to simple rating-based check
		return _simple_declaration_check(player, positions_cfg, main_cfg, config, rng)

	# Calculate advisory grade
	var advisory_grade := _calculate_advisory_grade(player, positions_cfg, main_cfg, config)

	# Simulate agent contact (RNG CALL 1)
	var agent_contacted := _simulate_agent_contact(player, advisory_grade, config, rng)

	# Calculate declaration probability
	var declaration_prob := _calculate_declaration_probability(
		player,
		advisory_grade,
		agent_contacted,
		config
	)

	# Roll for declaration (RNG CALL 2)
	var declares := rng.randf() < declaration_prob

	# Store advisory data (minimal persistent state)
	if not player.has("declaration_advisory"):
		player["declaration_advisory"] = {}

	var advisory: Dictionary = player["declaration_advisory"]
	advisory["nfl_advisory_grade"] = advisory_grade
	advisory["agent_contacted"] = agent_contacted
	advisory["returned_to_school"] = not declares
	advisory["year_evaluated"] = year

	# Apply return-to-school bonus if staying
	if not declares:
		_apply_return_to_school_bonus(player, config)

	return declares


## Calculate NFL advisory grade based on overall rating
##
## Grade Tiers:
##   - "1st_round": Elite prospects (85+)
##   - "2nd_round": Strong prospects (78-84)
##   - "3rd_day": Developmental prospects (70-77)
##   - "return_to_school": Below draft threshold (<70)
##
## RNG: None (deterministic calculation)
##
## @param player: Player dictionary
## @param positions_cfg: Position configuration
## @param main_cfg: Main game configuration
## @param config: Early declaration configuration
## @return String: Advisory grade
static func _calculate_advisory_grade(
	player: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	config: Dictionary
) -> String:
	# Load OVR weights config for weighted OVR calculation
	const OVR_WEIGHTS_PATH := "res://configs/sports/american_football/ovr_weights.json"
	var ovr_config := PlayerRatingCalculator.load_ovr_config(OVR_WEIGHTS_PATH)
	var position := String(player.get("position", ""))
	var rating := PlayerRatingCalculator.calculate_weighted_ovr(player, position, ovr_config)

	var grades_cfg: Dictionary = config.get("nfl_advisory_grades", {})

	# Check thresholds in descending order
	var first_round_cfg: Dictionary = grades_cfg.get("1st_round", {})
	var first_round_min := float(first_round_cfg.get("min_rating", 85.0))
	if rating >= first_round_min:
		return "1st_round"

	var second_round_cfg: Dictionary = grades_cfg.get("2nd_round", {})
	var second_round_min := float(second_round_cfg.get("min_rating", 78.0))
	if rating >= second_round_min:
		return "2nd_round"

	var third_day_cfg: Dictionary = grades_cfg.get("3rd_day", {})
	var third_day_min := float(third_day_cfg.get("min_rating", 70.0))
	if rating >= third_day_min:
		return "3rd_day"

	return "return_to_school"


## Simulate agent contact based on player rating and advisory grade
##
## Higher rated players are more likely to be contacted by agents.
## Agent contact increases declaration probability (agents push borderline players).
##
## RNG: 1 randf() call
##
## @param player: Player dictionary
## @param advisory_grade: String - NFL advisory grade
## @param config: Early declaration configuration
## @param rng: RandomNumberGenerator
## @return bool: True if agent contacted player
static func _simulate_agent_contact(
	player: Dictionary,
	advisory_grade: String,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> bool:
	var agent_cfg: Dictionary = config.get("agent_influence", {})

	# Base contact probability by advisory grade
	var contact_probs := {
		"1st_round": 0.95,      # Elite prospects almost always contacted
		"2nd_round": 0.80,      # Strong prospects usually contacted
		"3rd_day": 0.50,        # Developmental prospects sometimes contacted
		"return_to_school": 0.15  # Borderline prospects rarely contacted
	}

	var base_prob := float(contact_probs.get(advisory_grade, 0.15))

	# Optional: Boost probability if player has high hype (Phase 6 integration)
	var hype := float(player.get("hype", 0.0))
	if hype > 0.0:
		# High hype increases agent interest (+0.1 for max hype)
		var hype_boost := (hype / 100.0) * 0.1
		base_prob = min(base_prob + hype_boost, 0.98)

	# RNG CALL: Agent contact roll
	return rng.randf() < base_prob


## Calculate declaration probability based on multiple factors
##
## Factors:
##   1. Advisory grade (primary factor)
##   2. Agent influence (pushes declaration if contacted)
##   3. Financial need (can override grade for low-income players)
##   4. Injury history (high injury risk increases declaration urgency)
##   5. Development upside (low upside suggests declaring now)
##
## RNG: None (pure calculation)
##
## @param player: Player dictionary
## @param advisory_grade: String - NFL advisory grade
## @param agent_contacted: bool - Whether agent contacted player
## @param config: Early declaration configuration
## @return float: Declaration probability (0.0-1.0)
static func _calculate_declaration_probability(
	player: Dictionary,
	advisory_grade: String,
	agent_contacted: bool,
	config: Dictionary
) -> float:
	var grades_cfg: Dictionary = config.get("nfl_advisory_grades", {})
	var agent_cfg: Dictionary = config.get("agent_influence", {})
	var factors_cfg: Dictionary = config.get("decision_factors", {})

	# Base declaration rate from advisory grade
	var base_rate := 0.0
	match advisory_grade:
		"1st_round":
			var first_cfg: Dictionary = grades_cfg.get("1st_round", {})
			base_rate = float(first_cfg.get("declaration_rate", 0.95))
		"2nd_round":
			var second_cfg: Dictionary = grades_cfg.get("2nd_round", {})
			base_rate = float(second_cfg.get("declaration_rate", 0.80))
		"3rd_day":
			var third_cfg: Dictionary = grades_cfg.get("3rd_day", {})
			base_rate = float(third_cfg.get("declaration_rate", 0.45))
		"return_to_school":
			var return_cfg: Dictionary = grades_cfg.get("return_to_school", {})
			base_rate = float(return_cfg.get("declaration_rate", 0.15))

	var final_prob := base_rate

	# Factor 1: Agent influence boost
	if agent_contacted:
		var agent_boost := float(agent_cfg.get("agent_push_declaration_rate_boost", 0.15))
		final_prob += agent_boost

	# Factor 2: Financial need (increases declaration urgency)
	var financial_need := _calculate_financial_need(player)
	if financial_need > 0.7:  # High financial pressure
		var financial_weight := float(factors_cfg.get("financial_need_weight", 0.25))
		final_prob += financial_need * financial_weight

	# Factor 3: Injury history (increases declaration urgency)
	var injury_risk := _calculate_injury_risk(player)
	if injury_risk > 0.5:  # Significant injury history
		var injury_weight := float(factors_cfg.get("injury_history_weight", 0.20))
		final_prob += injury_risk * injury_weight

	# Factor 4: Development upside (low upside = declare now)
	var upside := _calculate_development_upside(player)
	if upside < 0.3:  # Limited improvement potential
		var upside_weight := float(factors_cfg.get("development_upside_weight", 0.30))
		final_prob += (1.0 - upside) * upside_weight * 0.5

	# Clamp to valid probability range
	return clamp(final_prob, 0.05, 0.98)


## Apply development bonus to players who return to school
##
## Players who stay for senior year receive:
##   - Development bonus (faster attribute growth)
##   - Maintained exposure (hype doesn't decay as much)
##   - Injury risk (chance of setback)
##
## RNG: None (bonus applied via development_context)
##
## @param player: Player dictionary (modified in-place)
## @param config: Early declaration configuration
static func _apply_return_to_school_bonus(
	player: Dictionary,
	config: Dictionary
) -> void:
	var bonus_cfg: Dictionary = config.get("return_to_school_boost", {})
	var dev_bonus := float(bonus_cfg.get("development_bonus", 1.15))

	# Apply development bonus via development_context
	# This will be picked up by PlayerLifecycle during next year's progression
	if not player.has("development_context"):
		player["development_context"] = {}

	var dev_context: Dictionary = player["development_context"]

	# Stack with existing multipliers
	var current_mult := float(dev_context.get("usage", 1.0))
	dev_context["usage"] = current_mult * dev_bonus
	dev_context["return_to_school_bonus"] = true

	# Note: Injury risk is handled by PlayerLifecycle injury system
	# We don't need to explicitly increase it here


## Calculate financial need factor (0.0 = wealthy, 1.0 = high need)
##
## Based on player background and family situation.
## High financial need increases declaration probability.
##
## RNG: None (deterministic)
##
## @param player: Player dictionary
## @return float: Financial need factor (0.0-1.0)
static func _calculate_financial_need(player: Dictionary) -> float:
	# Use background data if available
	var background: Dictionary = player.get("background", {})
	var socioeconomic := String(background.get("socioeconomic_status", "middle"))

	# Map socioeconomic status to financial need
	var need_map := {
		"low": 0.9,
		"lower_middle": 0.7,
		"middle": 0.5,
		"upper_middle": 0.3,
		"high": 0.1
	}

	var base_need := float(need_map.get(socioeconomic, 0.5))

	# Optional: Adjust based on family size (more dependents = higher need)
	var family_size := int(background.get("family_size", 4))
	if family_size > 5:
		base_need = min(base_need + 0.1, 1.0)

	return base_need


## Calculate injury risk factor (0.0 = clean, 1.0 = high risk)
##
## Based on player's injury history.
## High injury risk increases declaration urgency (declare before another injury).
##
## RNG: None (deterministic)
##
## @param player: Player dictionary
## @return float: Injury risk factor (0.0-1.0)
static func _calculate_injury_risk(player: Dictionary) -> float:
	var injuries: Array = player.get("injuries", [])

	if injuries.is_empty():
		return 0.0

	# Count injuries and sum severity
	var injury_count := injuries.size()
	var total_severity := 0.0
	var has_major_injury := false

	for injury in injuries:
		var inj: Dictionary = injury
		var severity := float(inj.get("severity", 1.0))
		total_severity += severity

		if severity >= 3.0:  # Major injury
			has_major_injury = true

	# Calculate risk score
	var risk := 0.0

	# Injury count contribution (0-4 injuries mapped to 0.0-0.5)
	risk += min(float(injury_count) * 0.125, 0.5)

	# Severity contribution (0.0-0.3)
	var avg_severity := total_severity / float(injury_count) if injury_count > 0 else 0.0
	risk += min(avg_severity * 0.1, 0.3)

	# Major injury penalty (+0.2)
	if has_major_injury:
		risk += 0.2

	return clamp(risk, 0.0, 1.0)


## Calculate development upside factor (0.0 = capped, 1.0 = high upside)
##
## Based on player age, current rating, and attribute ceiling.
## High upside suggests staying to improve draft stock.
##
## RNG: None (deterministic)
##
## @param player: Player dictionary
## @return float: Development upside factor (0.0-1.0)
static func _calculate_development_upside(player: Dictionary) -> float:
	var age := int(player.get("age", 21))
	var college_year := int(player.get("college_year", 3))

	# Younger players have more upside
	var age_factor: float = 1.0 - clamp((float(age) - 20.0) / 5.0, 0.0, 1.0)

	# Check attribute potential (difference between current and potential)
	# Simplified: Assume players can grow ~10 points in attributes
	# If already near peak, low upside
	var attributes: Dictionary = player.get("attributes", {})
	var has_ceiling_data := attributes.has("potential_ceiling")

	if has_ceiling_data:
		# Use explicit ceiling if available (future enhancement)
		var ceiling := float(attributes.get("potential_ceiling", 100.0))
		var current := float(attributes.get("overall", 75.0))
		var room_to_grow := (ceiling - current) / 25.0  # Normalize to 0-1
		return clamp(age_factor * 0.5 + room_to_grow * 0.5, 0.0, 1.0)
	else:
		# Fallback: Age-based upside only
		return clamp(age_factor, 0.0, 1.0)


## Simple declaration check (fallback when advisory system disabled)
##
## Matches original CollegeSeason._check_early_declaration() behavior.
## Used for backward compatibility and testing.
##
## RNG: 1 randf() call
##
## @param player: Player dictionary
## @param positions_cfg: Position configuration
## @param main_cfg: Main game configuration
## @param config: Early declaration configuration
## @param rng: RandomNumberGenerator
## @return bool: True if declares
static func _simple_declaration_check(
	player: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> bool:
	var rating_threshold := float(config.get("rating_threshold", 85.0))
	var base_chance := float(config.get("base_chance", 0.15))
	var rating_bonus_per_point := float(config.get("rating_bonus_per_point", 0.01))

	# Load OVR weights config for weighted OVR calculation
	const OVR_WEIGHTS_PATH := "res://configs/sports/american_football/ovr_weights.json"
	var ovr_config := PlayerRatingCalculator.load_ovr_config(OVR_WEIGHTS_PATH)
	var position := String(player.get("position", ""))
	var rating := PlayerRatingCalculator.calculate_weighted_ovr(player, position, ovr_config)

	if rating < rating_threshold:
		return false

	var chance := base_chance + (rating - rating_threshold) * rating_bonus_per_point
	chance = clamp(chance, 0.0, 0.95)

	return rng.randf() < chance
