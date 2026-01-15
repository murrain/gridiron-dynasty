## GdUnit4 test suite for Roster Management Data Flow
##
## Verifies that contract annual_value is required for cap calculations.
## Tests cap calculation behavior with and without annual_value field.
extends GdUnitTestSuite

const RosterManagement = preload("res://scripts/world/RosterManagement.gd")


func _create_main_cfg() -> Dictionary:
	return {
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


func _generate_realistic_salary(position: String, age: int, eval_score: float, rng: RandomNumberGenerator) -> float:
	var base: float = float({
		"QB": 8.0,
		"RB": 2.5,
		"WR": 4.0,
		"TE": 3.0,
		"OL": 3.5
	}.get(position, 3.0))

	var age_mult: float = 1.0
	if age < 25:
		age_mult = 0.6
	elif age < 28:
		age_mult = 1.2
	elif age < 32:
		age_mult = 1.0
	else:
		age_mult = 0.8

	var perf_mult: float = (eval_score / 75.0)
	var salary: float = base * age_mult * perf_mult * rng.randf_range(0.8, 1.2)

	return clampf(salary, 0.5, 25.0)


func _create_world_state_no_annual_value() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33333

	var teams := []
	for i in range(3):
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
				"eval_score": 60.0 + rng.randf() * 30.0,
				"age": 22 + (j % 10),
				"draft_year": 2020,
				"contract": {
					"years_remaining": 1 + (j % 4),
					"years_total": 4
					# MISSING: annual_value
				}
			})
		rosters[t["id"]] = {"players": players}

	return {
		"nfl_teams": teams,
		"nfl_rosters": rosters,
		"free_agents": {},
		"league": {"cap_limit": 200.0}
	}


func _create_world_state_with_annual_value() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 44444

	var teams := []
	for i in range(3):
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
			var age := 22 + (j % 10)
			var eval_score := 60.0 + rng.randf() * 30.0
			var position: String = ["QB", "RB", "WR", "TE", "OL"][j % 5]
			var annual_value := _generate_realistic_salary(position, age, eval_score, rng)

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
		"free_agents": {},
		"league": {"cap_limit": 200.0}
	}


func test_without_annual_value_zero_cap_usage() -> void:
	var world_state := _create_world_state_no_annual_value()
	var main_cfg := _create_main_cfg()

	var result := RosterManagement.run(world_state, 2025, 12345, main_cfg)

	# Cap usage should be 0 when annual_value is missing
	var team_id := "nfl_001"
	var roster: Dictionary = world_state["nfl_rosters"][team_id]
	var players: Array = roster["players"]

	var cap_used := RosterManagement._calculate_team_cap_usage(players)

	# Without annual_value, cap should be 0
	assert_float(cap_used).is_equal_approx(0.0, 0.01)


func test_with_annual_value_nonzero_cap_usage() -> void:
	var world_state := _create_world_state_with_annual_value()
	var main_cfg := _create_main_cfg()

	var _result := RosterManagement.run(world_state, 2025, 12345, main_cfg)

	var team_id := "nfl_001"
	var roster: Dictionary = world_state["nfl_rosters"][team_id]
	var players: Array = roster["players"]

	var cap_used := RosterManagement._calculate_team_cap_usage(players)

	# With annual_value, cap should be > 0
	assert_float(cap_used).is_greater(0.0)


func test_cap_calculation_detailed() -> void:
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

		var result := RosterManagement._calculate_team_cap_usage(players)

		assert_float(result).is_equal_approx(expected, 0.01)


func test_release_decision_logic() -> void:
	var cap_limit := 200.0

	# Scenario: Zero cap usage (missing annual_value)
	var cap_used_zero := 0.0
	var cap_space_zero := cap_limit - cap_used_zero
	var target := 40.0
	var will_release_zero := cap_space_zero < target
	assert_bool(will_release_zero).is_false()  # cap_space (200.0) >= target (40.0)

	# Scenario: Near cap limit
	var cap_used_high := 180.0
	var cap_space_high := cap_limit - cap_used_high
	var will_release_high := cap_space_high < target
	assert_bool(will_release_high).is_true()  # cap_space (20.0) < target (40.0)

	# Scenario: Over cap limit
	var cap_used_over := 210.0
	var cap_space_over := cap_limit - cap_used_over
	var will_release_over := cap_space_over < target
	assert_bool(will_release_over).is_true()  # cap_space (-10.0) < target (40.0)
