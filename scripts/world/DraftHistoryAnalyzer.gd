## DraftHistoryAnalyzer - Stateless service for analyzing historical drafts
##
## ARCHITECTURAL PATTERN: Stateless RefCounted Service
##
## This service provides retrospective analysis of past drafts, including:
## - Draft class performance over time
## - Bust identification (high picks who failed)
## - Steal identification (late picks who excelled)
## - Round-by-round success rates
## - Best/worst pick identification
##
## Analysis Criteria:
## - Bust: Drafted in top 50, but <2 years as starter OR out of league
## - Steal: Drafted after pick 100, but Pro Bowler OR 5+ year starter
## - Best pick: Highest career value relative to draft position
## - Worst pick: Lowest career value relative to draft position
##
## RNG Usage: None - all analysis is fully deterministic
##
## Usage:
##   var analysis = DraftHistoryAnalyzer.analyze_draft_class(
##       2033, 2036, world_state, positions_cfg
##   )
##
extends RefCounted
class_name DraftHistoryAnalyzer

const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

# Analysis thresholds
const BUST_PICK_THRESHOLD := 50      # Top 50 picks are "high picks"
const STEAL_PICK_THRESHOLD := 100    # Picks after 100 are "late picks"
const STARTER_YEARS_FOR_SUCCESS := 2 # Min years as starter to avoid bust label
const STARTER_YEARS_FOR_STEAL := 5   # Min years as starter for steal (if no Pro Bowl)
const MIN_YEARS_FOR_ANALYSIS := 3    # Need at least 3 years of data for meaningful analysis


## Analyze a draft class with hindsight
##
## @param draft_year: Year of the draft to analyze
## @param current_year: Current year (for elapsed time calculation)
## @param world_state: Full world state dictionary
## @param positions_cfg: Position configuration
## @return: Analysis dictionary with all metrics
static func analyze_draft_class(
	draft_year: int,
	current_year: int,
	world_state: Dictionary,
	positions_cfg: Dictionary
) -> Dictionary:
	var draft_history: Dictionary = world_state.get("draft_history", {})
	var draft_picks: Array = draft_history.get(draft_year, draft_history.get(str(draft_year), []))

	if draft_picks.is_empty():
		return {"error": "Draft year %d not found in history" % draft_year}

	var years_elapsed := current_year - draft_year

	if years_elapsed < 0:
		return {"error": "Draft year %d is in the future" % draft_year}

	# Get current status of all drafted players
	var players_status := _get_players_current_status(draft_picks, world_state)

	# Calculate various metrics
	var pro_bowlers := _count_pro_bowlers(players_status)
	var all_pros := _count_all_pros(players_status)
	var active_count := _count_active(players_status)
	var retired_count := _count_retired(players_status)

	var busts := _identify_busts(draft_picks, players_status)
	var steals := _identify_steals(draft_picks, players_status)
	var best_pick := _find_best_pick(draft_picks, players_status)
	var worst_pick := _find_worst_pick(draft_picks, players_status)
	var round_breakdown := _analyze_by_round(draft_picks, players_status)

	return {
		"year": draft_year,
		"years_elapsed": years_elapsed,
		"total_picks": draft_picks.size(),
		"analysis_complete": years_elapsed >= MIN_YEARS_FOR_ANALYSIS,

		# Accolades
		"pro_bowlers": pro_bowlers,
		"all_pros": all_pros,

		# Player status
		"active_players": active_count,
		"retired_players": retired_count,

		# Highlights
		"busts": busts,
		"steals": steals,
		"best_pick": best_pick,
		"worst_pick": worst_pick,

		# Breakdown
		"round_breakdown": round_breakdown,

		# Raw data for UI
		"picks": draft_picks,
		"players_status": players_status
	}


## Get current status of all drafted players
##
## Searches world state to find each player's current status,
## accolades, and career achievements.
static func _get_players_current_status(
	draft_picks: Array,
	world_state: Dictionary
) -> Dictionary:
	var status_map: Dictionary = {}

	for pick in draft_picks:
		var p: Dictionary = pick
		var player_id := String(p.get("player_id", ""))

		if player_id.is_empty():
			continue

		# Find player in current rosters or retired list
		var player_data := _find_player_in_world(player_id, world_state)

		status_map[player_id] = {
			"draft_pick": int(p.get("pick", 0)),
			"draft_round": int(p.get("round", 0)),
			"position": String(p.get("position", "")),
			"player_name": String(p.get("player_name", "")),
			"current_data": player_data,
			"is_active": player_data.get("nfl_status", "") == "active",
			"is_retired": player_data.get("nfl_status", "") == "retired",
			"pro_bowls": _count_accolades(player_data, "pro_bowl"),
			"all_pros": _count_accolades(player_data, "all_pro"),
			"years_as_starter": _count_starter_years(player_data),
			"career_games": int(player_data.get("career_games", 0)),
			"career_value": _calculate_career_value(player_data)
		}

	return status_map


## Find a player in the world state
##
## Searches active rosters, practice squads, and retired players.
static func _find_player_in_world(
	player_id: String,
	world_state: Dictionary
) -> Dictionary:
	# Search active rosters
	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id]
		var players: Array = roster.get("players", [])
		for player in players:
			var p: Dictionary = player
			var pid := String(p.get("player_id", p.get("id", "")))
			if pid == player_id:
				return p

	# Search retired players
	var retired: Array = world_state.get("retired_players", [])
	for player in retired:
		var p: Dictionary = player
		var pid := String(p.get("player_id", p.get("id", "")))
		if pid == player_id:
			return p

	# Search free agents
	var free_agents: Array = world_state.get("nfl_free_agents", [])
	for player in free_agents:
		var p: Dictionary = player
		var pid := String(p.get("player_id", p.get("id", "")))
		if pid == player_id:
			return p

	# Not found - return empty with unknown status
	return {"nfl_status": "unknown"}


## Count accolades of a specific type
static func _count_accolades(player_data: Dictionary, accolade_type: String) -> int:
	var accolades: Array = player_data.get("accolades", [])
	var count := 0
	for accolade in accolades:
		var a: Dictionary = accolade
		if String(a.get("type", "")) == accolade_type:
			count += 1
	return count


## Count years as starter
static func _count_starter_years(player_data: Dictionary) -> int:
	# Check for explicit starter years tracking
	if player_data.has("starter_years"):
		return int(player_data.get("starter_years", 0))

	# Estimate from career stats if available
	var career_starts := int(player_data.get("career_starts", 0))
	if career_starts > 0:
		# Assume ~16 starts per year as starter
		return career_starts / 16

	# Fallback: estimate from games played
	var games := int(player_data.get("career_games", 0))
	if games > 0:
		# Rough estimate: if played 10+ games per year, count as starter year
		var seasons := games / 17
		var avg_games := float(games) / float(max(seasons, 1))
		if avg_games >= 10.0:
			return seasons

	return 0


## Calculate career value score
##
## Combines various career achievements into a single value.
static func _calculate_career_value(player_data: Dictionary) -> float:
	var value := 0.0

	# Pro Bowls (high value)
	value += float(_count_accolades(player_data, "pro_bowl")) * 10.0

	# All-Pro (very high value)
	value += float(_count_accolades(player_data, "all_pro")) * 25.0

	# Starter years
	value += float(_count_starter_years(player_data)) * 3.0

	# Career games (longevity)
	value += float(player_data.get("career_games", 0)) * 0.1

	# Current overall rating (if still active)
	if player_data.get("nfl_status", "") == "active":
		var overall := float(player_data.get("composite_score", player_data.get("overall", 0)))
		value += (overall - 50.0) * 0.5  # Bonus for above-average players

	return value


## Count Pro Bowlers
static func _count_pro_bowlers(players_status: Dictionary) -> int:
	var count := 0
	for player_id in players_status.keys():
		var status: Dictionary = players_status[player_id]
		if int(status.get("pro_bowls", 0)) > 0:
			count += 1
	return count


## Count All-Pros
static func _count_all_pros(players_status: Dictionary) -> int:
	var count := 0
	for player_id in players_status.keys():
		var status: Dictionary = players_status[player_id]
		if int(status.get("all_pros", 0)) > 0:
			count += 1
	return count


## Count active players
static func _count_active(players_status: Dictionary) -> int:
	var count := 0
	for player_id in players_status.keys():
		var status: Dictionary = players_status[player_id]
		if bool(status.get("is_active", false)):
			count += 1
	return count


## Count retired players
static func _count_retired(players_status: Dictionary) -> int:
	var count := 0
	for player_id in players_status.keys():
		var status: Dictionary = players_status[player_id]
		if bool(status.get("is_retired", false)):
			count += 1
	return count


## Identify busts (high picks who failed)
##
## Bust criteria:
## - Drafted in top 50
## - Less than 2 years as starter OR out of league within 3 years
static func _identify_busts(
	draft_picks: Array,
	players_status: Dictionary
) -> Array:
	var busts: Array = []

	for pick in draft_picks:
		var p: Dictionary = pick
		var player_id := String(p.get("player_id", ""))
		var pick_number := int(p.get("pick", 0))

		if pick_number > BUST_PICK_THRESHOLD:
			continue  # Only high picks can be busts

		var status: Dictionary = players_status.get(player_id, {})
		var starter_years := int(status.get("years_as_starter", 0))
		var is_retired := bool(status.get("is_retired", false))

		# Bust if: never became starter OR out of league quickly
		if starter_years < STARTER_YEARS_FOR_SUCCESS or is_retired:
			var reason := "Out of league" if is_retired else "Never became starter"
			busts.append({
				"player_id": player_id,
				"player_name": String(p.get("player_name", "")),
				"pick": pick_number,
				"round": int(p.get("round", 0)),
				"position": String(p.get("position", "")),
				"reason": reason,
				"starter_years": starter_years
			})

	# Sort by pick number (highest picks first = worst busts)
	busts.sort_custom(func(a, b):
		return int(a.get("pick", 999)) < int(b.get("pick", 999))
	)

	return busts


## Identify steals (late picks who excelled)
##
## Steal criteria:
## - Drafted after pick 100
## - Made Pro Bowl OR 5+ years as starter
static func _identify_steals(
	draft_picks: Array,
	players_status: Dictionary
) -> Array:
	var steals: Array = []

	for pick in draft_picks:
		var p: Dictionary = pick
		var player_id := String(p.get("player_id", ""))
		var pick_number := int(p.get("pick", 0))

		if pick_number <= STEAL_PICK_THRESHOLD:
			continue  # Only late picks can be steals

		var status: Dictionary = players_status.get(player_id, {})
		var pro_bowls := int(status.get("pro_bowls", 0))
		var starter_years := int(status.get("years_as_starter", 0))

		if pro_bowls > 0 or starter_years >= STARTER_YEARS_FOR_STEAL:
			var achievement := "%d Pro Bowls" % pro_bowls if pro_bowls > 0 else "%d years as starter" % starter_years
			steals.append({
				"player_id": player_id,
				"player_name": String(p.get("player_name", "")),
				"pick": pick_number,
				"round": int(p.get("round", 0)),
				"position": String(p.get("position", "")),
				"achievement": achievement,
				"career_value": float(status.get("career_value", 0))
			})

	# Sort by career value (highest first)
	steals.sort_custom(func(a, b):
		return float(a.get("career_value", 0)) > float(b.get("career_value", 0))
	)

	return steals


## Find the best pick (highest value relative to draft position)
static func _find_best_pick(
	draft_picks: Array,
	players_status: Dictionary
) -> Dictionary:
	var best: Dictionary = {}
	var best_value := -999.0

	for pick in draft_picks:
		var p: Dictionary = pick
		var player_id := String(p.get("player_id", ""))
		var pick_number := int(p.get("pick", 0))

		var status: Dictionary = players_status.get(player_id, {})
		var career_value := float(status.get("career_value", 0))

		# Value relative to draft position (late picks get bonus)
		var position_bonus := float(pick_number) * 0.1
		var relative_value := career_value + position_bonus

		if relative_value > best_value:
			best_value = relative_value
			best = {
				"player_id": player_id,
				"player_name": String(p.get("player_name", "")),
				"pick": pick_number,
				"round": int(p.get("round", 0)),
				"position": String(p.get("position", "")),
				"career_value": career_value,
				"relative_value": relative_value
			}

	return best


## Find the worst pick (lowest value relative to draft position)
static func _find_worst_pick(
	draft_picks: Array,
	players_status: Dictionary
) -> Dictionary:
	var worst: Dictionary = {}
	var worst_value := 999.0

	for pick in draft_picks:
		var p: Dictionary = pick
		var player_id := String(p.get("player_id", ""))
		var pick_number := int(p.get("pick", 0))

		var status: Dictionary = players_status.get(player_id, {})
		var career_value := float(status.get("career_value", 0))

		# Value relative to draft position (high picks have higher expectations)
		var position_penalty := float(262 - pick_number) * 0.1
		var relative_value := career_value - position_penalty

		if relative_value < worst_value:
			worst_value = relative_value
			worst = {
				"player_id": player_id,
				"player_name": String(p.get("player_name", "")),
				"pick": pick_number,
				"round": int(p.get("round", 0)),
				"position": String(p.get("position", "")),
				"career_value": career_value,
				"relative_value": relative_value
			}

	return worst


## Analyze draft by round
static func _analyze_by_round(
	draft_picks: Array,
	players_status: Dictionary
) -> Dictionary:
	var by_round: Dictionary = {}

	for round_num in range(1, 8):
		var round_picks := draft_picks.filter(func(p):
			return int((p as Dictionary).get("round", 0)) == round_num
		)

		var starters := 0
		var pro_bowls := 0
		var all_pros := 0
		var total_career_value := 0.0

		for pick in round_picks:
			var player_id := String((pick as Dictionary).get("player_id", ""))
			var status: Dictionary = players_status.get(player_id, {})

			if int(status.get("years_as_starter", 0)) >= 3:
				starters += 1
			pro_bowls += int(status.get("pro_bowls", 0))
			all_pros += int(status.get("all_pros", 0))
			total_career_value += float(status.get("career_value", 0))

		var avg_value := total_career_value / float(max(round_picks.size(), 1))

		by_round["round_%d" % round_num] = {
			"total_picks": round_picks.size(),
			"starters": starters,
			"pro_bowls": pro_bowls,
			"all_pros": all_pros,
			"avg_career_value": avg_value,
			"success_rate": float(starters) / float(max(round_picks.size(), 1)) * 100.0
		}

	return by_round


## Get available draft years for analysis
static func get_available_draft_years(world_state: Dictionary) -> Array:
	var draft_history: Dictionary = world_state.get("draft_history", {})
	var years: Array = []

	for key in draft_history.keys():
		var year := int(key) if key is int else int(str(key))
		years.append(year)

	years.sort()
	return years


## Get draft summary for a specific team
static func get_team_draft_summary(
	team_id: String,
	draft_year: int,
	world_state: Dictionary,
	positions_cfg: Dictionary
) -> Dictionary:
	var analysis := analyze_draft_class(
		draft_year,
		int(world_state.get("current_year", draft_year + 1)),
		world_state,
		positions_cfg
	)

	if analysis.has("error"):
		return analysis

	var picks: Array = analysis.get("picks", [])
	var team_picks := picks.filter(func(p):
		return String((p as Dictionary).get("team_id", "")) == team_id
	)

	var players_status: Dictionary = analysis.get("players_status", {})

	# Calculate team-specific metrics
	var team_pro_bowls := 0
	var team_starters := 0
	var team_value := 0.0

	for pick in team_picks:
		var player_id := String((pick as Dictionary).get("player_id", ""))
		var status: Dictionary = players_status.get(player_id, {})
		team_pro_bowls += int(status.get("pro_bowls", 0))
		if int(status.get("years_as_starter", 0)) >= 2:
			team_starters += 1
		team_value += float(status.get("career_value", 0))

	return {
		"team_id": team_id,
		"year": draft_year,
		"picks_count": team_picks.size(),
		"pro_bowls": team_pro_bowls,
		"starters": team_starters,
		"total_career_value": team_value,
		"avg_pick_value": team_value / float(max(team_picks.size(), 1)),
		"picks": team_picks
	}


## Compare multiple draft classes
static func compare_draft_classes(
	years: Array,
	world_state: Dictionary,
	positions_cfg: Dictionary
) -> Dictionary:
	var comparisons: Array = []
	var current_year := int(world_state.get("current_year", 2035))

	for year in years:
		var analysis := analyze_draft_class(
			int(year), current_year, world_state, positions_cfg
		)

		if not analysis.has("error"):
			comparisons.append({
				"year": int(year),
				"pro_bowlers": analysis.get("pro_bowlers", 0),
				"all_pros": analysis.get("all_pros", 0),
				"busts": (analysis.get("busts", []) as Array).size(),
				"steals": (analysis.get("steals", []) as Array).size()
			})

	# Sort by year
	comparisons.sort_custom(func(a, b):
		return int(a.get("year", 0)) < int(b.get("year", 0))
	)

	# Find best/worst class
	var best_class: Dictionary = {}
	var worst_class: Dictionary = {}
	var best_score := -999.0
	var worst_score := 999.0

	for comp in comparisons:
		var c: Dictionary = comp
		var score := float(c.get("pro_bowlers", 0)) * 10.0 + float(c.get("all_pros", 0)) * 25.0
		if score > best_score:
			best_score = score
			best_class = c
		if score < worst_score:
			worst_score = score
			worst_class = c

	return {
		"comparisons": comparisons,
		"best_class": best_class,
		"worst_class": worst_class
	}
