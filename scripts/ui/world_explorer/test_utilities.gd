extends Node

## Test script for World Explorer utility classes
##
## This demonstrates how to use the query and formatter utilities
## Run this from a test scene with a bootstrapped world_state

func _ready():
	print("=== World Explorer Utilities Test ===\n")

	# Load a bootstrapped world state
	var world_state = _load_test_world_state()
	if world_state.is_empty():
		print("ERROR: No world_state loaded. Bootstrap first!")
		return

	print("Loaded world_state with current_year: %d" % world_state.get("current_year", 0))
	print("")

	# Test PlayerQueries
	_test_player_queries(world_state)
	print("")

	# Test TeamQueries
	_test_team_queries(world_state)
	print("")

	# Test DraftQueries
	_test_draft_queries(world_state)
	print("")

	# Test StatQueries
	_test_stat_queries(world_state)
	print("")

	# Test Formatters
	_test_formatters(world_state)
	print("")

	print("=== All Tests Complete ===")

func _load_test_world_state() -> Dictionary:
	# Try to load from the bootstrap save location
	var save_path = "user://world_state.json"
	if not FileAccess.file_exists(save_path):
		print("No world_state.json found at %s" % save_path)
		return {}

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		print("Failed to open world_state.json")
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("Failed to parse world_state.json: %s" % json.get_error_message())
		return {}

	return json.data

func _test_player_queries(world_state: Dictionary):
	print("--- Testing PlayerQueries ---")

	# Get all NFL players
	var nfl_players = PlayerQueries.get_all_nfl_players(world_state)
	print("Total NFL players: %d" % nfl_players.size())

	# Get first player as example
	if nfl_players.size() > 0:
		var player = nfl_players[0]
		print("Sample player: %s (ID: %s)" % [
			PlayerQueries.get_player_name(player),
			player.get("id", "?")
		])

		# Test get_player_by_id
		var found = PlayerQueries.get_player_by_id(world_state, player.get("id", ""))
		print("get_player_by_id works: %s" % ("YES" if found != null else "NO"))

		# Test rating calculation
		var rating = StatQueries.calculate_composite_rating(player)
		print("Player rating: %.1f" % rating)

	# Test search
	var search_results = PlayerQueries.find_players_by_name(world_state, "Smith")
	print("Players with 'Smith' in name: %d" % search_results.size())

	# Test position filter
	var qbs = PlayerQueries.get_players_by_position(nfl_players, "QB")
	print("NFL Quarterbacks: %d" % qbs.size())

func _test_team_queries(world_state: Dictionary):
	print("--- Testing TeamQueries ---")

	# Get first NFL team
	var nfl_teams = world_state.get("nfl_teams", [])
	if nfl_teams.size() > 0:
		var team = nfl_teams[0]
		var team_id = team.get("id", "")
		print("Sample team: %s (ID: %s)" % [team.get("name", "?"), team_id])

		# Test roster retrieval
		var roster = TeamQueries.get_nfl_roster(world_state, team_id)
		print("Roster size: %d" % roster.size())

		# Test roster by position
		var by_position = TeamQueries.get_roster_by_position(world_state, team_id, "nfl")
		print("Positions on roster: %d" % by_position.size())
		for pos in by_position.keys():
			print("  %s: %d players" % [pos, by_position[pos].size()])

		# Test salary cap
		var cap_used = TeamQueries.calculate_cap_usage(world_state, team_id)
		print("Salary cap used: $%.1fM" % cap_used)

	# Test college queries
	var colleges = world_state.get("colleges", [])
	if colleges.size() > 0:
		var college = colleges[0]
		var college_id = college.get("id", "")
		var college_roster = TeamQueries.get_college_roster(world_state, college_id)
		print("Sample college: %s (%d players)" % [
			college.get("name", "?"),
			college_roster.size()
		])

func _test_draft_queries(world_state: Dictionary):
	print("--- Testing DraftQueries ---")

	# Get available draft years
	var years = DraftQueries.get_draft_years(world_state)
	print("Draft years available: %s" % str(years))

	if years.size() > 0:
		var year = years[0]
		var pool = DraftQueries.get_draft_pool(world_state, year)
		print("Draft pool for %d: %d players" % [year, pool.size()])

		# Get top prospects
		var top_prospects = DraftQueries.get_top_prospects(world_state, year, 5)
		print("Top 5 prospects:")
		for i in range(top_prospects.size()):
			var player = top_prospects[i]
			var grade = DraftQueries.calculate_draft_grade(player)
			print("  %d. %s (%s) - Grade: %.1f" % [
				i + 1,
				PlayerQueries.get_player_name(player),
				player.get("position", "?"),
				grade
			])

func _test_stat_queries(world_state: Dictionary):
	print("--- Testing StatQueries ---")

	# Test core stats for various positions
	var positions = ["QB", "RB", "WR", "OL", "DL"]
	for pos in positions:
		var core_stats = StatQueries.get_core_stats_for_position(pos)
		print("%s core stats: %s" % [pos, ", ".join(core_stats)])

	# Test color mapping
	var test_values = [95.0, 85.0, 75.0, 65.0, 55.0, 45.0]
	print("\nStat color mapping:")
	for value in test_values:
		var color_hex = StatQueries.get_stat_color_hex(value)
		print("  %.0f -> %s" % [value, color_hex])

func _test_formatters(world_state: Dictionary):
	print("--- Testing Formatters ---")

	# Test player detail formatter
	var nfl_players = PlayerQueries.get_all_nfl_players(world_state)
	if nfl_players.size() > 0:
		var player = nfl_players[0]
		var formatted = PlayerDetailFormatter.format(player, world_state)
		print("PlayerDetailFormatter output (%d chars):" % formatted.length())
		print(formatted.substr(0, mini(200, formatted.length())) + "...")

	# Test team detail formatter
	var nfl_teams = world_state.get("nfl_teams", [])
	if nfl_teams.size() > 0:
		var team = nfl_teams[0]
		var formatted = TeamDetailFormatter.format(team, world_state, "nfl")
		print("\nTeamDetailFormatter output (%d chars):" % formatted.length())
		print(formatted.substr(0, mini(200, formatted.length())) + "...")

	# Test stats formatter
	print("\nStatsFormatter examples:")
	print("Stat bar (85/100): %s" % StatsFormatter.format_stat_bar(85.0))
	print("Rating badge (92): %s" % StatsFormatter.format_rating_badge(92.0))
	print("Comparison: %s" % StatsFormatter.format_stat_comparison(85.0, 78.0, "speed"))
