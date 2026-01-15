extends SceneTree

## Diagnostic Test: Roster Management Data Flow
##
## Purpose: Verify that missing annual_value field is causing 0 releases
## Tests both WITH and WITHOUT annual_value to prove the hypothesis

const RosterManagement = preload("res://scripts/world/RosterManagement.gd")

func _init():
	print("\n" + "=".repeat(80))
	print("ROSTER MANAGEMENT DATA FLOW DIAGNOSTIC")
	print("=".repeat(80))

	test_1_without_annual_value()
	test_2_with_annual_value()
	test_3_cap_calculation_analysis()
	test_4_release_decision_trace()

	print("\n" + "=".repeat(80))
	print("DIAGNOSTIC COMPLETE")
	print("=".repeat(80))

	quit()

func test_1_without_annual_value():
	print("\n[TEST 1] WITHOUT annual_value (reproduces integration test issue)")
	print("-".repeat(80))

	# Create world state with contracts MISSING annual_value (like integration test)
	var world_state := _create_world_state_no_annual_value()

	var main_cfg := {
		"roster_management": {
			"enabled": true,
			"target_fa_budget_min": 30.0,
			"target_fa_budget_max": 50.0,
			"value_threshold": 1.5,
			"age_decline_factor": 0.02,
			"min_roster_size": 45
		},
		"league": {
			"cap_limit": 200.0
		}
	}

	# Add league state
	world_state["league"] = {"cap_limit": 200.0}

	var result := RosterManagement.run(world_state, 2025, 12345, main_cfg)

	print("  Teams processed: %d" % result.get("teams_processed", 0))
	print("  Total releases: %d" % result.get("total_releases", 0))
	print("  Total cap saved: $%.2fM" % result.get("total_cap_saved", 0.0))

	# Analyze WHY no releases
	var team_id := "nfl_001"
	var roster: Dictionary = world_state["nfl_rosters"][team_id]
	var players: Array = roster["players"]

	var cap_used := RosterManagement._calculate_team_cap_usage(players)
	var cap_space := 200.0 - cap_used

	print("\n  Team Analysis (nfl_001):")
	print("    Roster size: %d players" % players.size())
	print("    Cap used: $%.2fM" % cap_used)
	print("    Cap space: $%.2fM" % cap_space)
	print("    Target budget: $30-50M")
	print("    Has enough space: %s" % ("YES" if cap_space >= 30.0 else "NO"))

	if result.get("total_releases", 0) == 0:
		print("\n  ✗ CONFIRMED: 0 releases with missing annual_value")
		print("  Root cause: cap_used = $0M, so cap_space = $200M >= target ($30-50M)")
	else:
		print("\n  ? UNEXPECTED: Got releases despite missing annual_value")

func test_2_with_annual_value():
	print("\n[TEST 2] WITH annual_value (correct contract structure)")
	print("-".repeat(80))

	# Create world state with contracts HAVING annual_value
	var world_state := _create_world_state_with_annual_value()

	var main_cfg := {
		"roster_management": {
			"enabled": true,
			"target_fa_budget_min": 30.0,
			"target_fa_budget_max": 50.0,
			"value_threshold": 1.5,
			"age_decline_factor": 0.02,
			"min_roster_size": 45
		},
		"league": {
			"cap_limit": 200.0
		}
	}

	# Add league state
	world_state["league"] = {"cap_limit": 200.0}

	var result := RosterManagement.run(world_state, 2025, 12345, main_cfg)

	print("  Teams processed: %d" % result.get("teams_processed", 0))
	print("  Total releases: %d" % result.get("total_releases", 0))
	print("  Total cap saved: $%.2fM" % result.get("total_cap_saved", 0.0))

	# Analyze team cap situation
	var team_id := "nfl_001"
	var roster: Dictionary = world_state["nfl_rosters"][team_id]
	var players: Array = roster["players"]

	var cap_used := RosterManagement._calculate_team_cap_usage(players)
	var cap_space := 200.0 - cap_used

	print("\n  Team Analysis (nfl_001):")
	print("    Roster size: %d players" % players.size())
	print("    Cap used: $%.2fM" % cap_used)
	print("    Cap space: $%.2fM" % cap_space)
	print("    Target budget: $30-50M")
	print("    Needs releases: %s" % ("YES" if cap_space < 30.0 else "NO"))

	if result.get("total_releases", 0) > 0:
		print("\n  ✓ SUCCESS: Got releases with correct annual_value")
		print("  Releases by team:")
		var releases_by_team: Dictionary = result.get("releases_by_team", {})
		for tid in releases_by_team.keys():
			print("    %s: %d releases" % [tid, releases_by_team[tid]])
	else:
		print("\n  ✗ ISSUE: 0 releases even with annual_value")
		print("  Possible reasons:")
		print("    - All contracts are efficient (no candidates)")
		print("    - Teams already have sufficient cap space")
		print("    - Players protected (rookies)")

func test_3_cap_calculation_analysis():
	print("\n[TEST 3] Cap Calculation Detailed Analysis")
	print("-".repeat(80))

	# Test cap calculation with various contract structures
	var test_cases := [
		{
			"name": "Missing annual_value",
			"players": [
				{"contract": {"years_remaining": 2}},
				{"contract": {"years_remaining": 3}},
				{"contract": {"years_remaining": 1}}
			],
			"expected": 0.0
		},
		{
			"name": "With annual_value",
			"players": [
				{"contract": {"annual_value": 10.0}},
				{"contract": {"annual_value": 15.0}},
				{"contract": {"annual_value": 5.0}}
			],
			"expected": 30.0
		},
		{
			"name": "Mixed (some missing)",
			"players": [
				{"contract": {"annual_value": 10.0}},
				{"contract": {"years_remaining": 2}},
				{"contract": {"annual_value": 5.0}}
			],
			"expected": 15.0
		},
		{
			"name": "Empty contracts",
			"players": [
				{"contract": {}},
				{"contract": {}},
				{"contract": {}}
			],
			"expected": 0.0
		}
	]

	for test_case in test_cases:
		var tc: Dictionary = test_case
		var players: Array = tc["players"]
		var expected: float = tc["expected"]
		var name: String = tc["name"]

		var result := RosterManagement._calculate_team_cap_usage(players)
		var status := "✓" if abs(result - expected) < 0.01 else "✗"

		print("  %s %s: $%.2fM (expected $%.2fM)" % [status, name, result, expected])

func test_4_release_decision_trace():
	print("\n[TEST 4] Release Decision Logic Trace")
	print("-".repeat(80))

	# Create scenarios with different cap situations
	var scenarios := [
		{
			"name": "Zero cap usage (missing annual_value)",
			"cap_used": 0.0,
			"target": 40.0,
			"should_release": false,
			"reason": "cap_space (200.0) >= target (40.0)"
		},
		{
			"name": "Low cap usage",
			"cap_used": 150.0,
			"target": 40.0,
			"should_release": false,
			"reason": "cap_space (50.0) >= target (40.0)"
		},
		{
			"name": "Near cap limit",
			"cap_used": 180.0,
			"target": 40.0,
			"should_release": true,
			"reason": "cap_space (20.0) < target (40.0)"
		},
		{
			"name": "Over cap limit",
			"cap_used": 210.0,
			"target": 40.0,
			"should_release": true,
			"reason": "cap_space (-10.0) < target (40.0)"
		}
	]

	var cap_limit := 200.0

	for scenario in scenarios:
		var s: Dictionary = scenario
		var name: String = s["name"]
		var cap_used: float = s["cap_used"]
		var target: float = s["target"]
		var should_release: bool = s["should_release"]
		var reason: String = s["reason"]

		var cap_space := cap_limit - cap_used
		var will_release := cap_space < target

		var status := "✓" if will_release == should_release else "✗"

		print("\n  %s %s" % [status, name])
		print("    Cap used: $%.2fM" % cap_used)
		print("    Cap space: $%.2fM" % cap_space)
		print("    Target: $%.2fM" % target)
		print("    Will release: %s" % ("YES" if will_release else "NO"))
		print("    Reason: %s" % reason)

func _create_world_state_no_annual_value() -> Dictionary:
	"""Create world state with contracts MISSING annual_value (reproduces issue)"""
	var teams := []
	for i in range(3):  # 3 teams for faster testing
		teams.append({
			"id": "nfl_%03d" % (i + 1),
			"name": "Team %d" % (i + 1),
			"region": "afc_east"
		})

	var rosters := {}
	for team in teams:
		var t: Dictionary = team
		var players := []
		for j in range(53):
			players.append({
				"id": "player_%s_%d" % [t["id"], j],
				"position": ["QB", "RB", "WR", "TE", "OL"][j % 5],
				"eval_score": 60.0 + randf() * 30.0,
				"age": 22 + (j % 10),
				"draft_year": 2020,
				"contract": {
					"years_remaining": 1 + (j % 4),
					"years_total": 4
					# MISSING: annual_value
					# MISSING: signed_year
				}
			})
		rosters[t["id"]] = {"players": players}

	return {
		"nfl_teams": teams,
		"nfl_rosters": rosters,
		"free_agents": {}
	}

func _create_world_state_with_annual_value() -> Dictionary:
	"""Create world state with contracts HAVING annual_value (correct)"""
	var teams := []
	for i in range(3):  # 3 teams for faster testing
		teams.append({
			"id": "nfl_%03d" % (i + 1),
			"name": "Team %d" % (i + 1),
			"region": "afc_east"
		})

	var rosters := {}
	for team in teams:
		var t: Dictionary = team
		var players := []
		for j in range(53):
			# Generate realistic annual_value based on position and age
			var age := 22 + (j % 10)
			var eval_score := 60.0 + randf() * 30.0
			var position: String = ["QB", "RB", "WR", "TE", "OL"][j % 5]

			# Higher salaries for older/better players (creates release candidates)
			var annual_value := _generate_realistic_salary(position, age, eval_score)

			players.append({
				"id": "player_%s_%d" % [t["id"], j],
				"position": position,
				"eval_score": eval_score,
				"age": age,
				"draft_year": 2020,
				"contract": {
					"annual_value": annual_value,
					"signed_year": 2020,
					"years_remaining": 1 + (j % 4),
					"years_total": 4
				}
			})
		rosters[t["id"]] = {"players": players}

	return {
		"nfl_teams": teams,
		"nfl_rosters": rosters,
		"free_agents": {}
	}

func _generate_realistic_salary(position: String, age: int, eval_score: float) -> float:
	"""Generate realistic NFL salary based on position, age, and performance"""
	# Base salary by position (millions)
	var base := {
		"QB": 8.0,
		"RB": 2.5,
		"WR": 4.0,
		"TE": 3.0,
		"OL": 3.5
	}.get(position, 3.0)

	# Age multiplier (veterans get paid more, but decline if too old)
	var age_mult := 1.0
	if age < 25:
		age_mult = 0.6  # Rookie scale
	elif age < 28:
		age_mult = 1.2  # Prime earning years
	elif age < 32:
		age_mult = 1.0  # Still good
	else:
		age_mult = 0.8  # Aging, overpaid candidates

	# Performance multiplier
	var perf_mult := (eval_score / 75.0)  # Scale 60-90 to ~0.8-1.2

	# Calculate final salary with some variance
	var salary := base * age_mult * perf_mult * randf_range(0.8, 1.2)

	# Clamp to realistic NFL range
	return clampf(salary, 0.5, 25.0)
