## Non-linear value curve for player valuation.
##
## Architecture: This class is part of the valuation layer, which transforms
## raw evaluation scores (from scouts, combines, etc.) into market values. The
## separation exists because:
## - Evaluation logic measures player ability (pure, context-free)
## - Valuation logic assigns market worth (depends on curve shape, elite
##   thresholds, and economic factors)
## This separation allows evaluation to remain stable while valuation curves
## can be tuned independently for game balance.
##
## Purpose: Transform raw evaluation scores into market values using non-linear
## curves that appropriately value elite players. A 95-rated player should be
## worth significantly more than a 90-rated player, not just 5% more.
##
## Curve types:
## - "exponential": Simple power curve with configurable exponent
## - "tiered_exponential": Different growth rates for different score tiers
## - "linear": Fallback to linear scaling (for backwards compatibility)
##
## Determinism: All functions are pure and deterministic. No RNG required.
extends RefCounted
class_name ValueCurve


## Convert an evaluation score to market value using the configured curve.
##
## Parameters:
## - eval_score: Player evaluation score (0-100 scale)
## - config: Dictionary with curve configuration (see value_curve in valuation.json)
##
## Returns: Market value as a float (units depend on configuration base_value)
static func score_to_market_value(eval_score: float, config: Dictionary) -> float:
	var curve_type := String(config.get("curve_type", "exponential"))
	var base := float(config.get("base_value", 1.0))

	match curve_type:
		"exponential":
			return _exponential(eval_score, base, config)
		"tiered_exponential":
			return _tiered_exponential(eval_score, base, config)
		"linear":
			return _linear(eval_score, base, config)
		_:
			# Unknown curve type, fall back to linear
			push_warning("ValueCurve: Unknown curve_type '%s', using linear fallback" % curve_type)
			return _linear(eval_score, base, config)


## Simple exponential curve: value = base * pow(normalized_score, exponent)
## Scores 90-100 are worth exponentially more than lower scores.
static func _exponential(eval_score: float, base: float, config: Dictionary) -> float:
	var exponent := float(config.get("exponent", 2.5))
	var normalized: float = clampf(eval_score / 100.0, 0.0, 1.0)

	# Apply elite threshold boost if configured
	var elite_threshold := float(config.get("elite_threshold", 92.0))
	var elite_boost := float(config.get("elite_multiplier_boost", 1.0))

	var value := base * pow(normalized, exponent) * 100.0

	if eval_score >= elite_threshold:
		value *= elite_boost

	return value


## Tiered exponential curve: Different growth rates for different score ranges.
## This allows fine-grained control over how value scales across the talent spectrum.
##
## Tiers are evaluated in order. Each tier specifies:
## - min/max: Score range for this tier
## - multiplier: Base multiplier for values in this tier
## - exponent: Growth rate within the tier
static func _tiered_exponential(eval_score: float, base: float, config: Dictionary) -> float:
	var tiers: Array = config.get("tiers", []) as Array

	if tiers.is_empty():
		# No tiers configured, fall back to simple exponential
		return _exponential(eval_score, base, config)

	# Find the matching tier
	for tier in tiers:
		var tier_dict: Dictionary = tier as Dictionary
		var tier_min := float(tier_dict.get("min", 0.0))
		var tier_max := float(tier_dict.get("max", 100.0))

		if eval_score >= tier_min and eval_score <= tier_max:
			var tier_mult := float(tier_dict.get("multiplier", 1.0))
			var tier_exp := float(tier_dict.get("exponent", 1.0))

			# Normalize score within the tier range
			var tier_range := tier_max - tier_min
			var position_in_tier: float = (eval_score - tier_min) / maxf(tier_range, 1.0)

			# Calculate value within this tier
			var tier_value := base * tier_mult * pow(position_in_tier, tier_exp)

			# Add cumulative value from previous tiers
			var cumulative := _cumulative_tier_value(tier_min, tiers, base)

			var total := cumulative + tier_value

			# Apply elite boost if applicable
			var elite_threshold := float(config.get("elite_threshold", 92.0))
			var elite_boost := float(config.get("elite_multiplier_boost", 1.0))
			if eval_score >= elite_threshold:
				total *= elite_boost

			return total

	# Score didn't match any tier (shouldn't happen with proper config)
	push_warning("ValueCurve: Score %.1f didn't match any tier, using exponential fallback" % eval_score)
	return _exponential(eval_score, base, config)


## Calculate cumulative value from all tiers below the given threshold.
## This ensures smooth transitions between tiers.
static func _cumulative_tier_value(threshold: float, tiers: Array, base: float) -> float:
	var cumulative := 0.0

	for tier in tiers:
		var tier_dict: Dictionary = tier as Dictionary
		var tier_min := float(tier_dict.get("min", 0.0))
		var tier_max := float(tier_dict.get("max", 100.0))

		# Only count tiers that are entirely below or at the threshold
		if tier_max <= threshold:
			var tier_mult := float(tier_dict.get("multiplier", 1.0))
			var tier_exp := float(tier_dict.get("exponent", 1.0))
			# Full tier contribution at exponent=1.0 (top of tier)
			cumulative += base * tier_mult * pow(1.0, tier_exp)

	return cumulative


## Linear curve for backwards compatibility: value = base + eval_score * per_point
static func _linear(eval_score: float, base: float, config: Dictionary) -> float:
	var per_point := float(config.get("per_point", 1.0))
	return base + eval_score * per_point


## Convenience method to get expected value ranges for testing/debugging.
## Returns expected approximate values for key score thresholds.
static func get_expected_values(config: Dictionary) -> Dictionary:
	return {
		"score_60": score_to_market_value(60.0, config),
		"score_75": score_to_market_value(75.0, config),
		"score_85": score_to_market_value(85.0, config),
		"score_92": score_to_market_value(92.0, config),
		"score_98": score_to_market_value(98.0, config)
	}
