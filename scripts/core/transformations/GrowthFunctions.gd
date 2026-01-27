extends RefCounted
class_name GrowthFunctions

## Pure functions for player stat development and progression.
## All functions return NEW player dictionaries, never mutate input.
##
## CRITICAL: All functions are PURE - they never modify input dictionaries.
## They always return NEW dictionaries with the updated values.

# Constants for injury suppression
const INJURY_SUPPRESSION_PER_SEVERITY := 0.25

# ============================================================================
# DEVELOPMENT FUNCTIONS - Pure Transformations
# ============================================================================

## Apply one year of stat development to a player (pure function).
##
## This is the main entry point for player stat progression. It computes
## stat changes based on age, phase (growth/prime/decline), context modifiers,
## and caps progress by potential.
##
## RNG consumption pattern:
##   - N calls to randf_range() where N = number of base stats
##   - Each stat gets one random draw for development
##   - Deterministic: same seed + same inputs = same outputs
##
## @param player: Player dictionary (unchanged)
## @param context: Development context (program quality, scheme fit, etc.)
## @param configs: Configuration dictionaries (development, positions, stats)
## @param rng: RandomNumberGenerator instance (state advanced by N calls)
## @return: Dictionary with {player: Dictionary, report: Dictionary}
##
## Algorithm:
##   1. Determine lifecycle phase (growth/prime/decline) from age
##   2. For each base stat:
##      a. Roll random progress value
##      b. Apply phase multiplier (growth=1.0, prime=0.35, decline=-1.0)
##      c. Apply context multipliers (coaching, scheme fit, wear, etc.)
##      d. Cap by potential (can't exceed max)
##      e. Clamp to valid range [0.0, 100.0]
##   3. Apply injury impacts (suppression, recovery, long-term penalties)
##   4. Return new player with updated stats + detailed report
##
## Example:
##   var result := GrowthFunctions.apply_development(player, context, configs, rng)
##   assert(player["stats"]["speed"] == 70)  # Original unchanged
##   assert(result.player["stats"]["speed"] > 70)  # New copy modified
##   print(result.report)  # {"phase": "growth", "stat_entries": [...]}
static func apply_development(
	player: Dictionary,
	context: Dictionary,
	configs: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	# Validate input
	if not player.has("stats"):
		return {
			"player": player.duplicate(true),
			"report": {"stat_entries": [], "phase": "unknown", "age": 0}
		}

	# Create immutable copy of player (deep copy all nested structures)
	var new_player := player.duplicate(true)

	# Extract player attributes
	var age := int(new_player.get("age", 18))
	var position := String(new_player.get("position", ""))

	# Extract stats (work on new_player's copy)
	var stats: Dictionary = new_player.get("stats", {}) as Dictionary
	var potential: Dictionary = new_player.get("potential", stats.duplicate()) as Dictionary

	# Determine lifecycle phase
	var phase := _determine_phase(age, position, configs)

	# Compute context multipliers
	var context_mult := _compute_context_multiplier(context)

	# Compute wear multiplier for decline phase
	var wear_mult := 1.0
	if phase == "decline":
		wear_mult = _compute_wear_multiplier(new_player, configs)

	# Extract config values
	var dev_config := _extract_development_config(position, configs)

	# Initialize report
	var report := {
		"age": age,
		"phase": phase,
		"stat_entries": [],
		"decline_multiplier": wear_mult,
		"context_multiplier": context_mult
	}

	# Compute stat changes (RNG calls happen here)
	var stat_changes := _compute_stat_changes(
		stats,
		potential,
		phase,
		context_mult,
		wear_mult,
		dev_config,
		configs,
		rng
	)

	# Apply stat changes to new_player's stats
	for stat_name in stat_changes.keys():
		var change_data: Dictionary = stat_changes[stat_name]
		stats[stat_name] = change_data.after
		(report["stat_entries"] as Array).append(change_data)

	# Update new_player with modified stats
	new_player["stats"] = stats
	new_player["potential"] = potential

	return {
		"player": new_player,
		"report": report
	}


## Determine lifecycle phase from age and position (pure function).
##
## RNG consumption: NONE (deterministic computation)
##
## @param age: Player's current age
## @param position: Player's position
## @param configs: Configuration dictionary
## @return: String phase name ("growth", "prime", or "decline")
static func _determine_phase(age: int, position: String, configs: Dictionary) -> String:
	var positions_cfg: Dictionary = configs.get("positions", {}) as Dictionary
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var dev_cfg: Dictionary = pos_cfg.get("development", {}) as Dictionary

	var peak_age := int(dev_cfg.get("peak_age", 26))
	var decline_start := int(dev_cfg.get("decline_start", 30))

	if age < peak_age:
		return "growth"
	elif age < decline_start:
		return "prime"
	else:
		return "decline"


## Compute context multiplier from development context (pure function).
##
## Uses ADDITIVE deviation system to prevent multiplicative stacking penalties.
## Example: [0.8, 0.8, 0.8] → deviations [-0.2, -0.2, -0.2] → sum -0.6 → clamped 0.7
##
## RNG consumption: NONE (deterministic computation)
##
## @param context: Dictionary of context modifiers (program_quality, usage, etc.)
## @return: float multiplier in range [0.7, 1.4]
##
## Context factors:
##   - program_quality: 0.8 to 1.2 (coaching, facilities, resources)
##   - coach_specialization: 0.9 to 1.1 (position coach expertise)
##   - usage: 0.7 to 1.3 (playing time and reps)
##   - competition_tier: 0.9 to 1.1 (level of competition)
##   - rehab_quality: 0.9 to 1.1 (medical staff quality)
##
## Algorithm:
##   1. Sum deviations from 1.0 for all factors (additive, not multiplicative)
##   2. Apply deviation to base (1.0) and clamp to prevent extremes
##   3. Floor of 0.7 ensures players in poor programs reach ~80% of potential
##   4. Ceiling of 1.4 prevents unrealistic bonuses from stacking
static func _compute_context_multiplier(context: Dictionary) -> float:
	# Extract context factors with safe defaults (1.0 = neutral)
	var modifiers := {
		"program_quality": float(context.get("program_quality", 1.0)),
		"coach_specialization": float(context.get("coach_specialization", 1.0)),
		"usage": float(context.get("usage", 1.0)),
		"competition_tier": float(context.get("competition_tier", 1.0)),
		"rehab_quality": float(context.get("rehab_quality", 1.0))
	}

	# Sum deviations from 1.0 (additive, not multiplicative)
	var total_deviation := 0.0
	for value in modifiers.values():
		total_deviation += (float(value) - 1.0)

	# Apply deviation to base (1.0) and clamp to prevent extremes
	var combined := 1.0 + total_deviation

	# CAP: Never below 0.7 (30% reduction max) or above 1.4 (40% bonus max)
	combined = clampf(combined, 0.7, 1.4)

	return combined


## Compute stat changes for one year of development (pure function).
##
## RNG consumption pattern:
##   - One randf_range() call per base stat
##   - Total calls = number of stats with type="base" in stats_cfg
##   - Typically 15-20 calls per player per year
##
## @param stats: Current stat values
## @param potential: Maximum potential values for each stat
## @param phase: Lifecycle phase ("growth", "prime", "decline")
## @param context_mult: Context multiplier from _compute_context_multiplier
## @param wear_mult: Wear multiplier for decline phase
## @param dev_config: Position-specific development config
## @param configs: Full configuration dictionary
## @param rng: RandomNumberGenerator instance
## @return: Dictionary of {stat_name: change_data}
##
## Algorithm for each stat:
##   1. RNG Call: Roll raw progress value in phase-specific range
##   2. Apply phase multiplier (growth=1.0, prime=0.35, decline=-1.0 * wear)
##   3. Apply context multiplier (coaching, scheme fit, etc.)
##   4. Apply scheme fit bonus (for growth phase only)
##   5. Clamp delta to annual progress cap (prevent unrealistic jumps)
##   6. Cap by potential (can't exceed max potential)
##   7. Clamp to valid range [0.0, 100.0]
static func _compute_stat_changes(
	stats: Dictionary,
	potential: Dictionary,
	phase: String,
	context_mult: float,
	wear_mult: float,
	dev_config: Dictionary,
	configs: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var changes := {}

	# Extract config values
	var base_min := float(dev_config.get("base_min", 1.0))
	var base_max := float(dev_config.get("base_max", 4.0))
	var cap := float(dev_config.get("progress_cap", 6.0))

	var prime_min := float(dev_config.get("prime_min", 0.2))
	var prime_max := float(dev_config.get("prime_max", 0.8))

	var decline_min := float(dev_config.get("decline_min", 0.4))
	var decline_max := float(dev_config.get("decline_max", 1.6))

	var growth_mult := float(dev_config.get("growth_mult", 1.0))
	var prime_mult := float(dev_config.get("prime_mult", 0.35))
	var decline_mult := float(dev_config.get("decline_mult", 1.0))

	# Get stat definitions to filter out derived stats
	var stat_defs := _get_stat_definitions(configs)

	# Process each stat
	for stat_name in stats.keys():
		var stat_name_str := String(stat_name)

		# Skip derived stats (only process base stats)
		var stat_def: Dictionary = stat_defs.get(stat_name_str, {}) as Dictionary
		if stat_def.get("type", "base") != "base":
			continue

		var current := float(stats.get(stat_name_str, 0.0))
		var pot := float(potential.get(stat_name_str, current))

		# RNG Call: Roll raw progress value
		var raw_draw := 0.0
		var applied_mult := 0.0

		if phase == "growth":
			raw_draw = rng.randf_range(base_min, base_max)
			applied_mult = growth_mult
		elif phase == "prime":
			raw_draw = rng.randf_range(prime_min, prime_max)
			applied_mult = prime_mult
		else:  # decline
			# Decline phase: roll positive value then negate to reduce stats
			raw_draw = rng.randf_range(decline_min, decline_max)
			# Negate the multiplier to make delta negative (stats decrease)
			applied_mult = -1.0 * decline_mult * wear_mult

		# Calculate delta with phase and context multipliers
		var delta := raw_draw * applied_mult * context_mult

		# Clamp delta to annual progress cap
		var unclamped := delta
		delta = clampf(delta, -cap, cap)
		var was_clamped := not is_equal_approx(unclamped, delta)

		# Apply delta to current value
		var next_val := clampf(current + delta, 0.0, 100.0)

		# Cap by potential (only for positive development)
		var capped_by_potential := false
		if delta > 0.0:
			var limited := minf(next_val, pot)
			capped_by_potential = not is_equal_approx(limited, next_val)
			next_val = limited

		# Store change data for report
		changes[stat_name_str] = {
			"stat": stat_name_str,
			"before": current,
			"potential": pot,
			"raw_draw": raw_draw,
			"multiplier": applied_mult,
			"delta_unclamped": unclamped,
			"delta": delta,
			"clamped": was_clamped,
			"capped_by_potential": capped_by_potential,
			"after": next_val
		}

	return changes


## Extract position-specific development config (pure function).
##
## RNG consumption: NONE (deterministic computation)
##
## @param position: Player's position
## @param configs: Configuration dictionary
## @return: Dictionary with extracted config values
static func _extract_development_config(position: String, configs: Dictionary) -> Dictionary:
	var positions_cfg: Dictionary = configs.get("positions", {}) as Dictionary
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var dev_cfg: Dictionary = pos_cfg.get("development", {}) as Dictionary

	var main_cfg: Dictionary = configs.get("main", {}) as Dictionary
	var dev_global: Dictionary = main_cfg.get("development", {}) as Dictionary

	# Extract curve multipliers
	var curve := String(dev_cfg.get("curve", "mid"))
	var curve_mults: Dictionary = dev_global.get("curve_multipliers", {}) as Dictionary
	var curve_cfg: Dictionary = curve_mults.get(curve, {}) as Dictionary

	return {
		"peak_age": int(dev_cfg.get("peak_age", 26)),
		"decline_start": int(dev_cfg.get("decline_start", 30)),
		"base_min": float(main_cfg.get("annual_base_progress_min", 1.0)),
		"base_max": float(main_cfg.get("annual_base_progress_max", 4.0)),
		"progress_cap": float(main_cfg.get("annual_progress_cap", 6.0)),
		"prime_min": float(dev_global.get("prime_growth_min", 0.2)),
		"prime_max": float(dev_global.get("prime_growth_max", 0.8)),
		"decline_min": float(dev_global.get("decline_min", 0.4)),
		"decline_max": float(dev_global.get("decline_max", 1.6)),
		"growth_mult": float(curve_cfg.get("growth", 1.0)),
		"prime_mult": float(curve_cfg.get("prime", 0.35)),
		"decline_mult": float(curve_cfg.get("decline", 1.0))
	}


## Compute wear decline multiplier for decline phase (pure function).
##
## Wear accelerates decline based on accumulated snaps, collisions, and injuries.
##
## RNG consumption: NONE (deterministic computation)
##
## @param player: Player dictionary
## @param configs: Configuration dictionary
## @return: float multiplier in range [1.0, 1.6]
##
## Algorithm:
##   1. Extract wear metrics (snaps, collisions, injury_count)
##   2. Normalize each by position-specific scale
##   3. Sum normalized values into wear_score
##   4. Apply per-unit penalty (default 0.2 = 20% per unit)
##   5. Clamp to [1.0, 1.6] to prevent extreme decline
static func _compute_wear_multiplier(player: Dictionary, configs: Dictionary) -> float:
	var main_cfg: Dictionary = configs.get("main", {}) as Dictionary
	var wear_cfg: Dictionary = main_cfg.get("wear", {}) as Dictionary

	# Extract wear data with safe defaults
	var wear: Dictionary = player.get("wear", {}) as Dictionary
	var snaps := float(wear.get("snaps", 0))
	var collisions := float(wear.get("collisions", 0))
	var injuries := float(wear.get("injury_count", 0))

	# Extract scale factors from config
	var snaps_scale := float(wear_cfg.get("decline_snaps_scale", 8000.0))
	var collisions_scale := float(wear_cfg.get("decline_collisions_scale", 2600.0))
	var injuries_scale := float(wear_cfg.get("decline_injuries_scale", 6.0))
	var per_unit := float(wear_cfg.get("decline_per_wear", 0.2))

	# Compute normalized wear score
	var wear_score := 0.0
	wear_score += snaps / maxf(1.0, snaps_scale)
	wear_score += collisions / maxf(1.0, collisions_scale)
	wear_score += injuries / maxf(1.0, injuries_scale)

	# Apply penalty per wear unit
	var multiplier := 1.0 + (wear_score * per_unit)

	# Clamp to reasonable range
	var min_mult := float(wear_cfg.get("decline_min_multiplier", 1.0))
	var max_mult := float(wear_cfg.get("decline_max_multiplier", 1.6))

	return clampf(multiplier, min_mult, max_mult)


## Get stat definitions from stats config (pure function).
##
## RNG consumption: NONE (deterministic computation)
##
## @param configs: Configuration dictionary
## @return: Dictionary of {stat_name: stat_definition}
static func _get_stat_definitions(configs: Dictionary) -> Dictionary:
	var stats_cfg: Dictionary = configs.get("stats", {}) as Dictionary
	var stat_list: Array = stats_cfg.get("stats", []) as Array

	var defs := {}
	for stat_data in stat_list:
		var stat_dict: Dictionary = stat_data as Dictionary
		var name := String(stat_dict.get("name", ""))
		if name != "":
			defs[name] = stat_dict

	return defs
