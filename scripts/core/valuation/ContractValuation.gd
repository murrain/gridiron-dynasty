## Contract valuation helper built around scouting composite scores.
##
## Updated to use PlayerValue for unified valuation logic. This provides:
## - Non-linear value curves (elite player premium)
## - Value-over-replacement (VOR) calculation
## - Positional scarcity adjustments
## - Team-specific valuation (with optional context)
##
## Evaluation source:
## - ScoutRuntime.score_player(...) in scripts/core/scouting/ScoutRuntime.gd.
## - Inputs: scout Dictionary, player Dictionary, positions_data Dictionary,
##   stats_cfg Dictionary, class_rules Dictionary, rng RandomNumberGenerator.
## - Output: composite-like 0..100 score (eval_score) used here as input_eval_score.
##
## Determinism: if jitter is enabled, callers MUST pass an RNG seeded from
## stable lineage (e.g., hash(player_id + season_year)). The chosen seed should
## be persisted in valuation_seed for traceability.
extends RefCounted
class_name ContractValuation

const PlayerValue = preload("res://scripts/core/valuation/PlayerValue.gd")

const DEFAULT_VERSION := "v2"

## Estimate contract value using unified PlayerValue calculator.
##
## This is the primary method for contract valuation, using PlayerValue
## to provide accurate, non-linear valuation with VOR and scarcity adjustments.
##
## @param player: Player dictionary with required keys:
##   - id: Unique player identifier
##   - position: Position code (e.g., "QB", "WR", "RB")
##   - age: Player age in years
##   - eval_score: Evaluation score (0-100 scale)
##
## @param config: Configuration dictionary from valuation.json
##
## @param rng: RandomNumberGenerator for jitter (if enabled in config)
##
## @param context: Optional context dictionary with keys:
##   - team_roster: Array of player dicts for team-specific valuation
##   - position_supply: Dict mapping position -> count of above-replacement players
##   If empty, uses market value only (no team-specific adjustments)
##
## @return: Dictionary with contract valuation data:
##   - apy: Average per year (market value, for backward compatibility)
##   - total: Total contract value (apy * typical years)
##   - years: Typical contract years
##   - market_value: What other teams would pay (from PlayerValue)
##   - team_value: Worth to current team (from PlayerValue)
##   - team_premium: Difference between team and market value
##   - vor: Value-over-replacement
##   - range_min: Minimum negotiation value
##   - range_max: Maximum negotiation value
##   - components: Detailed breakdown of all valuation components
##   - valuation_version: Version identifier for this calculation
static func estimate_value(
	player: Dictionary,
	config: Dictionary,
	rng: RandomNumberGenerator,
	context: Dictionary = {}
) -> Dictionary:
	# Use PlayerValue to calculate comprehensive valuation
	var valuation := PlayerValue.calculate(player, context, config, rng)

	# Primary value is market_value (what other teams would pay)
	var base_value: float = valuation.market_value

	# Apply jitter if configured
	var jitter_sigma := float(config.get("jitter_sigma_pct", 0.0))
	if jitter_sigma > 0.0:
		if rng == null:
			push_error("ContractValuation: RNG required when jitter_sigma_pct > 0.")
		else:
			# RNG call: randfn for jitter (1 call)
			base_value *= clamp(1.0 + rng.randfn(0.0, jitter_sigma), 0.5, 1.5)

	# Determine typical contract years based on age
	var age := int(player.get("age", 22))
	var years := _typical_contract_years(age)

	return {
		# Legacy fields for backward compatibility
		"apy": base_value,
		"total": base_value * years,
		"years": years,

		# New PlayerValue fields
		"market_value": valuation.market_value,
		"team_value": valuation.team_value,
		"team_premium": valuation.team_premium,
		"vor": valuation.vor,
		"range_min": valuation.range_min,
		"range_max": valuation.range_max,
		"components": valuation.components,

		# Metadata
		"valuation_version": DEFAULT_VERSION,
		"player_id": String(player.get("id", ""))
	}

## Determine typical contract years based on player age.
##
## Younger players get longer contracts (more productive years ahead).
## Older players get shorter contracts (less certainty).
##
## @param age: Player age in years
## @return: Typical contract length in years (1-5)
static func _typical_contract_years(age: int) -> int:
	if age <= 23:
		return 5  # Young players: 5-year deals
	elif age <= 27:
		return 4  # Prime age: 4-year deals
	elif age <= 30:
		return 3  # Mature: 3-year deals
	elif age <= 33:
		return 2  # Aging: 2-year deals
	else:
		return 1  # Veteran: 1-year deals

## LEGACY: Build valuation payload using old linear scoring.
##
## DEPRECATED: Use estimate_value() instead for accurate valuation.
##
## This method is kept for backward compatibility with existing code
## that directly calls build_payload. New code should use estimate_value().
##
## @param eval_score: Evaluation score (0-100)
## @param player: Player dictionary
## @param stats_cfg: Stats configuration
## @param valuation_cfg: Valuation configuration
## @param rng: Random number generator for jitter
## @param valuation_seed: Seed used for valuation
## @return: Legacy payload dictionary
static func build_payload(
	eval_score: float,
	player: Dictionary,
	stats_cfg: Dictionary,
	valuation_cfg: Dictionary,
	rng: RandomNumberGenerator,
	valuation_seed: int
) -> Dictionary:
	var version := String(valuation_cfg.get("version", DEFAULT_VERSION))
	var pos_mult := _position_multiplier(String(player.get("position", "ATH")), valuation_cfg)
	var age_mult := _age_multiplier(int(player.get("age", 0)), valuation_cfg)
	var blend_mult := _current_potential_multiplier(player, stats_cfg, valuation_cfg)
	var base_value := _score_to_value(eval_score, valuation_cfg)

	var est_value := base_value * pos_mult * age_mult * blend_mult
	var jitter_sigma := float(valuation_cfg.get("jitter_sigma_pct", 0.0))
	if jitter_sigma > 0.0:
		if rng == null:
			push_error("ContractValuation: RNG required when jitter_sigma_pct > 0.")
		else:
			est_value *= clamp(1.0 + rng.randfn(0.0, jitter_sigma), 0.5, 1.5)

	var spread := float(valuation_cfg.get("range_spread_pct", 0.15))
	var range_min := est_value * (1.0 - spread)
	var range_max := est_value * (1.0 + spread)

	return {
		"range_min": range_min,
		"range_max": range_max,
		"est_value": est_value,
		"input_eval_score": eval_score,
		"valuation_seed": valuation_seed,
		"valuation_version": version
	}

## Storage target: player["contract"]["valuation"].
## Payload format: range_min, range_max, est_value, input_eval_score,
## valuation_seed, valuation_version.
static func write_to_player_contract(player: Dictionary, payload: Dictionary) -> void:
	var contract: Dictionary = player.get("contract", {}) as Dictionary
	contract["valuation"] = payload.duplicate(true)
	player["contract"] = contract

static func _position_multiplier(position: String, valuation_cfg: Dictionary) -> float:
	var premiums: Dictionary = valuation_cfg.get("position_premiums", {}) as Dictionary
	return float(premiums.get(position, premiums.get("DEFAULT", 1.0)))

static func _age_multiplier(age: int, valuation_cfg: Dictionary) -> float:
	var table: Array = valuation_cfg.get("age_multipliers", []) as Array
	for row in table:
		var entry: Dictionary = row
		var min_age := int(entry.get("min", -1))
		var max_age := int(entry.get("max", -1))
		if age >= min_age and age <= max_age:
			return float(entry.get("mult", 1.0))
	return 1.0

static func _current_potential_multiplier(
	player: Dictionary,
	stats_cfg: Dictionary,
	valuation_cfg: Dictionary
) -> float:
	var weights: Dictionary = valuation_cfg.get("current_vs_potential", {}) as Dictionary
	var current_weight := float(weights.get("current_weight", 0.7))
	var potential_weight := float(weights.get("potential_weight", 0.3))
	var current_avg := _avg_stats(player.get("stats", {}) as Dictionary, stats_cfg)
	var potential_stats: Dictionary = player.get("potential", {}) as Dictionary
	if potential_stats.is_empty():
		potential_stats = player.get("stats", {}) as Dictionary
	var potential_avg := _avg_stats(potential_stats, stats_cfg)
	var blended := current_avg * current_weight + potential_avg * potential_weight
	return clamp(blended / 100.0, 0.5, 1.5)

static func _score_to_value(eval_score: float, valuation_cfg: Dictionary) -> float:
	var curve: Dictionary = valuation_cfg.get("score_to_value", {}) as Dictionary
	var base := float(curve.get("base", 0.0))
	var per_point := float(curve.get("per_point", 1.0))
	return base + eval_score * per_point

static func _avg_stats(stats: Dictionary, stats_cfg: Dictionary) -> float:
	var list: Array = stats_cfg.get("stats", []) as Array
	if list.is_empty():
		if stats.is_empty():
			return 50.0
		var sum := 0.0
		for v in stats.values():
			sum += float(v)
		return sum / float(stats.size())

	var total := 0.0
	for row in list:
		var entry: Dictionary = row
		var key := String(entry.get("name", ""))
		if key == "":
			continue
		total += float(stats.get(key, 50.0))
	return total / float(max(1, list.size()))
