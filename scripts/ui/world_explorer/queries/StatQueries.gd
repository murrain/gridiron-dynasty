class_name StatQueries
extends RefCounted

## Static utility class for stat calculations and queries
##
## Provides functions to calculate composite ratings, identify core stats,
## and map stat values to display colors

## Rating tier thresholds
const RATING_ELITE = 90.0       # Elite tier (green)
const RATING_GREAT = 80.0       # Great tier (light green)
const RATING_GOOD = 70.0        # Good tier (pale green)
const RATING_AVERAGE = 60.0     # Average tier (yellow)
const RATING_BELOW_AVG = 50.0   # Below average tier (orange)
# Below 50.0 is poor (red)

## Color codes for rating tiers
const COLOR_ELITE = "#00ff00"
const COLOR_GREAT = "#66ff66"
const COLOR_GOOD = "#99ff99"
const COLOR_AVERAGE = "#ffff00"
const COLOR_BELOW_AVG = "#ffaa00"
const COLOR_POOR = "#ff0000"

## Calculate composite rating
## Returns float 0-100 representing overall player rating
##
## For draft-eligible players and rated recruits, uses pre-calculated composite_score
## which includes position-specific weighting. Falls back to simple stat average
## for players without composite_score.
static func calculate_composite_rating(player: Dictionary) -> float:
	# Use pre-calculated composite_score if available
	# Draft-eligible players have this set by DraftClassGenerator with position weighting
	if player.has("composite_score"):
		return float(player.get("composite_score", 0.0))

	# Fallback: simple average of all stats (for players without composite_score)
	var stats = player.get("stats", {})
	if stats.is_empty():
		return 0.0

	var total: float = 0.0
	var count: int = 0

	for value in stats.values():
		total += float(value)
		count += 1

	return total / count if count > 0 else 0.0

## Get core stats for a position
## These are the most important attributes for each position
## Returns Array of stat name strings
static func get_core_stats_for_position(position: String) -> Array:
	match position:
		"QB":
			return ["throw_power", "throw_accuracy", "awareness", "decision_making"]
		"RB":
			return ["speed", "agility", "strength", "vision"]
		"WR":
			return ["speed", "route_running", "catching", "awareness"]
		"TE":
			return ["catching", "route_running", "blocking", "strength"]
		"OL":
			return ["strength", "blocking", "awareness", "technique"]
		"DL":
			return ["strength", "speed", "tackling", "technique"]
		"LB":
			return ["speed", "tackling", "awareness", "coverage"]
		"CB":
			return ["speed", "coverage", "awareness", "agility"]
		"S":
			return ["speed", "coverage", "tackling", "awareness"]
		"K", "P":
			return ["kick_power", "kick_accuracy"]
		_:
			return []

## Get color for stat value (Color object)
## value: Stat value 0-100
## Returns Color for rendering
static func get_stat_color(value: float) -> Color:
	return Color(get_stat_color_hex(value))

## Get color for stat value (hex string for BBCode)
## value: Stat value 0-100
## Returns hex color string (e.g., "#00ff00")
static func get_stat_color_hex(value: float) -> String:
	if value >= RATING_ELITE: return COLOR_ELITE
	if value >= RATING_GREAT: return COLOR_GREAT
	if value >= RATING_GOOD: return COLOR_GOOD
	if value >= RATING_AVERAGE: return COLOR_AVERAGE
	if value >= RATING_BELOW_AVG: return COLOR_BELOW_AVG
	return COLOR_POOR
