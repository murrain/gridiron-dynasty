extends RefCounted

## Test H4.6: Championship Drought Tracking
##
## Validates that years_since_championship is correctly calculated
## for teams with championships, teams without championships, and recent champions.

const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const Rand = preload("res://autoloads/Rand.gd")

func run(t) -> void:
	_test_recent_champion_has_zero_drought(t)
	_test_never_won_has_negative_one(t)
	_test_drought_increases_each_year(t)
	_test_drought_resets_on_championship(t)


func _test_recent_champion_has_zero_drought(t) -> void:
	var world_state := _create_test_world()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 11111

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

	# Get the champion
	var championships: Dictionary = world_state.get("championships", {})
	var college_champs: Dictionary = championships.get("college", {})
	var national_champions: Dictionary = college_champs.get("national_champions", {})
	var champion_id := String(national_champions.get(2025, ""))

	# Champion should have 0 years since championship
	var team_history: Dictionary = world_state.get("team_history", {})
	var champion_history: Dictionary = team_history.get(champion_id, {})
	var drought := int(champion_history.get("years_since_championship", -999))

	t.assert_eq(drought, 0, "Current champion should have 0 years_since_championship (got %d)" % drought)


func _test_never_won_has_negative_one(t) -> void:
	var world_state := _create_test_world()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 22222

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

	# Check non-champions have -1 drought
	var team_history: Dictionary = world_state.get("team_history", {})
	var checked_non_champion := false

	for team_id in team_history.keys():
		if not champion_ids.has(team_id):
			var history: Dictionary = team_history[team_id]
			var drought := int(history.get("years_since_championship", 0))

			t.assert_eq(drought, -1, "Team %s that never won should have -1 drought (got %d)" % [team_id, drought])
			checked_non_champion = true

	t.assert_true(checked_non_champion, "Should have verified at least one non-champion")


func _test_drought_increases_each_year(t) -> void:
	# Create controlled scenario with manual championship
	var world_state := {
		"team_history": {
			"team_001": {
				"team_id": "team_001",
				"all_time_wins": 10,
				"all_time_losses": 2,
				"first_season": 2020,
				"last_season": 2020,
				"championship_count": 1,
				"championship_years": [2020],  # Won in 2020
				"playoff_appearances": 1,
				"playoff_years": [2020],
				"longest_win_streak": 1,
				"longest_loss_streak": 0,
				"current_win_streak": 1,
				"current_loss_streak": 0,
				"years_since_championship": 0
			}
		},
		"season_records": {}
	}

	# Simulate passing years without championships
	var cs := CollegeSeason.new()

	for year in [2021, 2022, 2023]:
		var season_results := {
			"team_001": {
				"team_id": "team_001",
				"wins": 8,
				"losses": 4,
				"year": year
			}
		}

		# Update history (team doesn't win championship)
		cs._update_team_history(world_state, year, season_results, "other_team")

	# Check drought increased correctly
	var history: Dictionary = world_state["team_history"]["team_001"]
	var drought := int(history["years_since_championship"])

	# 2023 - 2020 = 3 years since championship
	t.assert_eq(drought, 3, "Drought should be 3 years (2023 - 2020)")


func _test_drought_resets_on_championship(t) -> void:
	# Create scenario with old championship
	var world_state := {
		"team_history": {
			"team_001": {
				"team_id": "team_001",
				"all_time_wins": 30,
				"all_time_losses": 6,
				"first_season": 2020,
				"last_season": 2022,
				"championship_count": 1,
				"championship_years": [2020],  # Won in 2020
				"playoff_appearances": 3,
				"playoff_years": [2020, 2021, 2022],
				"longest_win_streak": 3,
				"longest_loss_streak": 0,
				"current_win_streak": 3,
				"current_loss_streak": 0,
				"years_since_championship": 3  # 3-year drought
			}
		},
		"season_records": {}
	}

	# Team wins championship in 2023
	var season_results := {
		"team_001": {
			"team_id": "team_001",
			"wins": 12,
			"losses": 0,
			"year": 2023
		}
	}

	var cs := CollegeSeason.new()
	cs._update_team_history(world_state, 2023, season_results, "team_001")  # team_001 wins

	# Check drought reset to 0
	var history: Dictionary = world_state["team_history"]["team_001"]
	var drought := int(history["years_since_championship"])
	var champ_count := int(history["championship_count"])
	var champ_years: Array = history["championship_years"]

	t.assert_eq(drought, 0, "Drought should reset to 0 after winning championship")
	t.assert_eq(champ_count, 2, "Championship count should be 2")
	t.assert_true(2023 in champ_years, "2023 should be in championship_years")


func _create_test_world() -> Dictionary:
	var colleges := []
	var rosters := {}

	for i in range(6):
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
