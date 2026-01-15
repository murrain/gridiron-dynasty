## GdUnit4 test suite for A3.8: Rookie of the Year Awards
##
## Validates that OROY and DROY are correctly selected for first-year players only.
extends GdUnitTestSuite

const AwardSelector = preload("res://scripts/core/awards/AwardSelector.gd")


func test_oroy_selected_correctly() -> void:
	var year_stats := [
		{
			"player_id": "rookie_qb",
			"position": "QB",
			"team_id": "team_001",
			"conference": "afc_east",
			"is_rookie": true,
			"stats": {
				"pass_yards": 4000,
				"pass_tds": 30,
				"interceptions": 12,
				"games_played": 16
			}
		},
		{
			"player_id": "rookie_rb",
			"position": "RB",
			"team_id": "team_002",
			"conference": "nfc_north",
			"is_rookie": true,
			"stats": {
				"rush_yards": 1400,
				"rush_tds": 12,
				"receptions": 40,
				"receiving_yards": 350,
				"receiving_tds": 2,
				"games_played": 16
			}
		},
		{
			"player_id": "rookie_wr",
			"position": "WR",
			"team_id": "team_003",
			"conference": "afc_west",
			"is_rookie": true,
			"stats": {
				"receptions": 85,
				"receiving_yards": 1200,
				"receiving_tds": 10,
				"games_played": 16
			}
		}
	]

	var oroy := AwardSelector.select_offensive_rookie_of_year(year_stats)

	assert_str(oroy.get("player_id", "")).is_not_empty()
	assert_bool(oroy.has("position")).is_true()
	assert_bool(oroy.has("score")).is_true()
	assert_bool(oroy.has("stats_summary")).is_true()

	# WR with 85 receptions and 1200 yards scores highest
	assert_str(oroy.get("player_id", "")).is_equal("rookie_wr")


func test_droy_selected_correctly() -> void:
	var year_stats := [
		{
			"player_id": "rookie_edge",
			"position": "EDGE",
			"team_id": "team_001",
			"conference": "afc_east",
			"is_rookie": true,
			"stats": {
				"sacks": 13.0,
				"tackles_for_loss": 16,
				"tackles": 50,
				"games_played": 16
			}
		},
		{
			"player_id": "rookie_lb",
			"position": "LB",
			"team_id": "team_002",
			"conference": "nfc_north",
			"is_rookie": true,
			"stats": {
				"tackles": 110,
				"sacks": 4,
				"tackles_for_loss": 10,
				"pass_breakups": 5,
				"interceptions": 2,
				"games_played": 16
			}
		},
		{
			"player_id": "rookie_cb",
			"position": "CB",
			"team_id": "team_003",
			"conference": "afc_west",
			"is_rookie": true,
			"stats": {
				"interceptions": 6,
				"pass_breakups": 16,
				"tackles": 48,
				"games_played": 16
			}
		}
	]

	var droy := AwardSelector.select_defensive_rookie_of_year(year_stats)

	assert_str(droy.get("player_id", "")).is_not_empty()
	assert_bool(droy.has("position")).is_true()
	assert_bool(droy.has("score")).is_true()

	# LB with 110 tackles scores highest (tackles heavily weighted)
	assert_str(droy.get("player_id", "")).is_equal("rookie_lb")


func test_only_rookies_eligible() -> void:
	var year_stats := [
		{
			"player_id": "veteran_qb",
			"position": "QB",
			"team_id": "team_001",
			"conference": "afc_east",
			"is_rookie": false,  # NOT a rookie
			"stats": {
				"pass_yards": 5500,
				"pass_tds": 50,
				"interceptions": 5,
				"games_played": 16
			}
		},
		{
			"player_id": "rookie_qb",
			"position": "QB",
			"team_id": "team_002",
			"conference": "nfc_west",
			"is_rookie": true,
			"stats": {
				"pass_yards": 3500,
				"pass_tds": 25,
				"interceptions": 14,
				"games_played": 16
			}
		}
	]

	var oroy := AwardSelector.select_offensive_rookie_of_year(year_stats)

	# Even though veteran has much better stats, only rookie should win OROY
	assert_str(oroy.get("player_id", "")).is_equal("rookie_qb")


func test_rookie_vs_veteran_comparison() -> void:
	var year_stats := [
		{
			"player_id": "elite_veteran",
			"position": "EDGE",
			"team_id": "team_001",
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"sacks": 22.0,
				"tackles_for_loss": 28,
				"tackles": 65,
				"games_played": 16
			}
		},
		{
			"player_id": "good_rookie",
			"position": "EDGE",
			"team_id": "team_002",
			"conference": "nfc_north",
			"is_rookie": true,
			"stats": {
				"sacks": 11.0,
				"tackles_for_loss": 14,
				"tackles": 45,
				"games_played": 16
			}
		},
		{
			"player_id": "mediocre_rookie",
			"position": "EDGE",
			"team_id": "team_003",
			"conference": "afc_west",
			"is_rookie": true,
			"stats": {
				"sacks": 6.0,
				"tackles_for_loss": 8,
				"tackles": 35,
				"games_played": 16
			}
		}
	]

	# DPOY should go to veteran
	var dpoy := AwardSelector.select_defensive_player_of_year(year_stats)
	assert_str(dpoy.get("player_id", "")).is_equal("elite_veteran")

	# DROY should go to best rookie
	var droy := AwardSelector.select_defensive_rookie_of_year(year_stats)
	assert_str(droy.get("player_id", "")).is_equal("good_rookie")


func test_rookie_awards_stored_in_world_state() -> void:
	var world_state := {
		"player_career_stats": {
			"rookie_qb": {
				2025: {
					"position": "QB",
					"team_id": "team_001",
					"pass_yards": 3800,
					"pass_tds": 28,
					"interceptions": 12,
					"games_played": 16
				}
			},
			"veteran_qb": {
				2024: {
					"position": "QB",
					"team_id": "team_001",
					"pass_yards": 3500,
					"pass_tds": 25,
					"interceptions": 14,
					"games_played": 16
				},
				2025: {
					"position": "QB",
					"team_id": "team_001",
					"pass_yards": 4200,
					"pass_tds": 32,
					"interceptions": 10,
					"games_played": 16
				}
			},
			"rookie_edge": {
				2025: {
					"position": "EDGE",
					"team_id": "team_002",
					"sacks": 12.0,
					"tackles_for_loss": 16,
					"tackles": 50,
					"games_played": 16
				}
			},
			"veteran_edge": {
				2024: {
					"position": "EDGE",
					"team_id": "team_002",
					"sacks": 10.0,
					"tackles_for_loss": 14,
					"tackles": 45,
					"games_played": 16
				},
				2025: {
					"position": "EDGE",
					"team_id": "team_002",
					"sacks": 14.0,
					"tackles_for_loss": 18,
					"tackles": 52,
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
	assert_bool(awards_2025.has("oroy")).is_true()
	assert_bool(awards_2025.has("droy")).is_true()

	var oroy: Dictionary = awards_2025["oroy"]
	assert_str(oroy.get("player_id", "")).is_equal("rookie_qb")

	var droy: Dictionary = awards_2025["droy"]
	assert_str(droy.get("player_id", "")).is_equal("rookie_edge")


func test_no_rookies_returns_empty_award() -> void:
	var year_stats := [
		{
			"player_id": "veteran_qb",
			"position": "QB",
			"team_id": "team_001",
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"pass_yards": 4500,
				"pass_tds": 35,
				"interceptions": 10,
				"games_played": 16
			}
		}
	]

	var oroy := AwardSelector.select_offensive_rookie_of_year(year_stats)
	var droy := AwardSelector.select_defensive_rookie_of_year(year_stats)

	assert_str(oroy.get("player_id", "")).is_empty()
	assert_str(droy.get("player_id", "")).is_empty()


func test_rookie_detection_logic() -> void:
	# Test that rookie detection works correctly based on career stats

	# Scenario 1: Player with only 2025 stats = rookie in 2025
	var career_rookie := {
		2025: {
			"position": "QB",
			"team_id": "team_001",
			"pass_yards": 4000,
			"pass_tds": 30,
			"interceptions": 10,
			"games_played": 16
		}
	}

	# Scenario 2: Player with 2024 and 2025 stats = not rookie in 2025
	var career_veteran := {
		2024: {
			"position": "QB",
			"team_id": "team_001",
			"pass_yards": 3500,
			"pass_tds": 25,
			"interceptions": 12,
			"games_played": 16
		},
		2025: {
			"position": "QB",
			"team_id": "team_001",
			"pass_yards": 4000,
			"pass_tds": 30,
			"interceptions": 10,
			"games_played": 16
		}
	}

	# Test is_rookie_year logic
	var is_rookie_2025_for_rookie := AwardSelector._is_rookie_year(career_rookie, 2025)
	var is_rookie_2025_for_veteran := AwardSelector._is_rookie_year(career_veteran, 2025)

	assert_bool(is_rookie_2025_for_rookie).is_true()
	assert_bool(is_rookie_2025_for_veteran).is_false()

	# Edge case: Check for year 2024
	var is_rookie_2024_for_veteran := AwardSelector._is_rookie_year(career_veteran, 2024)
	assert_bool(is_rookie_2024_for_veteran).is_true()
