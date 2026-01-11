extends RefCounted

## Test G1.1: Game Simulation Determinism
##
## Validates that game simulation produces identical results with identical seeds.
## Tests the core requirement for reproducible 20-year simulations.

const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")
const Rand = preload("res://autoloads/Rand.gd")

func run(t) -> void:
	_test_determine_winner_determinism(t)
	_test_schedule_generation_determinism(t)
	_test_full_season_determinism(t)


func _test_determine_winner_determinism(t) -> void:
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

	var seed := 12345

	# Simulate same game 3 times with same seed
	var results := []
	for i in range(3):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var result := GameSimulator.determine_winner(game_matchup, team_strengths, rng, cfg)
		results.append(result)

	# All results should be identical
	t.assert_eq(results[0]["winner_id"], results[1]["winner_id"], "Winner should be deterministic (run 1 vs 2)")
	t.assert_eq(results[0]["winner_id"], results[2]["winner_id"], "Winner should be deterministic (run 1 vs 3)")
	t.assert_eq(results[0]["win_probability"], results[1]["win_probability"], "Win probability should be deterministic")
	t.assert_eq(results[0]["upset"], results[1]["upset"], "Upset flag should be deterministic")


func _test_schedule_generation_determinism(t) -> void:
	var colleges := []
	for i in range(10):
		colleges.append({"id": "college_%03d" % i})

	var year := 2025
	var weeks := 12
	var seed := 54321

	# Generate schedule 3 times with same seed
	var schedule1 := GameSimulator.generate_college_schedule(colleges, year, weeks, seed)
	var schedule2 := GameSimulator.generate_college_schedule(colleges, year, weeks, seed)
	var schedule3 := GameSimulator.generate_college_schedule(colleges, year, weeks, seed)

	t.assert_eq(schedule1.size(), schedule2.size(), "Schedule size should be deterministic")
	t.assert_eq(schedule1.size(), schedule3.size(), "Schedule size should be deterministic (vs run 3)")

	# Check first 5 games are identical
	for i in range(min(5, schedule1.size())):
		t.assert_eq(schedule1[i]["home_team_id"], schedule2[i]["home_team_id"], "Game %d home team should be deterministic" % i)
		t.assert_eq(schedule1[i]["away_team_id"], schedule2[i]["away_team_id"], "Game %d away team should be deterministic" % i)
		t.assert_eq(schedule1[i]["week"], schedule2[i]["week"], "Game %d week should be deterministic" % i)


func _test_full_season_determinism(t) -> void:
	# Create minimal test data
	var colleges := []
	for i in range(4):  # Small test league
		colleges.append({"id": "college_%03d" % i})

	var rosters := {}
	var positions_cfg := {
		"QB": {"core_stats": ["accuracy", "arm_strength"]},
		"RB": {"core_stats": ["speed", "power"]}
	}
	var main_cfg := {"class_rules": {}}

	# Create simple rosters
	for college in colleges:
		var c: Dictionary = college
		var college_id := String(c["id"])
		rosters[college_id] = {
			"players": [
				{"position": "QB", "composite_score": 70.0 + randf() * 10.0},
				{"position": "RB", "composite_score": 65.0 + randf() * 10.0}
			]
		}

	var year := 2025
	var weeks := 3  # Short season for testing
	var seed := 99999

	# Simulate full season twice
	var results_run1 := _simulate_test_season(colleges, rosters, year, weeks, seed, positions_cfg, main_cfg)
	var results_run2 := _simulate_test_season(colleges, rosters, year, weeks, seed, positions_cfg, main_cfg)

	# Results should be identical
	t.assert_eq(results_run1.size(), results_run2.size(), "Number of games should be deterministic")

	for i in range(results_run1.size()):
		var r1: Dictionary = results_run1[i]
		var r2: Dictionary = results_run2[i]
		t.assert_eq(r1["winner_id"], r2["winner_id"], "Game %d winner should be deterministic" % i)


func _simulate_test_season(colleges: Array, rosters: Dictionary, year: int, weeks: int, seed: int, positions_cfg: Dictionary, main_cfg: Dictionary) -> Array:
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
	var schedule := GameSimulator.generate_college_schedule(colleges, year, weeks, seed)

	# Simulate games
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var all_results: Array = []

	for matchup in schedule:
		var result := GameSimulator.determine_winner(matchup, team_strengths, rng, cfg)
		all_results.append(result)

	return all_results
