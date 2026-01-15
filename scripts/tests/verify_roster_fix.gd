extends SceneTree

## Quick verification that roster management fixes are working

const RosterManagement = preload("res://scripts/world/RosterManagement.gd")

func _init():
	print("\n" + "=".repeat(80))
	print("ROSTER MANAGEMENT FIX VERIFICATION")
	print("=".repeat(80))

	# Load configuration
	var cfg_path := "res://configs/sports/american_football/main.json"
	var cfg_file := FileAccess.open(cfg_path, FileAccess.READ)
	if not cfg_file:
		push_error("Cannot open config file: " + cfg_path)
		quit(1)
		return

	var main_cfg: Dictionary = JSON.parse_string(cfg_file.get_as_text())
	cfg_file.close()

	var rm_cfg: Dictionary = main_cfg.get("roster_management", {})
	var market_multiplier: float = rm_cfg.get("market_value_multiplier", 0.0)
	var value_threshold: float = rm_cfg.get("value_threshold", 1.5)

	print("\n[CONFIG VERIFICATION]")
	print("  market_value_multiplier: %.2f" % market_multiplier)
	print("  value_threshold: %.2f" % value_threshold)

	if market_multiplier == 0.0:
		print("  ❌ market_value_multiplier is 0 or missing!")
		quit(1)
		return
	else:
		print("  ✓ market_value_multiplier is configured")

	# Create test world state with realistic data
	print("\n[CREATING TEST DATA]")
	var world_state: Dictionary = {
		"nfl_teams": [
			{"id": "team_001", "name": "Test Team"}
		],
		"nfl_rosters": {
			"team_001": {
				"players": [
					# Overpaid veteran (should be released)
					{
						"player_id": "p1",
						"position": "QB",
						"age": 34,
						"eval_score": 65.0,
						"draft_year": 2010,
						"contract": {
							"annual_value": 20.0,  # $20M for declining 65-rated QB
							"signed_year": 2020,
							"years_remaining": 2,
							"years_total": 3
						}
					},
					# Good value player (should NOT be released)
					{
						"player_id": "p2",
						"position": "WR",
						"age": 27,
						"eval_score": 85.0,
						"draft_year": 2018,
						"contract": {
							"annual_value": 10.0,  # Fair $10M for 85-rated WR
							"signed_year": 2022,
							"years_remaining": 3,
							"years_total": 4
						}
					},
					# Rookie (should be PROTECTED)
					{
						"player_id": "p3",
						"position": "RB",
						"age": 22,
						"eval_score": 70.0,
						"draft_year": 2023,
						"contract": {
							"annual_value": 2.0,  # Rookie contract
							"signed_year": 2023,
							"years_remaining": 4,
							"years_total": 4
						}
					}
				]
			}
		},
		"league": {
			"cap_limit": 200.0
		},
		"free_agents": {},
		"player_releases": {}
	}
	print("  Created test roster with 3 players")

	# Run roster management
	print("\n[RUNNING ROSTER MANAGEMENT]")
	var result: Dictionary = RosterManagement.run(
		world_state,
		2024,
		12345,  # seed
		main_cfg
	)

	print("\n[RESULTS]")
	print("  Teams processed: %d" % result.get("teams_processed", 0))
	print("  Total releases: %d" % result.get("total_releases", 0))
	print("  Cap saved: $%.2fM" % result.get("total_cap_saved", 0.0))

	var releases_by_team: Dictionary = result.get("releases_by_team", {})
	if releases_by_team.has("team_001"):
		print("  ✓ Team had releases: %d" % releases_by_team["team_001"])
	else:
		print("  ℹ No releases for team (may have sufficient cap space)")

	# Check if the overpaid player was released
	var roster_after: Array = world_state["nfl_rosters"]["team_001"]["players"]
	var p1_still_there := false
	var p2_still_there := false
	var p3_still_there := false

	for player in roster_after:
		var p: Dictionary = player
		if p.get("player_id") == "p1":
			p1_still_there = true
		elif p.get("player_id") == "p2":
			p2_still_there = true
		elif p.get("player_id") == "p3":
			p3_still_there = true

	print("\n[PLAYER STATUS]")
	print("  Overpaid veteran (p1): %s" % ("RETAINED" if p1_still_there else "RELEASED ✓"))
	print("  Good value WR (p2): %s" % ("RETAINED ✓" if p2_still_there else "RELEASED"))
	print("  Rookie RB (p3): %s" % ("RETAINED ✓" if p3_still_there else "RELEASED"))

	# Calculate expected values with new formula
	print("\n[FORMULA VERIFICATION]")
	print("  For 65-rated, age 34 QB earning $20M:")
	var market_value_p1: float = 65.0 * market_multiplier
	var expected_value_p1: float = market_value_p1 * value_threshold
	var age_penalty_p1: float = 1.0 + (34.0 - 30.0) * 0.02
	var cap_ineff_p1: float = (20.0 / expected_value_p1) * age_penalty_p1
	print("    market_value = 65 * %.2f = $%.2fM" % [market_multiplier, market_value_p1])
	print("    expected_value = %.2f * %.2f = $%.2fM" % [market_value_p1, value_threshold, expected_value_p1])
	print("    age_penalty = 1.0 + (34-30)*0.02 = %.2f" % age_penalty_p1)
	print("    cap_inefficiency = (20.0 / %.2f) * %.2f = %.2f" % [expected_value_p1, age_penalty_p1, cap_ineff_p1])
	print("    %s (threshold is 1.0)" % ("OVERPAID ✓" if cap_ineff_p1 > 1.0 else "ACCEPTABLE"))

	print("\n  For 85-rated, age 27 WR earning $10M:")
	var market_value_p2: float = 85.0 * market_multiplier
	var expected_value_p2: float = market_value_p2 * value_threshold
	var cap_ineff_p2: float = 10.0 / expected_value_p2
	print("    market_value = 85 * %.2f = $%.2fM" % [market_multiplier, market_value_p2])
	print("    expected_value = %.2f * %.2f = $%.2fM" % [market_value_p2, value_threshold, expected_value_p2])
	print("    cap_inefficiency = 10.0 / %.2f = %.2f" % [expected_value_p2, cap_ineff_p2])
	print("    %s (threshold is 1.0)" % ("ACCEPTABLE ✓" if cap_ineff_p2 < 1.0 else "OVERPAID"))

	print("\n" + "=".repeat(80))
	print("VERIFICATION COMPLETE")
	print("=".repeat(80) + "\n")

	quit()
