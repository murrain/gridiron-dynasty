extends RefCounted

## Test S2.1: Player Career Stats Accumulation
##
## Validates that player career stats are properly accumulated across games and seasons.
## Tests the core requirement for career statistics tracking.

const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")
const StatGenerator = preload("res://scripts/core/game_simulation/StatGenerator.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

func run(t) -> void:
	_test_stats_structure_created(t)
	_test_single_game_stats_accumulated(t)
	_test_multiple_games_accumulation(t)
	_test_multiple_seasons_separate_years(t)
	_test_team_change_mid_career(t)
	_test_all_positions_have_stats(t)


func _test_stats_structure_created(t) -> void:
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
	t.assert_true(world_state.has("player_career_stats"), "world_state should have player_career_stats")
	var career_stats: Dictionary = world_state["player_career_stats"]
	t.assert_true(career_stats.has("player_001"), "Career stats should have player_001")
	t.assert_true(career_stats.has("player_002"), "Career stats should have player_002")

	# Verify year structure
	var p1_stats: Dictionary = career_stats["player_001"]
	t.assert_true(p1_stats.has(2025), "Player should have 2025 stats")

	# Verify stat line has required fields
	var stat_line: Dictionary = p1_stats[2025]
	t.assert_eq(stat_line["year"], 2025, "Stat line should have correct year")
	t.assert_eq(stat_line["team_id"], "team_001", "Stat line should have correct team_id")
	t.assert_eq(stat_line["position"], "QB", "Stat line should have correct position")
	t.assert_true(stat_line.has("games_played"), "Stat line should have games_played")
	t.assert_true(stat_line.has("games_started"), "Stat line should have games_started")


func _test_single_game_stats_accumulated(t) -> void:
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
	t.assert_true(qb_stats.has("pass_attempts"), "QB should have pass_attempts")
	t.assert_true(qb_stats.has("pass_completions"), "QB should have pass_completions")
	t.assert_true(qb_stats.has("pass_yards"), "QB should have pass_yards")
	t.assert_true(qb_stats.has("pass_tds"), "QB should have pass_tds")
	t.assert_true(qb_stats.has("interceptions"), "QB should have interceptions")

	# Stats should be reasonable for one game
	t.assert_gt(qb_stats["pass_attempts"], 0, "QB should have pass attempts")
	t.assert_le(qb_stats["pass_completions"], qb_stats["pass_attempts"], "Completions <= Attempts")
	t.assert_ge(qb_stats["pass_yards"], 0, "Yards should be non-negative")

	# RB should have rushing stats
	var rb_stats: Dictionary = career_stats["rb_001"][2025]
	t.assert_true(rb_stats.has("rush_attempts"), "RB should have rush_attempts")
	t.assert_true(rb_stats.has("rush_yards"), "RB should have rush_yards")
	t.assert_true(rb_stats.has("rush_tds"), "RB should have rush_tds")


func _test_multiple_games_accumulation(t) -> void:
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
	t.assert_eq(qb_stats["games_played"], 3, "QB should have played 3 games")
	t.assert_gt(qb_stats["pass_attempts"], 50, "QB should have 50+ attempts over 3 games")
	t.assert_gt(qb_stats["pass_yards"], 200, "QB should have 200+ yards over 3 games")


func _test_multiple_seasons_separate_years(t) -> void:
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
	t.assert_true(rb_career.has(2025), "Should have 2025 stats")
	t.assert_true(rb_career.has(2026), "Should have 2026 stats")
	t.assert_true(rb_career.has(2027), "Should have 2027 stats")

	# Each year should be independent
	t.assert_eq(rb_career[2025]["games_played"], 1, "2025 should have 1 game")
	t.assert_eq(rb_career[2026]["games_played"], 1, "2026 should have 1 game")
	t.assert_eq(rb_career[2027]["games_played"], 1, "2027 should have 1 game")

	# Years shouldn't cross-contaminate
	var yards_2025 := rb_career[2025]["rush_yards"]
	var yards_2026 := rb_career[2026]["rush_yards"]
	t.assert_true(yards_2025 != yards_2026 or rng.randf() < 0.01, "Different years should have different stats (with rare exception)")


func _test_team_change_mid_career(t) -> void:
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
	t.assert_eq(wr_stats["games_played"], 2, "WR should have 2 games despite team change")

	# Team ID should reflect latest team
	t.assert_eq(wr_stats["team_id"], "team_002", "Team ID should be updated to latest team")


func _test_all_positions_have_stats(t) -> void:
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
	t.assert_true(qb_stats.has("pass_attempts"), "QB has passing stats")

	var rb_stats: Dictionary = career_stats["rb_1"][2025]
	t.assert_true(rb_stats.has("rush_attempts"), "RB has rushing stats")

	var wr_stats: Dictionary = career_stats["wr_1"][2025]
	t.assert_true(wr_stats.has("receptions"), "WR has receiving stats")

	var te_stats: Dictionary = career_stats["te_1"][2025]
	t.assert_true(te_stats.has("receptions"), "TE has receiving stats")

	var dl_stats: Dictionary = career_stats["dl_1"][2025]
	t.assert_true(dl_stats.has("tackles"), "DL has defensive stats")

	var edge_stats: Dictionary = career_stats["edge_1"][2025]
	t.assert_true(edge_stats.has("sacks"), "EDGE has pass rush stats")

	var lb_stats: Dictionary = career_stats["lb_1"][2025]
	t.assert_true(lb_stats.has("tackles"), "LB has defensive stats")

	var cb_stats: Dictionary = career_stats["cb_1"][2025]
	t.assert_true(cb_stats.has("pass_breakups"), "CB has coverage stats")

	var s_stats: Dictionary = career_stats["s_1"][2025]
	t.assert_true(s_stats.has("tackles"), "S has defensive stats")

	var k_stats: Dictionary = career_stats["k_1"][2025]
	t.assert_true(k_stats.has("field_goals_attempted"), "K has kicking stats")

	var p_stats: Dictionary = career_stats["p_1"][2025]
	t.assert_true(p_stats.has("punts"), "P has punting stats")
