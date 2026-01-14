extends SceneTree

## Unit test for RosterManagement system
##
## Tests the core roster management logic in isolation

const RosterManagement = preload("res://scripts/world/RosterManagement.gd")

func _init():
	print("\n" + "=".repeat(80))
	print("ROSTER MANAGEMENT UNIT TEST")
	print("=".repeat(80))

	test_release_candidates_identification()
	test_cap_calculation()
	test_release_execution()
	test_dead_cap_placeholder()

	print("\n" + "=".repeat(80))
	print("ALL TESTS PASSED")
	print("=".repeat(80))

	quit()

func test_release_candidates_identification():
	print("\n[TEST 1] Identify release candidates")

	var players := [
		{
			"id": "p1",
			"name": "High Cap Low Value",
			"position": "WR",
			"age": 32,
			"eval_score": 55.0,
			"draft_year": 2010,
			"contract": {
				"annual_value": 15.0,
				"signed_year": 2015,
				"years_remaining": 1
			}
		},
		{
			"id": "p2",
			"name": "Good Value",
			"position": "QB",
			"age": 27,
			"eval_score": 85.0,
			"draft_year": 2018,
			"contract": {
				"annual_value": 10.0,
				"signed_year": 2022,
				"years_remaining": 2
			}
		},
		{
			"id": "p3",
			"name": "Rookie",
			"position": "RB",
			"age": 22,
			"eval_score": 70.0,
			"draft_year": 2023,
			"contract": {
				"annual_value": 2.0,
				"signed_year": 2023,
				"years_remaining": 3
			}
		},
		{
			"id": "p4",
			"name": "Overpaid Vet",
			"position": "OL",
			"age": 34,
			"eval_score": 60.0,
			"draft_year": 2012,
			"contract": {
				"annual_value": 12.0,
				"signed_year": 2018,
				"years_remaining": 1
			}
		}
	]

	var candidates := RosterManagement._identify_release_candidates(
		players,
		1.5,  # value_threshold
		0.02, # age_decline_factor
		2025  # current_year
	)

	print("  Found %d release candidates (expected 3)" % candidates.size())
	assert(candidates.size() == 3, "Should identify 3 candidates (excluding only the protected rookie)")

	# Check that rookie is NOT in candidates
	var has_rookie := false
	for c in candidates:
		if String(c.get("player_id", "")) == "p3":
			has_rookie = true
	assert(not has_rookie, "Rookies should be protected")

	print("  ✓ PASS: Correctly identifies release candidates")

func test_cap_calculation():
	print("\n[TEST 2] Calculate team cap usage")

	var players := [
		{
			"contract": {"annual_value": 10.0}
		},
		{
			"contract": {"annual_value": 15.0}
		},
		{
			"contract": {"annual_value": 5.0}
		},
		{
			"contract": {}  # No contract
		}
	]

	var total := RosterManagement._calculate_team_cap_usage(players)

	print("  Total cap usage: $%.2fM (expected $30.00M)" % total)
	assert(abs(total - 30.0) < 0.01, "Should sum cap hits correctly")

	print("  ✓ PASS: Cap calculation correct")

func test_release_execution():
	print("\n[TEST 3] Execute player releases")

	var world_state := {
		"nfl_rosters": {
			"team_001": {
				"players": [
					{"id": "p1", "name": "Player 1", "contract": {}},
					{"id": "p2", "name": "Player 2", "contract": {}},
					{"id": "p3", "name": "Player 3", "contract": {}}
				]
			}
		},
		"free_agents": {}
	}

	var releases := [
		{
			"player_id": "p2",
			"team_id": "team_001",
			"year": 2025,
			"reason": "cap_efficiency",
			"annual_value": 10.0,
			"dead_cap": 0.0,
			"net_savings": 10.0
		}
	]

	RosterManagement._execute_releases(world_state, "team_001", releases, 2025)

	var roster: Dictionary = world_state["nfl_rosters"]["team_001"]
	var remaining: Array = roster["players"]

	print("  Remaining roster size: %d (expected 2)" % remaining.size())
	assert(remaining.size() == 2, "Should remove released player")

	# Check released player is in FA pool
	var fa_pool: Dictionary = world_state.get("free_agents", {})
	var year_fas: Array = fa_pool.get(2025, [])

	print("  Free agents for 2025: %d (expected 1)" % year_fas.size())
	assert(year_fas.size() == 1, "Released player should be in FA pool")

	var released_player: Dictionary = year_fas[0]
	print("  Released player ID: %s (expected p2)" % released_player.get("id", ""))
	assert(String(released_player.get("id", "")) == "p2", "Correct player should be in FA pool")

	print("  ✓ PASS: Release execution works correctly")

func test_dead_cap_placeholder():
	print("\n[TEST 4] Dead cap calculation placeholder")

	var player := {
		"contract": {
			"annual_value": 10.0
		}
	}

	var dead_cap := RosterManagement._calculate_dead_cap(player)

	print("  Dead cap: $%.2fM (expected $0.00M - placeholder)" % dead_cap)
	assert(dead_cap == 0.0, "Placeholder should return 0.0")

	print("  ✓ PASS: Dead cap placeholder in place")
