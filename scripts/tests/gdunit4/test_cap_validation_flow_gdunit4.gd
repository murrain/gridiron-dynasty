## GdUnit4 test suite for CapValidationFlow
##
## Tests cap validation logic including over-cap detection and cap usage calculation.
extends GdUnitTestSuite

const CapValidationFlow = preload("res://scripts/world/CapValidationFlow.gd")


func test_cap_validation_flags_over_cap_teams() -> void:
	var world_state := {
		"teams": [
			{"id": "alpha", "name": "Alpha"},
			{"id": "beta", "name": "Beta"}
		],
		"team_rosters": {
			"alpha": [
				{"contract": {"annual_value": 3.5}},
				{"contract": {"annual_value": 3.0}}
			],
			"beta": [
				{"annual_value": 1.5}
			]
		}
	}

	var output := CapValidationFlow.run(world_state, 2030, "cap_validation", 6.0)
	var teams: Array = world_state.get("teams", []) as Array

	var alpha: Dictionary = teams[0]
	var beta: Dictionary = teams[1]

	assert_bool(alpha.get("is_over_cap", false)).is_true()
	assert_bool(beta.get("is_over_cap", true)).is_false()


func test_cap_validation_sums_contracts() -> void:
	var world_state := {
		"teams": [
			{"id": "alpha", "name": "Alpha"},
			{"id": "beta", "name": "Beta"}
		],
		"team_rosters": {
			"alpha": [
				{"contract": {"annual_value": 3.5}},
				{"contract": {"annual_value": 3.0}}
			],
			"beta": [
				{"annual_value": 1.5}
			]
		}
	}

	var _output := CapValidationFlow.run(world_state, 2030, "cap_validation", 6.0)
	var teams: Array = world_state.get("teams", []) as Array

	var alpha: Dictionary = teams[0]
	var beta: Dictionary = teams[1]

	var alpha_cap: Dictionary = alpha.get("cap", {})
	var beta_cap: Dictionary = beta.get("cap", {})

	# Alpha: 3.5 + 3.0 = 6.5
	assert_float(float(alpha_cap.get("cap_used", 0.0))).is_equal_approx(6.5, 0.0001)

	# Beta: 1.5
	assert_float(float(beta_cap.get("cap_used", 0.0))).is_equal_approx(1.5, 0.0001)


func test_cap_validation_reports_teams_checked() -> void:
	var world_state := {
		"teams": [
			{"id": "alpha", "name": "Alpha"},
			{"id": "beta", "name": "Beta"}
		],
		"team_rosters": {
			"alpha": [
				{"contract": {"annual_value": 3.5}},
				{"contract": {"annual_value": 3.0}}
			],
			"beta": [
				{"annual_value": 1.5}
			]
		}
	}

	var output := CapValidationFlow.run(world_state, 2030, "cap_validation", 6.0)

	assert_int(int(output.get("teams_checked", 0))).is_equal(2)


func test_cap_validation_empty_roster() -> void:
	var world_state := {
		"teams": [
			{"id": "empty_team", "name": "Empty Team"}
		],
		"team_rosters": {
			"empty_team": []
		}
	}

	var _output := CapValidationFlow.run(world_state, 2030, "cap_validation", 10.0)
	var teams: Array = world_state.get("teams", []) as Array

	var empty_team: Dictionary = teams[0]
	var cap: Dictionary = empty_team.get("cap", {})

	assert_bool(empty_team.get("is_over_cap", true)).is_false()
	assert_float(float(cap.get("cap_used", -1.0))).is_equal_approx(0.0, 0.0001)


func test_cap_validation_exactly_at_cap() -> void:
	var world_state := {
		"teams": [
			{"id": "exact_team", "name": "Exact Team"}
		],
		"team_rosters": {
			"exact_team": [
				{"contract": {"annual_value": 5.0}},
				{"contract": {"annual_value": 5.0}}
			]
		}
	}

	var _output := CapValidationFlow.run(world_state, 2030, "cap_validation", 10.0)
	var teams: Array = world_state.get("teams", []) as Array

	var exact_team: Dictionary = teams[0]

	# Exactly at cap should NOT be flagged as over cap
	assert_bool(exact_team.get("is_over_cap", true)).is_false()
