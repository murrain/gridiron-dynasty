extends RefCounted

## Test H4.1: Franchise Win Totals Accuracy
##
## Validates that all_time_wins and all_time_losses are correctly tracked
## across multiple seasons and match individual season records.

const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const Rand = preload("res://autoloads/Rand.gd")

func run(t) -> void:
	_test_franchise_totals_accumulate_correctly(t)
	_test_first_and_last_season_tracking(t)
	_test_totals_match_season_records(t)


func _test_franchise_totals_accumulate_correctly(t) -> void:
	# Create minimal test world
	var world_state := _create_test_world()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 12345

	# Simulate 3 seasons
	for year_offset in range(3):
		var year := 2025 + year_offset
		var year_seed := Rand.splitmix64(base_seed + year_offset)

		CollegeSeason.new().run(
			world_state,
			year,
			year_seed,
			config,
			positions_cfg,
			main_cfg,
			stats_cfg
		)

	# Verify team_history exists and has accumulated wins/losses
	var team_history: Dictionary = world_state.get("team_history", {})
	t.assert_true(not team_history.is_empty(), "Team history should be populated")

	# Check that at least one team has non-zero all_time_wins
	var has_wins := false
	for team_id in team_history.keys():
		var history: Dictionary = team_history[team_id]
		var all_time_wins := int(history.get("all_time_wins", 0))
		var all_time_losses := int(history.get("all_time_losses", 0))

		if all_time_wins > 0 or all_time_losses > 0:
			has_wins = true
			# Total games should be wins + losses = games_per_season * seasons
			var total_games := all_time_wins + all_time_losses
			t.assert_true(total_games > 0, "Team %s should have played games" % team_id)
			# With 12-game seasons over 3 years, should have ~36 total games
			t.assert_true(total_games >= 30 and total_games <= 40, "Team %s should have ~36 games (got %d)" % [team_id, total_games])

	t.assert_true(has_wins, "At least one team should have wins/losses recorded")


func _test_first_and_last_season_tracking(t) -> void:
	var world_state := _create_test_world()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 54321

	# Simulate years 2025, 2026, 2027
	for year_offset in range(3):
		var year := 2025 + year_offset
		var year_seed := Rand.splitmix64(base_seed + year_offset)

		CollegeSeason.new().run(
			world_state,
			year,
			year_seed,
			config,
			positions_cfg,
			main_cfg,
			stats_cfg
		)

	var team_history: Dictionary = world_state.get("team_history", {})

	# Check first_season and last_season
	for team_id in team_history.keys():
		var history: Dictionary = team_history[team_id]
		var first_season := int(history.get("first_season", 0))
		var last_season := int(history.get("last_season", 0))

		t.assert_eq(first_season, 2025, "Team %s first_season should be 2025" % team_id)
		t.assert_eq(last_season, 2027, "Team %s last_season should be 2027" % team_id)


func _test_totals_match_season_records(t) -> void:
	var world_state := _create_test_world()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 99999

	# Simulate 2 seasons
	for year_offset in range(2):
		var year := 2025 + year_offset
		var year_seed := Rand.splitmix64(base_seed + year_offset)

		CollegeSeason.new().run(
			world_state,
			year,
			year_seed,
			config,
			positions_cfg,
			main_cfg,
			stats_cfg
		)

	# Calculate expected totals from season_records
	var season_records: Dictionary = world_state.get("season_records", {})
	var expected_totals := {}

	for year in season_records.keys():
		var year_records: Dictionary = season_records[year]
		for team_id in year_records.keys():
			if not expected_totals.has(team_id):
				expected_totals[team_id] = {"wins": 0, "losses": 0}

			var record: Dictionary = year_records[team_id]
			expected_totals[team_id]["wins"] += int(record.get("wins", 0))
			expected_totals[team_id]["losses"] += int(record.get("losses", 0))

	# Compare with team_history
	var team_history: Dictionary = world_state.get("team_history", {})

	for team_id in expected_totals.keys():
		var expected: Dictionary = expected_totals[team_id]
		var history: Dictionary = team_history.get(team_id, {})

		var actual_wins := int(history.get("all_time_wins", 0))
		var actual_losses := int(history.get("all_time_losses", 0))

		t.assert_eq(actual_wins, expected["wins"], "Team %s all_time_wins should match season totals" % team_id)
		t.assert_eq(actual_losses, expected["losses"], "Team %s all_time_losses should match season totals" % team_id)


func _create_test_world() -> Dictionary:
	# Create minimal world with 4 colleges and rosters
	var colleges := []
	var rosters := {}

	for i in range(4):
		var college_id := "college_%03d" % i
		colleges.append({"id": college_id, "tier": "mid", "eliteness": 50.0})

		# Create roster with players
		var players := []
		for j in range(10):
			players.append({
				"player_id": "%s_player_%d" % [college_id, j],
				"position": "QB" if j == 0 else "RB",
				"college_year": 1,
				"composite_score": 60.0 + randf() * 20.0,
				"stats": {},
				"age": 18
			})

		rosters[college_id] = {"players": players}

	return {
		"colleges": colleges,
		"college_rosters": rosters,
		"draft_pool": {}
	}


func _create_test_config() -> Dictionary:
	return {
		"game_simulation": {
			"enabled": true,
			"regular_season_weeks": 12,
			"home_field_advantage": 3.0,
			"strength_sensitivity": 0.1,
			"upset_threshold": 5.0
		},
		"early_declaration": {
			"min_year": 3,
			"rating_threshold": 85.0,
			"base_chance": 0.15
		},
		"draft_declaration": {
			"rating_threshold": 65.0
		}
	}
