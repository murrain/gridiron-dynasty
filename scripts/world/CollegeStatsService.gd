extends RefCounted
class_name CollegeStatsService

## College Statistics Analysis Service
##
## Provides draft evaluation tools by analyzing player career statistics:
## - Calculate efficiency metrics (QBR, yards per carry, completion %, etc.)
## - Detect production trajectories (improving, declining, breakout)
## - Aggregate career totals for scouting
##
## All functions are static and pure (no state mutation, no RNG).
## Thread-safe for parallel computation.
##
## RNG Pattern: None (all calculations are deterministic)
##
## Data Model:
##   Reads from: world_state["player_career_stats"][player_id][year]
##   Outputs: Pure computed values (no state modification)
##
## Integration:
##   Called from CollegeSeason after game simulation to compute metrics
##   Used by draft evaluation systems to assess player quality

const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")


## Calculate efficiency metrics for a player's season
##
## RNG: None (pure calculation)
## Performance: O(1) per player per season
##
## Parameters:
##   player_id: String - Player identifier
##   year: int - Season year to analyze
##   career_stats: Dictionary - world_state["player_career_stats"]
##   positions_cfg: Dictionary - Position configuration
##
## Returns:
##   Dictionary with position-specific efficiency metrics
##   Empty dict if player has no stats for that year
##
## Example output for QB:
##   {
##     "qbr": 85.3,
##     "completion_percentage": 65.2,
##     "yards_per_attempt": 7.8,
##     "td_int_ratio": 2.5
##   }
static func calculate_efficiency_metrics(
	player_id: String,
	year: int,
	career_stats: Dictionary,
	positions_cfg: Dictionary
) -> Dictionary:
	var player_years: Dictionary = career_stats.get(player_id, {})
	var season_stats: Dictionary = player_years.get(year, {})

	if season_stats.is_empty():
		return {}

	var position := String(season_stats.get("position", ""))
	if position.is_empty():
		return {}

	# Route to position-specific metric calculation
	match position:
		"QB":
			return _calculate_qb_efficiency(season_stats)
		"RB":
			return _calculate_rb_efficiency(season_stats)
		"WR", "TE":
			return _calculate_receiver_efficiency(season_stats)
		"OL", "OT", "OG", "C":
			return _calculate_ol_efficiency(season_stats)
		"DL", "DT", "DE", "EDGE":
			return _calculate_dl_efficiency(season_stats)
		"LB":
			return _calculate_lb_efficiency(season_stats)
		"CB", "S":
			return _calculate_db_efficiency(season_stats)
		"K":
			return _calculate_k_efficiency(season_stats)
		"P":
			return _calculate_p_efficiency(season_stats)
		_:
			return {}


## Analyze production trajectory across all college seasons
##
## RNG: None (pure calculation)
## Performance: O(years) per player (~4 years college)
##
## Parameters:
##   player_id: String - Player identifier
##   career_stats: Dictionary - world_state["player_career_stats"]
##   positions_cfg: Dictionary - Position configuration
##
## Returns:
##   Dictionary with trajectory analysis:
##   {
##     "trend": "rising" | "declining" | "stable" | "insufficient_data",
##     "year_over_year": [float, float, float],  # % changes between seasons
##     "breakout_season": int | -1,  # Year of breakout performance
##     "consistency_score": float  # 0.0-1.0 (1.0 = very consistent)
##   }
static func analyze_production_trajectory(
	player_id: String,
	career_stats: Dictionary,
	positions_cfg: Dictionary
) -> Dictionary:
	var player_years: Dictionary = career_stats.get(player_id, {})

	if player_years.size() < 2:
		return {
			"trend": "insufficient_data",
			"year_over_year": [],
			"breakout_season": -1,
			"consistency_score": 0.0
		}

	# Get all years sorted
	var years: Array = player_years.keys()
	var year_ints: Array = []
	for y in years:
		year_ints.append(int(y))
	year_ints.sort()

	# Calculate composite performance score for each year
	var performance_scores: Array = []
	var position := ""

	for year_int in year_ints:
		var season_stats: Dictionary = player_years.get(year_int, {})
		if position.is_empty():
			position = String(season_stats.get("position", ""))

		var score := _calculate_performance_score(season_stats, position)
		performance_scores.append(score)

	# Calculate year-over-year changes
	var yoy_changes: Array = []
	for i in range(1, performance_scores.size()):
		var prev_score := float(performance_scores[i - 1])
		var curr_score := float(performance_scores[i])

		if prev_score > 0.0:
			var pct_change := ((curr_score - prev_score) / prev_score) * 100.0
			yoy_changes.append(pct_change)
		else:
			yoy_changes.append(0.0)

	# Determine trend
	var avg_change := 0.0
	if not yoy_changes.is_empty():
		var sum := 0.0
		for change in yoy_changes:
			sum += float(change)
		avg_change = sum / float(yoy_changes.size())

	var trend := "stable"
	if avg_change >= 5.0:
		trend = "rising"
	elif avg_change <= -3.0:
		trend = "declining"

	# Detect breakout season (largest positive jump)
	var breakout_season := -1
	var max_jump := 0.0
	for i in range(yoy_changes.size()):
		var change := float(yoy_changes[i])
		if change > max_jump and change >= 10.0:
			max_jump = change
			breakout_season = int(year_ints[i + 1])

	# Calculate consistency (inverse of standard deviation)
	var consistency := _calculate_consistency(performance_scores)

	return {
		"trend": trend,
		"year_over_year": yoy_changes,
		"breakout_season": breakout_season,
		"consistency_score": consistency
	}


## Get career totals for a player across all seasons
##
## RNG: None (pure aggregation)
## Performance: O(years) per player
##
## Parameters:
##   player_id: String - Player identifier
##   career_stats: Dictionary - world_state["player_career_stats"]
##
## Returns:
##   Dictionary with cumulative stats across all seasons
##   Includes all stat fields from season stats, summed
static func get_career_totals(
	player_id: String,
	career_stats: Dictionary
) -> Dictionary:
	var player_years: Dictionary = career_stats.get(player_id, {})

	if player_years.is_empty():
		return {}

	var totals := {}
	var position := ""
	var total_games_played := 0
	var total_games_started := 0

	for year in player_years.keys():
		var season_stats: Dictionary = player_years[year]

		if position.is_empty():
			position = String(season_stats.get("position", ""))

		total_games_played += int(season_stats.get("games_played", 0))
		total_games_started += int(season_stats.get("games_started", 0))

		# Accumulate all numeric stat fields
		for stat_key in season_stats.keys():
			if stat_key in ["year", "team_id", "position"]:
				continue

			var value = season_stats[stat_key]
			if value is int or value is float:
				var current := float(totals.get(stat_key, 0.0))
				totals[stat_key] = current + float(value)

	totals["position"] = position
	totals["games_played"] = total_games_played
	totals["games_started"] = total_games_started
	totals["seasons"] = player_years.size()

	return totals


## Get draft boost/penalty based on production trajectory
##
## RNG: None (config lookup)
## Performance: O(1)
##
## Parameters:
##   trajectory: Dictionary - Output from analyze_production_trajectory()
##   config: Dictionary - Configuration with trajectory thresholds
##
## Returns:
##   float: Multiplier to apply to draft grade (0.95 - 1.10)
##   1.0 = no change, >1.0 = boost, <1.0 = penalty
static func get_trajectory_draft_modifier(
	trajectory: Dictionary,
	config: Dictionary
) -> float:
	var trend := String(trajectory.get("trend", "stable"))
	var trajectory_cfg: Dictionary = config.get("trajectory_analysis", {})

	match trend:
		"rising":
			var rising_cfg: Dictionary = trajectory_cfg.get("rising", {})
			return 1.0 + float(rising_cfg.get("draft_boost", 0.05))

		"declining":
			var declining_cfg: Dictionary = trajectory_cfg.get("declining", {})
			return 1.0 + float(declining_cfg.get("draft_penalty", -0.03))

		_:
			return 1.0


# =========================
# Position-Specific Efficiency Calculations
# =========================

static func _calculate_qb_efficiency(stats: Dictionary) -> Dictionary:
	var attempts := int(stats.get("attempts", 0))
	var completions := int(stats.get("completions", 0))
	var passing_yards := int(stats.get("passing_yards", 0))
	var touchdown_passes := int(stats.get("touchdown_passes", 0))
	var interceptions := int(stats.get("interceptions", 0))

	var metrics := {}

	# Completion percentage
	if attempts > 0:
		metrics["completion_percentage"] = (float(completions) / float(attempts)) * 100.0
	else:
		metrics["completion_percentage"] = 0.0

	# Yards per attempt
	if attempts > 0:
		metrics["yards_per_attempt"] = float(passing_yards) / float(attempts)
	else:
		metrics["yards_per_attempt"] = 0.0

	# TD/INT ratio
	if interceptions > 0:
		metrics["td_int_ratio"] = float(touchdown_passes) / float(interceptions)
	else:
		metrics["td_int_ratio"] = float(touchdown_passes)

	# Simplified QBR (NFL passer rating formula)
	if attempts > 0:
		var a := ((float(completions) / float(attempts)) - 0.3) * 5.0
		var b := ((float(passing_yards) / float(attempts)) - 3.0) * 0.25
		var c := (float(touchdown_passes) / float(attempts)) * 20.0
		var d := 2.375 - ((float(interceptions) / float(attempts)) * 25.0)

		a = clamp(a, 0.0, 2.375)
		b = clamp(b, 0.0, 2.375)
		c = clamp(c, 0.0, 2.375)
		d = clamp(d, 0.0, 2.375)

		metrics["qbr"] = ((a + b + c + d) / 6.0) * 100.0
	else:
		metrics["qbr"] = 0.0

	return metrics


static func _calculate_rb_efficiency(stats: Dictionary) -> Dictionary:
	var carries := int(stats.get("carries", 0))
	var rushing_yards := int(stats.get("rushing_yards", 0))
	var receptions := int(stats.get("receptions", 0))
	var receiving_yards := int(stats.get("receiving_yards", 0))

	var metrics := {}

	# Yards per carry
	if carries > 0:
		metrics["yards_per_carry"] = float(rushing_yards) / float(carries)
	else:
		metrics["yards_per_carry"] = 0.0

	# Yards per reception
	if receptions > 0:
		metrics["yards_per_reception"] = float(receiving_yards) / float(receptions)
	else:
		metrics["yards_per_reception"] = 0.0

	# Total yards per touch
	var total_touches := carries + receptions
	if total_touches > 0:
		var total_yards := rushing_yards + receiving_yards
		metrics["yards_per_touch"] = float(total_yards) / float(total_touches)
	else:
		metrics["yards_per_touch"] = 0.0

	return metrics


static func _calculate_receiver_efficiency(stats: Dictionary) -> Dictionary:
	var targets := int(stats.get("targets", 0))
	var receptions := int(stats.get("receptions", 0))
	var receiving_yards := int(stats.get("receiving_yards", 0))
	var games_played := int(stats.get("games_played", 0))

	var metrics := {}

	# Catch rate
	if targets > 0:
		metrics["catch_rate"] = (float(receptions) / float(targets)) * 100.0
	else:
		metrics["catch_rate"] = 0.0

	# Yards per reception
	if receptions > 0:
		metrics["yards_per_reception"] = float(receiving_yards) / float(receptions)
	else:
		metrics["yards_per_reception"] = 0.0

	# Yards per game
	if games_played > 0:
		metrics["yards_per_game"] = float(receiving_yards) / float(games_played)
	else:
		metrics["yards_per_game"] = 0.0

	return metrics


static func _calculate_ol_efficiency(stats: Dictionary) -> Dictionary:
	var games_played := int(stats.get("games_played", 0))
	var games_started := int(stats.get("games_started", 0))
	var pancake_blocks := int(stats.get("pancake_blocks", 0))
	var sacks_allowed := int(stats.get("sacks_allowed", 0))

	var metrics := {}

	# Games started percentage
	if games_played > 0:
		metrics["start_percentage"] = (float(games_started) / float(games_played)) * 100.0
	else:
		metrics["start_percentage"] = 0.0

	# Pancakes per game
	if games_played > 0:
		metrics["pancakes_per_game"] = float(pancake_blocks) / float(games_played)
	else:
		metrics["pancakes_per_game"] = 0.0

	# Sacks allowed per game (lower is better)
	if games_played > 0:
		metrics["sacks_allowed_per_game"] = float(sacks_allowed) / float(games_played)
	else:
		metrics["sacks_allowed_per_game"] = 0.0

	return metrics


static func _calculate_dl_efficiency(stats: Dictionary) -> Dictionary:
	var games_played := int(stats.get("games_played", 0))
	var sacks := int(stats.get("sacks", 0))
	var tackles := int(stats.get("tackles", 0))
	var tackles_for_loss := int(stats.get("tackles_for_loss", 0))

	var metrics := {}

	# Sacks per game
	if games_played > 0:
		metrics["sacks_per_game"] = float(sacks) / float(games_played)
	else:
		metrics["sacks_per_game"] = 0.0

	# Tackles per game
	if games_played > 0:
		metrics["tackles_per_game"] = float(tackles) / float(games_played)
	else:
		metrics["tackles_per_game"] = 0.0

	# TFL per game
	if games_played > 0:
		metrics["tfl_per_game"] = float(tackles_for_loss) / float(games_played)
	else:
		metrics["tfl_per_game"] = 0.0

	return metrics


static func _calculate_lb_efficiency(stats: Dictionary) -> Dictionary:
	var games_played := int(stats.get("games_played", 0))
	var tackles := int(stats.get("tackles", 0))
	var sacks := int(stats.get("sacks", 0))
	var passes_defended := int(stats.get("passes_defended", 0))

	var metrics := {}

	# Tackles per game
	if games_played > 0:
		metrics["tackles_per_game"] = float(tackles) / float(games_played)
	else:
		metrics["tackles_per_game"] = 0.0

	# Sacks per game
	if games_played > 0:
		metrics["sacks_per_game"] = float(sacks) / float(games_played)
	else:
		metrics["sacks_per_game"] = 0.0

	# Passes defended per game
	if games_played > 0:
		metrics["passes_defended_per_game"] = float(passes_defended) / float(games_played)
	else:
		metrics["passes_defended_per_game"] = 0.0

	return metrics


static func _calculate_db_efficiency(stats: Dictionary) -> Dictionary:
	var games_played := int(stats.get("games_played", 0))
	var interceptions := int(stats.get("interceptions", 0))
	var passes_defended := int(stats.get("passes_defended", 0))
	var tackles := int(stats.get("tackles", 0))

	var metrics := {}

	# Interceptions per game
	if games_played > 0:
		metrics["interceptions_per_game"] = float(interceptions) / float(games_played)
	else:
		metrics["interceptions_per_game"] = 0.0

	# Passes defended per game
	if games_played > 0:
		metrics["passes_defended_per_game"] = float(passes_defended) / float(games_played)
	else:
		metrics["passes_defended_per_game"] = 0.0

	# Tackles per game
	if games_played > 0:
		metrics["tackles_per_game"] = float(tackles) / float(games_played)
	else:
		metrics["tackles_per_game"] = 0.0

	return metrics


static func _calculate_k_efficiency(stats: Dictionary) -> Dictionary:
	var fga := int(stats.get("field_goal_attempts", 0))
	var fgm := int(stats.get("field_goals_made", 0))
	var xpa := int(stats.get("extra_point_attempts", 0))
	var xpm := int(stats.get("extra_points_made", 0))

	var metrics := {}

	# Field goal percentage
	if fga > 0:
		metrics["field_goal_percentage"] = (float(fgm) / float(fga)) * 100.0
	else:
		metrics["field_goal_percentage"] = 0.0

	# Extra point percentage
	if xpa > 0:
		metrics["extra_point_percentage"] = (float(xpm) / float(xpa)) * 100.0
	else:
		metrics["extra_point_percentage"] = 0.0

	return metrics


static func _calculate_p_efficiency(stats: Dictionary) -> Dictionary:
	var punts := int(stats.get("punts", 0))
	var punt_yards := int(stats.get("punt_yards", 0))

	var metrics := {}

	# Average punt distance
	if punts > 0:
		metrics["punt_average"] = float(punt_yards) / float(punts)
	else:
		metrics["punt_average"] = 0.0

	return metrics


# =========================
# Helper Functions
# =========================

## Calculate composite performance score for a season
## Higher score = better performance
static func _calculate_performance_score(stats: Dictionary, position: String) -> float:
	var games_played := int(stats.get("games_played", 0))
	if games_played == 0:
		return 0.0

	# Position-specific scoring
	match position:
		"QB":
			var passing_yards := int(stats.get("passing_yards", 0))
			var touchdowns := int(stats.get("touchdown_passes", 0))
			var interceptions := int(stats.get("interceptions", 0))
			return float(passing_yards) / 10.0 + float(touchdowns) * 20.0 - float(interceptions) * 15.0

		"RB":
			var rushing_yards := int(stats.get("rushing_yards", 0))
			var rushing_tds := int(stats.get("rushing_touchdowns", 0))
			var receiving_yards := int(stats.get("receiving_yards", 0))
			return float(rushing_yards) / 5.0 + float(rushing_tds) * 20.0 + float(receiving_yards) / 10.0

		"WR", "TE":
			var receiving_yards := int(stats.get("receiving_yards", 0))
			var receiving_tds := int(stats.get("receiving_touchdowns", 0))
			var receptions := int(stats.get("receptions", 0))
			return float(receiving_yards) / 5.0 + float(receiving_tds) * 20.0 + float(receptions) * 2.0

		"DL", "EDGE", "DT", "DE":
			var sacks := int(stats.get("sacks", 0))
			var tackles := int(stats.get("tackles", 0))
			var tfl := int(stats.get("tackles_for_loss", 0))
			return float(sacks) * 30.0 + float(tackles) * 2.0 + float(tfl) * 5.0

		"LB":
			var tackles := int(stats.get("tackles", 0))
			var sacks := int(stats.get("sacks", 0))
			var passes_defended := int(stats.get("passes_defended", 0))
			return float(tackles) * 2.0 + float(sacks) * 20.0 + float(passes_defended) * 5.0

		"CB", "S":
			var interceptions := int(stats.get("interceptions", 0))
			var passes_defended := int(stats.get("passes_defended", 0))
			var tackles := int(stats.get("tackles", 0))
			return float(interceptions) * 25.0 + float(passes_defended) * 5.0 + float(tackles) * 2.0

		_:
			# Generic: games started
			var games_started := int(stats.get("games_started", 0))
			return float(games_started) * 10.0


## Calculate consistency score (inverse of coefficient of variation)
## 1.0 = perfectly consistent, 0.0 = highly variable
static func _calculate_consistency(scores: Array) -> float:
	if scores.size() < 2:
		return 1.0

	# Calculate mean
	var sum := 0.0
	for score in scores:
		sum += float(score)
	var mean := sum / float(scores.size())

	if mean == 0.0:
		return 0.0

	# Calculate standard deviation
	var variance := 0.0
	for score in scores:
		var diff := float(score) - mean
		variance += diff * diff
	variance /= float(scores.size())
	var std_dev := sqrt(variance)

	# Coefficient of variation (lower = more consistent)
	var cv := std_dev / mean

	# Convert to 0-1 scale (0.5 CV = 0.0 consistency, 0.0 CV = 1.0 consistency)
	var consistency: float = 1.0 - clamp(cv / 0.5, 0.0, 1.0)

	return consistency
