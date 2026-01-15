## GdUnit4 POC Test 2: Determinism Test
##
## Validates that game simulation produces identical results with identical seeds.
## Tests the core requirement for reproducible 20-year simulations.
## Migrated from test_g1_1_game_simulation_determinism.gd to demonstrate GdUnit4 patterns.
##
## POC Category: Determinism Test
extends GdUnitTestSuite

const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")
const Rand = preload("res://autoloads/Rand.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


func test_determine_winner_is_deterministic() -> void:
	var game_matchup := {
		"game_id": "test_game_1",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_001",
		"away_team_id": "team_002",
		"game_type": "regular"
	}

	var team_strengths := {
		"team_001": 75.0,
		"team_002": 65.0
	}

	var cfg := {
		"home_field_advantage": 3.0,
		"strength_sensitivity": 0.1,
		"upset_threshold": 5.0
	}

	var seed_value := 12345

	# Simulate same game 3 times with same seed
	var results: Array = []
	for i in range(3):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var result := GameSimulator.determine_winner(game_matchup, team_strengths, rng, cfg)
		results.append(result)

	# All results should be identical
	assert_that(results[0]["winner_id"]).is_equal(results[1]["winner_id"])
	assert_that(results[0]["winner_id"]).is_equal(results[2]["winner_id"])
	assert_float(results[0]["win_probability"]).is_equal(results[1]["win_probability"])
	assert_bool(results[0]["upset"]).is_equal(results[1]["upset"])


func test_schedule_generation_is_deterministic() -> void:
	var colleges: Array = []
	for i in range(10):
		colleges.append({"id": "college_%03d" % i})

	var year := 2025
	var weeks := 12
	var seed_value := 54321

	# Generate schedule 3 times with same seed
	var schedule1 := GameSimulator.generate_college_schedule(colleges, year, weeks, seed_value)
	var schedule2 := GameSimulator.generate_college_schedule(colleges, year, weeks, seed_value)
	var schedule3 := GameSimulator.generate_college_schedule(colleges, year, weeks, seed_value)

	assert_int(schedule1.size()).is_equal(schedule2.size())
	assert_int(schedule1.size()).is_equal(schedule3.size())

	# Check first 5 games are identical
	for i in range(min(5, schedule1.size())):
		assert_str(schedule1[i]["home_team_id"]).is_equal(schedule2[i]["home_team_id"])
		assert_str(schedule1[i]["away_team_id"]).is_equal(schedule2[i]["away_team_id"])
		assert_int(schedule1[i]["week"]).is_equal(schedule2[i]["week"])


func test_full_season_is_deterministic() -> void:
	# Create minimal test data
	var colleges: Array = []
	for i in range(4):  # Small test league
		colleges.append({"id": "college_%03d" % i})

	var rosters := {}
	var positions_cfg := {
		"QB": {"core_stats": ["accuracy", "arm_strength"]},
		"RB": {"core_stats": ["speed", "power"]}
	}
	var main_cfg := {"class_rules": {}}

	# Create simple rosters with deterministic values
	var setup_rng := RandomNumberGenerator.new()
	setup_rng.seed = 11111
	for college in colleges:
		var c: Dictionary = college
		var college_id := String(c["id"])
		rosters[college_id] = {
			"players": [
				{"position": "QB", "composite_score": 70.0 + setup_rng.randf() * 10.0},
				{"position": "RB", "composite_score": 65.0 + setup_rng.randf() * 10.0}
			]
		}

	var year := 2025
	var weeks := 3  # Short season for testing
	var seed_value := 99999

	# Simulate full season twice
	var results_run1 := _simulate_test_season(colleges, rosters, year, weeks, seed_value, positions_cfg, main_cfg)
	var results_run2 := _simulate_test_season(colleges, rosters, year, weeks, seed_value, positions_cfg, main_cfg)

	# Results should be identical
	assert_int(results_run1.size()).is_equal(results_run2.size())

	for i in range(results_run1.size()):
		var r1: Dictionary = results_run1[i]
		var r2: Dictionary = results_run2[i]
		assert_str(r1["winner_id"]).override_failure_message(
			"Game %d winner should be deterministic" % i
		).is_equal(r2["winner_id"])


func test_determine_winner_using_assert_deterministic() -> void:
	# Demonstrate using the TestHelpersGdUnit4.assert_deterministic helper
	var game_matchup := {
		"game_id": "test_game_deterministic",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_a",
		"away_team_id": "team_b",
		"game_type": "regular"
	}

	var team_strengths := {
		"team_a": 70.0,
		"team_b": 70.0
	}

	var cfg := {
		"home_field_advantage": 3.0,
		"strength_sensitivity": 0.1,
		"upset_threshold": 5.0
	}

	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng): return GameSimulator.determine_winner(game_matchup, team_strengths, rng, cfg),
		77777,
		"GameSimulator.determine_winner produces deterministic results"
	)


## Helper to simulate a test season
func _simulate_test_season(colleges: Array, rosters: Dictionary, year: int, weeks: int, seed_value: int, positions_cfg: Dictionary, main_cfg: Dictionary) -> Array:
	var cfg := {
		"home_field_advantage": 3.0,
		"strength_sensitivity": 0.1,
		"upset_threshold": 5.0
	}

	# Calculate team strengths
	var team_strengths := {}
	for college in colleges:
		var c: Dictionary = college
		var college_id := String(c["id"])
		if rosters.has(college_id):
			var roster: Dictionary = rosters[college_id]
			var strength := GameSimulator.calculate_team_strength(roster, positions_cfg, main_cfg)
			team_strengths[college_id] = strength

	# Generate schedule
	var schedule := GameSimulator.generate_college_schedule(colleges, year, weeks, seed_value)

	# Simulate games
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var all_results: Array = []

	for matchup in schedule:
		var result := GameSimulator.determine_winner(matchup, team_strengths, rng, cfg)
		all_results.append(result)

	return all_results
