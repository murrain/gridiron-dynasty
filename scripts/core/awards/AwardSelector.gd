extends RefCounted
class_name AwardSelector

## NFL Award Selection System
##
## Pure, stateless functions for selecting award winners based on player statistics.
## All functions are deterministic (no RNG required) - awards based solely on statistical performance.
##
## Implements:
##   - A3.2: Offensive/Defensive Player of the Year (OPOY/DPOY)
##   - A3.3: All-Pro Teams (First and Second Team)
##   - A3.4: Pro Bowl Selections (AFC/NFC rosters)
##   - A3.8: Rookie of the Year (OROY/DROY)
##
## Performance: O(n log n) where n = number of eligible players (dominated by sorting)
##
## Data Model:
##   Awards stored in world_state["awards"][year] = {
##     "opoy": {player_id, position, score, stats_summary},
##     "dpoy": {player_id, position, score, stats_summary},
##     "oroy": {player_id, position, score, stats_summary},
##     "droy": {player_id, position, score, stats_summary}
##   }
##
##   All-Pro stored in world_state["all_pro_teams"][year] = {
##     "first_team": [{player_id, position, score}, ...],
##     "second_team": [{player_id, position, score}, ...]
##   }
##
##   Pro Bowl stored in world_state["pro_bowl_rosters"][year] = {
##     "afc": [{player_id, position, conference, score}, ...],
##     "nfc": [{player_id, position, conference, score}, ...]
##   }

## Position groupings for award eligibility
const OFFENSIVE_POSITIONS := ["QB", "RB", "WR", "TE", "OL", "OT", "OG", "C"]
const DEFENSIVE_POSITIONS := ["DL", "DT", "DE", "EDGE", "LB", "CB", "S"]
const AFC_REGIONS := ["afc_east", "afc_north", "afc_south", "afc_west"]
const NFC_REGIONS := ["nfc_east", "nfc_north", "nfc_south", "nfc_west"]

## All-Pro roster requirements (22 positions per team)
const ALL_PRO_ROSTER := {
	"QB": 1,
	"RB": 2,
	"WR": 3,
	"TE": 1,
	"OL": 5,     # Simplified: 5 OL (covers OT/OG/C)
	"DL": 2,     # Interior DL (DT)
	"EDGE": 2,   # Edge rushers (DE/EDGE)
	"LB": 3,
	"CB": 2,
	"S": 2,
	"K": 1,
	"P": 1
}

## Pro Bowl roster requirements (44 positions per conference)
const PRO_BOWL_ROSTER := {
	"QB": 3,
	"RB": 3,
	"WR": 4,
	"TE": 2,
	"OL": 6,     # Simplified: 6 OL total
	"DL": 3,     # Interior DL
	"EDGE": 3,   # Edge rushers
	"LB": 4,
	"CB": 3,
	"S": 3,
	"K": 2,
	"P": 2
}


## Selects all NFL awards for a given season.
##
## This is the main entry point that orchestrates all award selections.
##
## Parameters:
##   world_state: Dictionary containing player_career_stats, nfl_rosters, nfl_teams
##   year: Season year for award selection
##
## Returns:
##   Dictionary with summary of all awards selected
##
## Side Effects:
##   Modifies world_state to add award results
static func select_all_awards(world_state: Dictionary, year: int) -> Dictionary:
	var player_stats: Dictionary = world_state.get("player_career_stats", {})
	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	var teams: Array = world_state.get("nfl_teams", [])

	if player_stats.is_empty() or rosters.is_empty() or teams.is_empty():
		return {
			"error": "Missing required data for award selection",
			"year": year
		}

	# Build team -> conference mapping
	var team_to_conference := _build_team_conference_map(teams)

	# Extract year stats for all players
	var year_stats := _extract_year_stats(player_stats, year, rosters, team_to_conference)

	if year_stats.is_empty():
		return {
			"warning": "No player stats found for year %d" % year,
			"year": year
		}

	# Select individual awards
	var opoy := select_offensive_player_of_year(year_stats)
	var dpoy := select_defensive_player_of_year(year_stats)
	var oroy := select_offensive_rookie_of_year(year_stats)
	var droy := select_defensive_rookie_of_year(year_stats)

	# Select All-Pro teams
	var all_pro := select_all_pro_teams(year_stats)

	# Select Pro Bowl rosters
	var pro_bowl := select_pro_bowl_rosters(year_stats)

	# Store in world_state
	var awards: Dictionary = world_state.get("awards", {})
	if not awards.has(year):
		awards[year] = {}

	awards[year]["opoy"] = opoy
	awards[year]["dpoy"] = dpoy
	awards[year]["oroy"] = oroy
	awards[year]["droy"] = droy
	world_state["awards"] = awards

	var all_pro_teams: Dictionary = world_state.get("all_pro_teams", {})
	all_pro_teams[year] = all_pro
	world_state["all_pro_teams"] = all_pro_teams

	var pro_bowl_rosters: Dictionary = world_state.get("pro_bowl_rosters", {})
	pro_bowl_rosters[year] = pro_bowl
	world_state["pro_bowl_rosters"] = pro_bowl_rosters

	return {
		"year": year,
		"opoy": opoy.get("player_id", ""),
		"dpoy": dpoy.get("player_id", ""),
		"oroy": oroy.get("player_id", ""),
		"droy": droy.get("player_id", ""),
		"all_pro_first_team_count": all_pro.get("first_team", []).size(),
		"all_pro_second_team_count": all_pro.get("second_team", []).size(),
		"pro_bowl_afc_count": pro_bowl.get("afc", []).size(),
		"pro_bowl_nfc_count": pro_bowl.get("nfc", []).size()
	}


## Selects Offensive Player of the Year (OPOY).
##
## Algorithm:
##   1. Filter to offensive positions only
##   2. Calculate position-specific score for each player
##   3. Return player with highest score
##
## Returns:
##   Dictionary with player_id, position, score, and stats_summary
static func select_offensive_player_of_year(year_stats: Array) -> Dictionary:
	var candidates := []

	for player_data in year_stats:
		var p: Dictionary = player_data
		var position := String(p.get("position", ""))

		if position in OFFENSIVE_POSITIONS:
			var score := _calculate_offensive_score(p)
			candidates.append({
				"player_id": p.get("player_id", ""),
				"position": position,
				"score": score,
				"stats": p.get("stats", {}),
				"team_id": p.get("team_id", "")
			})

	if candidates.is_empty():
		return {"player_id": "", "position": "", "score": 0.0}

	# Sort by score descending
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])

	var winner: Dictionary = candidates[0]
	return {
		"player_id": winner.get("player_id", ""),
		"position": winner.get("position", ""),
		"score": winner.get("score", 0.0),
		"stats_summary": _summarize_stats(winner.get("stats", {}), winner.get("position", "")),
		"team_id": winner.get("team_id", "")
	}


## Selects Defensive Player of the Year (DPOY).
##
## Algorithm:
##   1. Filter to defensive positions only
##   2. Calculate position-specific score for each player
##   3. Return player with highest score
##
## Returns:
##   Dictionary with player_id, position, score, and stats_summary
static func select_defensive_player_of_year(year_stats: Array) -> Dictionary:
	var candidates := []

	for player_data in year_stats:
		var p: Dictionary = player_data
		var position := String(p.get("position", ""))

		if position in DEFENSIVE_POSITIONS:
			var score := _calculate_defensive_score(p)
			candidates.append({
				"player_id": p.get("player_id", ""),
				"position": position,
				"score": score,
				"stats": p.get("stats", {}),
				"team_id": p.get("team_id", "")
			})

	if candidates.is_empty():
		return {"player_id": "", "position": "", "score": 0.0}

	# Sort by score descending
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])

	var winner: Dictionary = candidates[0]
	return {
		"player_id": winner.get("player_id", ""),
		"position": winner.get("position", ""),
		"score": winner.get("score", 0.0),
		"stats_summary": _summarize_stats(winner.get("stats", {}), winner.get("position", "")),
		"team_id": winner.get("team_id", "")
	}


## Selects Offensive Rookie of the Year (OROY).
##
## Algorithm:
##   1. Filter to offensive positions and is_rookie=true
##   2. Calculate position-specific score for each player
##   3. Return player with highest score
##
## Returns:
##   Dictionary with player_id, position, score, and stats_summary
static func select_offensive_rookie_of_year(year_stats: Array) -> Dictionary:
	var candidates := []

	for player_data in year_stats:
		var p: Dictionary = player_data
		var position := String(p.get("position", ""))
		var is_rookie := bool(p.get("is_rookie", false))

		if is_rookie and position in OFFENSIVE_POSITIONS:
			var score := _calculate_offensive_score(p)
			candidates.append({
				"player_id": p.get("player_id", ""),
				"position": position,
				"score": score,
				"stats": p.get("stats", {}),
				"team_id": p.get("team_id", "")
			})

	if candidates.is_empty():
		return {"player_id": "", "position": "", "score": 0.0}

	# Sort by score descending
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])

	var winner: Dictionary = candidates[0]
	return {
		"player_id": winner.get("player_id", ""),
		"position": winner.get("position", ""),
		"score": winner.get("score", 0.0),
		"stats_summary": _summarize_stats(winner.get("stats", {}), winner.get("position", "")),
		"team_id": winner.get("team_id", "")
	}


## Selects Defensive Rookie of the Year (DROY).
##
## Algorithm:
##   1. Filter to defensive positions and is_rookie=true
##   2. Calculate position-specific score for each player
##   3. Return player with highest score
##
## Returns:
##   Dictionary with player_id, position, score, and stats_summary
static func select_defensive_rookie_of_year(year_stats: Array) -> Dictionary:
	var candidates := []

	for player_data in year_stats:
		var p: Dictionary = player_data
		var position := String(p.get("position", ""))
		var is_rookie := bool(p.get("is_rookie", false))

		if is_rookie and position in DEFENSIVE_POSITIONS:
			var score := _calculate_defensive_score(p)
			candidates.append({
				"player_id": p.get("player_id", ""),
				"position": position,
				"score": score,
				"stats": p.get("stats", {}),
				"team_id": p.get("team_id", "")
			})

	if candidates.is_empty():
		return {"player_id": "", "position": "", "score": 0.0}

	# Sort by score descending
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])

	var winner: Dictionary = candidates[0]
	return {
		"player_id": winner.get("player_id", ""),
		"position": winner.get("position", ""),
		"score": winner.get("score", 0.0),
		"stats_summary": _summarize_stats(winner.get("stats", {}), winner.get("position", "")),
		"team_id": winner.get("team_id", "")
	}


## Selects All-Pro teams (First and Second Team).
##
## Algorithm:
##   1. Group players by position
##   2. For each position, select top N players based on score
##   3. First team gets top players, second team gets next players
##   4. Total: 22 first team + 22 second team positions
##
## Returns:
##   Dictionary with first_team and second_team arrays
static func select_all_pro_teams(year_stats: Array) -> Dictionary:
	var by_position := {}

	# Group players by position and calculate scores
	for player_data in year_stats:
		var p: Dictionary = player_data
		var position := String(p.get("position", ""))

		# Map specific positions to All-Pro categories
		var all_pro_pos := _map_to_all_pro_position(position)
		if all_pro_pos == "":
			continue

		var score := _calculate_overall_score(p)

		if not by_position.has(all_pro_pos):
			by_position[all_pro_pos] = []

		(by_position[all_pro_pos] as Array).append({
			"player_id": p.get("player_id", ""),
			"position": all_pro_pos,
			"original_position": position,
			"score": score,
			"team_id": p.get("team_id", "")
		})

	# Sort each position by score
	for pos in by_position.keys():
		var players: Array = by_position[pos]
		players.sort_custom(func(a, b): return a["score"] > b["score"])

	# Select first and second teams
	var first_team := []
	var second_team := []

	for pos in ALL_PRO_ROSTER.keys():
		var count := int(ALL_PRO_ROSTER[pos])
		var players: Array = by_position.get(pos, [])

		# First team: top N
		for i in range(min(count, players.size())):
			first_team.append(players[i])

		# Second team: next N
		for i in range(count, min(count * 2, players.size())):
			second_team.append(players[i])

	return {
		"first_team": first_team,
		"second_team": second_team
	}


## Selects Pro Bowl rosters (AFC and NFC).
##
## Algorithm:
##   1. Split players by conference (AFC/NFC)
##   2. Within each conference, group by position
##   3. Select top N players per position per conference
##   4. Total: 44 AFC + 44 NFC players
##
## Returns:
##   Dictionary with afc and nfc roster arrays
static func select_pro_bowl_rosters(year_stats: Array) -> Dictionary:
	var afc_by_position := {}
	var nfc_by_position := {}

	# Group players by conference and position
	for player_data in year_stats:
		var p: Dictionary = player_data
		var position := String(p.get("position", ""))
		var conference := String(p.get("conference", ""))

		# Map to Pro Bowl position
		var pb_pos := _map_to_pro_bowl_position(position)
		if pb_pos == "":
			continue

		var score := _calculate_overall_score(p)

		var player_entry := {
			"player_id": p.get("player_id", ""),
			"position": pb_pos,
			"original_position": position,
			"conference": conference,
			"score": score,
			"team_id": p.get("team_id", "")
		}

		if conference in AFC_REGIONS:
			if not afc_by_position.has(pb_pos):
				afc_by_position[pb_pos] = []
			(afc_by_position[pb_pos] as Array).append(player_entry)
		elif conference in NFC_REGIONS:
			if not nfc_by_position.has(pb_pos):
				nfc_by_position[pb_pos] = []
			(nfc_by_position[pb_pos] as Array).append(player_entry)

	# Sort each position by score within each conference
	for pos in afc_by_position.keys():
		var players: Array = afc_by_position[pos]
		players.sort_custom(func(a, b): return a["score"] > b["score"])

	for pos in nfc_by_position.keys():
		var players: Array = nfc_by_position[pos]
		players.sort_custom(func(a, b): return a["score"] > b["score"])

	# Select Pro Bowl rosters
	var afc_roster := []
	var nfc_roster := []

	for pos in PRO_BOWL_ROSTER.keys():
		var count := int(PRO_BOWL_ROSTER[pos])

		# AFC selections
		var afc_players: Array = afc_by_position.get(pos, [])
		for i in range(min(count, afc_players.size())):
			afc_roster.append(afc_players[i])

		# NFC selections
		var nfc_players: Array = nfc_by_position.get(pos, [])
		for i in range(min(count, nfc_players.size())):
			nfc_roster.append(nfc_players[i])

	return {
		"afc": afc_roster,
		"nfc": nfc_roster
	}


## PRIVATE HELPER FUNCTIONS


## Builds a mapping from team_id to conference region.
static func _build_team_conference_map(teams: Array) -> Dictionary:
	var mapping := {}
	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		var region := String(t.get("region", ""))
		if team_id != "" and region != "":
			mapping[team_id] = region
	return mapping


## Extracts year-specific stats for all players, enriched with metadata.
##
## Returns: Array of dictionaries with player_id, position, stats, team_id, conference, is_rookie
static func _extract_year_stats(
	player_stats: Dictionary,
	year: int,
	rosters: Dictionary,
	team_to_conference: Dictionary
) -> Array:
	var result := []

	for player_id in player_stats.keys():
		var career: Dictionary = player_stats[player_id]
		if not career.has(year):
			continue

		var stats: Dictionary = career[year]
		var team_id := String(stats.get("team_id", ""))
		var position := String(stats.get("position", ""))
		var conference := String(team_to_conference.get(team_id, ""))

		# Determine if rookie (first year with stats)
		var is_rookie := _is_rookie_year(career, year)

		result.append({
			"player_id": player_id,
			"position": position,
			"stats": stats,
			"team_id": team_id,
			"conference": conference,
			"is_rookie": is_rookie
		})

	return result


## Determines if a given year is a player's rookie year.
##
## Logic: First year with recorded stats in career
static func _is_rookie_year(career_stats: Dictionary, year: int) -> bool:
	var years := []
	for y in career_stats.keys():
		if typeof(y) == TYPE_INT or typeof(y) == TYPE_FLOAT:
			years.append(int(y))
		elif typeof(y) == TYPE_STRING:
			years.append(int(y))

	if years.is_empty():
		return false

	years.sort()
	return int(years[0]) == year


## Calculates offensive player score based on position-specific stats.
##
## Formula varies by position:
##   QB: pass_yards/10 + pass_tds*40 - interceptions*20
##   RB: rush_yards/10 + rush_tds*60 + receptions*5 + rec_yards/10
##   WR/TE: receptions*10 + rec_yards/10 + rec_tds*60
static func _calculate_offensive_score(player: Dictionary) -> float:
	var position := String(player.get("position", ""))
	var stats: Dictionary = player.get("stats", {})

	match position:
		"QB":
			return _score_qb(stats)
		"RB":
			return _score_rb(stats)
		"WR", "TE":
			return _score_receiver(stats)
		_:
			# Default: games played * 10 (minimal contribution)
			return float(stats.get("games_played", 0)) * 10.0

	return 0.0


## Calculates defensive player score based on position-specific stats.
##
## Formula varies by position:
##   DL/EDGE: sacks*50 + tackles_for_loss*30 + tackles*5
##   LB: tackles*10 + sacks*40 + tackles_for_loss*25 + pass_breakups*20
##   CB/S: interceptions*80 + pass_breakups*30 + tackles*5
static func _calculate_defensive_score(player: Dictionary) -> float:
	var position := String(player.get("position", ""))
	var stats: Dictionary = player.get("stats", {})

	match position:
		"DL", "DT", "DE", "EDGE":
			return _score_pass_rusher(stats)
		"LB":
			return _score_linebacker(stats)
		"CB", "S":
			return _score_defensive_back(stats)
		_:
			# Default: games played * 10
			return float(stats.get("games_played", 0)) * 10.0

	return 0.0


## Calculates overall score (used for All-Pro and Pro Bowl).
##
## Uses position-specific scoring but normalized across offense/defense
static func _calculate_overall_score(player: Dictionary) -> float:
	var position := String(player.get("position", ""))

	if position in OFFENSIVE_POSITIONS:
		return _calculate_offensive_score(player)
	elif position in DEFENSIVE_POSITIONS:
		return _calculate_defensive_score(player)
	else:
		# Special teams or unknown
		var stats: Dictionary = player.get("stats", {})
		return float(stats.get("games_played", 0)) * 10.0


## Position-specific scoring functions

static func _score_qb(stats: Dictionary) -> float:
	var pass_yards := float(stats.get("pass_yards", 0))
	var pass_tds := float(stats.get("pass_tds", 0))
	var interceptions := float(stats.get("interceptions", 0))
	var games_played := float(stats.get("games_played", 1))

	# Normalize to per-game basis, then scale up
	var score := (pass_yards / 10.0) + (pass_tds * 40.0) - (interceptions * 20.0)
	return score / games_played * 16.0  # Normalize to 16-game season


static func _score_rb(stats: Dictionary) -> float:
	var rush_yards := float(stats.get("rush_yards", 0))
	var rush_tds := float(stats.get("rush_tds", 0))
	var receptions := float(stats.get("receptions", 0))
	var rec_yards := float(stats.get("receiving_yards", 0))
	var rec_tds := float(stats.get("receiving_tds", 0))
	var games_played := float(stats.get("games_played", 1))

	var score := (rush_yards / 10.0) + (rush_tds * 60.0) + (receptions * 5.0) + (rec_yards / 10.0) + (rec_tds * 60.0)
	return score / games_played * 16.0


static func _score_receiver(stats: Dictionary) -> float:
	var receptions := float(stats.get("receptions", 0))
	var rec_yards := float(stats.get("receiving_yards", 0))
	var rec_tds := float(stats.get("receiving_tds", 0))
	var games_played := float(stats.get("games_played", 1))

	var score := (receptions * 10.0) + (rec_yards / 10.0) + (rec_tds * 60.0)
	return score / games_played * 16.0


static func _score_pass_rusher(stats: Dictionary) -> float:
	var sacks := float(stats.get("sacks", 0))
	var tfl := float(stats.get("tackles_for_loss", 0))
	var tackles := float(stats.get("tackles", 0))
	var games_played := float(stats.get("games_played", 1))

	var score := (sacks * 50.0) + (tfl * 30.0) + (tackles * 5.0)
	return score / games_played * 16.0


static func _score_linebacker(stats: Dictionary) -> float:
	var tackles := float(stats.get("tackles", 0))
	var sacks := float(stats.get("sacks", 0))
	var tfl := float(stats.get("tackles_for_loss", 0))
	var pass_breakups := float(stats.get("pass_breakups", 0))
	var interceptions := float(stats.get("interceptions", 0))
	var games_played := float(stats.get("games_played", 1))

	var score := (tackles * 10.0) + (sacks * 40.0) + (tfl * 25.0) + (pass_breakups * 20.0) + (interceptions * 60.0)
	return score / games_played * 16.0


static func _score_defensive_back(stats: Dictionary) -> float:
	var interceptions := float(stats.get("interceptions", 0))
	var pass_breakups := float(stats.get("pass_breakups", 0))
	var tackles := float(stats.get("tackles", 0))
	var games_played := float(stats.get("games_played", 1))

	var score := (interceptions * 80.0) + (pass_breakups * 30.0) + (tackles * 5.0)
	return score / games_played * 16.0


## Maps specific positions to All-Pro categories.
static func _map_to_all_pro_position(position: String) -> String:
	match position:
		"QB": return "QB"
		"RB": return "RB"
		"WR": return "WR"
		"TE": return "TE"
		"OL", "OT", "OG", "C": return "OL"
		"DL", "DT": return "DL"
		"DE", "EDGE": return "EDGE"
		"LB": return "LB"
		"CB": return "CB"
		"S": return "S"
		"K": return "K"
		"P": return "P"
		_: return ""


## Maps specific positions to Pro Bowl categories.
static func _map_to_pro_bowl_position(position: String) -> String:
	# Pro Bowl uses same mapping as All-Pro
	return _map_to_all_pro_position(position)


## Summarizes key stats for display purposes.
static func _summarize_stats(stats: Dictionary, position: String) -> Dictionary:
	match position:
		"QB":
			return {
				"pass_yards": stats.get("pass_yards", 0),
				"pass_tds": stats.get("pass_tds", 0),
				"interceptions": stats.get("interceptions", 0),
				"games_played": stats.get("games_played", 0)
			}
		"RB":
			return {
				"rush_yards": stats.get("rush_yards", 0),
				"rush_tds": stats.get("rush_tds", 0),
				"receptions": stats.get("receptions", 0),
				"games_played": stats.get("games_played", 0)
			}
		"WR", "TE":
			return {
				"receptions": stats.get("receptions", 0),
				"rec_yards": stats.get("receiving_yards", 0),
				"rec_tds": stats.get("receiving_tds", 0),
				"games_played": stats.get("games_played", 0)
			}
		"DL", "DT", "DE", "EDGE":
			return {
				"sacks": stats.get("sacks", 0),
				"tackles": stats.get("tackles", 0),
				"tackles_for_loss": stats.get("tackles_for_loss", 0),
				"games_played": stats.get("games_played", 0)
			}
		"LB":
			return {
				"tackles": stats.get("tackles", 0),
				"sacks": stats.get("sacks", 0),
				"pass_breakups": stats.get("pass_breakups", 0),
				"games_played": stats.get("games_played", 0)
			}
		"CB", "S":
			return {
				"interceptions": stats.get("interceptions", 0),
				"pass_breakups": stats.get("pass_breakups", 0),
				"tackles": stats.get("tackles", 0),
				"games_played": stats.get("games_played", 0)
			}
		_:
			return {
				"games_played": stats.get("games_played", 0)
			}
