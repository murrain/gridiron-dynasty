## Defines replacement-level talent by position.
##
## Replacement level = the talent available at league minimum cost
## (practice squad / street free agent quality).
##
## This is used to calculate value-over-replacement (VOR), which measures
## how much better a player is than the baseline talent available for free.
##
## Positions with scarce talent (QB, CB, EDGE) have lower replacement levels
## (harder to find quality replacements). Positions with abundant talent
## (RB, K, P) have higher replacement levels (easier to replace).
##
## Determinism: Replacement levels are fixed constants loaded from config.
## No RNG is needed for VOR calculation.
extends RefCounted
class_name ReplacementLevel

## Default replacement levels by position.
## These can be overridden by config at runtime.
##
## Rationale:
## - QB: 55.0 - Backup QBs are scarce, replacement level is higher
## - RB: 62.0 - RBs are abundant, easy to replace
## - WR: 58.0 - Moderate scarcity
## - TE: 56.0 - Moderate scarcity
## - OL: 54.0 - O-line depth is thin
## - DL: 57.0 - Moderate availability
## - EDGE: 52.0 - Elite edge rushers are rare
## - LB: 58.0 - Linebackers are more available
## - CB: 53.0 - Good corners are scarce
## - S: 57.0 - Safeties are moderately available
## - K: 65.0 - Kickers are very replaceable
## - P: 65.0 - Punters are very replaceable
static var DEFAULT_REPLACEMENT_LEVELS: Dictionary = {
	"QB": 55.0,
	"RB": 62.0,
	"WR": 58.0,
	"TE": 56.0,
	"OL": 54.0,
	"DL": 57.0,
	"EDGE": 52.0,
	"LB": 58.0,
	"CB": 53.0,
	"S": 57.0,
	"K": 65.0,
	"P": 65.0,
	"ATH": 55.0  # Generic athlete
}

## Get the replacement level for a given position.
##
## If config is provided, loads from config["replacement_levels"].
## Otherwise, uses DEFAULT_REPLACEMENT_LEVELS.
##
## @param position: Position code (e.g., "QB", "RB", "WR")
## @param config: Optional config dictionary containing "replacement_levels"
## @return: Replacement level score (0-100 scale)
static func get_replacement_level(position: String, config: Dictionary = {}) -> float:
	var levels: Dictionary
	if config.has("replacement_levels"):
		levels = config.get("replacement_levels", {}) as Dictionary
	else:
		levels = DEFAULT_REPLACEMENT_LEVELS

	return float(levels.get(position, 55.0))

## Calculate value-over-replacement (VOR) for a player.
##
## VOR measures how much better a player is than the baseline replacement
## talent available at that position. A VOR of 0 means the player is at or
## below replacement level (no value over what's freely available).
##
## @param player_score: Player's evaluation score (0-100 scale)
## @param position: Position code (e.g., "QB", "RB", "WR")
## @param config: Optional config dictionary containing "replacement_levels"
## @return: Value-over-replacement (clamped to min 0.0)
static func value_over_replacement(
	player_score: float,
	position: String,
	config: Dictionary = {}
) -> float:
	var repl := get_replacement_level(position, config)
	return max(0.0, player_score - repl)

## Calculate VOR for a player dictionary.
##
## Convenience method that extracts position and eval_score from player dict.
##
## @param player: Player dictionary with "position" and "eval_score" keys
## @param config: Optional config dictionary containing "replacement_levels"
## @return: Value-over-replacement (clamped to min 0.0)
static func player_vor(player: Dictionary, config: Dictionary = {}) -> float:
	var position := String(player.get("position", "ATH"))
	var eval_score := float(player.get("eval_score", 50.0))
	return value_over_replacement(eval_score, position, config)
