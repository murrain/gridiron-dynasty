extends RefCounted

## Test H4.2: Championship History Accuracy
##
## Validates that championship_count and championship_years are correctly tracked
## and match the championships data structure.

const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const Rand = preload("res://autoloads/Rand.gd")

func run(t) -> void:
	_test_champions_have_correct_count(t)
	_test_championship_years_match_championships(t)
	_test_non_champions_have_zero_count(t)


func _test_champions_have_correct_count(t) -> void:
	var world_state := _create_test_world()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 11111

	# Simulate 5 seasons
	for year_offset in range(5):
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

	# Get championships
	var championships: Dictionary = world_state.get("championships", {})
	var college_champs: Dictionary = championships.get("college", {})
	var national_champions: Dictionary = college_champs.get("national_champions", {})

	# Count championships per team
	var expected_counts := {}
	for year in national_champions.keys():
		var champion_id := String(national_champions[year])
		expected_counts[champion_id] = expected_counts.get(champion_id, 0) + 1

	# Verify team_history matches
	var team_history: Dictionary = world_state.get("team_history", {})

	for team_id in expected_counts.keys():
		var expected_count := int(expected_counts[team_id])
		var history: Dictionary = team_history.get(team_id, {})
		var actual_count := int(history.get("championship_count", 0))

		t.assert_eq(actual_count, expected_count, "Team %s should have %d championships (got %d)" % [team_id, expected_count, actual_count])


func _test_championship_years_match_championships(t) -> void:
	var world_state := _create_test_world()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 22222

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

	# Build expected championship_years per team
	var championships: Dictionary = world_state.get("championships", {})
	var college_champs: Dictionary = championships.get("college", {})
	var national_champions: Dictionary = college_champs.get("national_champions", {})

	var expected_years := {}
	for year in national_champions.keys():
		var champion_id := String(national_champions[year])
		if not expected_years.has(champion_id):
			expected_years[champion_id] = []
		(expected_years[champion_id] as Array).append(int(year))

	# Verify team_history championship_years match
	var team_history: Dictionary = world_state.get("team_history", {})

	for team_id in expected_years.keys():
		var expected: Array = expected_years[team_id]
		var history: Dictionary = team_history.get(team_id, {})
		var actual: Array = history.get("championship_years", [])

		t.assert_eq(actual.size(), expected.size(), "Team %s should have %d championship years" % [team_id, expected.size()])

		# Verify all expected years are present
		for year in expected:
			t.assert_true(year in actual, "Team %s championship_years should include %d" % [team_id, year])


func _test_non_champions_have_zero_count(t) -> void:
	var world_state := _create_test_world()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 33333

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

	# Get championship winners
	var championships: Dictionary = world_state.get("championships", {})
	var college_champs: Dictionary = championships.get("college", {})
	var national_champions: Dictionary = college_champs.get("national_champions", {})

	var champion_ids := {}
	for year in national_champions.keys():
		champion_ids[String(national_champions[year])] = true

	# Check that non-champions have zero count
	var team_history: Dictionary = world_state.get("team_history", {})
	var checked_non_champion := false

	for team_id in team_history.keys():
		if not champion_ids.has(team_id):
			var history: Dictionary = team_history[team_id]
			var count := int(history.get("championship_count", 0))
			var years: Array = history.get("championship_years", [])

			t.assert_eq(count, 0, "Non-champion team %s should have 0 championships" % team_id)
			t.assert_true(years.is_empty(), "Non-champion team %s should have empty championship_years" % team_id)
			checked_non_champion = true

	t.assert_true(checked_non_champion, "Should have verified at least one non-champion team")


func _create_test_world() -> Dictionary:
	var colleges := []
	var rosters := {}

	for i in range(6):
		var college_id := "college_%03d" % i
		colleges.append({"id": college_id, "tier": "mid", "eliteness": 50.0 + i * 5.0})

		var players := []
		for j in range(10):
			players.append({
				"player_id": "%s_player_%d" % [college_id, j],
				"position": "QB" if j == 0 else "RB",
				"college_year": 1,
				"composite_score": 55.0 + i * 3.0 + randf() * 10.0,
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
