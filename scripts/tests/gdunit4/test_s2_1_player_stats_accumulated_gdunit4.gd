## GdUnit4 test suite for S2.1: Player Career Stats Accumulation
##
## Validates that player career stats are properly accumulated across games and seasons.
## Tests the core requirement for career statistics tracking.
extends GdUnitTestSuite

const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")
const StatGenerator = preload("res://scripts/core/game_simulation/StatGenerator.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")


func test_stats_structure_created() -> void:
	var world_state := {}
	var game_result := {
		"game_id": "test_game_1",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_001",
		"away_team_id": "team_002",
		"winner_id": "team_001",
		"loser_id": "team_002",
		"game_type": "regular"
	}

	var home_roster := {
		"players": [
			{"player_id": "player_001", "position": "QB", "composite_score": 80.0}
		]
	}
	var away_roster := {
		"players": [
			{"player_id": "player_002", "position": "RB", "composite_score": 75.0}
		]
	}

	var positions_cfg := {"QB": {"core_stats": []}, "RB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Accumulate stats
	GameSimulator.accumulate_player_stats(
		world_state,
		game_result,
		home_roster,
		away_roster,
		positions_cfg,
		main_cfg,
		rng
	)

	# Verify structure exists
	assert_bool(world_state.has("player_career_stats")).is_true()
	var career_stats: Dictionary = world_state["player_career_stats"]
	assert_bool(career_stats.has("player_001")).is_true()
	assert_bool(career_stats.has("player_002")).is_true()

	# Verify year structure
	var p1_stats: Dictionary = career_stats["player_001"]
	assert_bool(p1_stats.has(2025)).is_true()

	# Verify stat line has required fields
	var stat_line: Dictionary = p1_stats[2025]
	assert_int(stat_line["year"]).is_equal(2025)
	assert_str(String(stat_line["team_id"])).is_equal("team_001")
	assert_str(String(stat_line["position"])).is_equal("QB")
	assert_bool(stat_line.has("games_played")).is_true()
	assert_bool(stat_line.has("games_started")).is_true()


func test_single_game_stats_accumulated() -> void:
	var world_state := {}
	var game_result := {
		"game_id": "test_game_1",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_001",
		"away_team_id": "team_002",
		"winner_id": "team_001",
		"loser_id": "team_002",
		"game_type": "regular"
	}

	var home_roster := {
		"players": [
			{"player_id": "qb_001", "position": "QB", "composite_score": 85.0}
		]
	}
	var away_roster := {
		"players": [
			{"player_id": "rb_001", "position": "RB", "composite_score": 75.0}
		]
	}

	var positions_cfg := {"QB": {"core_stats": []}, "RB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321

	GameSimulator.accumulate_player_stats(
		world_state,
		game_result,
		home_roster,
		away_roster,
		positions_cfg,
		main_cfg,
		rng
	)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var qb_stats: Dictionary = career_stats["qb_001"][2025]

	# QB should have passing stats
	assert_bool(qb_stats.has("pass_attempts")).is_true()
	assert_bool(qb_stats.has("pass_completions")).is_true()
	assert_bool(qb_stats.has("pass_yards")).is_true()
	assert_bool(qb_stats.has("pass_tds")).is_true()
	assert_bool(qb_stats.has("interceptions")).is_true()

	# Stats should be reasonable for one game
	assert_int(int(qb_stats["pass_attempts"])).is_greater(0)
	assert_int(int(qb_stats["pass_completions"])).is_less_equal(int(qb_stats["pass_attempts"]))
	assert_int(int(qb_stats["pass_yards"])).is_greater_equal(0)

	# RB should have rushing stats
	var rb_stats: Dictionary = career_stats["rb_001"][2025]
	assert_bool(rb_stats.has("rush_attempts")).is_true()
	assert_bool(rb_stats.has("rush_yards")).is_true()
	assert_bool(rb_stats.has("rush_tds")).is_true()


func test_multiple_games_accumulation() -> void:
	var world_state := {}
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 99999

	var home_roster := {
		"players": [
			{"player_id": "qb_multi", "position": "QB", "composite_score": 80.0}
		]
	}
	var away_roster := {
		"players": [
			{"player_id": "qb_opponent", "position": "QB", "composite_score": 70.0}
		]
	}

	# Simulate 3 games in same season
	for week in range(1, 4):
		var game_result := {
			"game_id": "test_game_%d" % week,
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
			home_roster,
			away_roster,
			positions_cfg,
			main_cfg,
			rng
		)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var qb_stats: Dictionary = career_stats["qb_multi"][2025]

	# Stats should accumulate across games
	assert_int(int(qb_stats["games_played"])).is_equal(3)
	assert_int(int(qb_stats["pass_attempts"])).is_greater(50)
	assert_int(int(qb_stats["pass_yards"])).is_greater(200)


func test_multiple_seasons_separate_years() -> void:
	var world_state := {}
	var positions_cfg := {"RB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111

	var roster := {
		"players": [
			{"player_id": "rb_career", "position": "RB", "composite_score": 85.0}
		]
	}
	var opponent := {
		"players": [
			{"player_id": "opponent", "position": "RB", "composite_score": 70.0}
		]
	}

	# Simulate games in different years
	for year in [2025, 2026, 2027]:
		var game_result := {
			"game_id": "test_game_y%d" % year,
			"year": year,
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
	var rb_career: Dictionary = career_stats["rb_career"]

	# Should have separate entries for each year
	assert_bool(rb_career.has(2025)).is_true()
	assert_bool(rb_career.has(2026)).is_true()
	assert_bool(rb_career.has(2027)).is_true()

	# Each year should be independent
	assert_int(int(rb_career[2025]["games_played"])).is_equal(1)
	assert_int(int(rb_career[2026]["games_played"])).is_equal(1)
	assert_int(int(rb_career[2027]["games_played"])).is_equal(1)


func test_team_change_mid_career() -> void:
	var world_state := {}
	var positions_cfg := {"WR": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 22222

	var roster_team1 := {
		"players": [
			{"player_id": "wr_transfer", "position": "WR", "composite_score": 80.0}
		]
	}
	var roster_team2 := {
		"players": [
			{"player_id": "wr_transfer", "position": "WR", "composite_score": 80.0}
		]
	}
	var opponent := {
		"players": [
			{"player_id": "opponent", "position": "WR", "composite_score": 70.0}
		]
	}

	# Game 1: Player on team_001
	var game1 := {
		"game_id": "test_game_1",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_001",
		"away_team_id": "team_003",
		"winner_id": "team_001",
		"loser_id": "team_003",
		"game_type": "regular"
	}
	GameSimulator.accumulate_player_stats(world_state, game1, roster_team1, opponent, positions_cfg, main_cfg, rng)

	# Game 2: Same player, different team (transfer)
	var game2 := {
		"game_id": "test_game_2",
		"year": 2025,
		"week": 2,
		"home_team_id": "team_002",
		"away_team_id": "team_003",
		"winner_id": "team_002",
		"loser_id": "team_003",
		"game_type": "regular"
	}
	GameSimulator.accumulate_player_stats(world_state, game2, roster_team2, opponent, positions_cfg, main_cfg, rng)

	var career_stats: Dictionary = world_state["player_career_stats"]
	var wr_stats: Dictionary = career_stats["wr_transfer"][2025]

	# Stats should accumulate despite team change
	assert_int(int(wr_stats["games_played"])).is_equal(2)

	# Team ID should reflect latest team
	assert_str(String(wr_stats["team_id"])).is_equal("team_002")


func test_all_positions_have_stats() -> void:
	var world_state := {}
	var positions_cfg := {
		"QB": {"core_stats": []},
		"RB": {"core_stats": []},
		"WR": {"core_stats": []},
		"TE": {"core_stats": []},
		"DL": {"core_stats": []},
		"EDGE": {"core_stats": []},
		"LB": {"core_stats": []},
		"CB": {"core_stats": []},
		"S": {"core_stats": []},
		"K": {"core_stats": []},
		"P": {"core_stats": []}
	}
	var main_cfg := {"class_rules": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 33333

	var home_roster := {
		"players": [
			{"player_id": "qb_1", "position": "QB", "composite_score": 80.0},
			{"player_id": "rb_1", "position": "RB", "composite_score": 75.0},
			{"player_id": "wr_1", "position": "WR", "composite_score": 75.0},
			{"player_id": "te_1", "position": "TE", "composite_score": 70.0},
			{"player_id": "dl_1", "position": "DL", "composite_score": 75.0},
			{"player_id": "edge_1", "position": "EDGE", "composite_score": 80.0},
			{"player_id": "lb_1", "position": "LB", "composite_score": 75.0},
			{"player_id": "cb_1", "position": "CB", "composite_score": 75.0},
			{"player_id": "s_1", "position": "S", "composite_score": 70.0},
			{"player_id": "k_1", "position": "K", "composite_score": 70.0},
			{"player_id": "p_1", "position": "P", "composite_score": 65.0}
		]
	}
	var away_roster := {
		"players": [
			{"player_id": "opponent_1", "position": "QB", "composite_score": 70.0}
		]
	}

	var game_result := {
		"game_id": "test_all_positions",
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
		home_roster,
		away_roster,
		positions_cfg,
		main_cfg,
		rng
	)

	var career_stats: Dictionary = world_state["player_career_stats"]

	# Verify each position has appropriate stats
	var qb_stats: Dictionary = career_stats["qb_1"][2025]
	assert_bool(qb_stats.has("pass_attempts")).is_true()

	var rb_stats: Dictionary = career_stats["rb_1"][2025]
	assert_bool(rb_stats.has("rush_attempts")).is_true()

	var wr_stats: Dictionary = career_stats["wr_1"][2025]
	assert_bool(wr_stats.has("receptions")).is_true()

	var te_stats: Dictionary = career_stats["te_1"][2025]
	assert_bool(te_stats.has("receptions")).is_true()

	var dl_stats: Dictionary = career_stats["dl_1"][2025]
	assert_bool(dl_stats.has("tackles")).is_true()

	var edge_stats: Dictionary = career_stats["edge_1"][2025]
	assert_bool(edge_stats.has("sacks")).is_true()

	var lb_stats: Dictionary = career_stats["lb_1"][2025]
	assert_bool(lb_stats.has("tackles")).is_true()

	var cb_stats: Dictionary = career_stats["cb_1"][2025]
	assert_bool(cb_stats.has("pass_breakups")).is_true()

	var s_stats: Dictionary = career_stats["s_1"][2025]
	assert_bool(s_stats.has("tackles")).is_true()

	var k_stats: Dictionary = career_stats["k_1"][2025]
	assert_bool(k_stats.has("field_goals_attempted")).is_true()

	var p_stats: Dictionary = career_stats["p_1"][2025]
	assert_bool(p_stats.has("punts")).is_true()
