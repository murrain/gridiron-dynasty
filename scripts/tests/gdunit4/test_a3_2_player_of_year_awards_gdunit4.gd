## GdUnit4 test suite for A3.2: Offensive and Defensive Player of the Year Awards
##
## Validates that OPOY and DPOY are correctly selected based on statistical performance.
extends GdUnitTestSuite

const AwardSelector = preload("res://scripts/core/awards/AwardSelector.gd")


func test_opoy_selected_correctly() -> void:
	# Create mock player stats
	var year_stats := [
		{
			"player_id": "qb_001",
			"position": "QB",
			"team_id": "team_001",
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"pass_yards": 5000,
				"pass_tds": 45,
				"interceptions": 8,
				"games_played": 16
			}
		},
		{
			"player_id": "rb_001",
			"position": "RB",
			"team_id": "team_002",
			"conference": "nfc_north",
			"is_rookie": false,
			"stats": {
				"rush_yards": 1800,
				"rush_tds": 18,
				"receptions": 60,
				"receiving_yards": 400,
				"receiving_tds": 2,
				"games_played": 16
			}
		},
		{
			"player_id": "wr_001",
			"position": "WR",
			"team_id": "team_003",
			"conference": "afc_west",
			"is_rookie": false,
			"stats": {
				"receptions": 100,
				"receiving_yards": 1500,
				"receiving_tds": 12,
				"games_played": 16
			}
		}
	]

	var opoy := AwardSelector.select_offensive_player_of_year(year_stats)

	assert_str(opoy.get("player_id", "")).is_not_empty()
	assert_bool(opoy.has("position")).is_true()
	assert_bool(opoy.has("score")).is_true()
	assert_bool(opoy.has("stats_summary")).is_true()

	# QB with 5000 yards and 45 TDs should win OPOY
	assert_str(opoy.get("player_id", "")).is_equal("qb_001")


func test_dpoy_selected_correctly() -> void:
	var year_stats := [
		{
			"player_id": "edge_001",
			"position": "EDGE",
			"team_id": "team_001",
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"sacks": 22.0,
				"tackles_for_loss": 25,
				"tackles": 60,
				"games_played": 16
			}
		},
		{
			"player_id": "lb_001",
			"position": "LB",
			"team_id": "team_002",
			"conference": "nfc_north",
			"is_rookie": false,
			"stats": {
				"tackles": 140,
				"sacks": 5,
				"tackles_for_loss": 15,
				"pass_breakups": 8,
				"interceptions": 3,
				"games_played": 16
			}
		},
		{
			"player_id": "cb_001",
			"position": "CB",
			"team_id": "team_003",
			"conference": "afc_west",
			"is_rookie": false,
			"stats": {
				"interceptions": 12,
				"pass_breakups": 25,
				"tackles": 60,
				"games_played": 16
			}
		}
	]

	var dpoy := AwardSelector.select_defensive_player_of_year(year_stats)

	assert_str(dpoy.get("player_id", "")).is_not_empty()
	assert_bool(dpoy.has("position")).is_true()
	assert_bool(dpoy.has("score")).is_true()

	# LB with most tackles should win (tackles heavily weighted for LBs)
	assert_str(dpoy.get("player_id", "")).is_equal("lb_001")


func test_opoy_position_specific_scoring() -> void:
	# Test that QB scoring formula works correctly
	var qb_stats := [
		{
			"player_id": "qb_test",
			"position": "QB",
			"team_id": "team_001",
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"pass_yards": 4000,
				"pass_tds": 30,
				"interceptions": 10,
				"games_played": 16
			}
		}
	]

	var opoy := AwardSelector.select_offensive_player_of_year(qb_stats)
	var score := float(opoy.get("score", 0.0))

	# Score should be: (4000/10 + 30*40 - 10*20) = 400 + 1200 - 200 = 1400
	assert_float(score).is_greater(1000.0)

	# Test RB scoring
	var rb_stats := [
		{
			"player_id": "rb_test",
			"position": "RB",
			"team_id": "team_001",
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"rush_yards": 1500,
				"rush_tds": 15,
				"receptions": 50,
				"receiving_yards": 400,
				"receiving_tds": 3,
				"games_played": 16
			}
		}
	]

	var rb_opoy := AwardSelector.select_offensive_player_of_year(rb_stats)
	var rb_score := float(rb_opoy.get("score", 0.0))

	assert_float(rb_score).is_greater(1000.0)


func test_dpoy_position_specific_scoring() -> void:
	# Test EDGE scoring
	var edge_stats := [
		{
			"player_id": "edge_test",
			"position": "EDGE",
			"team_id": "team_001",
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"sacks": 20.0,
				"tackles_for_loss": 20,
				"tackles": 50,
				"games_played": 16
			}
		}
	]

	var dpoy := AwardSelector.select_defensive_player_of_year(edge_stats)
	var score := float(dpoy.get("score", 0.0))

	# Score should be: (20*50 + 20*30 + 50*5) = 1000 + 600 + 250 = 1850
	assert_float(score).is_greater(1500.0)

	# Test CB scoring
	var cb_stats := [
		{
			"player_id": "cb_test",
			"position": "CB",
			"team_id": "team_001",
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"interceptions": 8,
				"pass_breakups": 15,
				"tackles": 60,
				"games_played": 16
			}
		}
	]

	var cb_dpoy := AwardSelector.select_defensive_player_of_year(cb_stats)
	var cb_score := float(cb_dpoy.get("score", 0.0))

	# Score should be: (8*80 + 15*30 + 60*5) = 640 + 450 + 300 = 1390
	assert_float(cb_score).is_greater(1000.0)


func test_awards_stored_in_world_state() -> void:
	var world_state := {
		"player_career_stats": {
			"qb_001": {
				2025: {
					"position": "QB",
					"team_id": "team_001",
					"pass_yards": 4500,
					"pass_tds": 35,
					"interceptions": 10,
					"games_played": 16
				}
			},
			"edge_001": {
				2025: {
					"position": "EDGE",
					"team_id": "team_002",
					"sacks": 18.0,
					"tackles_for_loss": 22,
					"tackles": 55,
					"games_played": 16
				}
			}
		},
		"nfl_rosters": {
			"team_001": {"players": []},
			"team_002": {"players": []}
		},
		"nfl_teams": [
			{"id": "team_001", "region": "afc_east"},
			{"id": "team_002", "region": "nfc_west"}
		]
	}

	var _summary := AwardSelector.select_all_awards(world_state, 2025)

	assert_bool(world_state.has("awards")).is_true()
	assert_bool(world_state["awards"].has(2025)).is_true()

	var awards_2025: Dictionary = world_state["awards"][2025]
	assert_bool(awards_2025.has("opoy")).is_true()
	assert_bool(awards_2025.has("dpoy")).is_true()

	var opoy: Dictionary = awards_2025["opoy"]
	assert_str(opoy.get("player_id", "")).is_equal("qb_001")

	var dpoy: Dictionary = awards_2025["dpoy"]
	assert_str(dpoy.get("player_id", "")).is_equal("edge_001")


func test_multiple_years_independent() -> void:
	var world_state := {
		"player_career_stats": {
			"qb_001": {
				2025: {
					"position": "QB",
					"team_id": "team_001",
					"pass_yards": 4500,
					"pass_tds": 35,
					"interceptions": 10,
					"games_played": 16
				},
				2026: {
					"position": "QB",
					"team_id": "team_001",
					"pass_yards": 3800,
					"pass_tds": 28,
					"interceptions": 12,
					"games_played": 16
				}
			},
			"qb_002": {
				2025: {
					"position": "QB",
					"team_id": "team_002",
					"pass_yards": 3500,
					"pass_tds": 25,
					"interceptions": 14,
					"games_played": 16
				},
				2026: {
					"position": "QB",
					"team_id": "team_002",
					"pass_yards": 5200,
					"pass_tds": 42,
					"interceptions": 8,
					"games_played": 16
				}
			},
			"edge_001": {
				2025: {
					"position": "EDGE",
					"team_id": "team_003",
					"sacks": 18.0,
					"tackles_for_loss": 22,
					"tackles": 55,
					"games_played": 16
				},
				2026: {
					"position": "EDGE",
					"team_id": "team_003",
					"sacks": 20.0,
					"tackles_for_loss": 24,
					"tackles": 60,
					"games_played": 16
				}
			}
		},
		"nfl_rosters": {
			"team_001": {"players": []},
			"team_002": {"players": []},
			"team_003": {"players": []}
		},
		"nfl_teams": [
			{"id": "team_001", "region": "afc_east"},
			{"id": "team_002", "region": "nfc_west"},
			{"id": "team_003", "region": "afc_north"}
		]
	}

	# Select awards for both years
	AwardSelector.select_all_awards(world_state, 2025)
	AwardSelector.select_all_awards(world_state, 2026)

	var awards: Dictionary = world_state["awards"]
	assert_bool(awards.has(2025)).is_true()
	assert_bool(awards.has(2026)).is_true()

	# 2025: qb_001 should win (better stats)
	assert_str(awards[2025]["opoy"].get("player_id", "")).is_equal("qb_001")

	# 2026: qb_002 should win (better stats in 2026)
	assert_str(awards[2026]["opoy"].get("player_id", "")).is_equal("qb_002")


func test_no_stats_returns_empty_award() -> void:
	var year_stats := []

	var opoy := AwardSelector.select_offensive_player_of_year(year_stats)
	var dpoy := AwardSelector.select_defensive_player_of_year(year_stats)

	assert_str(opoy.get("player_id", "")).is_empty()
	assert_str(dpoy.get("player_id", "")).is_empty()
