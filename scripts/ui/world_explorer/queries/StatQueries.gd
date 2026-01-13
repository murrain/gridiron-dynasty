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
## Reads from positions.json configuration file
## Returns Array of stat name strings
static func get_core_stats_for_position(position: String) -> Array:
	var config_path := "res://configs/sports/american_football/positions.json"
	if not FileAccess.file_exists(config_path):
		push_warning("StatQueries: positions.json not found at %s" % config_path)
		return []

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_warning("StatQueries: Cannot open positions.json")
		return []

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_warning("StatQueries: Cannot parse positions.json: %s" % json.get_error_message())
		return []

	var positions_cfg: Dictionary = json.data
	if not positions_cfg.has(position):
		return []

	var pos_config: Dictionary = positions_cfg[position]
	return pos_config.get("core_stats", [])

## Get secondary stats for a position
## Reads stats with role="secondary" from distributions in positions.json
## Returns Array of stat name strings
static func get_secondary_stats_for_position(position: String) -> Array:
	var config_path := "res://configs/sports/american_football/positions.json"
	if not FileAccess.file_exists(config_path):
		return []

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return []

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		return []

	var positions_cfg: Dictionary = json.data
	if not positions_cfg.has(position):
		return []

	var pos_config: Dictionary = positions_cfg[position]
	var distributions: Dictionary = pos_config.get("distributions", {})

	var secondary_stats: Array = []
	for stat_name in distributions.keys():
		var stat_config: Dictionary = distributions[stat_name]
		if stat_config.get("role", "") == "secondary":
			secondary_stats.append(stat_name)

	return secondary_stats

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
