## Team-specific impact valuation.
##
## Calculates how valuable a player is to their current team based on:
## 1. Roster depth at their position (how hard to replace internally)
## 2. Leverage multiplier (no backup = higher value)
## 3. Position importance for winning games
##
## This captures the concept that a star QB with no backup is worth more
## to their current team than market value, while a RB3 is worth less
## than market value to their team.
##
## Determinism: All calculations are deterministic based on roster state.
## No RNG is used in team impact valuation.
extends RefCounted
class_name TeamImpact

## Compute team-specific value for a player on their current roster.
##
## Returns a comprehensive dictionary with:
## - raw_impact: How much better than replacement
## - depth: Number of other players at same position
## - leverage_multiplier: Amplifier for thin depth (1.0-1.4)
## - position_importance: Win impact weight (0.4-2.5)
## - team_value: Final team-specific value score
##
## @param player: Player dictionary with "id", "position", "eval_score"
## @param team_roster: Array of all players on the team (including this player)
## @param config: Config dictionary with "team_impact" section
## @return: Dictionary with team valuation components
static func compute_team_value(
	player: Dictionary,
	team_roster: Array,
	config: Dictionary
) -> Dictionary:
	var position := String(player.get("position", "ATH"))
	var player_score := float(player.get("eval_score", 0.0))
	var player_id := String(player.get("id", ""))

	# Find other players at same position on roster
	var position_mates: Array = []
	for p in team_roster:
		if String(p.get("position", "")) == position and String(p.get("id", "")) != player_id:
			position_mates.append(p)

	# Sort by score descending
	position_mates.sort_custom(func(a, b):
		return float(a.get("eval_score", 0)) > float(b.get("eval_score", 0))
	)

	# Find best replacement on roster (or replacement level if none)
	var replacement_score := ReplacementLevel.get_replacement_level(position, config)
	if position_mates.size() > 0:
		replacement_score = max(replacement_score, float(position_mates[0].get("eval_score", 0)))

	# Impact = how much better than the replacement
	var impact: float = max(0.0, player_score - replacement_score)

	# Leverage: if team has no backup, impact is amplified
	var depth := position_mates.size()
	var leverage_mult := 1.0
	var team_impact_config: Dictionary = config.get("team_impact", {}) as Dictionary
	if depth == 0:
		leverage_mult = float(team_impact_config.get("no_backup_multiplier", 1.4))
	elif depth == 1:
		leverage_mult = float(team_impact_config.get("thin_depth_multiplier", 1.15))

	# Position importance for wins
	var pos_importance := _get_position_win_impact(position, config)

	return {
		"player_id": player_id,
		"position": position,
		"player_score": player_score,
		"replacement_score": replacement_score,
		"raw_impact": impact,
		"depth": depth,
		"leverage_multiplier": leverage_mult,
		"position_importance": pos_importance,
		"team_value": impact * leverage_mult * pos_importance
	}

## Get position importance for winning games.
##
## Based on NFL analytics, different positions have different impacts
## on team success. QB has the highest impact, followed by premium
## positions like EDGE and CB. Replaceable positions like K and P
## have minimal impact.
##
## @param position: Position code (e.g., "QB", "RB", "WR")
## @param config: Config dictionary with "team_impact.position_win_impacts"
## @return: Win impact multiplier (0.4-2.5)
static func _get_position_win_impact(position: String, config: Dictionary) -> float:
	var team_impact_config: Dictionary = config.get("team_impact", {}) as Dictionary

	# Default win impacts if not specified in config
	var default_impacts := {
		"QB": 2.5,    # QB has outsized impact on wins
		"EDGE": 1.4,
		"CB": 1.3,
		"WR": 1.2,
		"OL": 1.1,
		"DL": 1.1,
		"LB": 1.0,
		"S": 0.95,
		"TE": 0.9,
		"RB": 0.8,    # RBs are more replaceable
		"K": 0.5,
		"P": 0.4,
		"ATH": 1.0
	}

	var impacts: Dictionary = team_impact_config.get("position_win_impacts", default_impacts) as Dictionary
	return float(impacts.get(position, 1.0))
