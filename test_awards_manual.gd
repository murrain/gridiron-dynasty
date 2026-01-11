extends SceneTree

const AwardSelector = preload("res://scripts/core/awards/AwardSelector.gd")

func _init() -> void:
	print("Testing Award System...")

	# Test 1: Basic OPOY selection
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
		}
	]

	var opoy := AwardSelector.select_offensive_player_of_year(year_stats)

	if opoy.get("player_id", "") == "qb_001":
		print("✓ OPOY test passed")
	else:
		print("✗ OPOY test failed: got %s" % opoy.get("player_id", ""))

	# Test 2: All-Pro teams
	var all_pro := AwardSelector.select_all_pro_teams(year_stats)

	if all_pro.has("first_team") and all_pro.has("second_team"):
		print("✓ All-Pro structure test passed")
	else:
		print("✗ All-Pro structure test failed")

	# Test 3: Full integration
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
			}
		},
		"nfl_rosters": {
			"team_001": {"players": []}
		},
		"nfl_teams": [
			{"id": "team_001", "region": "afc_east"}
		]
	}

	var summary := AwardSelector.select_all_awards(world_state, 2025)

	if world_state.has("awards") and world_state["awards"].has(2025):
		print("✓ World state integration test passed")
		print("  Awards: OPOY=%s, DPOY=%s, OROY=%s, DROY=%s" % [
			summary.get("opoy", ""),
			summary.get("dpoy", ""),
			summary.get("oroy", ""),
			summary.get("droy", "")
		])
	else:
		print("✗ World state integration test failed")

	print("\nAll manual tests completed!")
	quit(0)
