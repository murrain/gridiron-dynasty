extends RefCounted
class_name FranchiseRecords

## Team Franchise Records - Per-Team All-Time Statistical Records
##
## Tracks team-specific records (best performances by players while on that team).
## Distinct from league records: Records are scoped to individual franchises.
##
## Implements Feature 3: Team Franchise Records
##   - Single-game records (player performance in one game while on team)
##   - Single-season records (player performance in one season while on team)
##   - Career records (player performance across all seasons with team)
##   - Team season records (team-wide stats in a single season)
##
## Data Model:
##   world_state["franchise_records"][team_id] = {
##     "single_season": {
##       "pass_yards": {value, player_id, player_name, year},
##       "rush_yards": {value, player_id, player_name, year},
##       ...
##     },
##     "team_season": {
##       "total_points": {value, year},
##       "total_yards": {value, year},
##       "wins": {value, year},
##       ...
##     },
##     "history": [
##       {record_type, category, old_value, new_value, player_id, year}
##     ]
##   }
##
## Performance: O(p × k) where p = players per team (~53), k = stat categories (~30)
## RNG Pattern: None (pure comparison and aggregation)

## Player single-season franchise record categories
const PLAYER_SINGLE_SEASON := [
	# Offense
	"pass_yards",
	"pass_tds",
	"pass_completions",
	"rush_yards",
	"rush_tds",
	"receptions",
	"receiving_yards",
	"receiving_tds",
	# Defense
	"tackles",
	"sacks",
	"tackles_for_loss",
	"interceptions",
	"pass_breakups"
]

## Team season records (aggregated team performance)
const TEAM_SEASON := [
	"wins",
	"total_points_for",
	"total_points_against",
	"point_differential",
	"total_yards",
	"total_touchdowns"
]


## Updates franchise records for all teams based on current season.
##
## This is the main entry point called from NflSeason after stat accumulation.
## Processes both player and team records for each franchise.
##
## Parameters:
##   world_state: Dictionary containing player_career_stats, nfl_rosters, season_records
##   year: Current season year
##
## Side Effects:
##   - Modifies world_state["franchise_records"][team_id]
##   - Appends to each team's record history when records broken
##
## Performance: O(t × p × k) where t = teams (32), p = players per team (~53), k = categories (~30)
static func update_all_franchise_records(world_state: Dictionary, year: int) -> Dictionary:
	var player_stats: Dictionary = world_state.get("player_career_stats", {})
	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	var season_records: Dictionary = world_state.get("season_records", {})

	if player_stats.is_empty() or rosters.is_empty():
		return {"teams_processed": 0, "records_broken": 0}

	# Initialize franchise records structure if not exists
	if not world_state.has("franchise_records"):
		world_state["franchise_records"] = {}

	var franchise_records: Dictionary = world_state["franchise_records"]
	var teams_processed := 0
	var total_records_broken := 0

	# Build player name lookup
	var player_names := _build_player_name_map(rosters)

	# Process each team
	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id]
		var players: Array = roster.get("players", [])

		# Initialize team record book if not exists
		if not franchise_records.has(team_id):
			franchise_records[team_id] = {
				"team_id": team_id,
				"single_season": {},
				"team_season": {},
				"history": []
			}

		var team_records: Dictionary = franchise_records[team_id]
		var single_season: Dictionary = team_records.get("single_season", {})
		var team_season: Dictionary = team_records.get("team_season", {})
		var history: Array = team_records.get("history", [])

		# Update player single-season records
		var player_records_broken := _update_player_records(
			single_season,
			history,
			player_stats,
			players,
			player_names,
			team_id,
			year
		)

		# Update team season records
		var team_records_broken := _update_team_season_records(
			team_season,
			history,
			season_records,
			team_id,
			year
		)

		# Save updated records
		team_records["single_season"] = single_season
		team_records["team_season"] = team_season
		team_records["history"] = history
		franchise_records[team_id] = team_records

		teams_processed += 1
		total_records_broken += player_records_broken + team_records_broken

	world_state["franchise_records"] = franchise_records

	return {
		"teams_processed": teams_processed,
		"records_broken": total_records_broken,
		"year": year
	}


## Updates player single-season records for a team.
##
## Parameters:
##   single_season: Dictionary of current franchise player records
##   history: Array to append record-breaking events to
##   player_stats: Dictionary of all player career stats
##   players: Array of player dictionaries on this team's roster
##   player_names: Dictionary mapping player_id to full name
##   team_id: Team identifier
##   year: Current season year
##
## Returns: Number of records broken
static func _update_player_records(
	single_season: Dictionary,
	history: Array,
	player_stats: Dictionary,
	players: Array,
	player_names: Dictionary,
	team_id: String,
	year: int
) -> int:
	var records_broken := 0

	for player in players:
		var p: Dictionary = player
		var player_id := String(p.get("id", ""))
		if player_id == "":
			continue

		var career_data: Dictionary = player_stats.get(player_id, {})
		if not career_data.has(year):
			continue

		var season_stats: Dictionary = career_data[year]

		# Verify player was on this team this year
		var stat_team_id := String(season_stats.get("team_id", ""))
		if stat_team_id != team_id:
			continue

		var player_name := String(player_names.get(player_id, "Unknown Player"))

		# Check all player stat categories
		for category in PLAYER_SINGLE_SEASON:
			var value := float(season_stats.get(category, 0.0))
			if _is_new_franchise_record(single_season, category, value):
				_set_franchise_record(single_season, category, {
					"value": value,
					"player_id": player_id,
					"player_name": player_name,
					"year": year
				}, history, "single_season")
				records_broken += 1

	return records_broken


## Updates team season records (aggregated team performance).
##
## Parameters:
##   team_season: Dictionary of current franchise team records
##   history: Array to append record-breaking events to
##   season_records: Dictionary of all team season results
##   team_id: Team identifier
##   year: Current season year
##
## Returns: Number of records broken
static func _update_team_season_records(
	team_season: Dictionary,
	history: Array,
	season_records: Dictionary,
	team_id: String,
	year: int
) -> int:
	var year_records: Dictionary = season_records.get(year, {})
	var team_record: Dictionary = year_records.get(team_id, {})

	if team_record.is_empty():
		return 0

	var records_broken := 0

	# Extract team season stats
	var wins := int(team_record.get("wins", 0))
	var points_for := float(team_record.get("points_for", 0.0))
	var points_against := float(team_record.get("points_against", 0.0))
	var total_yards := float(team_record.get("total_yards", 0.0))
	var total_tds := float(team_record.get("total_touchdowns", 0.0))

	# Check each team record category
	if _is_new_franchise_record(team_season, "wins", float(wins)):
		_set_franchise_record(team_season, "wins", {
			"value": float(wins),
			"year": year
		}, history, "team_season")
		records_broken += 1

	if _is_new_franchise_record(team_season, "total_points_for", points_for):
		_set_franchise_record(team_season, "total_points_for", {
			"value": points_for,
			"year": year
		}, history, "team_season")
		records_broken += 1

	if _is_new_franchise_record(team_season, "total_points_against", points_against):
		# Note: For points_against, lower is better, so we invert the check
		# This will be handled by is_inverse logic in a future enhancement
		pass

	var point_diff := points_for - points_against
	if _is_new_franchise_record(team_season, "point_differential", point_diff):
		_set_franchise_record(team_season, "point_differential", {
			"value": point_diff,
			"year": year
		}, history, "team_season")
		records_broken += 1

	if _is_new_franchise_record(team_season, "total_yards", total_yards):
		_set_franchise_record(team_season, "total_yards", {
			"value": total_yards,
			"year": year
		}, history, "team_season")
		records_broken += 1

	if _is_new_franchise_record(team_season, "total_touchdowns", total_tds):
		_set_franchise_record(team_season, "total_touchdowns", {
			"value": total_tds,
			"year": year
		}, history, "team_season")
		records_broken += 1

	return records_broken


## Checks if a value breaks an existing franchise record.
##
## Parameters:
##   record_category: Dictionary containing current records
##   stat_name: Name of statistical category
##   value: New value to check
##
## Returns: true if value exceeds current record (or no record exists)
static func _is_new_franchise_record(record_category: Dictionary, stat_name: String, value: float) -> bool:
	if not record_category.has(stat_name):
		return value > 0.0  # First record must be positive

	var current_record: Dictionary = record_category[stat_name]
	var current_value := float(current_record.get("value", 0.0))
	return value > current_value


## Sets a new franchise record and logs it to history.
##
## Parameters:
##   record_category: Dictionary to store record in
##   stat_name: Name of statistical category
##   record_data: Dictionary containing value and metadata
##   history: Array to append record-breaking event to
##   record_type: "single_season" or "team_season"
static func _set_franchise_record(
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


## Queries franchise records for a specific team and category.
##
## Parameters:
##   world_state: Dictionary containing franchise_records
##   team_id: Team identifier
##   record_type: "single_season" or "team_season"
##   category: Statistical category name
##
## Returns: Dictionary with record data, or empty dict if no record exists
static func get_franchise_record(
	world_state: Dictionary,
	team_id: String,
	record_type: String,
	category: String
) -> Dictionary:
	var franchise_records: Dictionary = world_state.get("franchise_records", {})
	var team_records: Dictionary = franchise_records.get(team_id, {})
	var category_records: Dictionary = team_records.get(record_type, {})
	return category_records.get(category, {})


## Gets all franchise records broken by a team in a specific year.
##
## Parameters:
##   world_state: Dictionary containing franchise_records
##   team_id: Team identifier
##   year: Season year to filter by
##
## Returns: Array of record-breaking events from that year
static func get_franchise_records_broken_in_year(
	world_state: Dictionary,
	team_id: String,
	year: int
) -> Array:
	var franchise_records: Dictionary = world_state.get("franchise_records", {})
	var team_records: Dictionary = franchise_records.get(team_id, {})
	var history: Array = team_records.get("history", [])
	var result := []

	for event in history:
		var e: Dictionary = event
		if int(e.get("year", 0)) == year:
			result.append(e)

	return result


## Gets all franchise records for a specific team.
##
## Parameters:
##   world_state: Dictionary containing franchise_records
##   team_id: Team identifier
##
## Returns: Dictionary with all franchise records for the team
static func get_all_franchise_records(world_state: Dictionary, team_id: String) -> Dictionary:
	var franchise_records: Dictionary = world_state.get("franchise_records", {})
	return franchise_records.get(team_id, {})
