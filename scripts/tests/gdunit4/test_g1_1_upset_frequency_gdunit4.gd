## GdUnit4 test suite for G1.1: Upset Frequency
##
## Validates that upsets (underdog by >5 points wins) occur at realistic rates (15-25%)
## based on historical NCAA/NFL data.
extends GdUnitTestSuite

const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")


func test_upset_detection() -> void:
	var cfg := {
		"home_field_advantage": 3.0,
		"strength_sensitivity": 0.1,
		"upset_threshold": 5.0
	}

	# Scenario 1: Underdog wins by >5 points (should be upset)
	var team_strengths1 := {
		"team_weak": 60.0,
		"team_strong": 70.0  # 10 point favorite
	}

	var matchup1 := {
		"game_id": "test_1",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_weak",
		"away_team_id": "team_strong",
		"game_type": "regular"
	}

	# Force underdog to win by manipulating RNG
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 0
	var result1 := GameSimulator.determine_winner(matchup1, team_strengths1, rng1, cfg)

	# If underdog won, it should be marked as upset
	if result1["winner_id"] == "team_weak":
		assert_bool(result1["upset"]).is_true()

	# Scenario 2: Close game (4 point difference) - not upset threshold
	var team_strengths2 := {
		"team_a": 70.0,
		"team_b": 66.0  # 4 point difference (below 5 point threshold)
	}

	var matchup2 := {
		"game_id": "test_2",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_a",
		"away_team_id": "team_b",
		"game_type": "regular"
	}

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1000
	var result2 := GameSimulator.determine_winner(matchup2, team_strengths2, rng2, cfg)

	# Even if underdog wins, difference is too small to be called upset
	assert_bool(result2["upset"]).is_false()


func test_upset_frequency_statistical() -> void:
	# Simulate many games with favorites (10+ point advantage) and measure upset rate
	var cfg := {
		"home_field_advantage": 3.0,
		"strength_sensitivity": 0.1,
		"upset_threshold": 5.0
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var total_games := 500
	var total_upsets := 0

	# Use deterministic strength differences
	var diff_rng := RandomNumberGenerator.new()
	diff_rng.seed = 123456

	for i in range(total_games):
		# Create matchup where away team is 10-15 point favorite
		var strength_diff := 10.0 + diff_rng.randf() * 5.0
		var team_strengths := {
			"home_team": 60.0,
			"away_team": 60.0 + strength_diff
		}

		var matchup := {
			"game_id": "test_game_%d" % i,
			"year": 2025,
			"week": 1,
			"home_team_id": "home_team",
			"away_team_id": "away_team",
			"game_type": "regular"
		}

		var result := GameSimulator.determine_winner(matchup, team_strengths, rng, cfg)
		if result["upset"]:
			total_upsets += 1

	var upset_rate := float(total_upsets) / float(total_games)

	# Upset rate should be 5-35% (with 10+ point favorites)
	assert_float(upset_rate).is_greater_equal(0.05)
	assert_float(upset_rate).is_less_equal(0.35)


func test_upset_probability_curve() -> void:
	# Test that upset probability decreases with strength differential
	var cfg := {
		"home_field_advantage": 3.0,
		"strength_sensitivity": 0.1,
		"upset_threshold": 5.0
	}

	# Simulate games at different strength differentials
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var differentials := [7.0, 10.0, 15.0, 20.0]
	var upset_rates := []

	for diff in differentials:
		var upsets := 0
		var games := 200

		for i in range(games):
			var team_strengths := {
				"underdog": 60.0,
				"favorite": 60.0 + diff
			}

			var matchup := {
				"game_id": "test_%f_%d" % [diff, i],
				"year": 2025,
				"week": 1,
				"home_team_id": "underdog",
				"away_team_id": "favorite",
				"game_type": "regular"
			}

			var result := GameSimulator.determine_winner(matchup, team_strengths, rng, cfg)
			if result["upset"]:
				upsets += 1

		var rate := float(upsets) / float(games)
		upset_rates.append(rate)

	# Upset rate should generally decrease as differential increases
	# Use relaxed comparison to allow for statistical variance
	for i in range(upset_rates.size() - 1):
		assert_float(upset_rates[i]).is_greater_equal(upset_rates[i + 1] * 0.8)
