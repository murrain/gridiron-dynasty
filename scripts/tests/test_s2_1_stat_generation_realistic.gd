extends RefCounted

## Test S2.1: Stat Generation Realism
##
## Validates that generated stats are realistic and correlate with player ratings.
## Tests that higher-rated players produce better statistics.

const StatGenerator = preload("res://scripts/core/game_simulation/StatGenerator.gd")
const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")

func run(t) -> void:
	_test_qb_rating_correlation(t)
	_test_rb_rating_correlation(t)
	_test_wr_rating_correlation(t)
	_test_defensive_rating_correlation(t)
	_test_starter_vs_bench_stats(t)
	_test_winner_bonus_stats(t)
	_test_stat_determinism(t)


func _test_qb_rating_correlation(t) -> void:
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
	t.assert_gt(high_stats["pass_attempts"], low_stats["pass_attempts"], "High QB should attempt more passes")
	t.assert_gt(high_stats["pass_yards"], low_stats["pass_yards"], "High QB should have more yards")
	t.assert_gt(high_stats["pass_tds"], low_stats["pass_tds"], "High QB should have more TDs")
	t.assert_lt(high_stats["interceptions"], low_stats["interceptions"], "High QB should have fewer INTs")

	# Completion percentage should be better for high-rated QB
	var low_pct := float(low_stats["pass_completions"]) / float(low_stats["pass_attempts"])
	var high_pct := float(high_stats["pass_completions"]) / float(high_stats["pass_attempts"])
	t.assert_gt(high_pct, low_pct, "High QB should have better completion percentage")


func _test_rb_rating_correlation(t) -> void:
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
	t.assert_gt(high_stats["rush_attempts"], low_stats["rush_attempts"], "High RB gets more carries")
	t.assert_gt(high_stats["rush_yards"], low_stats["rush_yards"], "High RB gains more yards")

	# Yards per carry should be better
	var low_ypc := float(low_stats["rush_yards"]) / float(max(1, low_stats["rush_attempts"]))
	var high_ypc := float(high_stats["rush_yards"]) / float(max(1, high_stats["rush_attempts"]))
	t.assert_gt(high_ypc, low_ypc, "High RB should have better YPC")


func _test_wr_rating_correlation(t) -> void:
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
	t.assert_gt(high_stats["targets"], low_stats["targets"], "High WR gets more targets")
	t.assert_gt(high_stats["receptions"], low_stats["receptions"], "High WR has more receptions")
	t.assert_gt(high_stats["receiving_yards"], low_stats["receiving_yards"], "High WR has more yards")


func _test_defensive_rating_correlation(t) -> void:
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
	t.assert_gt(high_stats["tackles"], low_stats["tackles"], "High LB has more tackles")
	t.assert_gt(high_stats["tackles_for_loss"], low_stats["tackles_for_loss"], "High LB has more TFLs")


func _test_starter_vs_bench_stats(t) -> void:
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
	t.assert_eq(starter_stats["games_played"], 1, "Starter played")
	t.assert_eq(backup1_stats["games_played"], 1, "Backup1 played")
	t.assert_eq(backup2_stats["games_played"], 1, "Backup2 played")

	# Only starter should have games_started = 1
	t.assert_eq(starter_stats["games_started"], 1, "Starter should have started")
	t.assert_eq(backup1_stats["games_started"], 0, "Backup1 should not have started")
	t.assert_eq(backup2_stats["games_started"], 0, "Backup2 should not have started")

	# Starter should have significantly more stats
	t.assert_gt(starter_stats["pass_attempts"], backup1_stats["pass_attempts"], "Starter has more attempts than backup1")
	t.assert_gt(starter_stats["pass_attempts"], backup2_stats["pass_attempts"], "Starter has more attempts than backup2")
	t.assert_gt(starter_stats["pass_yards"], backup1_stats["pass_yards"], "Starter has more yards than backup1")


func _test_winner_bonus_stats(t) -> void:
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
	# (This is probabilistic but with same seed and rating, winner should perform better)
	var winner_td_int_ratio := float(winner_stats["pass_tds"]) / float(max(1, winner_stats["interceptions"]))
	var loser_td_int_ratio := float(loser_stats["pass_tds"]) / float(max(1, loser_stats["interceptions"]))

	t.assert_ge(winner_td_int_ratio, loser_td_int_ratio, "Winner should have better or equal TD/INT ratio")


func _test_stat_determinism(t) -> void:
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
	t.assert_eq(results[0]["pass_attempts"], results[1]["pass_attempts"], "Run 1 vs 2: pass_attempts deterministic")
	t.assert_eq(results[0]["pass_attempts"], results[2]["pass_attempts"], "Run 1 vs 3: pass_attempts deterministic")
	t.assert_eq(results[0]["pass_yards"], results[1]["pass_yards"], "Run 1 vs 2: pass_yards deterministic")
	t.assert_eq(results[0]["pass_yards"], results[2]["pass_yards"], "Run 1 vs 3: pass_yards deterministic")
	t.assert_eq(results[0]["pass_tds"], results[1]["pass_tds"], "Run 1 vs 2: pass_tds deterministic")
	t.assert_eq(results[0]["interceptions"], results[1]["interceptions"], "Run 1 vs 2: interceptions deterministic")
