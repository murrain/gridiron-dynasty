extends RefCounted
class_name HallOfFame

## NFL Hall of Fame System
##
## Evaluates retired players for Hall of Fame induction based on career achievements.
## Uses a scoring system that considers awards, statistics, and longevity.
##
## Implements Feature 4: Hall of Fame System
##   - Eligibility checking (retired players only)
##   - HOF score calculation (weighted formula based on career achievements)
##   - Annual inductee selection (top eligible players)
##   - Historical tracking (all inductees by year)
##
## Data Model:
##   world_state["hall_of_fame"] = {
##     "inductees": [
##       {player_id, induction_year, hof_score, career_summary, position},
##       ...
##     ],
##     "eligible_pool": [
##       {player_id, retirement_year, hof_score, position},
##       ...
##     ],
##     "induction_history": {
##       year: [player_id, player_id, ...],
##       ...
##     }
##   }
##
## Eligibility Rules:
##   - Must be retired
##   - Must have played at least 5 NFL seasons
##   - Must have HOF score >= minimum threshold (default 100)
##
## HOF Score Formula (weighted):
##   - OPOY/DPOY: 50 points each
##   - All-Pro First Team: 25 points each
##   - All-Pro Second Team: 15 points each
##   - Pro Bowl: 10 points each
##   - Championships: 30 points each
##   - Career stats: Position-specific bonuses (yards, TDs, sacks, etc.)
##   - Longevity: 5 points per season (up to 15 seasons)
##
## Performance: O(r) where r = retired players (only processes new retirees)
## RNG Pattern: None (pure calculation, deterministic)

## HOF scoring weights
const SCORE_WEIGHTS := {
	"opoy": 50.0,
	"dpoy": 50.0,
	"all_pro_first": 25.0,
	"all_pro_second": 15.0,
	"pro_bowl": 10.0,
	"championships": 30.0,
	"rookie_of_year": 15.0
}

## Career stat thresholds and bonuses (offense)
const CAREER_STAT_BONUSES_OFFENSE := {
	"career_pass_yards": {"threshold": 40000.0, "points_per_10k": 20.0},
	"career_pass_tds": {"threshold": 300.0, "points_per_100": 25.0},
	"career_rush_yards": {"threshold": 10000.0, "points_per_5k": 20.0},
	"career_rush_tds": {"threshold": 80.0, "points_per_50": 25.0},
	"career_receiving_yards": {"threshold": 10000.0, "points_per_5k": 20.0},
	"career_receptions": {"threshold": 700.0, "points_per_500": 15.0},
	"career_receiving_tds": {"threshold": 80.0, "points_per_50": 25.0}
}

## Career stat thresholds and bonuses (defense)
const CAREER_STAT_BONUSES_DEFENSE := {
	"career_sacks": {"threshold": 100.0, "points_per_50": 30.0},
	"career_interceptions": {"threshold": 30.0, "points_per_25": 25.0},
	"career_tackles": {"threshold": 1000.0, "points_per_500": 15.0}
}

## Minimum eligibility requirements
const MIN_SEASONS := 5
const MIN_HOF_SCORE := 100.0

## Maximum inductees per year (to simulate selective HOF process)
const MAX_INDUCTEES_PER_YEAR := 5


## Processes Hall of Fame eligibility and selects new inductees.
##
## This is the main entry point called from NflSeason after retirements.
## Only evaluates newly retired players for efficiency.
##
## Parameters:
##   world_state: Dictionary containing retired_players, player_career_stats
##   year: Current season year (for induction tracking)
##   new_retirees: Array of players who retired this year
##
## Side Effects:
##   - Modifies world_state["hall_of_fame"]
##   - Moves eligible players from pool to inductees
##
## Performance: O(r) where r = new retirees (typically <100 per year)
static func process_hall_of_fame(
	world_state: Dictionary,
	year: int,
	new_retirees: Array
) -> Dictionary:
	var player_stats: Dictionary = world_state.get("player_career_stats", {})

	# Initialize HOF structure if not exists
	if not world_state.has("hall_of_fame"):
		world_state["hall_of_fame"] = {
			"inductees": [],
			"eligible_pool": [],
			"induction_history": {}
		}

	var hof: Dictionary = world_state["hall_of_fame"]
	var inductees: Array = hof.get("inductees", [])
	var eligible_pool: Array = hof.get("eligible_pool", [])
	var induction_history: Dictionary = hof.get("induction_history", {})

	var new_eligible := 0
	var inducted_count := 0

	# Evaluate new retirees for eligibility
	for retiree in new_retirees:
		var p: Dictionary = retiree
		var player_id := String(p.get("id", ""))
		if player_id == "":
			continue

		# Check if already inducted
		if _is_already_inducted(inductees, player_id):
			continue

		# Check eligibility
		if not is_hof_eligible(p, player_stats):
			continue

		# Calculate HOF score
		var hof_score := calculate_hof_score(p, player_stats)

		# Add to eligible pool
		eligible_pool.append({
			"player_id": player_id,
			"retirement_year": int(p.get("retirement_year", year)),
			"hof_score": hof_score,
			"position": String(p.get("position", "")),
			"first_name": String(p.get("first_name", "")),
			"last_name": String(p.get("last_name", ""))
		})
		new_eligible += 1

	# Sort eligible pool by HOF score descending
	eligible_pool.sort_custom(func(a, b): return float(a["hof_score"]) > float(b["hof_score"]))

	# Select top inductees (up to MAX_INDUCTEES_PER_YEAR)
	var year_inductees := []
	var to_remove := []

	for i in range(min(MAX_INDUCTEES_PER_YEAR, eligible_pool.size())):
		var candidate: Dictionary = eligible_pool[i]
		var player_id := String(candidate["player_id"])

		# Create inductee record
		var inductee := {
			"player_id": player_id,
			"induction_year": year,
			"hof_score": float(candidate["hof_score"]),
			"position": String(candidate["position"]),
			"first_name": String(candidate["first_name"]),
			"last_name": String(candidate["last_name"]),
			"career_summary": _build_career_summary(player_id, player_stats)
		}

		inductees.append(inductee)
		year_inductees.append(player_id)
		to_remove.append(candidate)
		inducted_count += 1

	# Remove inducted players from eligible pool
	for candidate in to_remove:
		eligible_pool.erase(candidate)

	# Update induction history
	if inducted_count > 0:
		induction_history[year] = year_inductees

	# Save updated HOF data
	hof["inductees"] = inductees
	hof["eligible_pool"] = eligible_pool
	hof["induction_history"] = induction_history
	world_state["hall_of_fame"] = hof

	return {
		"year": year,
		"new_eligible": new_eligible,
		"inducted": inducted_count,
		"eligible_pool_size": eligible_pool.size(),
		"total_inductees": inductees.size()
	}


## Calculates Hall of Fame score for a player.
##
## Formula combines awards, career stats, and longevity using weighted scoring.
##
## Parameters:
##   player: Dictionary containing player data (career_awards, position, etc.)
##   player_stats: Dictionary mapping player_id -> career stats
##
## Returns: Float HOF score (higher = better candidate)
static func calculate_hof_score(player: Dictionary, player_stats: Dictionary) -> float:
	var score := 0.0
	var player_id := String(player.get("id", ""))
	var position := String(player.get("position", ""))
	var career_awards: Dictionary = player.get("career_awards", {})

	# Award-based scoring
	score += float(career_awards.get("opoy", 0)) * SCORE_WEIGHTS["opoy"]
	score += float(career_awards.get("dpoy", 0)) * SCORE_WEIGHTS["dpoy"]
	score += float(career_awards.get("all_pro_first", 0)) * SCORE_WEIGHTS["all_pro_first"]
	score += float(career_awards.get("all_pro_second", 0)) * SCORE_WEIGHTS["all_pro_second"]
	score += float(career_awards.get("pro_bowl", 0)) * SCORE_WEIGHTS["pro_bowl"]
	score += float(career_awards.get("championships", 0)) * SCORE_WEIGHTS["championships"]
	score += float(career_awards.get("rookie_of_year", 0)) * SCORE_WEIGHTS["rookie_of_year"]

	# Career stat bonuses
	var career_data: Dictionary = player_stats.get(player_id, {})
	var career_totals := _aggregate_career_stats(career_data)

	# Position-specific stat bonuses
	if position in ["QB", "RB", "WR", "TE"]:
		score += _calculate_offensive_stat_bonus(career_totals, position)
	elif position in ["DL", "DT", "DE", "EDGE", "LB", "CB", "S"]:
		score += _calculate_defensive_stat_bonus(career_totals, position)

	# Longevity bonus (5 points per season, capped at 15 seasons)
	var seasons := int(career_totals.get("seasons", 0))
	score += min(seasons, 15) * 5.0

	return score


## Checks if a player is eligible for Hall of Fame consideration.
##
## Eligibility Requirements:
##   - Must be retired
##   - Must have played at least MIN_SEASONS (default 5)
##   - Must have HOF score >= MIN_HOF_SCORE (default 100)
##
## Parameters:
##   player: Dictionary containing player data
##   player_stats: Dictionary mapping player_id -> career stats
##
## Returns: true if player meets eligibility requirements
static func is_hof_eligible(player: Dictionary, player_stats: Dictionary) -> bool:
	var player_id := String(player.get("id", ""))
	var career_data: Dictionary = player_stats.get(player_id, {})

	# Check minimum seasons
	var career_totals := _aggregate_career_stats(career_data)
	var seasons := int(career_totals.get("seasons", 0))
	if seasons < MIN_SEASONS:
		return false

	# Check minimum HOF score
	var hof_score := calculate_hof_score(player, player_stats)
	if hof_score < MIN_HOF_SCORE:
		return false

	return true


## Selects inductees from the eligible pool for a given year.
##
## This is called internally by process_hall_of_fame() after eligibility checks.
## Selects up to MAX_INDUCTEES_PER_YEAR based on HOF score ranking.
##
## Parameters:
##   eligible_pool: Array of eligible players sorted by HOF score
##   max_inductees: Maximum number of players to induct this year
##
## Returns: Array of player_ids to be inducted
static func select_inductees(eligible_pool: Array, max_inductees: int) -> Array:
	var inductees := []

	for i in range(min(max_inductees, eligible_pool.size())):
		var candidate: Dictionary = eligible_pool[i]
		inductees.append(String(candidate["player_id"]))

	return inductees


## PRIVATE HELPER FUNCTIONS


## Checks if a player is already inducted into Hall of Fame.
static func _is_already_inducted(inductees: Array, player_id: String) -> bool:
	for inductee in inductees:
		var i: Dictionary = inductee
		if String(i.get("player_id", "")) == player_id:
			return true
	return false


## Aggregates career statistics across all seasons.
static func _aggregate_career_stats(career_data: Dictionary) -> Dictionary:
	var totals := {
		"career_pass_yards": 0.0,
		"career_pass_tds": 0.0,
		"career_rush_yards": 0.0,
		"career_rush_tds": 0.0,
		"career_receptions": 0.0,
		"career_receiving_yards": 0.0,
		"career_receiving_tds": 0.0,
		"career_tackles": 0.0,
		"career_sacks": 0.0,
		"career_interceptions": 0.0,
		"career_games_played": 0.0,
		"seasons": 0
	}

	var season_count := 0
	for year_key in career_data.keys():
		# Skip non-numeric keys
		if not (typeof(year_key) == TYPE_INT or typeof(year_key) == TYPE_FLOAT or typeof(year_key) == TYPE_STRING):
			continue

		var season_stats: Dictionary = career_data[year_key]
		if not season_stats is Dictionary:
			continue

		season_count += 1

		# Accumulate stats
		totals["career_pass_yards"] += float(season_stats.get("pass_yards", 0.0))
		totals["career_pass_tds"] += float(season_stats.get("pass_tds", 0.0))
		totals["career_rush_yards"] += float(season_stats.get("rush_yards", 0.0))
		totals["career_rush_tds"] += float(season_stats.get("rush_tds", 0.0))
		totals["career_receptions"] += float(season_stats.get("receptions", 0.0))
		totals["career_receiving_yards"] += float(season_stats.get("receiving_yards", 0.0))
		totals["career_receiving_tds"] += float(season_stats.get("receiving_tds", 0.0))
		totals["career_tackles"] += float(season_stats.get("tackles", 0.0))
		totals["career_sacks"] += float(season_stats.get("sacks", 0.0))
		totals["career_interceptions"] += float(season_stats.get("interceptions", 0.0))
		totals["career_games_played"] += float(season_stats.get("games_played", 0.0))

	totals["seasons"] = season_count
	return totals


## Calculates offensive stat bonus for HOF score.
static func _calculate_offensive_stat_bonus(career_totals: Dictionary, position: String) -> float:
	var bonus := 0.0

	match position:
		"QB":
			var pass_yards := float(career_totals.get("career_pass_yards", 0.0))
			if pass_yards >= CAREER_STAT_BONUSES_OFFENSE["career_pass_yards"]["threshold"]:
				bonus += (pass_yards / 10000.0) * CAREER_STAT_BONUSES_OFFENSE["career_pass_yards"]["points_per_10k"]

			var pass_tds := float(career_totals.get("career_pass_tds", 0.0))
			if pass_tds >= CAREER_STAT_BONUSES_OFFENSE["career_pass_tds"]["threshold"]:
				bonus += (pass_tds / 100.0) * CAREER_STAT_BONUSES_OFFENSE["career_pass_tds"]["points_per_100"]

		"RB":
			var rush_yards := float(career_totals.get("career_rush_yards", 0.0))
			if rush_yards >= CAREER_STAT_BONUSES_OFFENSE["career_rush_yards"]["threshold"]:
				bonus += (rush_yards / 5000.0) * CAREER_STAT_BONUSES_OFFENSE["career_rush_yards"]["points_per_5k"]

			var rush_tds := float(career_totals.get("career_rush_tds", 0.0))
			if rush_tds >= CAREER_STAT_BONUSES_OFFENSE["career_rush_tds"]["threshold"]:
				bonus += (rush_tds / 50.0) * CAREER_STAT_BONUSES_OFFENSE["career_rush_tds"]["points_per_50"]

		"WR", "TE":
			var rec_yards := float(career_totals.get("career_receiving_yards", 0.0))
			if rec_yards >= CAREER_STAT_BONUSES_OFFENSE["career_receiving_yards"]["threshold"]:
				bonus += (rec_yards / 5000.0) * CAREER_STAT_BONUSES_OFFENSE["career_receiving_yards"]["points_per_5k"]

			var receptions := float(career_totals.get("career_receptions", 0.0))
			if receptions >= CAREER_STAT_BONUSES_OFFENSE["career_receptions"]["threshold"]:
				bonus += (receptions / 500.0) * CAREER_STAT_BONUSES_OFFENSE["career_receptions"]["points_per_500"]

			var rec_tds := float(career_totals.get("career_receiving_tds", 0.0))
			if rec_tds >= CAREER_STAT_BONUSES_OFFENSE["career_receiving_tds"]["threshold"]:
				bonus += (rec_tds / 50.0) * CAREER_STAT_BONUSES_OFFENSE["career_receiving_tds"]["points_per_50"]

	return bonus


## Calculates defensive stat bonus for HOF score.
static func _calculate_defensive_stat_bonus(career_totals: Dictionary, position: String) -> float:
	var bonus := 0.0

	match position:
		"DL", "DT", "DE", "EDGE":
			var sacks := float(career_totals.get("career_sacks", 0.0))
			if sacks >= CAREER_STAT_BONUSES_DEFENSE["career_sacks"]["threshold"]:
				bonus += (sacks / 50.0) * CAREER_STAT_BONUSES_DEFENSE["career_sacks"]["points_per_50"]

		"CB", "S":
			var ints := float(career_totals.get("career_interceptions", 0.0))
			if ints >= CAREER_STAT_BONUSES_DEFENSE["career_interceptions"]["threshold"]:
				bonus += (ints / 25.0) * CAREER_STAT_BONUSES_DEFENSE["career_interceptions"]["points_per_25"]

		"LB":
			var tackles := float(career_totals.get("career_tackles", 0.0))
			if tackles >= CAREER_STAT_BONUSES_DEFENSE["career_tackles"]["threshold"]:
				bonus += (tackles / 500.0) * CAREER_STAT_BONUSES_DEFENSE["career_tackles"]["points_per_500"]

			var sacks := float(career_totals.get("career_sacks", 0.0))
			if sacks >= CAREER_STAT_BONUSES_DEFENSE["career_sacks"]["threshold"]:
				bonus += (sacks / 50.0) * CAREER_STAT_BONUSES_DEFENSE["career_sacks"]["points_per_50"]

	return bonus


## Builds a career summary for display purposes.
static func _build_career_summary(player_id: String, player_stats: Dictionary) -> Dictionary:
	var career_data: Dictionary = player_stats.get(player_id, {})
	var totals := _aggregate_career_stats(career_data)

	return {
		"seasons": int(totals.get("seasons", 0)),
		"games_played": int(totals.get("career_games_played", 0)),
		"pass_yards": float(totals.get("career_pass_yards", 0.0)),
		"pass_tds": float(totals.get("career_pass_tds", 0.0)),
		"rush_yards": float(totals.get("career_rush_yards", 0.0)),
		"rush_tds": float(totals.get("career_rush_tds", 0.0)),
		"receptions": float(totals.get("career_receptions", 0.0)),
		"receiving_yards": float(totals.get("career_receiving_yards", 0.0)),
		"receiving_tds": float(totals.get("career_receiving_tds", 0.0)),
		"tackles": float(totals.get("career_tackles", 0.0)),
		"sacks": float(totals.get("career_sacks", 0.0)),
		"interceptions": float(totals.get("career_interceptions", 0.0))
	}


## QUERY FUNCTIONS


## Gets all Hall of Fame inductees.
static func get_all_inductees(world_state: Dictionary) -> Array:
	var hof: Dictionary = world_state.get("hall_of_fame", {})
	return hof.get("inductees", [])


## Gets inductees for a specific year.
static func get_inductees_by_year(world_state: Dictionary, year: int) -> Array:
	var hof: Dictionary = world_state.get("hall_of_fame", {})
	var history: Dictionary = hof.get("induction_history", {})
	return history.get(year, [])


## Checks if a player is in the Hall of Fame.
static func is_in_hall_of_fame(world_state: Dictionary, player_id: String) -> bool:
	var inductees: Array = get_all_inductees(world_state)
	return _is_already_inducted(inductees, player_id)


## Gets HOF score for a player (even if not inducted).
static func get_player_hof_score(player: Dictionary, player_stats: Dictionary) -> float:
	return calculate_hof_score(player, player_stats)
