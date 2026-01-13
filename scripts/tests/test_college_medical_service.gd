extends RefCounted

const CollegeMedicalService = preload("res://scripts/world/CollegeMedicalService.gd")

func run(t) -> void:
	test_apply_college_injury_context(t)
	test_evaluate_medical_status_clean(t)
	test_evaluate_medical_status_concern(t)
	test_check_for_recurring_injury(t)
	test_evaluate_for_team(t)
	test_calculate_injury_hype_impact(t)

func test_apply_college_injury_context(t) -> void:
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
	t.assert_true(injury.has("college_injury_context"), "injury has college context")

	var context: Dictionary = injury.get("college_injury_context", {})
	t.assert_eq(context.get("year"), 2024, "context has correct year")
	t.assert_true(int(context.get("games_missed", 0)) > 0, "games missed calculated")
	t.assert_true(float(context.get("hype_impact", 0.0)) < 0.0, "hype impact is negative")

	# Verify hype was reduced
	t.assert_true(float(player.get("hype", 50.0)) < 50.0, "player hype was reduced")

	# Verify history was added
	t.assert_true(player.has("history"), "history was initialized")
	var history: Array = player.get("history", [])
	t.assert_true(history.size() > 0, "injury added to history")

func test_evaluate_medical_status_clean(t) -> void:
	var player := {"player_id": "test_001", "injuries": []}
	var config := {"medical_evaluation": {}}

	var eval := CollegeMedicalService.evaluate_medical_status(player, config)

	t.assert_eq(eval.get("grade"), "clean", "no injuries = clean grade")
	t.assert_eq(float(eval.get("durability_projection")), 1.0, "durability is 1.0 for clean")
	t.assert_eq(float(eval.get("draft_impact")), 1.0, "draft_impact is 1.0 for clean")

func test_evaluate_medical_status_concern(t) -> void:
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

	t.assert_eq(int(eval.get("injury_count")), 3, "injury count is 3")
	t.assert_true(eval.get("recurring_injuries", []).size() > 0, "recurring injuries detected")
	t.assert_true(float(eval.get("durability_projection")) < 1.0, "durability reduced")

func test_check_for_recurring_injury(t) -> void:
	var player := {
		"injuries": [
			{"type": "knee"},
			{"type": "knee"},
			{"type": "ankle"}
		]
	}

	var is_recurring := CollegeMedicalService.check_for_recurring_injury(player, "knee", {})
	t.assert_true(is_recurring, "knee is recurring (2+ occurrences)")

	is_recurring = CollegeMedicalService.check_for_recurring_injury(player, "ankle", {})
	t.assert_false(is_recurring, "ankle is not recurring (only 1 occurrence)")

func test_evaluate_for_team(t) -> void:
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

	t.assert_eq(ra_score, 100.0, "clean player scores 100 with risk_averse team")
	t.assert_eq(ag_score, 100.0, "clean player scores 100 with aggressive team")

	# Major concern
	player = {"medical_evaluation": {"grade": "major_concern"}}
	ra_score = CollegeMedicalService.evaluate_for_team(player, risk_averse_team, config)
	ag_score = CollegeMedicalService.evaluate_for_team(player, aggressive_team, config)

	t.assert_true(ra_score < ag_score, "risk_averse team penalizes more than aggressive")

func test_calculate_injury_hype_impact(t) -> void:
	var player := {
		"injuries": [
			{"college_injury_context": {"hype_impact": -8.0}},
			{"college_injury_context": {"hype_impact": -5.0}},
			{"type": "minor"}  # No college context
		]
	}

	var total := CollegeMedicalService.calculate_injury_hype_impact(player)
	t.assert_true(abs(total - (-13.0)) < 0.01, "total hype impact is -13.0")
