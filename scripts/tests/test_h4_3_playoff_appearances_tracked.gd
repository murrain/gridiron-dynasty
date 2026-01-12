extends RefCounted

## Test H4.3: Playoff Appearance Tracking
##
## Validates that playoff_appearances and playoff_years are correctly tracked
## and that the top teams are identified each season.

const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const Rand = preload("res://autoloads/Rand.gd")

func run(t) -> void:
	_test_top_teams_make_playoffs(t)
	_test_playoff_appearances_accumulate(t)
	_test_playoff_years_recorded(t)


func _test_top_teams_make_playoffs(t) -> void:
	var world_state := _create_test_world()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 44444

	# Simulate 1 season
	CollegeSeason.new().run(
		world_state,
		2025,
		base_seed,
		config,
		positions_cfg,
		main_cfg,
		stats_cfg
	)

	# Get season records and find top 4 teams by wins
	var season_records: Dictionary = world_state.get("season_records", {})
	var year_records: Dictionary = season_records.get(2025, {})

	var teams := []
	for team_id in year_records.keys():
		var record: Dictionary = year_records[team_id]
		teams.append({
			"team_id": team_id,
			"wins": int(record.get("wins", 0))
		})

	# Sort by wins descending
	teams.sort_custom(func(a, b): return int(a["wins"]) > int(b["wins"]))

	# Top 4 teams should have playoff appearance
	var team_history: Dictionary = world_state.get("team_history", {})
	var playoff_count := 0

	for i in range(min(4, teams.size())):
		var team_id := String(teams[i]["team_id"])
		var history: Dictionary = team_history.get(team_id, {})
		var appearances := int(history.get("playoff_appearances", 0))

		t.assert_eq(appearances, 1, "Top %d team %s should have 1 playoff appearance" % [i+1, team_id])

		var playoff_years: Array = history.get("playoff_years", [])
		t.assert_true(2025 in playoff_years, "Top team %s should have 2025 in playoff_years" % team_id)
		playoff_count += 1

	t.assert_eq(playoff_count, 4, "Exactly 4 teams should make playoffs (college)")


func _test_playoff_appearances_accumulate(t) -> void:
	var world_state := _create_test_world_with_dynasty()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 55555

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

	# Dynasty team (college_000) should have multiple playoff appearances
	var team_history: Dictionary = world_state.get("team_history", {})
	var dynasty_history: Dictionary = team_history.get("college_000", {})
	var appearances := int(dynasty_history.get("playoff_appearances", 0))

	# Dynasty team should make playoffs most years (at least 2 out of 3)
	t.assert_true(appearances >= 2, "Dynasty team should make playoffs at least 2/3 seasons (got %d)" % appearances)


func _test_playoff_years_recorded(t) -> void:
	var world_state := _create_test_world()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 66666

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

	# Verify playoff_years array is populated correctly
	var team_history: Dictionary = world_state.get("team_history", {})

	var teams_with_playoffs := 0
	for team_id in team_history.keys():
		var history: Dictionary = team_history[team_id]
		var appearances := int(history.get("playoff_appearances", 0))
		var playoff_years: Array = history.get("playoff_years", [])

		# playoff_years array size should match appearances count
		t.assert_eq(playoff_years.size(), appearances, "Team %s playoff_years size should match appearances" % team_id)

		if appearances > 0:
			teams_with_playoffs += 1
			# All years should be valid
			for year in playoff_years:
				t.assert_true(int(year) >= 2025 and int(year) <= 2026, "Team %s playoff year should be 2025-2026" % team_id)

	# Should have some teams with playoff appearances
	t.assert_true(teams_with_playoffs >= 4, "At least 4 teams should have playoff appearances")


func _create_test_world() -> Dictionary:
	var colleges := []
	var rosters := {}

	for i in range(8):
		var college_id := "college_%03d" % i
		colleges.append({"id": college_id, "tier": "mid", "eliteness": 50.0})

		var players := []
		for j in range(10):
			players.append({
				"player_id": "%s_player_%d" % [college_id, j],
				"position": "QB" if j == 0 else "RB",
				"college_year": 1,
				"composite_score": 60.0 + randf() * 15.0,
				"stats": {},
				"age": 18
			})

		rosters[college_id] = {"players": players}

	return {
		"colleges": colleges,
		"college_rosters": rosters,
		"draft_pool": {}
	}


func _create_test_world_with_dynasty() -> Dictionary:
	var colleges := []
	var rosters := {}

	for i in range(8):
		var college_id := "college_%03d" % i
		colleges.append({"id": college_id, "tier": "mid", "eliteness": 50.0})

		# Give college_000 stronger players (dynasty team)
		var base_strength := 80.0 if i == 0 else 60.0

		var players := []
		for j in range(10):
			players.append({
				"player_id": "%s_player_%d" % [college_id, j],
				"position": "QB" if j == 0 else "RB",
				"college_year": 1,
				"composite_score": base_strength + randf() * 10.0,
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
			"rating_threshold": 85.0
		},
		"draft_declaration": {
			"rating_threshold": 65.0
		}
	}
