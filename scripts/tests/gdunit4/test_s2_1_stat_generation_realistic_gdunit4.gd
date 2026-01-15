## GdUnit4 test suite for S2.1: Stat Generation Realism
##
## Validates that generated stats are realistic and correlate with player ratings.
## Tests that higher-rated players produce better statistics.
extends GdUnitTestSuite

const StatGenerator = preload("res://scripts/core/game_simulation/StatGenerator.gd")
const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")


func test_qb_rating_correlation() -> void:
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Low-rated QB
	var low_qb_roster := {
		"players": [
			{"player_id": "qb_low", "position": "QB", "composite_score": 50.0}
		]
	}

	# High-rated QB
	var high_qb_roster := {
		"players": [
			{"player_id": "qb_high", "position": "QB", "composite_score": 95.0}
		]
	}

	var opponent := {
		"players": [
			{"player_id": "opponent", "position": "QB", "composite_score": 70.0}
		]
	}

	var game_result := {
		"game_id": "test_qb_rating",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_low",
		"away_team_id": "team_high",
		"winner_id": "team_high",  # High QB wins
		"loser_id": "team_low",
		"game_type": "regular"
	}

	var world_state := {}

	# Generate stats for low QB
	rng.seed = 12345  # Reset seed for fair comparison
	GameSimulator.accumulate_player_stats(
		world_state,
		game_result,
		low_qb_roster,
		opponent,
		positions_cfg,
		main_cfg,
		rng
	)

	# Generate stats for high QB (change home/away)
	rng.seed = 12345  # Reset seed for fair comparison
	game_result["home_team_id"] = "team_high"
	game_result["away_team_id"] = "team_low"
	GameSimulator.accumulate_player_stats(
		world_state,
		game_result,
		opponent,
		high_qb_roster,
		positions_cfg,
		main_cfg,
		rng
	)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var low_stats: Dictionary = career_stats["qb_low"][2025]
	var high_stats: Dictionary = career_stats["qb_high"][2025]

	# High-rated QB should have better stats
	assert_int(int(high_stats["pass_attempts"])).is_greater(int(low_stats["pass_attempts"]))
	assert_int(int(high_stats["pass_yards"])).is_greater(int(low_stats["pass_yards"]))
	assert_int(int(high_stats["pass_tds"])).is_greater(int(low_stats["pass_tds"]))
	assert_int(int(high_stats["interceptions"])).is_less(int(low_stats["interceptions"]))

	# Completion percentage should be better for high-rated QB
	var low_pct := float(low_stats["pass_completions"]) / float(low_stats["pass_attempts"])
	var high_pct := float(high_stats["pass_completions"]) / float(high_stats["pass_attempts"])
	assert_float(high_pct).is_greater(low_pct)


func test_rb_rating_correlation() -> void:
	var positions_cfg := {"RB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()

	var low_rb := {"player_id": "rb_low", "position": "RB", "composite_score": 50.0}
	var high_rb := {"player_id": "rb_high", "position": "RB", "composite_score": 95.0}

	var world_state := {}
	var opponent := {"players": [{"player_id": "opp", "position": "RB", "composite_score": 70.0}]}

	# Low RB game
	rng.seed = 54321
	var game1 := {
		"game_id": "rb_low_game",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_001",
		"away_team_id": "team_002",
		"winner_id": "team_001",
		"loser_id": "team_002",
		"game_type": "regular"
	}
	GameSimulator.accumulate_player_stats(
		world_state,
		game1,
		{"players": [low_rb]},
		opponent,
		positions_cfg,
		main_cfg,
		rng
	)

	# High RB game
	rng.seed = 54321  # Reset seed
	var game2 := {
		"game_id": "rb_high_game",
		"year": 2025,
		"week": 2,
		"home_team_id": "team_003",
		"away_team_id": "team_004",
		"winner_id": "team_003",
		"loser_id": "team_004",
		"game_type": "regular"
	}
	GameSimulator.accumulate_player_stats(
		world_state,
		game2,
		{"players": [high_rb]},
		opponent,
		positions_cfg,
		main_cfg,
		rng
	)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var low_stats: Dictionary = career_stats["rb_low"][2025]
	var high_stats: Dictionary = career_stats["rb_high"][2025]

	# High RB should have better stats
	assert_int(int(high_stats["rush_attempts"])).is_greater(int(low_stats["rush_attempts"]))
	assert_int(int(high_stats["rush_yards"])).is_greater(int(low_stats["rush_yards"]))

	# Yards per carry should be better
	var low_ypc := float(low_stats["rush_yards"]) / float(max(1, low_stats["rush_attempts"]))
	var high_ypc := float(high_stats["rush_yards"]) / float(max(1, high_stats["rush_attempts"]))
	assert_float(high_ypc).is_greater(low_ypc)


func test_wr_rating_correlation() -> void:
	var positions_cfg := {"WR": {"core_stats": []}, "QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()

	var world_state := {}
	var opponent := {"players": [{"player_id": "opp", "position": "WR", "composite_score": 70.0}]}

	var low_wr := {"player_id": "wr_low", "position": "WR", "composite_score": 50.0}
	var high_wr := {"player_id": "wr_high", "position": "WR", "composite_score": 95.0}

	# Test low WR
	rng.seed = 99999
	var game1 := {
		"game_id": "wr_low_game",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_001",
		"away_team_id": "team_002",
		"winner_id": "team_001",
		"loser_id": "team_002",
		"game_type": "regular"
	}
	GameSimulator.accumulate_player_stats(
		world_state,
		game1,
		{"players": [low_wr]},
		opponent,
		positions_cfg,
		main_cfg,
		rng
	)

	# Test high WR
	rng.seed = 99999  # Reset seed
	var game2 := {
		"game_id": "wr_high_game",
		"year": 2025,
		"week": 2,
		"home_team_id": "team_003",
		"away_team_id": "team_004",
		"winner_id": "team_003",
		"loser_id": "team_004",
		"game_type": "regular"
	}
	GameSimulator.accumulate_player_stats(
		world_state,
		game2,
		{"players": [high_wr]},
		opponent,
		positions_cfg,
		main_cfg,
		rng
	)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var low_stats: Dictionary = career_stats["wr_low"][2025]
	var high_stats: Dictionary = career_stats["wr_high"][2025]

	# High WR should have better stats
	assert_int(int(high_stats["targets"])).is_greater(int(low_stats["targets"]))
	assert_int(int(high_stats["receptions"])).is_greater(int(low_stats["receptions"]))
	assert_int(int(high_stats["receiving_yards"])).is_greater(int(low_stats["receiving_yards"]))


func test_defensive_rating_correlation() -> void:
	var positions_cfg := {"LB": {"core_stats": []}, "QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()

	var world_state := {}
	var opponent := {"players": [{"player_id": "opp", "position": "QB", "composite_score": 70.0}]}

	var low_lb := {"player_id": "lb_low", "position": "LB", "composite_score": 50.0}
	var high_lb := {"player_id": "lb_high", "position": "LB", "composite_score": 95.0}

	# Test low LB
	rng.seed = 11111
	var game1 := {
		"game_id": "lb_low_game",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_001",
		"away_team_id": "team_002",
		"winner_id": "team_001",
		"loser_id": "team_002",
		"game_type": "regular"
	}
	GameSimulator.accumulate_player_stats(
		world_state,
		game1,
		{"players": [low_lb]},
		opponent,
		positions_cfg,
		main_cfg,
		rng
	)

	# Test high LB
	rng.seed = 11111  # Reset seed
	var game2 := {
		"game_id": "lb_high_game",
		"year": 2025,
		"week": 2,
		"home_team_id": "team_003",
		"away_team_id": "team_004",
		"winner_id": "team_003",
		"loser_id": "team_004",
		"game_type": "regular"
	}
	GameSimulator.accumulate_player_stats(
		world_state,
		game2,
		{"players": [high_lb]},
		opponent,
		positions_cfg,
		main_cfg,
		rng
	)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var low_stats: Dictionary = career_stats["lb_low"][2025]
	var high_stats: Dictionary = career_stats["lb_high"][2025]

	# High LB should have more tackles
	assert_int(int(high_stats["tackles"])).is_greater(int(low_stats["tackles"]))
	assert_int(int(high_stats["tackles_for_loss"])).is_greater(int(low_stats["tackles_for_loss"]))


func test_starter_vs_bench_stats() -> void:
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 22222

	# Team with 3 QBs - only best should be starter
	var roster := {
		"players": [
			{"player_id": "qb_starter", "position": "QB", "composite_score": 90.0},
			{"player_id": "qb_backup1", "position": "QB", "composite_score": 70.0},
			{"player_id": "qb_backup2", "position": "QB", "composite_score": 60.0}
		]
	}
	var opponent := {"players": [{"player_id": "opp", "position": "QB", "composite_score": 75.0}]}

	var world_state := {}
	var game_result := {
		"game_id": "starter_test",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_001",
		"away_team_id": "team_002",
		"winner_id": "team_001",
		"loser_id": "team_002",
		"game_type": "regular"
	}

	GameSimulator.accumulate_player_stats(
		world_state,
		game_result,
		roster,
		opponent,
		positions_cfg,
		main_cfg,
		rng
	)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var starter_stats: Dictionary = career_stats["qb_starter"][2025]
	var backup1_stats: Dictionary = career_stats["qb_backup1"][2025]
	var backup2_stats: Dictionary = career_stats["qb_backup2"][2025]

	# All should have games_played = 1
	assert_int(int(starter_stats["games_played"])).is_equal(1)
	assert_int(int(backup1_stats["games_played"])).is_equal(1)
	assert_int(int(backup2_stats["games_played"])).is_equal(1)

	# Only starter should have games_started = 1
	assert_int(int(starter_stats["games_started"])).is_equal(1)
	assert_int(int(backup1_stats["games_started"])).is_equal(0)
	assert_int(int(backup2_stats["games_started"])).is_equal(0)

	# Starter should have significantly more stats
	assert_int(int(starter_stats["pass_attempts"])).is_greater(int(backup1_stats["pass_attempts"]))
	assert_int(int(starter_stats["pass_attempts"])).is_greater(int(backup2_stats["pass_attempts"]))
	assert_int(int(starter_stats["pass_yards"])).is_greater(int(backup1_stats["pass_yards"]))


func test_winner_bonus_stats() -> void:
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()

	var world_state := {}
	var qb_winner := {"player_id": "qb_winner", "position": "QB", "composite_score": 80.0}
	var qb_loser := {"player_id": "qb_loser", "position": "QB", "composite_score": 80.0}

	# Winner QB
	rng.seed = 33333
	var game1 := {
		"game_id": "winner_game",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_winner",
		"away_team_id": "team_loser",
		"winner_id": "team_winner",
		"loser_id": "team_loser",
		"game_type": "regular"
	}
	GameSimulator.accumulate_player_stats(
		world_state,
		game1,
		{"players": [qb_winner]},
		{"players": [qb_loser]},
		positions_cfg,
		main_cfg,
		rng
	)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var winner_stats: Dictionary = career_stats["qb_winner"][2025]
	var loser_stats: Dictionary = career_stats["qb_loser"][2025]

	# Winner should generally have better TD/INT ratio
	var winner_td_int_ratio := float(winner_stats["pass_tds"]) / float(max(1, winner_stats["interceptions"]))
	var loser_td_int_ratio := float(loser_stats["pass_tds"]) / float(max(1, loser_stats["interceptions"]))

	assert_float(winner_td_int_ratio).is_greater_equal(loser_td_int_ratio)


func test_stat_determinism() -> void:
	var positions_cfg := {"QB": {"core_stats": []}, "RB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}

	var roster := {
		"players": [
			{"player_id": "qb_det", "position": "QB", "composite_score": 85.0},
			{"player_id": "rb_det", "position": "RB", "composite_score": 80.0}
		]
	}
	var opponent := {"players": [{"player_id": "opp", "position": "QB", "composite_score": 75.0}]}

	var game_result := {
		"game_id": "det_test",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_001",
		"away_team_id": "team_002",
		"winner_id": "team_001",
		"loser_id": "team_002",
		"game_type": "regular"
	}

	# Run same simulation 3 times with same seed
	var results := []
	for i in range(3):
		var world_state := {}
		var rng := RandomNumberGenerator.new()
		rng.seed = 44444  # Same seed each time

		GameSimulator.accumulate_player_stats(
			world_state,
			game_result,
			roster,
			opponent,
			positions_cfg,
			main_cfg,
			rng
		)

		var career_stats: Dictionary = world_state["player_career_stats"]
		results.append(career_stats["qb_det"][2025])

	# All 3 runs should produce identical stats
	assert_int(int(results[0]["pass_attempts"])).is_equal(int(results[1]["pass_attempts"]))
	assert_int(int(results[0]["pass_attempts"])).is_equal(int(results[2]["pass_attempts"]))
	assert_int(int(results[0]["pass_yards"])).is_equal(int(results[1]["pass_yards"]))
	assert_int(int(results[0]["pass_yards"])).is_equal(int(results[2]["pass_yards"]))
	assert_int(int(results[0]["pass_tds"])).is_equal(int(results[1]["pass_tds"]))
	assert_int(int(results[0]["interceptions"])).is_equal(int(results[1]["interceptions"]))
