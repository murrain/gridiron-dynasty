extends RefCounted
class_name RetirementFunctions

## Pure functions for retirement checks.
## All functions are side-effect-free and deterministic.
##
## CRITICAL RNG MANAGEMENT:
## - All probabilistic functions accept RNG as explicit parameter
## - RNG consumption patterns are documented per function
## - Same seed + same inputs = same outputs (guaranteed determinism)

# ============================================================================
# PUBLIC API - Pure Retirement Functions
# ============================================================================

## Determine if a player should retire this year (pure function).
##
## RNG consumption pattern:
##   - 0 calls if career-ending injury detected (immediate retirement)
##   - 0 calls if age < min_age (no retirement possible)
##   - 0 calls if age >= max_age (forced retirement)
##   - 1 call otherwise: retirement probability roll
##   Total: 0-1 calls per invocation (deterministic for given seed)
##
## Algorithm:
##   1. Check for career-ending injury (immediate forced retirement)
##   2. Check age boundaries (min_age, max_age)
##   3. Calculate retirement probability based on age, rating, and position
##   4. Roll against probability
##
## Input: player dict, configs dict, RNG instance
## Output: bool (true if player should retire)
##
## Determinism guarantee:
##   - Same RNG state + same player = same retirement decision
##   - RNG call only occurs when retirement is probabilistic
static func should_retire(
	player: Dictionary,
	configs: Dictionary,
	rng: RandomNumberGenerator
) -> bool:
	# Check for career-ending injury (immediate forced retirement)
	var injuries: Array = player.get("injuries", []) as Array
	for injury_entry in injuries:
		var injury: Dictionary = injury_entry as Dictionary
		if injury.get("career_ending", false):
			return true

	var main_cfg := configs.get("main", {}) as Dictionary
	var positions_cfg := configs.get("positions", {}) as Dictionary
	var cfg: Dictionary = main_cfg.get("retirement", {}) as Dictionary

	var age := int(player.get("age", 18))
	var min_age := int(cfg.get("min_age", 27))
	var soft_cap_age := int(cfg.get("soft_cap_age", 33))
	var max_age := int(cfg.get("max_age", 40))

	# Age boundaries
	if age < min_age:
		return false
	if age >= max_age:
		return true

	# Calculate retirement probability
	var chance := calculate_retirement_probability(player, configs)

	# RNG Call 1: Retirement roll (only if age is in probabilistic range)
	return rng.randf() < chance

## Calculate retirement probability for a player (pure function).
##
## Returns a probability value [0.0, 0.95] based on:
## - Base retirement chance (from config)
## - Age above soft cap (linear increase per year)
## - Low rating boost (aging players with declining skills more likely to retire)
##
## Input: player dict, configs dict
## Output: float probability [0.0, 0.95] (capped at 95%)
##
## No RNG consumption - pure calculation.
static func calculate_retirement_probability(
	player: Dictionary,
	configs: Dictionary
) -> float:
	var main_cfg := configs.get("main", {}) as Dictionary
	var positions_cfg := configs.get("positions", {}) as Dictionary
	var cfg: Dictionary = main_cfg.get("retirement", {}) as Dictionary

	var age := int(player.get("age", 18))
	var min_age := int(cfg.get("min_age", 27))
	var soft_cap_age := int(cfg.get("soft_cap_age", 33))
	var max_age := int(cfg.get("max_age", 40))

	# Age boundaries
	if age < min_age:
		return 0.0
	if age >= max_age:
		return 1.0

	# Base chance plus age slope
	var chance := float(cfg.get("base_chance", 0.02))
	var age_slope := float(cfg.get("age_chance_per_year", 0.04))
	chance += max(0, age - soft_cap_age) * age_slope

	# Low rating boost
	var low_rating_threshold := float(cfg.get("low_rating_threshold", 55.0))
	var low_rating_boost := float(cfg.get("low_rating_boost", 0.08))
	if _core_rating(player, positions_cfg) < low_rating_threshold:
		chance += low_rating_boost

	# Cap at 95% (always leave 5% chance of continuing)
	chance = clamp(chance, 0.0, 0.95)
	return chance

## Apply retirement to a player (pure function).
##
## Sets the player's stage to RETIRED.
## Does NOT consume RNG - retirement is deterministic once decided.
##
## Input: player dict
## Output: new player dict with stage = RETIRED
static func apply_retirement(player: Dictionary) -> Dictionary:
	var new_player := player.duplicate(true)
	new_player["stage"] = 6  # Player.PlayerStage.RETIRED
	return new_player

# ============================================================================
# INTERNAL HELPERS - Private Pure Functions
# ============================================================================

## Calculate core rating for a player based on position-specific core stats (pure function).
##
## Uses position's core_stats array to compute average rating.
## Falls back to mean of all stats if no core stats defined.
##
## Input: player dict, positions config dict
## Output: float rating [0.0, 100.0]
##
## No RNG consumption - pure calculation.
static func _core_rating(player: Dictionary, positions_cfg: Dictionary) -> float:
	var position := String(player.get("position", ""))
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var core_stats: Array = (pos_cfg.get("core_stats", []) as Array)
	var stats: Dictionary = player.get("stats", {}) as Dictionary

	# If no core stats defined, use mean of all stats
	if core_stats.is_empty():
		return _mean_of_stats(stats)

	# Calculate average of core stats
	var total := 0.0
	var count := 0
	for stat in core_stats:
		if stats.has(stat):
			total += float(stats.get(stat, 0.0))
			count += 1

	if count == 0:
		return _mean_of_stats(stats)

	return total / float(count)

## Calculate mean of all stats in a stats dictionary (pure function).
##
## Filters for numeric values only (float or int).
##
## Input: stats dict
## Output: float mean [0.0, 100.0]
##
## No RNG consumption - pure calculation.
static func _mean_of_stats(stats: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for v in stats.values():
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			total += float(v)
			count += 1
	return (total / float(count)) if count > 0 else 0.0
