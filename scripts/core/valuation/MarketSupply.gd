## Market Supply Calculator
##
## Tracks how many players are above replacement level at each position.
## This feeds into positional scarcity calculations in PlayerValue.
##
## The supply count is used to determine how valuable a position is based
## on how many quality players are available. Positions with lower supply
## (fewer above-replacement players) are more scarce and valuable.
##
## Determinism: Supply calculation is purely deterministic based on player
## data. No RNG is involved in counting players above thresholds.
extends RefCounted
class_name MarketSupply

const ReplacementLevel = preload("res://scripts/core/valuation/ReplacementLevel.gd")

## Compute how many players are above replacement level at each position.
##
## This is used for scarcity multiplier calculations in PlayerValue.
## Only players with eval_score > replacement_level are counted as
## contributing to the supply pool.
##
## @param all_players: Array of player dictionaries with "position" and "eval_score" keys
## @param config: Optional config dictionary containing "replacement_levels"
## @return: Dictionary mapping position -> count of above-replacement players
##
## Example:
##   var supply = compute_position_supply(nfl_players)
##   # Returns: {"QB": 64, "RB": 120, "WR": 180, ...}
static func compute_position_supply(
	all_players: Array,
	config: Dictionary = {}
) -> Dictionary:
	# Handle null or empty input gracefully
	if all_players == null or all_players.is_empty():
		return {}

	var supply: Dictionary = {}

	for player in all_players:
		# Skip invalid player entries
		if player == null or not (player is Dictionary):
			continue

		var position := String(player.get("position", "ATH"))
		var score := float(player.get("eval_score", 0.0))
		var repl := ReplacementLevel.get_replacement_level(position, config)

		# Only count players above replacement level
		# Using > (not >=) because we want strictly above replacement
		if score > repl:
			supply[position] = supply.get(position, 0) + 1

	return supply

## Compute supply for a specific player pool (e.g., draft-eligible, free agents).
##
## This filters the player pool to only include players meeting a minimum
## eval_score threshold, then counts how many are above replacement level
## at each position.
##
## @param player_pool: Array of player dictionaries to evaluate
## @param min_score: Minimum eval_score threshold (players below this are filtered out)
## @param config: Optional config dictionary containing "replacement_levels"
## @return: Dictionary mapping position -> count of above-replacement players
##
## Example:
##   # Count only draft-worthy players (60+ score)
##   var draft_supply = compute_pool_supply(draft_class, 60.0)
##   # Returns: {"QB": 3, "RB": 8, "WR": 12, ...}
static func compute_pool_supply(
	player_pool: Array,
	min_score: float = 0.0,
	config: Dictionary = {}
) -> Dictionary:
	# Handle null or empty input gracefully
	if player_pool == null or player_pool.is_empty():
		return {}

	# Filter to players meeting minimum score threshold
	var filtered := player_pool.filter(func(p):
		if p == null or not (p is Dictionary):
			return false
		return float(p.get("eval_score", 0.0)) >= min_score
	)

	# Use standard supply calculation on filtered pool
	return compute_position_supply(filtered, config)
