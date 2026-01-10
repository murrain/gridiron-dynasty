extends RefCounted

const CapValidationFlow = preload("res://scripts/world/CapValidationFlow.gd")

func run(t) -> void:
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

	var alpha_cap: Dictionary = alpha.get("cap", {})
	var beta_cap: Dictionary = beta.get("cap", {})

	t.assert_eq(alpha.get("is_over_cap", false), true, "alpha is flagged over cap")
	t.assert_eq(beta.get("is_over_cap", true), false, "beta is not flagged over cap")
	t.assert_approx(float(alpha_cap.get("cap_used", 0.0)), 6.5, 0.0001, "alpha cap used sums contracts")
	t.assert_approx(float(beta_cap.get("cap_used", 0.0)), 1.5, 0.0001, "beta cap used sums contracts")
	t.assert_eq(int(output.get("teams_checked", 0)), 2, "output reports teams checked")
