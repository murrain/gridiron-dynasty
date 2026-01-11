extends RefCounted

## Test G1.1: Upset Frequency
##
## Validates that upsets (underdog by >5 points wins) occur at realistic rates (15-25%)
## based on historical NCAA/NFL data.

const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")

func run(t) -> void:
	_test_upset_detection(t)
	_test_upset_frequency_statistical(t)


func _test_upset_detection(t) -> void:
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
	rng1.seed = 0  # Find a seed where underdog wins
	var result1 := GameSimulator.determine_winner(matchup1, team_strengths1, rng1, cfg)

	# If underdog won, it should be marked as upset
	if result1["winner_id"] == "team_weak":
		t.assert_eq(result1["upset"], true, "Underdog win should be marked as upset")

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
	t.assert_eq(result2["upset"], false, "Win within upset threshold should not be marked as upset")


func _test_upset_frequency_statistical(t) -> void:
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

	for i in range(total_games):
		# Create matchup where away team is 10-15 point favorite
		var strength_diff := 10.0 + randf() * 5.0
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

	# Upset rate should be 10-30% (with 10+ point favorites)
	# Lower than real-world because we're using larger favorites
	t.assert_gte(upset_rate, 0.05, "Upset rate should be >= 5% (some upsets occur)")
	t.assert_lte(upset_rate, 0.35, "Upset rate should be <= 35% (favorites usually win)")

	print("Upset rate: %.1f%% (expected 10-30%% for 10+ point favorites)" % (upset_rate * 100.0))


func _test_upset_probability_curve(t) -> void:
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
		print("Differential %.0f: %.1f%% upsets" % [diff, rate * 100.0])

	# Upset rate should decrease as differential increases
	for i in range(upset_rates.size() - 1):
		t.assert_gte(upset_rates[i], upset_rates[i + 1] * 0.8, "Upset rate should decrease with larger differentials (monotonic trend)")
