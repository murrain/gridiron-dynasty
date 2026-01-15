## GdUnit4 test suite for CollegeMedicalService
##
## Tests injury context, medical evaluations, recurring injury detection,
## team-specific evaluations, and hype impact calculations.
extends GdUnitTestSuite

const CollegeMedicalService = preload("res://scripts/world/CollegeMedicalService.gd")


func test_apply_college_injury_context() -> void:
	var player := {
		"player_id": "test_001",
		"hype": 50.0,
		"injuries": [
			{
				"type": "knee",
				"body_part": "ACL",
				"severity": 3.0,
				"recovery_timeline": {"years_total": 1}
			}
		]
	}

	var config := {
		"injury_hype_impact": {
			"base_per_severity": -4.0,
			"base_halflife": 0.5,
			"halflife_per_severity": 0.25,
			"type_multipliers": {"knee": 1.5}
		}
	}

	CollegeMedicalService.apply_college_injury_context(player, 2024, 12, config)

	var injuries: Array = player.get("injuries", [])
	var injury: Dictionary = injuries[0]
	assert_bool(injury.has("college_injury_context")).is_true()

	var context: Dictionary = injury.get("college_injury_context", {})
	assert_int(context.get("year")).is_equal(2024)
	assert_int(int(context.get("games_missed", 0))).is_greater(0)
	assert_float(float(context.get("hype_impact", 0.0))).is_less(0.0)

	# Verify hype was reduced
	assert_float(float(player.get("hype", 50.0))).is_less(50.0)

	# Verify history was added
	assert_bool(player.has("history")).is_true()
	var history: Array = player.get("history", [])
	assert_int(history.size()).is_greater(0)


func test_evaluate_medical_status_clean() -> void:
	var player := {"player_id": "test_001", "injuries": []}
	var config := {"medical_evaluation": {}}

	var eval := CollegeMedicalService.evaluate_medical_status(player, config)

	assert_str(eval.get("grade")).is_equal("clean")
	assert_float(float(eval.get("durability_projection"))).is_equal(1.0)
	assert_float(float(eval.get("draft_impact"))).is_equal(1.0)


func test_evaluate_medical_status_concern() -> void:
	var player := {
		"player_id": "test_001",
		"injuries": [
			{"type": "knee", "severity": 2.5},
			{"type": "knee", "severity": 2.0},  # Recurring
			{"type": "ankle", "severity": 1.5}
		]
	}

	var config := {
		"medical_evaluation": {
			"surgery_required_types": ["knee", "shoulder", "back"],
			"recurring_injury_multiplier": 1.5,
			"grade_criteria": {
				"failed": {"triggers": ["recurring_major", "multiple_surgeries"]},
				"major_concern": {"max_injuries": 4, "max_surgeries": 2, "max_severity_sum": 12.0},
				"minor_concern": {"max_injuries": 2, "max_surgeries": 1, "max_severity_sum": 6.0},
				"clean": {"max_injuries": 1, "max_surgeries": 0, "max_severity_sum": 3.0}
			},
			"draft_impact_multipliers": {
				"clean": 1.0,
				"minor_concern": 0.95,
				"major_concern": 0.85,
				"failed": 0.70
			}
		}
	}

	var eval := CollegeMedicalService.evaluate_medical_status(player, config)

	assert_int(int(eval.get("injury_count"))).is_equal(3)
	assert_int(eval.get("recurring_injuries", []).size()).is_greater(0)
	assert_float(float(eval.get("durability_projection"))).is_less(1.0)


func test_check_for_recurring_injury() -> void:
	var player := {
		"injuries": [
			{"type": "knee"},
			{"type": "knee"},
			{"type": "ankle"}
		]
	}

	var is_recurring := CollegeMedicalService.check_for_recurring_injury(player, "knee", {})
	assert_bool(is_recurring).is_true()

	is_recurring = CollegeMedicalService.check_for_recurring_injury(player, "ankle", {})
	assert_bool(is_recurring).is_false()


func test_evaluate_for_team() -> void:
	var config := {
		"team_medical_tolerance": {
			"risk_averse": {"penalty_multiplier": 1.5},
			"cautious": {"penalty_multiplier": 1.0},
			"moderate_risk": {"penalty_multiplier": 0.7},
			"aggressive": {"penalty_multiplier": 0.4}
		}
	}

	# Clean medical
	var player := {"medical_evaluation": {"grade": "clean"}}

	var risk_averse_team := {"medical_tolerance": "risk_averse"}
	var aggressive_team := {"medical_tolerance": "aggressive"}

	var ra_score := CollegeMedicalService.evaluate_for_team(player, risk_averse_team, config)
	var ag_score := CollegeMedicalService.evaluate_for_team(player, aggressive_team, config)

	assert_float(ra_score).is_equal(100.0)
	assert_float(ag_score).is_equal(100.0)

	# Major concern
	player = {"medical_evaluation": {"grade": "major_concern"}}
	ra_score = CollegeMedicalService.evaluate_for_team(player, risk_averse_team, config)
	ag_score = CollegeMedicalService.evaluate_for_team(player, aggressive_team, config)

	assert_float(ra_score).is_less(ag_score)


func test_calculate_injury_hype_impact() -> void:
	var player := {
		"injuries": [
			{"college_injury_context": {"hype_impact": -8.0}},
			{"college_injury_context": {"hype_impact": -5.0}},
			{"type": "minor"}  # No college context
		]
	}

	var total := CollegeMedicalService.calculate_injury_hype_impact(player)
	assert_float(abs(total - (-13.0))).is_less(0.01)
