extends RefCounted
class_name PlayerRatingCalculator

## Shared utility for calculating player overall ratings.
## Single source of truth to prevent duplication and ensure consistent behavior
## across pipeline filtering (HS→College, College→NFL).
##
## Used by:
## - AdvanceWorldYear._filter_college_eligible() for HS→College filtering
## - CollegeSeason (draft declaration) for College→NFL filtering
##
## RNG Usage: None (pure calculation from player data)

## [DEPRECATED] Use calculate_weighted_ovr() instead.
## This function remains for reference but should not be used in new code.
## Simple unweighted average creates mathematical bias (see ARCHITECTURE_REVIEW_2026-01-21.md).
##
## Calculates overall rating for a player using a priority cascade:
## 1. composite_score (if present) - pre-calculated rating
## 2. core_avg (if present) - pre-calculated core stats average
## 3. Position-specific core stats - calculated from position config
## 4. Simple stats average - fallback when no position config exists
##
## Parameters:
##   player: Player dictionary with stats
##   positions_cfg: Position configuration (for core_stats definition)
##   class_rules: Class rules configuration (currently unused, reserved for future)
##
## Returns:
##   Overall rating as float (typically 0.0-100.0 range)
static func calculate_overall_rating(
	player: Dictionary,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> float:
	push_warning("DEPRECATED: calculate_overall_rating() called. Use calculate_weighted_ovr() instead.")
	# Priority 1: Use pre-calculated composite_score if available
	if player.has("composite_score"):
		return float(player.get("composite_score", 0.0))

	# Priority 2: Use pre-calculated core_avg if available
	if player.has("core_avg"):
		return float(player.get("core_avg", 0.0))

	# Priority 3: Calculate from position-specific core stats
	var position := String(player.get("position", ""))
	if position != "" and positions_cfg.has(position):
		var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
		var core_stats: Array = pos_cfg.get("core_stats", []) as Array

		if not core_stats.is_empty():
			# Stats can be nested under "stats" key or at top level
			var stats_dict: Dictionary = player.get("stats", {}) as Dictionary
			var use_nested := not stats_dict.is_empty()

			var core_sum := 0.0
			for stat in core_stats:
				var stat_name := String(stat)
				var stat_value: float
				if use_nested:
					stat_value = float(stats_dict.get(stat_name, 50.0))
				else:
					stat_value = float(player.get(stat_name, 50.0))
				core_sum += stat_value

			var core_avg := core_sum / float(core_stats.size())
			return core_avg

	# Priority 4: Fallback to simple average of all numeric stats
	var stat_sum := 0.0
	var stat_count := 0

	for key in player.keys():
		var value = player[key]
		if value is float or value is int:
			# Skip non-rating fields (IDs, years, ages that aren't actually ratings)
			if key in ["player_id", "age", "year", "college_year", "hs_year"]:
				continue
			stat_sum += float(value)
			stat_count += 1

	if stat_count > 0:
		return stat_sum / float(stat_count)

	# Ultimate fallback: neutral rating
	return 50.0

## Get visibility tier for a stat from position config
##
## Parameters:
##   stat_name: Name of the stat
##   position: Position string
##   positions_cfg: Position configuration dictionary
##
## Returns: "public", "scoutable", "hidden", or "" if not found
static func get_stat_visibility(
	stat_name: String,
	position: String,
	positions_cfg: Dictionary
) -> String:
	if position == "" or not positions_cfg.has(position):
		return ""

	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var distributions: Dictionary = pos_cfg.get("distributions", {}) as Dictionary

	if not distributions.has(stat_name):
		return ""

	var stat_cfg: Dictionary = distributions.get(stat_name, {}) as Dictionary
	return String(stat_cfg.get("visibility", ""))

## Calculate displayed rating (what teams see pre-scouting)
##
## Only includes:
## - Public stats (always visible)
## - Scouted stats (from scouting_data, with noise)
##
## Excludes:
## - Hidden stats (never in displayed rating)
## - Unscouted scoutable stats
##
## Parameters:
##   player: Player dictionary with stats
##   position: Position string
##   positions_cfg: Position configuration
##   scouting_data: Dictionary with "revealed_stats" (stat_name -> scouted_value)
##
## Returns: Displayed rating (float)
static func calculate_displayed_rating(
	player: Dictionary,
	position: String,
	positions_cfg: Dictionary,
	scouting_data: Dictionary
) -> float:
	if position == "" or not positions_cfg.has(position):
		return calculate_overall_rating(player, positions_cfg, {})

	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var core_stats: Array = pos_cfg.get("core_stats", []) as Array
	var distributions: Dictionary = pos_cfg.get("distributions", {}) as Dictionary

	if core_stats.is_empty():
		return calculate_overall_rating(player, positions_cfg, {})

	var player_stats: Dictionary = player.get("stats", {}) as Dictionary
	var revealed_stats: Dictionary = scouting_data.get("revealed_stats", {}) as Dictionary

	var stat_sum := 0.0
	var stat_count := 0

	# Only include core stats that are public or scouted
	for stat in core_stats:
		var stat_name := String(stat)
		var visibility := get_stat_visibility(stat_name, position, positions_cfg)

		if visibility == "public":
			# Public stat - always use true value
			stat_sum += float(player_stats.get(stat_name, 50.0))
			stat_count += 1
		elif visibility == "scoutable" and revealed_stats.has(stat_name):
			# Scoutable stat that has been scouted - use scouted value (with noise)
			stat_sum += float(revealed_stats.get(stat_name, 50.0))
			stat_count += 1
		# Hidden stats and unscouted scoutable stats are excluded

	if stat_count > 0:
		return stat_sum / float(stat_count)
	else:
		# Fallback: only public stats
		return calculate_true_rating(player, position, positions_cfg)

## Calculate true rating (internal, no scouting noise)
##
## Includes:
## - Public stats (always known)
## - ALL scoutable stats (true values, no noise)
##
## Excludes:
## - Hidden stats (never affect rating)
##
## This is the "true" player rating that would be known with perfect scouting.
##
## Parameters:
##   player: Player dictionary with stats
##   position: Position string
##   positions_cfg: Position configuration
##
## Returns: True rating (float)
static func calculate_true_rating(
	player: Dictionary,
	position: String,
	positions_cfg: Dictionary
) -> float:
	if position == "" or not positions_cfg.has(position):
		return calculate_overall_rating(player, positions_cfg, {})

	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var core_stats: Array = pos_cfg.get("core_stats", []) as Array

	if core_stats.is_empty():
		return calculate_overall_rating(player, positions_cfg, {})

	var player_stats: Dictionary = player.get("stats", {}) as Dictionary

	var stat_sum := 0.0
	var stat_count := 0

	# Include all core stats that are public or scoutable (no hidden)
	for stat in core_stats:
		var stat_name := String(stat)
		var visibility := get_stat_visibility(stat_name, position, positions_cfg)

		if visibility in ["public", "scoutable"]:
			# Include public and scoutable stats at true value
			stat_sum += float(player_stats.get(stat_name, 50.0))
			stat_count += 1
		# Hidden stats are excluded

	if stat_count > 0:
		return stat_sum / float(stat_count)
	else:
		# Fallback to standard calculation
		return calculate_overall_rating(player, positions_cfg, {})


# =============================================================================
# WEIGHTED OVR CALCULATION SYSTEM (Phase 1)
# =============================================================================
# Three-tier weight system: base weights -> side-of-ball weights -> position weights
# See docs/architecture/WEIGHTED_OVR_SYSTEM.md for full design specification.
#
# RNG Usage: None (pure calculation from player data and config)
# =============================================================================

## Neutral value used for missing stats in weighted OVR calculation
const MISSING_STAT_NEUTRAL_VALUE := 50.0

## Tolerance for weight sum validation (weights should sum to 1.0 +/- this value)
const WEIGHT_SUM_TOLERANCE := 0.01


## Calculates weighted OVR using three-tier inheritance system.
##
## Calculation order:
## 1. Start with base weights (applies to ALL positions)
## 2. Layer in side-of-ball weights (offensive vs defensive)
## 3. Apply position-specific override_base (replaces base for this position)
## 4. Apply position-specific override_side (replaces side for this position)
## 5. Layer in position-specific weights (highest priority)
## 6. Calculate weighted sum: sum(stat * weight) for all weights
##
## Weight inheritance priority (highest to lowest):
## - Position-specific weights (weights key)
## - Position override_side (replaces side-of-ball weights)
## - Position override_base (replaces base weights)
## - Side-of-ball weights
## - Base weights
##
## Parameters:
##   player: Player dictionary with stats (may be nested under "stats" key or at top level)
##   position: Position string (QB, CB, OL, etc.)
##   ovr_config: OVR calculation config loaded from ovr_weights.json
##
## Returns:
##   Weighted OVR as float (0.0-100.0 range)
##
## RNG Consumption: None (deterministic pure function)
static func calculate_weighted_ovr(
	player: Dictionary,
	position: String,
	ovr_config: Dictionary
) -> float:
	# Get player stats (may be nested under "stats" key or at top level)
	var stats_dict: Dictionary = player.get("stats", {}) as Dictionary
	var use_nested := not stats_dict.is_empty()

	# Load three tiers of weights from config
	var base_weights: Dictionary = ovr_config.get("base_weights", {})
	var side_weights_all: Dictionary = ovr_config.get("side_of_ball_weights", {})
	var position_weights_all: Dictionary = ovr_config.get("position_weights", {})

	# Get position-specific config
	if not position_weights_all.has(position):
		push_warning("Weighted OVR: No weights defined for position '%s', falling back to legacy calculation" % position)
		return _weighted_ovr_fallback(player, stats_dict, use_nested)

	var pos_config: Dictionary = position_weights_all.get(position, {})
	var side_of_ball := String(pos_config.get("side_of_ball", "offensive"))
	var pos_weights: Dictionary = pos_config.get("weights", {})
	var override_base: Dictionary = pos_config.get("override_base", {})
	var override_side: Dictionary = pos_config.get("override_side", {})

	# Get side-of-ball weights for this position's side
	var side_weights: Dictionary = side_weights_all.get(side_of_ball, {})

	# Build final weight map using inheritance priority
	# Start with base weights, then layer in higher-priority overrides
	var final_weights := {}

	# Step 1: Start with base weights (lowest priority)
	for stat in base_weights.keys():
		if stat.begins_with("_"):
			continue  # Skip metadata keys like _comment
		final_weights[stat] = float(base_weights[stat])

	# Step 2: Layer in side-of-ball weights (may override base)
	for stat in side_weights.keys():
		if stat.begins_with("_"):
			continue
		final_weights[stat] = float(side_weights[stat])

	# Step 3: Apply position override_base (replaces base weights for this position)
	for stat in override_base.keys():
		if stat.begins_with("_"):
			continue
		final_weights[stat] = float(override_base[stat])

	# Step 4: Apply position override_side (replaces side weights for this position)
	for stat in override_side.keys():
		if stat.begins_with("_"):
			continue
		final_weights[stat] = float(override_side[stat])

	# Step 5: Layer in position-specific weights (highest priority)
	for stat in pos_weights.keys():
		if stat.begins_with("_"):
			continue
		final_weights[stat] = float(pos_weights[stat])

	# Calculate weighted sum
	var weighted_sum := 0.0
	var total_weight := 0.0  # Track for validation and normalization

	for stat_name in final_weights.keys():
		var weight := float(final_weights[stat_name])

		# Skip zero weights (no contribution)
		if weight == 0.0:
			continue

		# Get stat value from player
		var stat_value: float
		if use_nested:
			stat_value = float(stats_dict.get(stat_name, MISSING_STAT_NEUTRAL_VALUE))
		else:
			stat_value = float(player.get(stat_name, MISSING_STAT_NEUTRAL_VALUE))

		weighted_sum += stat_value * weight
		total_weight += weight

	# Validation: weights should sum to approximately 1.0
	if abs(total_weight - 1.0) > WEIGHT_SUM_TOLERANCE:
		push_warning("Weighted OVR: Position '%s' weights sum to %.4f (expected 1.0 +/- %.4f)" % [position, total_weight, WEIGHT_SUM_TOLERANCE])

	# Normalize if weights don't sum to exactly 1.0
	# This ensures consistent OVR scale regardless of weight sum
	if total_weight > 0.0:
		return weighted_sum / total_weight
	else:
		# No valid weights - return neutral value
		return MISSING_STAT_NEUTRAL_VALUE


## Fallback calculation for positions without weight config in ovr_weights.json.
## Uses legacy core_avg or simple average approach.
##
## Parameters:
##   player: Player dictionary
##   stats_dict: Pre-extracted stats dictionary (for nested stats)
##   use_nested: Whether stats are under "stats" key
##
## Returns: Fallback OVR as float
static func _weighted_ovr_fallback(
	player: Dictionary,
	stats_dict: Dictionary,
	use_nested: bool
) -> float:
	# Priority 1: Use pre-calculated core_avg if available
	if player.has("core_avg"):
		return float(player.get("core_avg", MISSING_STAT_NEUTRAL_VALUE))

	# Priority 2: Simple average of all numeric stats
	var stat_sum := 0.0
	var stat_count := 0

	var source := stats_dict if use_nested else player
	for key in source.keys():
		var value = source[key]
		if value is float or value is int:
			# Skip non-rating fields
			if key in ["player_id", "age", "year", "college_year", "hs_year"]:
				continue
			stat_sum += float(value)
			stat_count += 1

	if stat_count > 0:
		return stat_sum / float(stat_count)

	return MISSING_STAT_NEUTRAL_VALUE


## Validates OVR config at startup or config load time.
## Ensures all position weights sum to 1.0 and all required fields exist.
##
## Validation Rules:
## 1. Each position must have "side_of_ball" field
## 2. Each position's total weights must sum to 1.0 (+/- WEIGHT_SUM_TOLERANCE)
## 3. Total = base_overrides + side_overrides + position_weights
##
## Parameters:
##   ovr_config: OVR calculation config loaded from ovr_weights.json
##   positions_cfg: Position configuration from positions.json (for reference, optional validation)
##
## Returns:
##   true if all validations pass, false if any validation fails
static func validate_ovr_config(ovr_config: Dictionary, positions_cfg: Dictionary) -> bool:
	var is_valid := true
	var position_weights: Dictionary = ovr_config.get("position_weights", {})
	var base_weights: Dictionary = ovr_config.get("base_weights", {})
	var side_weights_all: Dictionary = ovr_config.get("side_of_ball_weights", {})

	if position_weights.is_empty():
		push_error("OVR Config Validation: No position_weights defined")
		return false

	for position in position_weights.keys():
		# Skip metadata keys
		if position.begins_with("_"):
			continue

		var pos_config: Dictionary = position_weights.get(position, {})

		# Rule 1: Check side_of_ball is specified
		if not pos_config.has("side_of_ball"):
			push_error("OVR Config Validation: Position '%s' missing 'side_of_ball' declaration" % position)
			is_valid = false
			continue

		var side_of_ball := String(pos_config.get("side_of_ball", ""))

		# Calculate total weight for this position using the same inheritance logic
		# as calculate_weighted_ovr to ensure validation matches calculation
		var total_weight := 0.0
		var final_weights := {}

		# Start with base weights
		for stat in base_weights.keys():
			if stat.begins_with("_"):
				continue
			final_weights[stat] = float(base_weights[stat])

		# Layer in side-of-ball weights
		var side_weights: Dictionary = side_weights_all.get(side_of_ball, {})
		for stat in side_weights.keys():
			if stat.begins_with("_"):
				continue
			final_weights[stat] = float(side_weights[stat])

		# Apply override_base
		var override_base: Dictionary = pos_config.get("override_base", {})
		for stat in override_base.keys():
			if stat.begins_with("_"):
				continue
			final_weights[stat] = float(override_base[stat])

		# Apply override_side
		var override_side: Dictionary = pos_config.get("override_side", {})
		for stat in override_side.keys():
			if stat.begins_with("_"):
				continue
			final_weights[stat] = float(override_side[stat])

		# Apply position-specific weights
		var weights: Dictionary = pos_config.get("weights", {})
		for stat in weights.keys():
			if stat.begins_with("_"):
				continue
			final_weights[stat] = float(weights[stat])

		# Sum all final weights
		for stat in final_weights.keys():
			total_weight += float(final_weights[stat])

		# Rule 2: Check sum is approximately 1.0
		if abs(total_weight - 1.0) > WEIGHT_SUM_TOLERANCE:
			push_error("OVR Config Validation: Position '%s' weights sum to %.4f (expected 1.0 +/- %.4f)" % [position, total_weight, WEIGHT_SUM_TOLERANCE])
			is_valid = false

	return is_valid


## Loads OVR weights config from file path.
## Returns empty dictionary if file not found or invalid JSON.
##
## Parameters:
##   file_path: Path to ovr_weights.json file (e.g., "res://configs/sports/american_football/ovr_weights.json")
##
## Returns:
##   Loaded config dictionary, or empty dictionary on error
static func load_ovr_config(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_error("OVR Config: File not found at '%s'" % file_path)
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("OVR Config: Failed to open file '%s'" % file_path)
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_error("OVR Config: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {}

	var data = json.get_data()
	if not data is Dictionary:
		push_error("OVR Config: Root element must be a Dictionary")
		return {}

	return data as Dictionary
