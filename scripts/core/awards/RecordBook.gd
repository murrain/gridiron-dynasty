extends RefCounted
class_name RecordBook

## NFL Record Book - League-wide Statistical Records
##
## Tracks single-season and career records across all statistical categories.
## This system enables historical comparison and identifies statistical excellence.
##
## Implements Feature 2: League Records Tracking
##   - Single-season records (per statistical category per year)
##   - Career records (all-time leaders per statistical category)
##   - Record checking and updating (check_record())
##   - Historical tracking (who held the record, when broken)
##
## Data Model:
##   world_state["league_records"] = {
##     "single_season": {
##       "pass_yards": {value, player_id, year, player_name, team_id},
##       "rush_yards": {value, player_id, year, player_name, team_id},
##       ...
##     },
##     "career": {
##       "pass_yards": {value, player_id, player_name, years_active},
##       "career_sacks": {value, player_id, player_name, years_active},
##       ...
##     },
##     "history": [
##       {record_type, category, old_value, new_value, player_id, year, broken_date}
##     ]
##   }
##
## Performance: O(k) where k = number of stat categories (~50)
## RNG Pattern: None (pure comparison and aggregation)

## Offensive single-season record categories
const SINGLE_SEASON_OFFENSE := [
	"pass_yards",
	"pass_tds",
	"pass_completions",
	"pass_attempts",
	"rush_yards",
	"rush_tds",
	"rush_attempts",
	"receptions",
	"receiving_yards",
	"receiving_tds",
	"total_yards",  # rush + receiving
	"total_tds"     # rush + receiving + pass
]

## Defensive single-season record categories
const SINGLE_SEASON_DEFENSE := [
	"tackles",
	"sacks",
	"tackles_for_loss",
	"interceptions",
	"pass_breakups",
	"forced_fumbles",
	"fumble_recoveries",
	"defensive_tds"
]

## Career record categories (aggregated over entire career)
## Note: Career records use player_career_stats aggregation
const CAREER_CATEGORIES := [
	# Offense
	"career_pass_yards",
	"career_pass_tds",
	"career_rush_yards",
	"career_rush_tds",
	"career_receptions",
	"career_receiving_yards",
	"career_receiving_tds",
	# Defense
	"career_tackles",
	"career_sacks",
	"career_interceptions",
	"career_pass_breakups",
	# Longevity
	"career_games_played",
	"career_seasons"
]


## Updates league records based on current season statistics.
##
## This is the main entry point called from NflSeason after stat accumulation.
## Checks all single-season records for the current year and updates career records.
##
## Parameters:
##   world_state: Dictionary containing player_career_stats, nfl_rosters
##   year: Current season year
##
## Side Effects:
##   - Modifies world_state["league_records"]
##   - Appends to world_state["league_records"]["history"] when records broken
##
## Performance: O(n × k) where n = active players, k = stat categories
static func update_records(world_state: Dictionary, year: int) -> Dictionary:
	var player_stats: Dictionary = world_state.get("player_career_stats", {})
	var rosters: Dictionary = world_state.get("nfl_rosters", {})

	if player_stats.is_empty():
		return {"records_checked": 0, "records_broken": 0}

	# Initialize record book if not exists
	if not world_state.has("league_records"):
		world_state["league_records"] = {
			"single_season": {},
			"career": {},
			"history": []
		}

	var records: Dictionary = world_state["league_records"]
	var single_season: Dictionary = records.get("single_season", {})
	var career: Dictionary = records.get("career", {})
	var history: Array = records.get("history", [])

	var records_checked := 0
	var records_broken := 0

	# Build player name lookup (for record display)
	var player_names := _build_player_name_map(rosters)

	# Check single-season records for current year
	for player_id in player_stats.keys():
		var career_data: Dictionary = player_stats[player_id]
		if not career_data.has(year):
			continue

		var season_stats: Dictionary = career_data[year]
		var team_id := String(season_stats.get("team_id", ""))
		var player_name := String(player_names.get(player_id, "Unknown Player"))

		# Check offensive records
		for category in SINGLE_SEASON_OFFENSE:
			records_checked += 1
			var value := _extract_stat_value(season_stats, category)
			if _is_new_record(single_season, category, value):
				_set_record(single_season, category, {
					"value": value,
					"player_id": player_id,
					"player_name": player_name,
					"team_id": team_id,
					"year": year
				}, history, "single_season")
				records_broken += 1

		# Check defensive records
		for category in SINGLE_SEASON_DEFENSE:
			records_checked += 1
			var value := _extract_stat_value(season_stats, category)
			if _is_new_record(single_season, category, value):
				_set_record(single_season, category, {
					"value": value,
					"player_id": player_id,
					"player_name": player_name,
					"team_id": team_id,
					"year": year
				}, history, "single_season")
				records_broken += 1

	# Update career records (aggregate across all years)
	for player_id in player_stats.keys():
		var career_data: Dictionary = player_stats[player_id]
		var player_name := String(player_names.get(player_id, "Unknown Player"))

		# Aggregate career totals
		var career_totals := _aggregate_career_stats(career_data)

		# Check each career category
		for category in CAREER_CATEGORIES:
			records_checked += 1
			var value := float(career_totals.get(category, 0.0))
			if _is_new_record(career, category, value):
				_set_record(career, category, {
					"value": value,
					"player_id": player_id,
					"player_name": player_name,
					"years_active": career_totals.get("seasons", 0)
				}, history, "career")
				records_broken += 1

	# Update world_state
	records["single_season"] = single_season
	records["career"] = career
	records["history"] = history
	world_state["league_records"] = records

	return {
		"records_checked": records_checked,
		"records_broken": records_broken,
		"year": year
	}


## Checks if a value breaks an existing record.
##
## Parameters:
##   record_category: Dictionary containing current records
##   stat_name: Name of statistical category
##   value: New value to check
##
## Returns: true if value exceeds current record (or no record exists)
static func _is_new_record(record_category: Dictionary, stat_name: String, value: float) -> bool:
	if not record_category.has(stat_name):
		return value > 0.0  # First record must be positive

	var current_record: Dictionary = record_category[stat_name]
	var current_value := float(current_record.get("value", 0.0))
	return value > current_value


## Sets a new record and logs it to history.
##
## Parameters:
##   record_category: Dictionary to store record in
##   stat_name: Name of statistical category
##   record_data: Dictionary containing value, player_id, and metadata
##   history: Array to append record-breaking event to
##   record_type: "single_season" or "career"
static func _set_record(
	record_category: Dictionary,
	stat_name: String,
	record_data: Dictionary,
	history: Array,
	record_type: String
) -> void:
	# Get old record for history tracking
	var old_value := 0.0
	var old_player := ""
	if record_category.has(stat_name):
		var old_record: Dictionary = record_category[stat_name]
		old_value = float(old_record.get("value", 0.0))
		old_player = String(old_record.get("player_id", ""))

	# Set new record
	record_category[stat_name] = record_data

	# Log to history
	history.append({
		"record_type": record_type,
		"category": stat_name,
		"old_value": old_value,
		"old_player_id": old_player,
		"new_value": float(record_data.get("value", 0.0)),
		"new_player_id": String(record_data.get("player_id", "")),
		"new_player_name": String(record_data.get("player_name", "")),
		"year": int(record_data.get("year", 0)),
		"timestamp": Time.get_unix_time_from_system()
	})


## Extracts stat value, handling composite categories.
##
## Composite categories:
##   - total_yards = rush_yards + receiving_yards
##   - total_tds = rush_tds + receiving_tds + pass_tds
##
## Parameters:
##   stats: Dictionary of player stats for a season
##   category: Statistical category name
##
## Returns: Float value for the category
static func _extract_stat_value(stats: Dictionary, category: String) -> float:
	match category:
		"total_yards":
			var rush := float(stats.get("rush_yards", 0.0))
			var rec := float(stats.get("receiving_yards", 0.0))
			return rush + rec
		"total_tds":
			var rush := float(stats.get("rush_tds", 0.0))
			var rec := float(stats.get("receiving_tds", 0.0))
			var passing := float(stats.get("pass_tds", 0.0))
			return rush + rec + passing
		_:
			return float(stats.get(category, 0.0))


## Aggregates career statistics across all seasons.
##
## Parameters:
##   career_data: Dictionary mapping year -> season_stats
##
## Returns: Dictionary with career totals for all categories
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
		"career_pass_breakups": 0.0,
		"career_games_played": 0.0,
		"seasons": 0
	}

	var season_count := 0
	for year_key in career_data.keys():
		# Skip non-numeric keys (metadata)
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
		totals["career_pass_breakups"] += float(season_stats.get("pass_breakups", 0.0))
		totals["career_games_played"] += float(season_stats.get("games_played", 0.0))

	totals["seasons"] = season_count
	totals["career_seasons"] = season_count

	return totals


## Builds a player_id -> full_name mapping for display purposes.
##
## Parameters:
##   rosters: Dictionary of team_id -> roster data
##
## Returns: Dictionary mapping player_id to "First Last" string
static func _build_player_name_map(rosters: Dictionary) -> Dictionary:
	var names := {}

	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id]
		var players: Array = roster.get("players", [])

		for player in players:
			var p: Dictionary = player
			var player_id := String(p.get("id", ""))
			if player_id == "":
				continue

			var first := String(p.get("first_name", ""))
			var last := String(p.get("last_name", ""))
			var full_name := "%s %s" % [first, last]
			names[player_id] = full_name.strip_edges()

	return names


## Queries the record book for a specific category.
##
## Parameters:
##   world_state: Dictionary containing league_records
##   record_type: "single_season" or "career"
##   category: Statistical category name
##
## Returns: Dictionary with record data, or empty dict if no record exists
static func get_record(world_state: Dictionary, record_type: String, category: String) -> Dictionary:
	var records: Dictionary = world_state.get("league_records", {})
	var category_records: Dictionary = records.get(record_type, {})
	return category_records.get(category, {})


## Gets all records broken in a specific year.
##
## Parameters:
##   world_state: Dictionary containing league_records
##   year: Season year to filter by
##
## Returns: Array of record-breaking events from that year
static func get_records_broken_in_year(world_state: Dictionary, year: int) -> Array:
	var records: Dictionary = world_state.get("league_records", {})
	var history: Array = records.get("history", [])
	var result := []

	for event in history:
		var e: Dictionary = event
		if int(e.get("year", 0)) == year:
			result.append(e)

	return result


## Gets the top N players for a career stat category.
##
## Parameters:
##   world_state: Dictionary containing league_records
##   category: Career stat category name
##   limit: Number of top players to return (default 10)
##
## Returns: Array of player records sorted by value descending
static func get_career_leaders(world_state: Dictionary, category: String, limit: int = 10) -> Array:
	var player_stats: Dictionary = world_state.get("player_career_stats", {})
	var leaders := []

	# Aggregate career stats for all players
	for player_id in player_stats.keys():
		var career_data: Dictionary = player_stats[player_id]
		var totals := _aggregate_career_stats(career_data)
		var value := float(totals.get(category, 0.0))

		if value > 0.0:
			leaders.append({
				"player_id": player_id,
				"value": value,
				"seasons": int(totals.get("seasons", 0))
			})

	# Sort by value descending
	leaders.sort_custom(func(a, b): return float(a["value"]) > float(b["value"]))

	# Return top N
	var result := []
	for i in range(min(limit, leaders.size())):
		result.append(leaders[i])

	return result
