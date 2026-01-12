extends RefCounted

## Test G1.1: Home Advantage Realism
##
## Validates that home team win rates are in the expected range (55-65%)
## based on real-world NCAA/NFL statistics.

const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")

func run(t) -> void:
	_test_equal_teams_home_advantage(t)
	_test_home_win_rate_statistical(t)


func _test_equal_teams_home_advantage(t) -> void:
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
	t.assert_gte(home_win_prob, 0.55, "Home team win probability should be >= 55%")
	t.assert_lte(home_win_prob, 0.62, "Home team win probability should be <= 62%")

	# Neutral site (no home advantage) should be 50%
	var neutral_prob := GameSimulator.calculate_win_probability(
		home_strength,
		away_strength,
		false,  # not home
		cfg
	)
	t.assert_eq(neutral_prob, 0.5, "Neutral site should be 50/50 for equal teams")


func _test_home_win_rate_statistical(t) -> void:
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
	t.assert_gte(home_win_rate, 0.53, "Home win rate should be >= 53% (accounting for variance)")
	t.assert_lte(home_win_rate, 0.67, "Home win rate should be <= 67% (accounting for variance)")

	# Print for manual inspection
	print("Home win rate: %.1f%% (expected 55-62%%)" % (home_win_rate * 100.0))


## Bonus: Test that home advantage scales appropriately with strength differential
func _test_home_advantage_scaling(t) -> void:
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
	t.assert_gte(prob1, 0.68, "Stronger home team should have >= 68% win prob")
	t.assert_lte(prob1, 0.75, "Stronger home team should have <= 75% win prob")

	t.assert_gte(prob2, 0.43, "Weaker home team should still have >= 43% chance")
	t.assert_lte(prob2, 0.50, "Weaker home team should have <= 50% chance")

	print("Home favorite (75 vs 70): %.1f%%" % (prob1 * 100.0))
	print("Home underdog (70 vs 75): %.1f%%" % (prob2 * 100.0))
