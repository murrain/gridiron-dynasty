extends RefCounted
class_name SchemeFitCalculator

## Scheme Fit Evaluation System
##
## Calculates scheme-adjusted player ratings based on team schemes.
## Teams evaluate players differently based on scheme fit - a receiving TE
## is more valuable to a West Coast offense than a Power Run offense.
##
## Key concepts:
## - Schemes define stat weights (0.65-1.35 range)
## - Elite players (90+ rating) transcend scheme (20% impact)
## - Scheme fit creates meaningful evaluation divergence between teams
##
## RNG Usage: None (pure calculation from player data and scheme config)

## Load schemes configuration
static func load_schemes_config() -> Dictionary:
	var config_path := "res://configs/sports/american_football/schemes.json"
	if not FileAccess.file_exists(config_path):
		push_error("Schemes config not found at: " + config_path)
		return {}

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open schemes config")
		return {}

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_error("Failed to parse schemes config JSON")
		return {}

	var data = json.data
	if not data is Dictionary:
		push_error("Schemes config is not a dictionary")
		return {}

	return data as Dictionary

## Get scheme weights for a specific position
## Returns empty dict if scheme or position not found (all weights = 1.0)
static func get_scheme_weights(
	schemes_config: Dictionary,
	scheme_type: String,  # "offensive_schemes" or "defensive_schemes"
	scheme_name: String,
	position: String
) -> Dictionary:
	var schemes: Dictionary = schemes_config.get(scheme_type, {}) as Dictionary
	var scheme: Dictionary = schemes.get(scheme_name, {}) as Dictionary
	var position_weights: Dictionary = scheme.get("position_stat_weights", {}) as Dictionary
	return position_weights.get(position, {}) as Dictionary

## Calculate scheme-weighted rating for a player
##
## For each stat, apply scheme weight (default 1.0 if not specified).
## Returns weighted average of all stats.
##
## Parameters:
##   player: Player dictionary with "stats" dict
##   position: Position string (QB, RB, etc.)
##   scheme_weights: Dictionary of stat_name -> weight (0.65-1.35)
##
## Returns: Scheme-weighted rating (float)
static func calculate_scheme_rating(
	player: Dictionary,
	position: String,
	scheme_weights: Dictionary
) -> float:
	var player_stats: Dictionary = player.get("stats", {}) as Dictionary
	if player_stats.is_empty():
		return 50.0  # Neutral fallback

	var weighted_sum := 0.0
	var weight_total := 0.0

	for stat_name in player_stats.keys():
		var stat_value := float(player_stats.get(stat_name, 50.0))
		var weight := float(scheme_weights.get(stat_name, 1.0))  # Unmapped stats = 1.0

		weighted_sum += stat_value * weight
		weight_total += weight

	if weight_total > 0.0:
		return weighted_sum / weight_total
	else:
		return 50.0

## Calculate elite player dampening factor
##
## Elite players (90+) transcend scheme - teams can adapt scheme around elite talent.
## Very good players (80-90) are partially affected.
## Average players (70-80) are moderately affected.
## Below average (<70) are fully affected by scheme fit.
##
## Parameters:
##   base_rating: Player's base overall rating
##
## Returns: Dampening multiplier (0.2 for elite, 1.0 for average)
static func calculate_elite_dampening(base_rating: float) -> float:
	if base_rating >= 90.0:
		return 0.2  # Scheme matters 20% as much for elite players
	elif base_rating >= 80.0:
		# Linear interpolation: 90->0.2, 80->0.5
		return 0.5 - ((base_rating - 80.0) / 10.0) * 0.3
	elif base_rating >= 70.0:
		# Linear interpolation: 80->0.5, 70->1.0
		return 1.0 - ((base_rating - 70.0) / 10.0) * 0.5
	else:
		return 1.0  # Full scheme impact for below-average players

## Calculate final scheme-adjusted rating
##
## Combines base rating, scheme fit, elite dampening, and coach rigidity to produce
## the final rating that a team with this scheme sees for this player.
##
## Parameters:
##   player: Player dictionary with stats
##   position: Position string
##   scheme_weights: Dictionary of stat_name -> weight
##   base_rating: Player's base overall rating (from PlayerRatingCalculator)
##   coach_rigidity: Coach's scheme_rigidity (0.5=flexible, 1.0=normal, 1.2=rigid)
##
## Returns: Scheme-adjusted rating (float)
static func calculate_scheme_adjusted_rating(
	player: Dictionary,
	position: String,
	scheme_weights: Dictionary,
	base_rating: float,
	coach_rigidity: float = 1.0
) -> float:
	var scheme_rating := calculate_scheme_rating(player, position, scheme_weights)

	# Calculate delta as percentage
	if base_rating == 0.0:
		return scheme_rating  # Avoid division by zero

	var scheme_fit_delta := (scheme_rating - base_rating) / base_rating

	# Apply elite dampening and coach rigidity
	var elite_dampening := calculate_elite_dampening(base_rating)
	var effective_delta := scheme_fit_delta * elite_dampening * coach_rigidity

	# Apply delta to base rating
	return base_rating * (1.0 + effective_delta)

## Determine if a position is offensive or defensive
static func get_scheme_type_for_position(position: String) -> String:
	var offensive_positions := ["QB", "RB", "WR", "TE", "OL"]
	var defensive_positions := ["DL", "EDGE", "LB", "CB", "S"]

	if position in offensive_positions:
		return "offensive_schemes"
	elif position in defensive_positions:
		return "defensive_schemes"
	else:
		# Special teams (K, P) - no scheme fit
		return ""

## Convenience method: Calculate scheme-adjusted rating from team/coach data
##
## Automatically loads schemes config, determines scheme type, and calculates fit.
##
## Parameters:
##   player: Player dictionary
##   position: Position string
##   base_rating: Base overall rating
##   team_offensive_scheme: Team's offensive scheme name
##   team_defensive_scheme: Team's defensive scheme name
##   coach_rigidity: Coach's scheme_rigidity (default 1.0)
##
## Returns: Scheme-adjusted rating (float)
static func calculate_for_team(
	player: Dictionary,
	position: String,
	base_rating: float,
	team_offensive_scheme: String,
	team_defensive_scheme: String,
	coach_rigidity: float = 1.0
) -> float:
	var scheme_type := get_scheme_type_for_position(position)

	# Special teams or unknown position - no scheme adjustment
	if scheme_type == "":
		return base_rating

	var schemes_config := load_schemes_config()
	if schemes_config.is_empty():
		push_warning("Schemes config not loaded, returning base rating")
		return base_rating

	# Determine which scheme to use
	var scheme_name := team_offensive_scheme if scheme_type == "offensive_schemes" else team_defensive_scheme

	# Get weights for this scheme + position
	var scheme_weights := get_scheme_weights(schemes_config, scheme_type, scheme_name, position)

	# Calculate adjusted rating
	return calculate_scheme_adjusted_rating(
		player,
		position,
		scheme_weights,
		base_rating,
		coach_rigidity
	)
