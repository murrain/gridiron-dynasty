## GdUnit4 test suite for ScoutingKnowledgeModifier
##
## Validates:
## 1. Knowledge level determination (comprehensive, solid, moderate, limited, unknown)
## 2. Round-based risk multipliers
## 3. Team philosophy tolerance scaling
## 4. Hype-based implicit scouting hours
## 5. Determinism (no RNG usage)
## 6. Edge cases (unknown player in R1, comprehensive knowledge, etc.)
extends GdUnitTestSuite

const ScoutingKnowledgeModifier = preload("res://scripts/core/evaluation/modifiers/ScoutingKnowledgeModifier.gd")
const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")


# =============================================================================
# SETUP & TEARDOWN
# =============================================================================

func before_test() -> void:
	ScoutingKnowledgeModifier.clear_cache()


func after_test() -> void:
	ScoutingKnowledgeModifier.clear_cache()


# =============================================================================
# FIXTURE HELPERS
# =============================================================================

## Create test context with configurable scouting parameters
func _create_test_context(
	player_hype: float = 50.0,
	team_philosophy: String = "traditional",
	round_num: int = 1,
	explicit_scouting_hours: float = 0.0
) -> EvaluationContext:
	var player := {
		"player_id": "test_player_001",
		"position": "WR",
		"hype": player_hype
	}

	# Add explicit scouting data if provided
	var scouting_investments := {}
	if explicit_scouting_hours > 0.0:
		scouting_investments["test_player_001"] = {
			"hours": explicit_scouting_hours
		}

	var team := {
		"id": "test_team",
		"offensive_scheme": "pro_style",
		"defensive_scheme": "cover_2",
		"scouting_philosophy": team_philosophy,
		"scouting_investments": scouting_investments
	}

	var roster := {
		"players": [],
		"by_position": {}
	}

	var positions_cfg := {
		"WR": {"starters": 3, "core_stats": ["speed"]}
	}

	var ctx := EvaluationContext.for_draft(
		player, team, roster, round_num, 2025,
		positions_cfg, {}, {}, {}
	)
	ctx.base_rating = 72.0
	return ctx


# =============================================================================
# TEST CASES - KNOWLEDGE LEVELS
# =============================================================================

func test_comprehensive_knowledge_no_penalty() -> void:
	# 40+ hours of scouting = comprehensive knowledge = no penalty
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx := _create_test_context(50.0, "traditional", 1, 45.0)

	var result := modifier.calculate(ctx)

	assert_str(result.details.get("knowledge_level", "")).is_equal("comprehensive")
	assert_float(result.additive_bonus).is_equal_approx(0.0, 0.01)
	print("[TEST] Comprehensive knowledge (45h): %.1f OVR" % result.additive_bonus)


func test_solid_knowledge_no_penalty() -> void:
	# 20-40 hours = solid knowledge = no penalty
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx := _create_test_context(50.0, "traditional", 1, 25.0)

	var result := modifier.calculate(ctx)

	assert_str(result.details.get("knowledge_level", "")).is_equal("solid")
	assert_float(result.additive_bonus).is_equal_approx(0.0, 0.01)
	print("[TEST] Solid knowledge (25h): %.1f OVR" % result.additive_bonus)


func test_moderate_knowledge_small_penalty() -> void:
	# 8-20 hours = moderate knowledge = -1.0 base penalty
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx := _create_test_context(50.0, "traditional", 4, 12.0)  # R4 to avoid round amp

	var result := modifier.calculate(ctx)

	assert_str(result.details.get("knowledge_level", "")).is_equal("moderate")
	assert_float(result.additive_bonus).is_less(0.0)
	print("[TEST] Moderate knowledge (12h): %.1f OVR" % result.additive_bonus)


func test_limited_knowledge_medium_penalty() -> void:
	# 2-8 hours = limited knowledge = -2.0 base penalty
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx := _create_test_context(50.0, "traditional", 4, 4.0)

	var result := modifier.calculate(ctx)

	assert_str(result.details.get("knowledge_level", "")).is_equal("limited")
	assert_float(result.additive_bonus).is_less(-1.0)
	print("[TEST] Limited knowledge (4h): %.1f OVR" % result.additive_bonus)


func test_unknown_knowledge_large_penalty() -> void:
	# 0-2 hours = unknown = -4.0 base penalty
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx := _create_test_context(0.0, "traditional", 4, 0.0)  # No hype = no implicit hours

	var result := modifier.calculate(ctx)

	assert_str(result.details.get("knowledge_level", "")).is_equal("unknown")
	assert_float(result.additive_bonus).is_less(-2.0)
	print("[TEST] Unknown knowledge (0h): %.1f OVR" % result.additive_bonus)


# =============================================================================
# TEST CASES - HYPE-BASED IMPLICIT SCOUTING
# =============================================================================

func test_high_hype_provides_implicit_hours() -> void:
	# High hype (100) = ~15 implicit hours = limited knowledge
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx := _create_test_context(100.0, "traditional", 4, 0.0)

	var result := modifier.calculate(ctx)

	# 100 hype = 15 implicit hours = between solid (20h) and moderate (8h)
	var hours := float(result.details.get("scouting_hours", 0.0))
	assert_float(hours).is_greater(10.0)
	print("[TEST] High hype implicit hours: %.1f" % hours)


func test_medium_hype_provides_some_hours() -> void:
	# Medium hype (50) = ~7.5 implicit hours = limited knowledge
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx := _create_test_context(50.0, "traditional", 4, 0.0)

	var result := modifier.calculate(ctx)

	var hours := float(result.details.get("scouting_hours", 0.0))
	assert_float(hours).is_greater(5.0)
	assert_float(hours).is_less(10.0)
	print("[TEST] Medium hype implicit hours: %.1f" % hours)


func test_low_hype_minimal_hours() -> void:
	# Low hype (20) = ~3 implicit hours = limited knowledge
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx := _create_test_context(20.0, "traditional", 4, 0.0)

	var result := modifier.calculate(ctx)

	var hours := float(result.details.get("scouting_hours", 0.0))
	assert_float(hours).is_less(5.0)
	print("[TEST] Low hype implicit hours: %.1f" % hours)


# =============================================================================
# TEST CASES - ROUND AMPLIFICATION
# =============================================================================

func test_round_1_amplifies_penalty() -> void:
	# Round 1: 2.0x multiplier on penalties
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx_r1 := _create_test_context(30.0, "traditional", 1, 0.0)  # ~4.5h = limited
	var ctx_r5 := _create_test_context(30.0, "traditional", 5, 0.0)

	var result_r1 := modifier.calculate(ctx_r1)
	var result_r5 := modifier.calculate(ctx_r5)

	# R1 penalty should be larger than R5
	assert_float(absf(result_r1.additive_bonus)).is_greater(absf(result_r5.additive_bonus))
	print("[TEST] Round amplification - R1: %.1f, R5: %.1f" % [
		result_r1.additive_bonus, result_r5.additive_bonus
	])


func test_round_2_3_moderate_amplification() -> void:
	# Round 2-3: 1.5x multiplier
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx_r2 := _create_test_context(30.0, "traditional", 2, 0.0)
	var ctx_r3 := _create_test_context(30.0, "traditional", 3, 0.0)

	var result_r2 := modifier.calculate(ctx_r2)
	var result_r3 := modifier.calculate(ctx_r3)

	# R2 and R3 should have similar amplification
	assert_float(result_r2.additive_bonus).is_equal_approx(result_r3.additive_bonus, 1.0)
	print("[TEST] R2-R3 amplification: R2: %.1f, R3: %.1f" % [
		result_r2.additive_bonus, result_r3.additive_bonus
	])


func test_round_4_plus_reduced_amplification() -> void:
	# Round 4+: 0.8x multiplier (teams tolerate risk)
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx_r4 := _create_test_context(30.0, "traditional", 4, 0.0)
	var ctx_r7 := _create_test_context(30.0, "traditional", 7, 0.0)

	var result_r4 := modifier.calculate(ctx_r4)
	var result_r7 := modifier.calculate(ctx_r7)

	# Both should have reduced (0.8x) amplification
	var multiplier_r4 := float(result_r4.details.get("round_multiplier", 0.0))
	var multiplier_r7 := float(result_r7.details.get("round_multiplier", 0.0))
	assert_float(multiplier_r4).is_equal_approx(0.8, 0.1)
	assert_float(multiplier_r7).is_equal_approx(0.8, 0.1)
	print("[TEST] Late round multiplier: R4: %.2fx, R7: %.2fx" % [multiplier_r4, multiplier_r7])


# =============================================================================
# TEST CASES - TEAM PHILOSOPHY TOLERANCE
# =============================================================================

func test_analytics_heavy_tolerates_unknowns() -> void:
	# Analytics teams have high tolerance (0.7) = lower penalties
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx_analytics := _create_test_context(30.0, "analytics_heavy", 4, 0.0)
	var ctx_traditional := _create_test_context(30.0, "traditional", 4, 0.0)

	var result_analytics := modifier.calculate(ctx_analytics)
	var result_traditional := modifier.calculate(ctx_traditional)

	# Analytics team should have smaller penalty
	assert_float(absf(result_analytics.additive_bonus)).is_less(absf(result_traditional.additive_bonus))
	print("[TEST] Philosophy tolerance - Analytics: %.1f, Traditional: %.1f" % [
		result_analytics.additive_bonus, result_traditional.additive_bonus
	])


func test_traditional_strict_on_unknowns() -> void:
	# Traditional teams have low tolerance (0.5) = larger penalties
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx := _create_test_context(30.0, "traditional", 1, 0.0)

	var result := modifier.calculate(ctx)
	var tolerance := float(result.details.get("tolerance", 0.0))

	assert_float(tolerance).is_equal_approx(0.5, 0.1)
	print("[TEST] Traditional tolerance: %.2f" % tolerance)


func test_aggressive_tolerates_risk() -> void:
	# Aggressive teams have very high tolerance (1.2) = reduced penalties
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx_aggressive := _create_test_context(30.0, "aggressive", 4, 0.0)
	var ctx_traditional := _create_test_context(30.0, "traditional", 4, 0.0)

	var result_aggressive := modifier.calculate(ctx_aggressive)
	var result_traditional := modifier.calculate(ctx_traditional)

	# Aggressive team should have even smaller penalty than analytics
	assert_float(absf(result_aggressive.additive_bonus)).is_less(absf(result_traditional.additive_bonus))
	print("[TEST] Aggressive tolerance: %.1f OVR penalty" % result_aggressive.additive_bonus)


# =============================================================================
# TEST CASES - EXTREME SCENARIOS
# =============================================================================

func test_unknown_player_round_1_traditional() -> void:
	# Worst case: Unknown player in R1 with traditional team
	# Expected: -4.0 * 2.0 * 2.0 = -16.0 OVR
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx := _create_test_context(0.0, "traditional", 1, 0.0)

	var result := modifier.calculate(ctx)

	assert_float(result.additive_bonus).is_less(-10.0)
	assert_float(result.additive_bonus).is_greater_equal(-16.0)
	print("[TEST] Worst case (unknown R1 traditional): %.1f OVR" % result.additive_bonus)


func test_unknown_player_round_1_analytics() -> void:
	# Bad but not worst: Unknown player in R1 with analytics team
	# Expected: -4.0 * 2.0 * ~1.43 = ~-11.4 OVR
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx := _create_test_context(0.0, "analytics_heavy", 1, 0.0)

	var result := modifier.calculate(ctx)

	assert_float(result.additive_bonus).is_less(-8.0)
	assert_float(result.additive_bonus).is_greater(-14.0)
	print("[TEST] Unknown R1 analytics: %.1f OVR" % result.additive_bonus)


func test_well_scouted_player_any_round() -> void:
	# Best case: 40+ hours = no penalty regardless of round/philosophy
	var modifier := ScoutingKnowledgeModifier.new()

	var ctx_r1_trad := _create_test_context(50.0, "traditional", 1, 50.0)
	var ctx_r1_anal := _create_test_context(50.0, "analytics_heavy", 1, 50.0)
	var ctx_r7_trad := _create_test_context(50.0, "traditional", 7, 50.0)

	var result_r1_trad := modifier.calculate(ctx_r1_trad)
	var result_r1_anal := modifier.calculate(ctx_r1_anal)
	var result_r7_trad := modifier.calculate(ctx_r7_trad)

	assert_float(result_r1_trad.additive_bonus).is_equal_approx(0.0, 0.01)
	assert_float(result_r1_anal.additive_bonus).is_equal_approx(0.0, 0.01)
	assert_float(result_r7_trad.additive_bonus).is_equal_approx(0.0, 0.01)
	print("[TEST] Well-scouted (50h) all scenarios: 0.0 OVR penalty")


# =============================================================================
# TEST CASES - DETERMINISM
# =============================================================================

func test_determinism_same_inputs() -> void:
	# Same inputs should always produce same output
	var modifier := ScoutingKnowledgeModifier.new()
	var results: Array = []

	for i in range(10):
		var ctx := _create_test_context(45.0, "traditional", 2, 5.0)
		var result := modifier.calculate(ctx)
		results.append(result.additive_bonus)

	var first := float(results[0])
	for bonus in results:
		assert_float(float(bonus)).is_equal_approx(first, 0.001)

	print("[TEST] Determinism verified: 10 identical calculations = %.2f" % first)


# =============================================================================
# TEST CASES - EDGE CASES
# =============================================================================

func test_not_applicable_non_draft_phase() -> void:
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx := _create_test_context(50.0, "traditional", 1, 0.0)
	ctx.phase = "free_agency"

	assert_bool(modifier.is_applicable(ctx)).is_false()
	print("[TEST] Not applicable for non-draft phase")


func test_not_applicable_invalid_round() -> void:
	var modifier := ScoutingKnowledgeModifier.new()
	var ctx := _create_test_context(50.0, "traditional", 0, 0.0)

	assert_bool(modifier.is_applicable(ctx)).is_false()
	print("[TEST] Not applicable for round 0")


func test_bounds_check() -> void:
	var modifier := ScoutingKnowledgeModifier.new()
	var bounds := modifier.get_bounds()

	assert_float(float(bounds["min"])).is_equal_approx(-16.0, 0.01)
	assert_float(float(bounds["max"])).is_equal_approx(0.0, 0.01)
	print("[TEST] Bounds: [%.1f, %.1f]" % [bounds["min"], bounds["max"]])


func test_modifier_metadata() -> void:
	var modifier := ScoutingKnowledgeModifier.new()

	assert_str(modifier.get_id()).is_equal("scouting_knowledge")
	assert_str(modifier.get_display_name()).is_equal("Scouting Knowledge")
	assert_int(modifier.get_priority()).is_equal(35)
	assert_bool("additive" in modifier.get_tags()).is_true()
	assert_bool("scouting" in modifier.get_tags()).is_true()
	print("[TEST] Modifier metadata verified")


func test_explicit_hours_override_implicit() -> void:
	# Explicit scouting hours should take precedence over hype-based
	var modifier := ScoutingKnowledgeModifier.new()

	# Low hype (would give ~3h) but explicit 50h
	var ctx := _create_test_context(20.0, "traditional", 1, 50.0)

	var result := modifier.calculate(ctx)

	# Should be comprehensive (50h) not limited (3h from hype)
	assert_str(result.details.get("knowledge_level", "")).is_equal("comprehensive")
	assert_float(result.additive_bonus).is_equal_approx(0.0, 0.01)
	print("[TEST] Explicit hours override implicit: knowledge = comprehensive")
