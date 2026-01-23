extends GdUnitTestSuite
class_name TestHypeModifierGdUnit4

## Tests for HypeModifier - Additive OVR adjustments based on hype and awards
##
## Validates:
## - Hype calculation (media hype influence)
## - Award bonuses (Heisman, All-American, etc.)
## - Team susceptibility scaling
## - Round scaling (early vs late rounds)
## - Bounds enforcement (-3 to +9 OVR)
## - Determinism (no RNG)

const HypeModifier = preload("res://scripts/core/evaluation/modifiers/HypeModifier.gd")
const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# =============================================================================
# METADATA TESTS
# =============================================================================

func test_hype_modifier_has_correct_id() -> void:
	var modifier := HypeModifier.new()
	assert_string(modifier.get_id()).is_equal("hype")


func test_hype_modifier_is_additive_type() -> void:
	var modifier := HypeModifier.new()
	var tags := modifier.get_tags()

	assert_array(tags).contains(["additive"])


func test_hype_modifier_has_correct_priority() -> void:
	var modifier := HypeModifier.new()
	# Should run after team need (25) and scouting knowledge (35), before scheme fit (50)
	assert_int(modifier.get_priority()).is_equal(40)


func test_hype_modifier_has_correct_bounds() -> void:
	var modifier := HypeModifier.new()
	var bounds := modifier.get_bounds()

	assert_float(bounds["min"]).is_equal(-3.0)
	assert_float(bounds["max"]).is_equal(9.0)


# =============================================================================
# APPLICABILITY TESTS
# =============================================================================

func test_is_applicable_only_during_draft_phase() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	var team := {"team_id": "T001"}

	# Draft phase - should be applicable
	var ctx_draft := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	assert_bool(modifier.is_applicable(ctx_draft)).is_true()

	# FA phase - should not be applicable
	var ctx_fa := EvaluationContext.for_free_agency(player, team, {}, 2025, {}, {})
	assert_bool(modifier.is_applicable(ctx_fa)).is_false()

	# Trade phase - should not be applicable
	var ctx_trade := EvaluationContext.for_trade(player, team, {}, 2025, {}, {})
	assert_bool(modifier.is_applicable(ctx_trade)).is_false()


func test_is_not_applicable_when_draft_round_zero() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	var team := {"team_id": "T001"}

	var ctx := EvaluationContext.for_draft(player, team, {}, 0, 2025, {}, {}, {}, {})

	assert_bool(modifier.is_applicable(ctx)).is_false()


# =============================================================================
# HYPE CALCULATION TESTS
# =============================================================================

func test_neutral_hype_produces_zero_adjustment() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 50.0  # Neutral hype
	var team := {"team_id": "T001", "hype_susceptibility": 0.5}

	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	var result := modifier.calculate(ctx)

	# Neutral hype with no awards should be near zero
	assert_float(result.additive_bonus).is_equal_approx(0.0, 0.1)


func test_high_hype_produces_positive_bonus() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 90.0  # High hype (80% above neutral)
	var team := {"team_id": "T001", "hype_susceptibility": 0.5}

	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	var result := modifier.calculate(ctx)

	# High hype should produce positive bonus
	assert_float(result.additive_bonus).is_greater(0.0)
	assert_that(result.details).has("player_hype")
	assert_float(result.details["player_hype"]).is_equal(90.0)


func test_low_hype_produces_negative_penalty() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 25.0  # Low hype (50% below neutral)
	var team := {"team_id": "T001", "hype_susceptibility": 0.5}

	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	var result := modifier.calculate(ctx)

	# Low hype should produce negative penalty
	assert_float(result.additive_bonus).is_less(0.0)


func test_team_susceptibility_scales_hype_effect() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 80.0

	# Low susceptibility (analytics team)
	var team_analytics := {"team_id": "T001", "hype_susceptibility": 0.2}
	var ctx_analytics := EvaluationContext.for_draft(player, team_analytics, {}, 1, 2025, {}, {}, {}, {})
	var result_analytics := modifier.calculate(ctx_analytics)

	# High susceptibility (narrative team)
	var team_narrative := {"team_id": "T002", "hype_susceptibility": 0.8}
	var ctx_narrative := EvaluationContext.for_draft(player, team_narrative, {}, 1, 2025, {}, {}, {}, {})
	var result_narrative := modifier.calculate(ctx_narrative)

	# Narrative team should have larger bonus from same hype
	assert_float(result_narrative.additive_bonus).is_greater(result_analytics.additive_bonus)


func test_round_scaling_reduces_late_round_hype_effect() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 80.0
	var team := {"team_id": "T001", "hype_susceptibility": 0.5}

	# Round 1 (highest scaling: 1.2x)
	var ctx_r1 := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	var result_r1 := modifier.calculate(ctx_r1)

	# Round 5 (late round scaling: 0.5x)
	var ctx_r5 := EvaluationContext.for_draft(player, team, {}, 5, 2025, {}, {}, {}, {})
	var result_r5 := modifier.calculate(ctx_r5)

	# Round 1 should have larger effect than round 5
	assert_float(result_r1.additive_bonus).is_greater(result_r5.additive_bonus)


# =============================================================================
# AWARD BONUS TESTS
# =============================================================================

func test_heisman_winner_receives_large_bonus() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 50.0  # Neutral hype
	player["awards"] = ["heisman_winner"]
	var team := {"team_id": "T001", "hype_susceptibility": 0.5}

	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	var result := modifier.calculate(ctx)

	# Heisman winner should get significant bonus (3.0 OVR default)
	assert_float(result.additive_bonus).is_greater_equal(3.0)


func test_all_american_receives_bonus() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 50.0
	player["awards"] = ["all_american_first"]
	var team := {"team_id": "T001", "hype_susceptibility": 0.5}

	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	var result := modifier.calculate(ctx)

	# All-American should get bonus (2.0 OVR default)
	assert_float(result.additive_bonus).is_greater_equal(2.0)


func test_multiple_awards_stack() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 50.0
	player["awards"] = ["all_american_first", "conference_poy", "combine_standout"]
	var team := {"team_id": "T001", "hype_susceptibility": 0.5}

	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	var result := modifier.calculate(ctx)

	# Multiple awards should stack (2.0 + 1.0 + 0.5 = 3.5)
	assert_float(result.additive_bonus).is_greater_equal(3.0)


func test_award_bonus_capped_at_maximum() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 100.0  # Max hype
	# Stack many awards that would exceed cap
	player["awards"] = [
		"heisman_winner",
		"all_american_first",
		"conference_poy",
		"combine_standout",
		"senior_bowl_mvp"
	]
	var team := {"team_id": "T001", "hype_susceptibility": 1.0}

	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	var result := modifier.calculate(ctx)

	# Should respect max bound of 9.0 OVR
	assert_float(result.additive_bonus).is_less_equal(9.0)


func test_award_bonuses_independent_of_team_susceptibility() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 50.0  # Neutral hype (no hype bonus)
	player["awards"] = ["heisman_winner"]

	# Low susceptibility team
	var team_low := {"team_id": "T001", "hype_susceptibility": 0.1}
	var ctx_low := EvaluationContext.for_draft(player, team_low, {}, 1, 2025, {}, {}, {}, {})
	var result_low := modifier.calculate(ctx_low)

	# High susceptibility team
	var team_high := {"team_id": "T002", "hype_susceptibility": 0.9}
	var ctx_high := EvaluationContext.for_draft(player, team_high, {}, 1, 2025, {}, {}, {}, {})
	var result_high := modifier.calculate(ctx_high)

	# Award bonuses should be equal (independent of susceptibility)
	assert_float(result_low.additive_bonus).is_equal_approx(result_high.additive_bonus, 0.1)


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_missing_hype_defaults_to_neutral() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	# No hype field
	var team := {"team_id": "T001", "hype_susceptibility": 0.5}

	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	var result := modifier.calculate(ctx)

	# Should default to neutral (50.0) and produce near-zero bonus
	assert_float(result.additive_bonus).is_equal_approx(0.0, 0.5)


func test_missing_susceptibility_defaults_to_moderate() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 80.0
	var team := {"team_id": "T001"}  # No susceptibility field

	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	var result := modifier.calculate(ctx)

	# Should use default susceptibility (0.5) and produce moderate bonus
	assert_float(result.additive_bonus).is_greater(0.0)


func test_empty_awards_array_produces_no_award_bonus() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 50.0
	player["awards"] = []
	var team := {"team_id": "T001", "hype_susceptibility": 0.5}

	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	var result := modifier.calculate(ctx)

	# Only award bonus should be zero; hype might have small effect
	assert_float(result.details.get("award_bonus", 0.0)).is_equal(0.0)


func test_unknown_awards_ignored_gracefully() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 50.0
	player["awards"] = ["unknown_award", "fake_award"]
	var team := {"team_id": "T001", "hype_susceptibility": 0.5}

	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	var result := modifier.calculate(ctx)

	# Unknown awards should be ignored, no error
	assert_object(result).is_not_null()


# =============================================================================
# DETERMINISM TESTS
# =============================================================================

func test_hype_calculation_is_deterministic() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 75.0
	player["awards"] = ["all_american_first"]
	var team := {"team_id": "T001", "hype_susceptibility": 0.6}

	var ctx1 := EvaluationContext.for_draft(player, team, {}, 2, 2025, {}, {}, {}, {})
	var result1 := modifier.calculate(ctx1)

	var ctx2 := EvaluationContext.for_draft(player, team, {}, 2, 2025, {}, {}, {}, {})
	var result2 := modifier.calculate(ctx2)

	# Should produce identical results
	assert_float(result1.additive_bonus).is_equal(result2.additive_bonus)
	assert_that(result1.details).is_equal(result2.details)


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

func test_heisman_winner_high_hype_produces_large_bonus() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 95.0  # Very high hype
	player["awards"] = ["heisman_winner", "all_american_first"]
	var team := {"team_id": "T001", "hype_susceptibility": 0.7}

	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	var result := modifier.calculate(ctx)

	# High hype + multiple awards = large bonus
	# But capped at 9.0 OVR
	assert_float(result.additive_bonus).is_greater(5.0)
	assert_float(result.additive_bonus).is_less_equal(9.0)


func test_small_school_player_low_hype_receives_penalty() -> void:
	var modifier := HypeModifier.new()
	var player := TestHelpersGdUnit4.create_test_player()
	player["hype"] = 30.0  # Very low hype
	player["awards"] = []  # No awards
	var team := {"team_id": "T001", "hype_susceptibility": 0.5}

	var ctx := EvaluationContext.for_draft(player, team, {}, 3, 2025, {}, {}, {}, {})
	var result := modifier.calculate(ctx)

	# Low hype + no awards = penalty
	assert_float(result.additive_bonus).is_less(0.0)
	assert_float(result.additive_bonus).is_greater_equal(-3.0)  # Respect min bound
