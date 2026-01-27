## Unified player valuation calculator.
##
## Architecture: This is the top-level valuation module that integrates all
## valuation components:
## - ValueCurve: Non-linear market value curves for elite player premium
## - ReplacementLevel: Value-over-replacement (VOR) baseline
## - PositionalScarcity: Market-wide supply/demand multipliers
## - TeamImpact: Team-specific value based on roster depth
## - ContractValuation: Age multipliers for contract value
##
## Purpose: Provide a single authoritative valuation that combines:
## 1. Intrinsic player quality (VOR + curve)
## 2. Market conditions (scarcity)
## 3. Team-specific factors (depth, leverage)
## 4. Age/longevity considerations
##
## This produces two key values:
## - market_value: What other teams would pay (external demand)
## - team_value: What player is worth to current team (internal value)
##
## The difference (team_premium) captures how much more valuable a player
## is to their current team vs. the open market. A star QB with no backup
## has high team_premium. A 3rd-string RB has negative team_premium.
##
## Determinism: All calculations are deterministic. No RNG is used in the
## core valuation logic. The optional jitter in ContractValuation is handled
## separately and is not part of this calculator.
##
## Usage:
##   var result = PlayerValue.calculate(player, context, config, rng)
##   var market_value = result.market_value
##   var team_value = result.team_value
##   var premium = result.team_premium
extends RefCounted
class_name PlayerValue

const ValueCurve = preload("res://scripts/core/valuation/ValueCurve.gd")
const ReplacementLevel = preload("res://scripts/core/valuation/ReplacementLevel.gd")
const PositionalScarcity = preload("res://scripts/core/valuation/PositionalScarcity.gd")
const TeamImpact = preload("res://scripts/core/valuation/TeamImpact.gd")
const ContractValuation = preload("res://scripts/core/valuation/ContractValuation.gd")


## Calculate comprehensive player valuation.
##
## Combines all valuation components to produce market value and team-specific
## value for a player.
##
## @param player: Player dictionary with required keys:
##   - id: Unique player identifier
##   - position: Position code (e.g., "QB", "WR", "RB")
##   - age: Player age in years
##   - eval_score: Evaluation score (0-100 scale)
##
## @param context: Context dictionary with optional keys:
##   - team_roster: Array of player dicts for team-specific valuation
##   - position_supply: Dictionary mapping position -> count of above-replacement players
##   - market_data: Additional market context (reserved for future use)
##
## @param config: Configuration dictionary from valuation.json with keys:
##   - value_curve: Curve configuration for ValueCurve.score_to_market_value
##   - replacement_levels: Position-specific replacement levels
##   - scarcity: Scarcity multiplier config (scarcity_min, scarcity_max)
##   - team_impact: Team impact config (no_backup_multiplier, etc.)
##   - age_multipliers: Age-based multiplier table
##   - range_spread_pct: Variance range for contracts (default 0.18)
##
## @param rng: RandomNumberGenerator (unused in current implementation, reserved for future jitter)
##
## @return: Dictionary with comprehensive valuation data:
##   - player_id: Player identifier
##   - position: Player position
##   - age: Player age
##   - eval_score: Input evaluation score
##   - vor: Value-over-replacement
##   - curved_value: Base market value from curve
##   - scarcity_multiplier: Market scarcity adjustment
##   - age_multiplier: Age-based adjustment
##   - market_value: Final market value (what other teams would pay)
##   - team_value: Team-specific value (worth to current team)
##   - team_premium: Difference between team_value and market_value
##   - range_min: Minimum contract value (market_value - spread)
##   - range_max: Maximum contract value (market_value + spread)
##   - components: Detailed breakdown of all valuation components
static func calculate(
	player: Dictionary,
	context: Dictionary,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var position := String(player.get("position", "ATH"))
	var age := int(player.get("age", 22))
	var eval_score := float(player.get("eval_score", 50.0))

	# 1. Value-over-replacement (VOR)
	# Measures how much better the player is than replacement-level talent
	var vor := ReplacementLevel.value_over_replacement(eval_score, position, config)

	# 2. Non-linear curve applied to VOR
	# Elite players get exponentially higher values
	# We apply the curve to VOR rather than raw eval_score to ensure
	# replacement-level players (VOR=0) have near-zero market value
	var curved_value := ValueCurve.score_to_market_value(vor, config.get("value_curve", {}))

	# 3. Positional scarcity multiplier (market-wide)
	# If supply is low relative to demand, values increase
	var scarcity_mult := 1.0
	if context.has("position_supply"):
		var supply := int(context.get("position_supply", {}).get(position, 100))
		scarcity_mult = PositionalScarcity.compute_scarcity_multiplier(
			position, supply, config.get("scarcity", {})
		)

	# 4. Age multiplier (contract longevity adjustment)
	# Younger players are worth more due to longer productive careers
	var age_mult := ContractValuation._age_multiplier(age, config)

	# 5. Team-specific impact (if on a team)
	# How valuable is this player to their current team specifically?
	# Accounts for roster depth, position importance, and leverage
	# Default team_value is 1.0 (multiplier, meaning team_value = market_value)
	var team_impact := {"team_value": 1.0}
	if context.has("team_roster"):
		team_impact = TeamImpact.compute_team_value(
			player, context.get("team_roster", []), config
		)

	# Final market value (what other teams would pay)
	# Combines intrinsic value (curved_value) with market conditions (scarcity)
	# and age considerations
	var market_value := curved_value * scarcity_mult * age_mult

	# Team value (what this player is worth to current team)
	# Uses team-specific multiplier on market value to account for depth
	# and position leverage. TeamImpact.team_value is now a multiplier (1.0-1.4)
	# that scales the market value based on roster context.
	var team_multiplier: float = float(team_impact.get("team_value", 1.0))
	var team_value: float = market_value * team_multiplier

	# Contract range (with variance)
	# Provides min/max bounds for contract negotiations
	# Read from market section (config.market.range_spread_pct)
	var market_config := config.get("market", {}) as Dictionary
	var spread := float(market_config.get("range_spread_pct", 0.18))
	var range_min := market_value * (1.0 - spread)
	var range_max := market_value * (1.0 + spread)

	return {
		"player_id": String(player.get("id", "")),
		"position": position,
		"age": age,
		"eval_score": eval_score,
		"vor": vor,
		"curved_value": curved_value,
		"scarcity_multiplier": scarcity_mult,
		"age_multiplier": age_mult,
		"market_value": market_value,
		"team_value": team_value,
		"team_premium": team_value - market_value,  # How much more to current team
		"range_min": range_min,
		"range_max": range_max,
		"components": {
			"vor": vor,
			"curve_output": curved_value,
			"scarcity": scarcity_mult,
			"age": age_mult,
			"team_impact": team_impact
		}
	}

## Validate that config contains all required sections for PlayerValue.
##
## This validation checks that the configuration dictionary has all the sections
## and fields required by the PlayerValue calculator. It's recommended to call
## this during initialization or when loading configs to catch errors early.
##
## @param config: Configuration dictionary to validate (typically from valuation.json)
## @return: Array of error strings (empty if config is valid)
static func validate_config(config: Dictionary) -> Array:
	var errors: Array = []

	# Check required sections exist
	var required := ["value_curve", "replacement_levels", "scarcity", "team_impact"]
	for section in required:
		if not config.has(section):
			errors.append("Missing config section: %s" % section)

	# Check value_curve has tiers
	if config.has("value_curve"):
		var curve_config := config.get("value_curve", {}) as Dictionary
		var tiers := curve_config.get("tiers", []) as Array
		if tiers.is_empty():
			errors.append("value_curve.tiers must have at least one tier")
		elif tiers.size() < 3:
			errors.append("value_curve.tiers should have at least 3 tiers for proper distribution")

		# Check for elite threshold
		if not curve_config.has("elite_threshold"):
			errors.append("value_curve.elite_threshold is required")
		if not curve_config.has("elite_multiplier_boost"):
			errors.append("value_curve.elite_multiplier_boost is required")

	# Check replacement_levels has all standard positions
	if config.has("replacement_levels"):
		var levels: Dictionary = config.get("replacement_levels", {}) as Dictionary
		var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]
		for pos in positions:
			if not levels.has(pos):
				errors.append("Missing replacement_level for position: %s" % pos)

	# Check scarcity config
	if config.has("scarcity"):
		var scarcity_config := config.get("scarcity", {}) as Dictionary
		if not scarcity_config.has("scarcity_min"):
			errors.append("scarcity.scarcity_min is required")
		if not scarcity_config.has("scarcity_max"):
			errors.append("scarcity.scarcity_max is required")
		if not scarcity_config.has("starter_slots"):
			errors.append("scarcity.starter_slots is required")

		# Validate range makes sense
		var min_val := float(scarcity_config.get("scarcity_min", 0.7))
		var max_val := float(scarcity_config.get("scarcity_max", 1.5))
		if min_val >= max_val:
			errors.append("scarcity_min (%.2f) must be less than scarcity_max (%.2f)" % [min_val, max_val])

	# Check team_impact config
	if config.has("team_impact"):
		var team_config := config.get("team_impact", {}) as Dictionary
		if not team_config.has("no_backup_multiplier"):
			errors.append("team_impact.no_backup_multiplier is required")
		if not team_config.has("thin_depth_multiplier"):
			errors.append("team_impact.thin_depth_multiplier is required")
		if not team_config.has("position_win_impacts"):
			errors.append("team_impact.position_win_impacts is required")

	return errors
