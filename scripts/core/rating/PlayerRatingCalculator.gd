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
