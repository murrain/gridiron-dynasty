## GdUnit4 test suite for G1.1: Home Advantage Realism
##
## Validates that home team win rates are in the expected range (55-65%)
## based on real-world NCAA/NFL statistics.
extends GdUnitTestSuite

const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")


func test_equal_teams_home_advantage() -> void:
	# With equal teams, home advantage should produce ~58% win rate
	var cfg := {
		"home_field_advantage": 3.0,
		"strength_sensitivity": 0.1,
		"upset_threshold": 5.0
	}

	var home_strength := 70.0
	var away_strength := 70.0

	# Calculate win probability
	var home_win_prob := GameSimulator.calculate_win_probability(
		home_strength,
		away_strength,
		true,  # is_home
		cfg
	)

	# Should be between 55% and 62% (3 point advantage with k=0.1)
	assert_float(home_win_prob).is_greater_equal(0.55)
	assert_float(home_win_prob).is_less_equal(0.62)

	# Neutral site (no home advantage) should be 50%
	var neutral_prob := GameSimulator.calculate_win_probability(
		home_strength,
		away_strength,
		false,  # not home
		cfg
	)
	assert_float(neutral_prob).is_equal(0.5)


func test_home_win_rate_statistical() -> void:
	# Simulate 1000 games between equal teams and verify home win rate
	var cfg := {
		"home_field_advantage": 3.0,
		"strength_sensitivity": 0.1,
		"upset_threshold": 5.0
	}

	var team_strengths := {
		"home_team": 70.0,
		"away_team": 70.0
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var home_wins := 0
	var total_games := 1000

	for i in range(total_games):
		var matchup := {
			"game_id": "test_game_%d" % i,
			"year": 2025,
			"week": 1,
			"home_team_id": "home_team",
			"away_team_id": "away_team",
			"game_type": "regular"
		}

		var result := GameSimulator.determine_winner(matchup, team_strengths, rng, cfg)
		if result["winner_id"] == "home_team":
			home_wins += 1

	var home_win_rate := float(home_wins) / float(total_games)

	# With 1000 games, we expect 55-65% home win rate (within statistical variance)
	assert_float(home_win_rate).is_greater_equal(0.53)
	assert_float(home_win_rate).is_less_equal(0.67)


func test_home_advantage_scaling() -> void:
	var cfg := {
		"home_field_advantage": 3.0,
		"strength_sensitivity": 0.1,
		"upset_threshold": 5.0
	}

	# Scenario 1: Home team slightly stronger (75 vs 70)
	var prob1 := GameSimulator.calculate_win_probability(75.0, 70.0, true, cfg)
	# Expected: ~71% (5 point diff + 3 point home = 8 point total advantage)

	# Scenario 2: Away team slightly stronger (70 vs 75)
	var prob2 := GameSimulator.calculate_win_probability(70.0, 75.0, true, cfg)
	# Expected: ~46% (home advantage partially offsets away team's strength)

	# Home advantage should provide meaningful but not overwhelming boost
	assert_float(prob1).is_greater_equal(0.68)
	assert_float(prob1).is_less_equal(0.75)

	assert_float(prob2).is_greater_equal(0.43)
	assert_float(prob2).is_less_equal(0.50)
