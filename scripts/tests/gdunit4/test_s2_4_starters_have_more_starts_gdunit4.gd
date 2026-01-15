## GdUnit4 test suite for S2.4: Starters Have More Starts
##
## Validates that higher-rated players are correctly identified as starters
## and have higher games_started counts than bench players.
extends GdUnitTestSuite

const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")
const StatGenerator = preload("res://scripts/core/game_simulation/StatGenerator.gd")


func test_single_starter_per_position() -> void:
	var world_state := {}
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# QB depth chart: starter (90), backup1 (70), backup2 (60)
	var roster := {
		"players": [
			{"player_id": "qb_starter", "position": "QB", "composite_score": 90.0},
			{"player_id": "qb_backup1", "position": "QB", "composite_score": 70.0},
			{"player_id": "qb_backup2", "position": "QB", "composite_score": 60.0}
		]
	}
	var opponent := {
		"players": [
			{"player_id": "opponent", "position": "QB", "composite_score": 75.0}
		]
	}

	var game_result := {
		"game_id": "test_starter",
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

	# Only highest-rated QB should be starter
	assert_int(int(career_stats["qb_starter"][2025]["games_started"])).is_equal(1)
	assert_int(int(career_stats["qb_backup1"][2025]["games_started"])).is_equal(0)
	assert_int(int(career_stats["qb_backup2"][2025]["games_started"])).is_equal(0)

	# All should have games_played
	assert_int(int(career_stats["qb_starter"][2025]["games_played"])).is_equal(1)
	assert_int(int(career_stats["qb_backup1"][2025]["games_played"])).is_equal(1)
	assert_int(int(career_stats["qb_backup2"][2025]["games_played"])).is_equal(1)


func test_multiple_starters_by_rating() -> void:
	var world_state := {}
	var positions_cfg := {"WR": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321

	# WR depth chart: 5 WRs, top 3 should start (per STARTER_POSITION_THRESHOLDS)
	var roster := {
		"players": [
			{"player_id": "wr1", "position": "WR", "composite_score": 95.0},  # Starter
			{"player_id": "wr2", "position": "WR", "composite_score": 85.0},  # Starter
			{"player_id": "wr3", "position": "WR", "composite_score": 80.0},  # Starter
			{"player_id": "wr4", "position": "WR", "composite_score": 70.0},  # Bench
			{"player_id": "wr5", "position": "WR", "composite_score": 60.0}   # Bench
		]
	}
	var opponent := {
		"players": [
			{"player_id": "opponent", "position": "WR", "composite_score": 75.0}
		]
	}

	var game_result := {
		"game_id": "test_wr_depth",
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

	# Top 3 WRs should be starters
	assert_int(int(career_stats["wr1"][2025]["games_started"])).is_equal(1)
	assert_int(int(career_stats["wr2"][2025]["games_started"])).is_equal(1)
	assert_int(int(career_stats["wr3"][2025]["games_started"])).is_equal(1)

	# Bottom 2 WRs should be bench
	assert_int(int(career_stats["wr4"][2025]["games_started"])).is_equal(0)
	assert_int(int(career_stats["wr5"][2025]["games_started"])).is_equal(0)

	# All should have games_played
	for i in range(1, 6):
		var wr_id := "wr%d" % i
		assert_int(int(career_stats[wr_id][2025]["games_played"])).is_equal(1)


func test_games_started_less_than_or_equal_games_played() -> void:
	var world_state := {}
	var positions_cfg := {
		"QB": {"core_stats": []},
		"RB": {"core_stats": []},
		"WR": {"core_stats": []},
		"LB": {"core_stats": []}
	}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 99999

	var roster := {
		"players": [
			{"player_id": "qb1", "position": "QB", "composite_score": 85.0},
			{"player_id": "qb2", "position": "QB", "composite_score": 70.0},
			{"player_id": "rb1", "position": "RB", "composite_score": 80.0},
			{"player_id": "rb2", "position": "RB", "composite_score": 75.0},
			{"player_id": "wr1", "position": "WR", "composite_score": 85.0},
			{"player_id": "lb1", "position": "LB", "composite_score": 80.0}
		]
	}
	var opponent := {
		"players": [
			{"player_id": "opponent", "position": "QB", "composite_score": 75.0}
		]
	}

	# Simulate 10 games
	for week in range(1, 11):
		var game_result := {
			"game_id": "season_w%d" % week,
			"year": 2025,
			"week": week,
			"home_team_id": "team_001",
			"away_team_id": "team_002",
			"winner_id": "team_001" if week % 2 == 0 else "team_002",
			"loser_id": "team_002" if week % 2 == 0 else "team_001",
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

	# Verify invariant: games_started <= games_played for ALL players
	for player_id in career_stats.keys():
		if player_id == "opponent":
			continue

		var stats: Dictionary = career_stats[player_id][2025]
		var games_played := int(stats["games_played"])
		var games_started := int(stats["games_started"])

		assert_int(games_started).is_less_equal(games_played)


func test_starter_determination_by_position() -> void:
	var world_state := {}
	var positions_cfg := {
		"QB": {"core_stats": []},
		"RB": {"core_stats": []},
		"LB": {"core_stats": []},
		"CB": {"core_stats": []}
	}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111

	# Test multiple positions with different starter counts
	var roster := {
		"players": [
			# QB: 1 starter expected
			{"player_id": "qb1", "position": "QB", "composite_score": 90.0},
			{"player_id": "qb2", "position": "QB", "composite_score": 70.0},

			# RB: 2 starters expected
			{"player_id": "rb1", "position": "RB", "composite_score": 85.0},
			{"player_id": "rb2", "position": "RB", "composite_score": 80.0},
			{"player_id": "rb3", "position": "RB", "composite_score": 70.0},

			# LB: 3 starters expected
			{"player_id": "lb1", "position": "LB", "composite_score": 90.0},
			{"player_id": "lb2", "position": "LB", "composite_score": 85.0},
			{"player_id": "lb3", "position": "LB", "composite_score": 80.0},
			{"player_id": "lb4", "position": "LB", "composite_score": 70.0},

			# CB: 2 starters expected
			{"player_id": "cb1", "position": "CB", "composite_score": 85.0},
			{"player_id": "cb2", "position": "CB", "composite_score": 82.0},
			{"player_id": "cb3", "position": "CB", "composite_score": 75.0}
		]
	}
	var opponent := {
		"players": [
			{"player_id": "opponent", "position": "QB", "composite_score": 75.0}
		]
	}

	var game_result := {
		"game_id": "position_test",
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

	# QB: Only top 1 starts
	assert_int(int(career_stats["qb1"][2025]["games_started"])).is_equal(1)
	assert_int(int(career_stats["qb2"][2025]["games_started"])).is_equal(0)

	# RB: Top 2 start
	assert_int(int(career_stats["rb1"][2025]["games_started"])).is_equal(1)
	assert_int(int(career_stats["rb2"][2025]["games_started"])).is_equal(1)
	assert_int(int(career_stats["rb3"][2025]["games_started"])).is_equal(0)

	# LB: Top 3 start
	assert_int(int(career_stats["lb1"][2025]["games_started"])).is_equal(1)
	assert_int(int(career_stats["lb2"][2025]["games_started"])).is_equal(1)
	assert_int(int(career_stats["lb3"][2025]["games_started"])).is_equal(1)
	assert_int(int(career_stats["lb4"][2025]["games_started"])).is_equal(0)

	# CB: Top 2 start
	assert_int(int(career_stats["cb1"][2025]["games_started"])).is_equal(1)
	assert_int(int(career_stats["cb2"][2025]["games_started"])).is_equal(1)
	assert_int(int(career_stats["cb3"][2025]["games_started"])).is_equal(0)


func test_starters_accumulate_across_season() -> void:
	var world_state := {}
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 22222

	var roster := {
		"players": [
			{"player_id": "qb_starter", "position": "QB", "composite_score": 85.0},
			{"player_id": "qb_backup", "position": "QB", "composite_score": 65.0}
		]
	}
	var opponent := {
		"players": [
			{"player_id": "opponent", "position": "QB", "composite_score": 75.0}
		]
	}

	# Simulate 12-game season
	for week in range(1, 13):
		var game_result := {
			"game_id": "season_w%d" % week,
			"year": 2025,
			"week": week,
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
	var backup_stats: Dictionary = career_stats["qb_backup"][2025]

	# Starter should have started all 12 games
	assert_int(int(starter_stats["games_started"])).is_equal(12)
	assert_int(int(starter_stats["games_played"])).is_equal(12)

	# Backup should have played all 12 but started 0
	assert_int(int(backup_stats["games_started"])).is_equal(0)
	assert_int(int(backup_stats["games_played"])).is_equal(12)

	# Starter should have significantly more accumulated stats
	assert_int(int(starter_stats["pass_attempts"])).is_greater(int(backup_stats["pass_attempts"]) * 3)


func test_depth_chart_positions() -> void:
	var world_state := {}
	var positions_cfg := {"OL": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 33333

	# OL depth chart: 7 players, top 5 should start
	var roster := {
		"players": [
			{"player_id": "ol1", "position": "OL", "composite_score": 90.0},
			{"player_id": "ol2", "position": "OL", "composite_score": 87.0},
			{"player_id": "ol3", "position": "OL", "composite_score": 84.0},
			{"player_id": "ol4", "position": "OL", "composite_score": 81.0},
			{"player_id": "ol5", "position": "OL", "composite_score": 78.0},
			{"player_id": "ol6", "position": "OL", "composite_score": 70.0},
			{"player_id": "ol7", "position": "OL", "composite_score": 65.0}
		]
	}
	var opponent := {
		"players": [
			{"player_id": "opponent", "position": "OL", "composite_score": 75.0}
		]
	}

	var game_result := {
		"game_id": "ol_test",
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

	# Top 5 OL should be starters
	for i in range(1, 6):
		var ol_id := "ol%d" % i
		assert_int(int(career_stats[ol_id][2025]["games_started"])).is_equal(1)

	# Bottom 2 OL should be bench
	assert_int(int(career_stats["ol6"][2025]["games_started"])).is_equal(0)
	assert_int(int(career_stats["ol7"][2025]["games_started"])).is_equal(0)
