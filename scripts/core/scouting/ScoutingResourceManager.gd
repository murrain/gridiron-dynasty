extends RefCounted
class_name ScoutingResourceManager

## Scouting Resource Management System
##
## Provides stateless utility functions for team-specific scouting calculations.
## Teams maintain their own scouting data and must allocate limited resources.
##
## Key concepts:
## - Teams have annual scouting hours budget (varies by league tier)
## - Scouting depth depends on hours invested per player
## - Multi-year scouting improves accuracy and reduces variance
## - Stale reports become less reliable over time
##
## RNG Usage: None (pure calculation functions)

## Scouting resource budgets by league tier
const SCOUTING_RESOURCES := {
	"nfl": {
		"annual_scout_hours": 8000,
		"max_detailed_reports": 150,
		"max_basic_reports": 400,
		"years_to_scout_college": 4
	},
	"college_p5": {
		"annual_scout_hours": 3000,
		"max_detailed_reports": 60,
		"max_basic_reports": 200,
		"years_to_scout_hs": 2
	},
	"college_g5": {
		"annual_scout_hours": 1500,
		"max_detailed_reports": 30,
		"max_basic_reports": 100,
		"years_to_scout_hs": 1
	},
	"college_fcs": {
		"annual_scout_hours": 800,
		"max_detailed_reports": 15,
		"max_basic_reports": 50,
		"years_to_scout_hs": 1
	}
}

## Scouting Report Dictionary Schema:
## {
##   "player_id": String,
##   "revealed_stats": {
##     "stat_name": float,  # Scouted value (may have noise)
##   },
##   "hours_invested": float,
##   "confidence_level": String,  # "minimal" | "basic" | "detailed" | "comprehensive"
##   "last_updated_year": int,
##   "evaluation_years": Array[int]  # Years this player was scouted
## }

## Calculate scouting depth level based on hours invested
##
## Parameters:
##   hours_invested: Total hours spent scouting this player
##
## Returns: Dictionary with depth information
##   - level: String ("minimal", "basic", "detailed", "comprehensive")
##   - stats_revealed: String ("few", "some", "most", "all")
##   - accuracy_modifier: float (0.7 - 1.15)
##   - difficulty_threshold: String ("easy", "medium", "hard", "very_hard")
static func calculate_scouting_depth(hours_invested: float) -> Dictionary:
	if hours_invested >= 60.0:
		return {
			"level": "comprehensive",
			"stats_revealed": "all",
			"accuracy_modifier": 1.15,
			"difficulty_threshold": "very_hard"
		}
	elif hours_invested >= 25.0:
		return {
			"level": "detailed",
			"stats_revealed": "most",
			"accuracy_modifier": 1.0,
			"difficulty_threshold": "hard"
		}
	elif hours_invested >= 8.0:
		return {
			"level": "basic",
			"stats_revealed": "some",
			"accuracy_modifier": 0.85,
			"difficulty_threshold": "medium"
		}
	else:
		return {
			"level": "minimal",
			"stats_revealed": "few",
			"accuracy_modifier": 0.7,
			"difficulty_threshold": "easy"
		}

## Calculate multi-year scouting bonus
##
## Scouting a player across multiple years provides better insight into
## their development trajectory and character, improving evaluation accuracy.
##
## Parameters:
##   years_scouted: Number of distinct years the player was scouted
##
## Returns: Dictionary with bonus information
##   - accuracy_bonus: float (additional accuracy multiplier, 0.0 - 0.15)
##   - variance_reduction: float (reduction in evaluation noise, 0.0 - 0.45)
static func calculate_multi_year_bonus(years_scouted: int) -> Dictionary:
	match years_scouted:
		1:
			return {"accuracy_bonus": 0.0, "variance_reduction": 0.0}
		2:
			return {"accuracy_bonus": 0.05, "variance_reduction": 0.15}
		3:
			return {"accuracy_bonus": 0.10, "variance_reduction": 0.30}
		_:  # 4+ years
			return {"accuracy_bonus": 0.15, "variance_reduction": 0.45}

## Calculate staleness penalty for outdated scouting reports
##
## Scouting data becomes less reliable over time as players develop.
## Reports should be refreshed periodically for accurate evaluations.
##
## Parameters:
##   last_scouted_year: Year the report was last updated
##   current_year: Current simulation year
##
## Returns: Accuracy multiplier (1.0 = current, lower = stale)
static func calculate_staleness_penalty(last_scouted_year: int, current_year: int) -> float:
	var years_since := current_year - last_scouted_year

	if years_since == 0:
		return 1.0  # Current year, no penalty
	elif years_since == 1:
		return 0.9  # Slight penalty, player developed
	elif years_since == 2:
		return 0.75  # Significant change possible
	else:
		return 0.5  # Very outdated, should re-scout

## Get scouting resource budget for a league tier
##
## Parameters:
##   league_tier: "nfl", "college_p5", "college_g5", or "college_fcs"
##
## Returns: Dictionary with resource limits, or default NFL values if unknown tier
static func get_resources_for_tier(league_tier: String) -> Dictionary:
	return SCOUTING_RESOURCES.get(league_tier, SCOUTING_RESOURCES["nfl"])

## Check if a team has sufficient hours to scout at a given depth
##
## Parameters:
##   hours_remaining: Hours left in the team's annual budget
##   target_depth: "minimal", "basic", "detailed", or "comprehensive"
##
## Returns: true if team can afford this scouting depth
static func can_afford_depth(hours_remaining: float, target_depth: String) -> bool:
	var required_hours := get_minimum_hours_for_depth(target_depth)
	return hours_remaining >= required_hours

## Get minimum hours required for a scouting depth level
##
## Parameters:
##   depth: "minimal", "basic", "detailed", or "comprehensive"
##
## Returns: Minimum hours required
static func get_minimum_hours_for_depth(depth: String) -> float:
	match depth:
		"comprehensive":
			return 60.0
		"detailed":
			return 25.0
		"basic":
			return 8.0
		"minimal":
			return 2.0
		_:
			return 2.0  # Default to minimal

## Determine which stats can be revealed at a given scouting depth
##
## Parameters:
##   depth_level: Scouting depth dictionary from calculate_scouting_depth()
##   position: Player's position
##   positions_cfg: Position configuration with stat difficulty
##
## Returns: Array of stat names that can be revealed
static func get_revealable_stats(
	depth_level: Dictionary,
	position: String,
	positions_cfg: Dictionary
) -> Array:
	var difficulty_threshold := String(depth_level.get("difficulty_threshold", "easy"))
	var difficulty_order := ["easy", "medium", "hard", "very_hard"]
	var threshold_index := difficulty_order.find(difficulty_threshold)

	if threshold_index == -1:
		threshold_index = 0  # Default to easy

	var revealable: Array = []

	if not positions_cfg.has(position):
		return revealable

	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var distributions: Dictionary = pos_cfg.get("distributions", {}) as Dictionary

	for stat_name in distributions.keys():
		var stat_cfg: Dictionary = distributions.get(stat_name, {}) as Dictionary
		var visibility := String(stat_cfg.get("visibility", "public"))

		# Skip hidden stats entirely
		if visibility == "hidden":
			continue

		# Public stats are always available
		if visibility == "public":
			revealable.append(stat_name)
			continue

		# For scoutable stats, check difficulty
		if visibility == "scoutable":
			var stat_difficulty := String(stat_cfg.get("scout_difficulty", "medium"))
			var stat_diff_index := difficulty_order.find(stat_difficulty)

			if stat_diff_index == -1:
				stat_diff_index = 1  # Default to medium

			# Can reveal if our threshold covers this difficulty
			if stat_diff_index <= threshold_index:
				revealable.append(stat_name)

	return revealable

## Create an empty scouting report for a player
##
## Parameters:
##   player_id: ID of the player being scouted
##   current_year: Current simulation year
##
## Returns: Empty scouting report dictionary
static func create_empty_report(player_id: String, current_year: int) -> Dictionary:
	return {
		"player_id": player_id,
		"revealed_stats": {},
		"hours_invested": 0.0,
		"confidence_level": "minimal",
		"last_updated_year": current_year,
		"evaluation_years": []
	}

## Update a scouting report with new observations
##
## Parameters:
##   existing_report: Current scouting report (or empty dictionary)
##   new_observations: Dictionary of stat_name -> observed_value
##   hours_spent: Hours invested in this scouting session
##   current_year: Current simulation year
##
## Returns: Updated scouting report dictionary
static func update_report(
	existing_report: Dictionary,
	new_observations: Dictionary,
	hours_spent: float,
	current_year: int
) -> Dictionary:
	var report := existing_report.duplicate(true)

	# Initialize if new report
	if report.is_empty():
		report = {
			"player_id": "",
			"revealed_stats": {},
			"hours_invested": 0.0,
			"confidence_level": "minimal",
			"last_updated_year": current_year,
			"evaluation_years": []
		}

	# Merge new observations with existing
	var revealed_stats: Dictionary = report.get("revealed_stats", {}) as Dictionary
	for stat_name in new_observations.keys():
		var new_value := float(new_observations.get(stat_name, 50.0))
		var old_value = revealed_stats.get(stat_name, null)

		if old_value != null:
			# Average multiple evaluations for better accuracy
			# More recent evaluations weighted higher (70% weight to new)
			revealed_stats[stat_name] = float(old_value) * 0.3 + new_value * 0.7
		else:
			revealed_stats[stat_name] = new_value

	report["revealed_stats"] = revealed_stats

	# Update hours
	report["hours_invested"] = float(report.get("hours_invested", 0.0)) + hours_spent

	# Update confidence level based on total hours
	var depth := calculate_scouting_depth(float(report["hours_invested"]))
	report["confidence_level"] = depth["level"]

	# Update year tracking
	report["last_updated_year"] = current_year
	var eval_years: Array = (report.get("evaluation_years", []) as Array).duplicate()
	if not eval_years.has(current_year):
		eval_years.append(current_year)
	report["evaluation_years"] = eval_years

	return report

## Check if a scouting report is too stale to use
##
## Parameters:
##   report: Scouting report dictionary
##   current_year: Current simulation year
##   max_stale_years: Maximum years before report is considered useless (default 3)
##
## Returns: true if report should be discarded
static func is_report_stale(report: Dictionary, current_year: int, max_stale_years: int = 3) -> bool:
	var last_updated := int(report.get("last_updated_year", 0))
	return (current_year - last_updated) > max_stale_years
