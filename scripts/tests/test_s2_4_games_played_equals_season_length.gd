extends RefCounted

## Test S2.4: Games Played Equals Season Length
##
## Validates that player games_played statistics match the expected season length.
## Tests college (12 games) and NFL (17 games) season tracking.

const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")

func run(t) -> void:
	_test_college_season_12_games(t)
	_test_nfl_season_17_games(t)
	_test_partial_season_injury_simulation(t)
	_test_multiple_seasons_games_played(t)


func _test_college_season_12_games(t) -> void:
	var world_state := {}
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player_roster := {
		"players": [
			{"player_id": "college_qb", "position": "QB", "composite_score": 80.0}
		]
	}
	var opponent_roster := {
		"players": [
			{"player_id": "opponent_qb", "position": "QB", "composite_score": 75.0}
		]
	}

	# Simulate 12-game college season
	for week in range(1, 13):
		var game_result := {
			"game_id": "college_w%d" % week,
			"year": 2025,
			"week": week,
			"home_team_id": "college_001",
			"away_team_id": "college_002",
			"winner_id": "college_001" if week % 2 == 0 else "college_002",
			"loser_id": "college_002" if week % 2 == 0 else "college_001",
			"game_type": "regular"
		}

		GameSimulator.accumulate_player_stats(
			world_state,
			game_result,
			player_roster,
			opponent_roster,
			positions_cfg,
			main_cfg,
			rng
		)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var player_stats: Dictionary = career_stats["college_qb"][2025]

	# Player should have played exactly 12 games
	t.assert_eq(player_stats["games_played"], 12, "College player should have 12 games played")

	# Verify accumulated stats are reasonable for 12 games
	t.assert_gt(player_stats["pass_attempts"], 200, "12 games should accumulate 200+ pass attempts")
	t.assert_gt(player_stats["pass_yards"], 2000, "12 games should accumulate 2000+ pass yards")


func _test_nfl_season_17_games(t) -> void:
	var world_state := {}
	var positions_cfg := {"RB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321

	var player_roster := {
		"players": [
			{"player_id": "nfl_rb", "position": "RB", "composite_score": 85.0}
		]
	}
	var opponent_roster := {
		"players": [
			{"player_id": "opponent_rb", "position": "RB", "composite_score": 75.0}
		]
	}

	# Simulate 17-game NFL season
	for week in range(1, 18):
		var game_result := {
			"game_id": "nfl_w%d" % week,
			"year": 2025,
			"week": week,
			"home_team_id": "nfl_001",
			"away_team_id": "nfl_002",
			"winner_id": "nfl_001",
			"loser_id": "nfl_002",
			"game_type": "regular"
		}

		GameSimulator.accumulate_player_stats(
			world_state,
			game_result,
			player_roster,
			opponent_roster,
			positions_cfg,
			main_cfg,
			rng
		)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var player_stats: Dictionary = career_stats["nfl_rb"][2025]

	# Player should have played exactly 17 games
	t.assert_eq(player_stats["games_played"], 17, "NFL player should have 17 games played")

	# Verify accumulated stats are reasonable for 17 games
	t.assert_gt(player_stats["rush_attempts"], 200, "17 games should accumulate 200+ rush attempts")
	t.assert_gt(player_stats["rush_yards"], 800, "17 games should accumulate 800+ rush yards")


func _test_partial_season_injury_simulation(t) -> void:
	var world_state := {}
	var positions_cfg := {"WR": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 99999

	var player_roster := {
		"players": [
			{"player_id": "wr_injured", "position": "WR", "composite_score": 80.0}
		]
	}
	var opponent_roster := {
		"players": [
			{"player_id": "opponent_wr", "position": "WR", "composite_score": 75.0}
		]
	}

	# Player only plays first 6 games (injured after that)
	for week in range(1, 7):
		var game_result := {
			"game_id": "injury_w%d" % week,
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
			player_roster,
			opponent_roster,
			positions_cfg,
			main_cfg,
			rng
		)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var player_stats: Dictionary = career_stats["wr_injured"][2025]

	# Player should only have 6 games played (not full season)
	t.assert_eq(player_stats["games_played"], 6, "Injured player should only have 6 games played")

	# Stats should reflect partial season
	t.assert_lt(player_stats["receptions"], 100, "6 games should have fewer than 100 receptions")


func _test_multiple_seasons_games_played(t) -> void:
	var world_state := {}
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111

	var player_roster := {
		"players": [
			{"player_id": "career_qb", "position": "QB", "composite_score": 85.0}
		]
	}
	var opponent_roster := {
		"players": [
			{"player_id": "opponent", "position": "QB", "composite_score": 75.0}
		]
	}

	# Simulate 3 seasons: 12 games each
	for year in [2025, 2026, 2027]:
		for week in range(1, 13):
			var game_result := {
				"game_id": "y%d_w%d" % [year, week],
				"year": year,
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
				player_roster,
				opponent_roster,
				positions_cfg,
				main_cfg,
				rng
			)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var player_career: Dictionary = career_stats["career_qb"]

	# Each year should have exactly 12 games
	t.assert_eq(player_career[2025]["games_played"], 12, "2025 should have 12 games")
	t.assert_eq(player_career[2026]["games_played"], 12, "2026 should have 12 games")
	t.assert_eq(player_career[2027]["games_played"], 12, "2027 should have 12 games")

	# Total career games should be 36 (3 seasons * 12 games)
	var total_games := 0
	for year in [2025, 2026, 2027]:
		total_games += int(player_career[year]["games_played"])

	t.assert_eq(total_games, 36, "Career total should be 36 games across 3 seasons")

	# Each year's stats should be independent
	var attempts_2025: Variant = player_career[2025]["pass_attempts"]
	var attempts_2026: Variant = player_career[2026]["pass_attempts"]
	var attempts_2027: Variant = player_career[2027]["pass_attempts"]

	# While values may be close, they should not all be identical (due to RNG)
	var all_identical: bool = (attempts_2025 == attempts_2026 and attempts_2026 == attempts_2027)
	t.assert_false(all_identical, "Each season should have independent stat generation")


func _test_roster_changes_games_played(t) -> void:
	var world_state := {}
	var positions_cfg := {"LB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 22222

	var team1_roster := {
		"players": [
			{"player_id": "lb_transfer", "position": "LB", "composite_score": 80.0}
		]
	}
	var team2_roster := {
		"players": [
			{"player_id": "lb_transfer", "position": "LB", "composite_score": 80.0}
		]
	}
	var opponent := {
		"players": [
			{"player_id": "opponent", "position": "LB", "composite_score": 75.0}
		]
	}

	# Player plays 5 games with team 1
	for week in range(1, 6):
		var game_result := {
			"game_id": "team1_w%d" % week,
			"year": 2025,
			"week": week,
			"home_team_id": "team_001",
			"away_team_id": "team_003",
			"winner_id": "team_001",
			"loser_id": "team_003",
			"game_type": "regular"
		}

		GameSimulator.accumulate_player_stats(
			world_state,
			game_result,
			team1_roster,
			opponent,
			positions_cfg,
			main_cfg,
			rng
		)

	# Player transfers to team 2 and plays 7 more games
	for week in range(6, 13):
		var game_result := {
			"game_id": "team2_w%d" % week,
			"year": 2025,
			"week": week,
			"home_team_id": "team_002",
			"away_team_id": "team_003",
			"winner_id": "team_002",
			"loser_id": "team_003",
			"game_type": "regular"
		}

		GameSimulator.accumulate_player_stats(
			world_state,
			game_result,
			team2_roster,
			opponent,
			positions_cfg,
			main_cfg,
			rng
		)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var player_stats: Dictionary = career_stats["lb_transfer"][2025]

	# Player should have total of 12 games despite team change
	t.assert_eq(player_stats["games_played"], 12, "Player should have 12 games total despite roster change")

	# Team ID should reflect last team played for
	t.assert_eq(player_stats["team_id"], "team_002", "Team ID should be latest team")
