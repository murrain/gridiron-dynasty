extends RefCounted

## Test S2.4: Starters Have More Starts
##
## Validates that higher-rated players are correctly identified as starters
## and have higher games_started counts than bench players.

const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")
const StatGenerator = preload("res://scripts/core/game_simulation/StatGenerator.gd")

func run(t) -> void:
	_test_single_starter_per_position(t)
	_test_multiple_starters_by_rating(t)
	_test_games_started_less_than_or_equal_games_played(t)
	_test_starter_determination_by_position(t)
	_test_starters_accumulate_across_season(t)
	_test_depth_chart_positions(t)


func _test_single_starter_per_position(t) -> void:
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
	t.assert_eq(career_stats["qb_starter"][2025]["games_started"], 1, "Highest rated QB starts")
	t.assert_eq(career_stats["qb_backup1"][2025]["games_started"], 0, "Backup1 doesn't start")
	t.assert_eq(career_stats["qb_backup2"][2025]["games_started"], 0, "Backup2 doesn't start")

	# All should have games_played
	t.assert_eq(career_stats["qb_starter"][2025]["games_played"], 1, "Starter played")
	t.assert_eq(career_stats["qb_backup1"][2025]["games_played"], 1, "Backup1 played")
	t.assert_eq(career_stats["qb_backup2"][2025]["games_played"], 1, "Backup2 played")


func _test_multiple_starters_by_rating(t) -> void:
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
	t.assert_eq(career_stats["wr1"][2025]["games_started"], 1, "WR1 (highest) starts")
	t.assert_eq(career_stats["wr2"][2025]["games_started"], 1, "WR2 (second) starts")
	t.assert_eq(career_stats["wr3"][2025]["games_started"], 1, "WR3 (third) starts")

	# Bottom 2 WRs should be bench
	t.assert_eq(career_stats["wr4"][2025]["games_started"], 0, "WR4 is backup")
	t.assert_eq(career_stats["wr5"][2025]["games_started"], 0, "WR5 is backup")

	# All should have games_played
	for i in range(1, 6):
		var wr_id := "wr%d" % i
		t.assert_eq(career_stats[wr_id][2025]["games_played"], 1, "%s played" % wr_id)


func _test_games_started_less_than_or_equal_games_played(t) -> void:
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

		t.assert_le(games_started, games_played,
			"%s: games_started (%d) <= games_played (%d)" % [player_id, games_started, games_played])


func _test_starter_determination_by_position(t) -> void:
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
	t.assert_eq(career_stats["qb1"][2025]["games_started"], 1, "QB1 starts")
	t.assert_eq(career_stats["qb2"][2025]["games_started"], 0, "QB2 doesn't start")

	# RB: Top 2 start
	t.assert_eq(career_stats["rb1"][2025]["games_started"], 1, "RB1 starts")
	t.assert_eq(career_stats["rb2"][2025]["games_started"], 1, "RB2 starts")
	t.assert_eq(career_stats["rb3"][2025]["games_started"], 0, "RB3 doesn't start")

	# LB: Top 3 start
	t.assert_eq(career_stats["lb1"][2025]["games_started"], 1, "LB1 starts")
	t.assert_eq(career_stats["lb2"][2025]["games_started"], 1, "LB2 starts")
	t.assert_eq(career_stats["lb3"][2025]["games_started"], 1, "LB3 starts")
	t.assert_eq(career_stats["lb4"][2025]["games_started"], 0, "LB4 doesn't start")

	# CB: Top 2 start
	t.assert_eq(career_stats["cb1"][2025]["games_started"], 1, "CB1 starts")
	t.assert_eq(career_stats["cb2"][2025]["games_started"], 1, "CB2 starts")
	t.assert_eq(career_stats["cb3"][2025]["games_started"], 0, "CB3 doesn't start")


func _test_starters_accumulate_across_season(t) -> void:
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
	t.assert_eq(starter_stats["games_started"], 12, "Starter started all 12 games")
	t.assert_eq(starter_stats["games_played"], 12, "Starter played all 12 games")

	# Backup should have played all 12 but started 0
	t.assert_eq(backup_stats["games_started"], 0, "Backup started 0 games")
	t.assert_eq(backup_stats["games_played"], 12, "Backup played all 12 games")

	# Starter should have significantly more accumulated stats
	t.assert_gt(starter_stats["pass_attempts"], backup_stats["pass_attempts"] * 3,
		"Starter has 3x+ more attempts than backup")


func _test_depth_chart_positions(t) -> void:
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
		t.assert_eq(career_stats[ol_id][2025]["games_started"], 1, "%s starts" % ol_id)

	# Bottom 2 OL should be bench
	t.assert_eq(career_stats["ol6"][2025]["games_started"], 0, "OL6 is backup")
	t.assert_eq(career_stats["ol7"][2025]["games_started"], 0, "OL7 is backup")
