extends RefCounted

## Test A3.8: Rookie of the Year Awards
##
## Validates that OROY and DROY are correctly selected for first-year players only.

const AwardSelector = preload("res://scripts/core/awards/AwardSelector.gd")

func run(t) -> void:
	_test_oroy_selected_correctly(t)
	_test_droy_selected_correctly(t)
	_test_only_rookies_eligible(t)
	_test_rookie_vs_veteran_comparison(t)
	_test_rookie_awards_stored_in_world_state(t)
	_test_no_rookies_returns_empty_award(t)
	_test_rookie_detection_logic(t)


func _test_oroy_selected_correctly(t) -> void:
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

	t.assert_ne(oroy.get("player_id", ""), "", "OROY should be selected")
	t.assert_true(oroy.has("position"), "OROY should have position")
	t.assert_true(oroy.has("score"), "OROY should have score")
	t.assert_true(oroy.has("stats_summary"), "OROY should have stats summary")

	# WR with 85 receptions and 1200 yards scores highest
	t.assert_eq(oroy.get("player_id", ""), "rookie_wr", "Elite rookie WR should win OROY")


func _test_droy_selected_correctly(t) -> void:
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

	t.assert_ne(droy.get("player_id", ""), "", "DROY should be selected")
	t.assert_true(droy.has("position"), "DROY should have position")
	t.assert_true(droy.has("score"), "DROY should have score")

	# LB with 110 tackles scores highest (tackles heavily weighted)
	t.assert_eq(droy.get("player_id", ""), "rookie_lb", "Elite rookie LB should win DROY")


func _test_only_rookies_eligible(t) -> void:
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
	t.assert_eq(oroy.get("player_id", ""), "rookie_qb", "Only rookies should be eligible for OROY")


func _test_rookie_vs_veteran_comparison(t) -> void:
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
	t.assert_eq(dpoy.get("player_id", ""), "elite_veteran", "Veteran should win DPOY")

	# DROY should go to best rookie
	var droy := AwardSelector.select_defensive_rookie_of_year(year_stats)
	t.assert_eq(droy.get("player_id", ""), "good_rookie", "Best rookie should win DROY")


func _test_rookie_awards_stored_in_world_state(t) -> void:
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

	var summary := AwardSelector.select_all_awards(world_state, 2025)

	t.assert_true(world_state.has("awards"), "world_state should have awards")
	t.assert_true(world_state["awards"].has(2025), "Awards should exist for 2025")

	var awards_2025: Dictionary = world_state["awards"][2025]
	t.assert_true(awards_2025.has("oroy"), "2025 awards should have OROY")
	t.assert_true(awards_2025.has("droy"), "2025 awards should have DROY")

	# Note: Only rookie_qb and rookie_edge in the world state, so they win by default
	var oroy: Dictionary = awards_2025["oroy"]
	t.assert_eq(oroy.get("player_id", ""), "rookie_qb", "Rookie QB should win OROY (only offensive rookie)")

	var droy: Dictionary = awards_2025["droy"]
	t.assert_eq(droy.get("player_id", ""), "rookie_edge", "Rookie EDGE should win DROY (only defensive rookie)")


func _test_no_rookies_returns_empty_award(t) -> void:
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

	t.assert_eq(oroy.get("player_id", ""), "", "No rookies should return empty OROY")
	t.assert_eq(droy.get("player_id", ""), "", "No rookies should return empty DROY")


func _test_rookie_detection_logic(t) -> void:
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

	t.assert_true(is_rookie_2025_for_rookie, "Player with only 2025 stats should be rookie in 2025")
	t.assert_true(not (is_rookie_2025_for_veteran), "Player with 2024 stats should NOT be rookie in 2025")

	# Edge case: Check for year 2024
	var is_rookie_2024_for_veteran := AwardSelector._is_rookie_year(career_veteran, 2024)
	t.assert_true(is_rookie_2024_for_veteran, "Player should be rookie in their first year (2024)")
