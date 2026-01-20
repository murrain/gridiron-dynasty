extends RefCounted
class_name StatFunctions

## Pure functions for stat manipulation.
## All functions are side-effect-free and deterministic.
##
## CRITICAL RNG MANAGEMENT:
## - None of these functions consume RNG
## - All stat operations are deterministic based on inputs
## - No probabilistic logic in stat calculations

# ============================================================================
# PUBLIC API - Pure Stat Functions
# ============================================================================

## Apply stat changes to a player (pure function).
##
## Merges a dictionary of stat changes into the player's current stats.
## Clamps all values to [0.0, 100.0] range.
##
## Input: player dict, changes dict (e.g., {"speed": 85, "strength": 78})
## Output: new player dict with updated stats
##
## No RNG consumption - deterministic application of changes.
##
## Example:
##   var changes := {"speed": 85, "strength": 78}
##   var updated := StatFunctions.apply_stat_changes(player, changes)
static func apply_stat_changes(
	player: Dictionary,
	changes: Dictionary
) -> Dictionary:
	var new_player := player.duplicate(true)
	var stats: Dictionary = new_player.get("stats", {}) as Dictionary

	# Create new stats dict if it doesn't exist
	if stats.is_empty():
		stats = {}

	# Apply each change, clamping to [0.0, 100.0]
	for stat_name in changes.keys():
		var new_value := float(changes[stat_name])
		stats[stat_name] = clamp(new_value, 0.0, 100.0)

	new_player["stats"] = stats
	return new_player

## Cap all stats at their potential values (pure function).
##
## Ensures no stat exceeds its corresponding potential value.
## Used after development to enforce potential ceiling.
##
## Input: player dict
## Output: new player dict with stats capped at potential
##
## No RNG consumption - deterministic capping operation.
static func cap_stats_at_potential(player: Dictionary) -> Dictionary:
	var new_player := player.duplicate(true)
	var stats: Dictionary = new_player.get("stats", {}) as Dictionary
	var potential: Dictionary = new_player.get("potential", stats) as Dictionary

	# Create new stats dict with capped values
	var capped_stats := {}
	for stat_name in stats.keys():
		var current := float(stats[stat_name])
		var pot := float(potential.get(stat_name, current))
		capped_stats[stat_name] = min(current, pot)

	new_player["stats"] = capped_stats
	return new_player

## Calculate composite score for a player using weighted stats (pure function).
##
## Computes weighted average of stats based on provided weights.
## Used for overall ratings, draft grades, and position-specific evaluations.
##
## Input: player dict, weights dict (e.g., {"speed": 0.3, "strength": 0.2, ...})
## Output: float composite score [0.0, 100.0]
##
## No RNG consumption - pure calculation.
##
## Algorithm:
##   1. For each weight, multiply stat value by weight
##   2. Sum all weighted values
##   3. Divide by sum of weights to normalize
##
## Example:
##   var weights := {"speed": 0.4, "strength": 0.3, "agility": 0.3}
##   var score := StatFunctions.calculate_composite_score(player, weights)
static func calculate_composite_score(
	player: Dictionary,
	weights: Dictionary
) -> float:
	var stats: Dictionary = player.get("stats", {}) as Dictionary

	if weights.is_empty():
		return 0.0

	var weighted_sum := 0.0
	var weight_sum := 0.0

	for stat_name in weights.keys():
		var weight := float(weights[stat_name])
		var value := float(stats.get(stat_name, 0.0))

		weighted_sum += value * weight
		weight_sum += weight

	if weight_sum == 0.0:
		return 0.0

	return weighted_sum / weight_sum

## Apply stat decay to a player (pure function).
##
## Reduces all stats by a decay_rate multiplier.
## Used for decline phase or injury recovery.
##
## Input: player dict, decay_rate (e.g., 0.95 for 5% reduction)
## Output: new player dict with decayed stats
##
## No RNG consumption - deterministic decay operation.
##
## Note: decay_rate should be in range [0.0, 1.0]
##       Values > 1.0 will increase stats (growth)
##       Values < 1.0 will decrease stats (decay)
##
## Example:
##   var decayed := StatFunctions.apply_stat_decay(player, 0.95)  # 5% decay
static func apply_stat_decay(
	player: Dictionary,
	decay_rate: float
) -> Dictionary:
	var new_player := player.duplicate(true)
	var stats: Dictionary = new_player.get("stats", {}) as Dictionary

	# Apply decay to each stat
	var decayed_stats := {}
	for stat_name in stats.keys():
		var current := float(stats[stat_name])
		var decayed := current * decay_rate
		decayed_stats[stat_name] = clamp(decayed, 0.0, 100.0)

	new_player["stats"] = decayed_stats
	return new_player

## Apply delta changes to stats (pure function).
##
## Adds delta values to current stats (can be positive or negative).
## Clamps all values to [0.0, 100.0] range.
##
## Input: player dict, deltas dict (e.g., {"speed": 2.5, "strength": -1.0})
## Output: new player dict with updated stats
##
## No RNG consumption - deterministic delta application.
##
## Example:
##   var deltas := {"speed": 2.5, "strength": -1.0}
##   var updated := StatFunctions.apply_stat_deltas(player, deltas)
static func apply_stat_deltas(
	player: Dictionary,
	deltas: Dictionary
) -> Dictionary:
	var new_player := player.duplicate(true)
	var stats: Dictionary = new_player.get("stats", {}) as Dictionary

	# Apply each delta, clamping to [0.0, 100.0]
	for stat_name in deltas.keys():
		var current := float(stats.get(stat_name, 0.0))
		var delta := float(deltas[stat_name])
		stats[stat_name] = clamp(current + delta, 0.0, 100.0)

	new_player["stats"] = stats
	return new_player

## Scale stats by position-specific multipliers (pure function).
##
## Applies position-specific scaling to stats.
## Used for positional adjustments or conversion calculations.
##
## Input: player dict, multipliers dict (e.g., {"speed": 1.1, "strength": 0.9})
## Output: new player dict with scaled stats
##
## No RNG consumption - deterministic scaling operation.
##
## Example:
##   var multipliers := {"speed": 1.1, "strength": 0.9}
##   var scaled := StatFunctions.scale_stats(player, multipliers)
static func scale_stats(
	player: Dictionary,
	multipliers: Dictionary
) -> Dictionary:
	var new_player := player.duplicate(true)
	var stats: Dictionary = new_player.get("stats", {}) as Dictionary

	# Apply each multiplier, clamping to [0.0, 100.0]
	for stat_name in multipliers.keys():
		if stats.has(stat_name):
			var current := float(stats[stat_name])
			var multiplier := float(multipliers[stat_name])
			stats[stat_name] = clamp(current * multiplier, 0.0, 100.0)

	new_player["stats"] = stats
	return new_player

## Get stat value with default fallback (pure function).
##
## Safe accessor that returns stat value or default if stat doesn't exist.
##
## Input: player dict, stat_name string, default_value float
## Output: float stat value
##
## No RNG consumption - pure lookup.
static func get_stat(
	player: Dictionary,
	stat_name: String,
	default_value: float = 0.0
) -> float:
	var stats: Dictionary = player.get("stats", {}) as Dictionary
	return float(stats.get(stat_name, default_value))

## Set single stat value (pure function).
##
## Sets a single stat to a specific value, clamped to [0.0, 100.0].
##
## Input: player dict, stat_name string, value float
## Output: new player dict with updated stat
##
## No RNG consumption - deterministic assignment.
static func set_stat(
	player: Dictionary,
	stat_name: String,
	value: float
) -> Dictionary:
	var new_player := player.duplicate(true)
	var stats: Dictionary = new_player.get("stats", {}) as Dictionary
	stats[stat_name] = clamp(value, 0.0, 100.0)
	new_player["stats"] = stats
	return new_player

## Calculate mean of all stats (pure function).
##
## Computes simple average of all stat values.
## Useful for overall rating approximations.
##
## Input: player dict
## Output: float mean value [0.0, 100.0]
##
## No RNG consumption - pure calculation.
static func calculate_mean_stat(player: Dictionary) -> float:
	var stats: Dictionary = player.get("stats", {}) as Dictionary
	if stats.is_empty():
		return 0.0

	var total := 0.0
	var count := 0
	for value in stats.values():
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			total += float(value)
			count += 1

	return (total / float(count)) if count > 0 else 0.0

## Calculate mean of specific stats (pure function).
##
## Computes average of a subset of stats (e.g., position core stats).
##
## Input: player dict, stat_names array
## Output: float mean value [0.0, 100.0]
##
## No RNG consumption - pure calculation.
##
## Example:
##   var core_stats := ["speed", "strength", "agility"]
##   var core_rating := StatFunctions.calculate_mean_of_stats(player, core_stats)
static func calculate_mean_of_stats(
	player: Dictionary,
	stat_names: Array
) -> float:
	if stat_names.is_empty():
		return 0.0

	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var total := 0.0
	var count := 0

	for stat_name in stat_names:
		if stats.has(stat_name):
			total += float(stats[stat_name])
			count += 1

	return (total / float(count)) if count > 0 else 0.0

## Normalize stats to a target mean (pure function).
##
## Scales all stats proportionally to achieve a target mean value.
## Preserves relative differences between stats while adjusting overall level.
##
## Input: player dict, target_mean float
## Output: new player dict with normalized stats
##
## No RNG consumption - deterministic normalization.
##
## Example:
##   # Normalize player to 75 overall
##   var normalized := StatFunctions.normalize_stats_to_mean(player, 75.0)
static func normalize_stats_to_mean(
	player: Dictionary,
	target_mean: float
) -> Dictionary:
	var current_mean := calculate_mean_stat(player)
	if current_mean == 0.0:
		return player  # Can't normalize from 0

	var scale_factor := target_mean / current_mean
	var multipliers := {}

	var stats: Dictionary = player.get("stats", {}) as Dictionary
	for stat_name in stats.keys():
		multipliers[stat_name] = scale_factor

	return scale_stats(player, multipliers)
