## GdUnit4 test suite for HypeModifier
##
## Validates:
## 1. Base hype adjustment calculation
## 2. Award signal bonuses (Heisman, All-American, etc.)
## 3. Round scaling behavior
## 4. Team susceptibility scaling
## 5. Determinism (no RNG usage)
## 6. Edge cases (max hype, min hype, award stacking)
extends GdUnitTestSuite

const HypeModifier = preload("res://scripts/core/evaluation/modifiers/HypeModifier.gd")
const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")


# =============================================================================
# SETUP & TEARDOWN
# =============================================================================

func before_test() -> void:
	HypeModifier.clear_cache()


func after_test() -> void:
	HypeModifier.clear_cache()


# =============================================================================
# FIXTURE HELPERS
# =============================================================================

## Create test context with configurable hype parameters
func _create_test_context(
	player_hype: float = 50.0,
	team_susceptibility: float = 0.5,
	round_num: int = 1,
	awards: Array = []
) -> EvaluationContext:
	var player := {
		"player_id": "test_player_001",
		"position": "QB",
		"hype": player_hype,
		"awards": awards
	}

	var team := {
		"id": "test_team",
		"offensive_scheme": "pro_style",
		"defensive_scheme": "cover_2",
		"hype_susceptibility": team_susceptibility
	}

	var roster := {
		"players": [],
		"by_position": {}
	}

	var positions_cfg := {
		"QB": {"starters": 1, "core_stats": ["accuracy"]}
	}

	var ctx := EvaluationContext.for_draft(
		player, team, roster, round_num, 2025,
		positions_cfg, {}, {}, {}
	)
	ctx.base_rating = 75.0
	return ctx


# =============================================================================
# TEST CASES - BASE HYPE ADJUSTMENT
# =============================================================================

func test_neutral_hype_no_adjustment() -> void:
	# Hype 50 (neutral) = no hype adjustment
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(50.0, 0.5, 3, [])  # R3 for 1.0x scale

	var result := modifier.calculate(ctx)

	# Hype delta = 0, so hype bonus should be ~0
	var hype_bonus := float(result.details.get("hype_bonus_after_scale", 0.0))
	assert_float(hype_bonus).is_equal_approx(0.0, 0.1)
	print("[TEST] Neutral hype (50): %.2f OVR" % hype_bonus)


func test_high_hype_positive_adjustment() -> void:
	# Hype 80 = +0.6 delta * 5.0 max * susceptibility * round_scale
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(80.0, 0.5, 3, [])

	var result := modifier.calculate(ctx)

	var hype_bonus := float(result.details.get("hype_bonus_after_scale", 0.0))
	assert_float(hype_bonus).is_greater(0.0)
	print("[TEST] High hype (80, 0.5 susc, R3): +%.2f OVR" % hype_bonus)


func test_low_hype_negative_adjustment() -> void:
	# Hype 20 = -0.6 delta * 3.0 max_penalty * susceptibility * round_scale
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(20.0, 0.5, 3, [])

	var result := modifier.calculate(ctx)

	var hype_bonus := float(result.details.get("hype_bonus_after_scale", 0.0))
	assert_float(hype_bonus).is_less(0.0)
	print("[TEST] Low hype (20): %.2f OVR" % hype_bonus)


func test_max_hype_positive_adjustment() -> void:
	# Hype 100 = +1.0 delta * 5.0 max * susceptibility * round_scale
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(100.0, 0.8, 1, [])  # High susceptibility, R1

	var result := modifier.calculate(ctx)

	var hype_bonus := float(result.details.get("hype_bonus_after_scale", 0.0))
	assert_float(hype_bonus).is_greater(3.0)
	print("[TEST] Max hype (100, 0.8 susc, R1): +%.2f OVR" % hype_bonus)


func test_min_hype_negative_adjustment() -> void:
	# Hype 0 = -1.0 delta * 3.0 max_penalty * susceptibility
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(0.0, 0.8, 1, [])

	var result := modifier.calculate(ctx)

	var hype_bonus := float(result.details.get("hype_bonus_after_scale", 0.0))
	assert_float(hype_bonus).is_less(-1.0)
	print("[TEST] Min hype (0, 0.8 susc, R1): %.2f OVR" % hype_bonus)


# =============================================================================
# TEST CASES - TEAM SUSCEPTIBILITY
# =============================================================================

func test_analytics_team_low_susceptibility() -> void:
	# Analytics teams (0.2 susceptibility) largely ignore hype
	var modifier := HypeModifier.new()
	var ctx_analytics := _create_test_context(90.0, 0.2, 3, [])
	var ctx_balanced := _create_test_context(90.0, 0.5, 3, [])

	var result_analytics := modifier.calculate(ctx_analytics)
	var result_balanced := modifier.calculate(ctx_balanced)

	var analytics_bonus := float(result_analytics.details.get("hype_bonus_after_scale", 0.0))
	var balanced_bonus := float(result_balanced.details.get("hype_bonus_after_scale", 0.0))

	# Analytics team should have smaller hype effect
	assert_float(analytics_bonus).is_less(balanced_bonus)
	print("[TEST] Susceptibility - Analytics (0.2): +%.2f, Balanced (0.5): +%.2f" % [
		analytics_bonus, balanced_bonus
	])


func test_narrative_team_high_susceptibility() -> void:
	# Narrative-driven teams (0.8 susceptibility) chase hype
	var modifier := HypeModifier.new()
	var ctx_narrative := _create_test_context(90.0, 0.8, 3, [])
	var ctx_balanced := _create_test_context(90.0, 0.5, 3, [])

	var result_narrative := modifier.calculate(ctx_narrative)
	var result_balanced := modifier.calculate(ctx_balanced)

	var narrative_bonus := float(result_narrative.details.get("hype_bonus_after_scale", 0.0))
	var balanced_bonus := float(result_balanced.details.get("hype_bonus_after_scale", 0.0))

	# Narrative team should have larger hype effect
	assert_float(narrative_bonus).is_greater(balanced_bonus)
	print("[TEST] Susceptibility - Narrative (0.8): +%.2f, Balanced (0.5): +%.2f" % [
		narrative_bonus, balanced_bonus
	])


func test_zero_susceptibility_no_hype_effect() -> void:
	# Team with 0 susceptibility = pure analytics, no hype effect
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(100.0, 0.0, 1, [])

	var result := modifier.calculate(ctx)

	var hype_bonus := float(result.details.get("hype_bonus_after_scale", 0.0))
	assert_float(hype_bonus).is_equal_approx(0.0, 0.01)
	print("[TEST] Zero susceptibility: %.2f OVR from hype" % hype_bonus)


# =============================================================================
# TEST CASES - ROUND SCALING
# =============================================================================

func test_round_1_amplified_hype() -> void:
	# Round 1-2: 1.2x hype effect (media pressure highest)
	var modifier := HypeModifier.new()
	var ctx_r1 := _create_test_context(80.0, 0.5, 1, [])
	var ctx_r3 := _create_test_context(80.0, 0.5, 3, [])

	var result_r1 := modifier.calculate(ctx_r1)
	var result_r3 := modifier.calculate(ctx_r3)

	var r1_bonus := float(result_r1.details.get("hype_bonus_after_scale", 0.0))
	var r3_bonus := float(result_r3.details.get("hype_bonus_after_scale", 0.0))

	# R1 should have larger hype effect than R3
	assert_float(absf(r1_bonus)).is_greater(absf(r3_bonus))
	print("[TEST] Round scaling - R1: %.2f, R3: %.2f" % [r1_bonus, r3_bonus])


func test_round_4_plus_reduced_hype() -> void:
	# Round 4+: 0.5x hype effect
	var modifier := HypeModifier.new()
	var ctx_r3 := _create_test_context(80.0, 0.5, 3, [])
	var ctx_r5 := _create_test_context(80.0, 0.5, 5, [])

	var result_r3 := modifier.calculate(ctx_r3)
	var result_r5 := modifier.calculate(ctx_r5)

	var r3_scale := float(result_r3.details.get("round_scale", 0.0))
	var r5_scale := float(result_r5.details.get("round_scale", 0.0))

	assert_float(r5_scale).is_less(r3_scale)
	print("[TEST] Late round scale - R3: %.2fx, R5: %.2fx" % [r3_scale, r5_scale])


# =============================================================================
# TEST CASES - AWARD SIGNAL BONUSES
# =============================================================================

func test_heisman_winner_bonus() -> void:
	# Heisman winner: +3.0 OVR (independent of susceptibility)
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(50.0, 0.5, 3, ["heisman_winner"])

	var result := modifier.calculate(ctx)

	var award_bonus := float(result.details.get("award_bonus", 0.0))
	assert_float(award_bonus).is_equal_approx(3.0, 0.1)
	print("[TEST] Heisman winner: +%.1f OVR award bonus" % award_bonus)


func test_all_american_first_team_bonus() -> void:
	# All-American 1st: +2.0 OVR
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(50.0, 0.5, 3, ["all_american_first"])

	var result := modifier.calculate(ctx)

	var award_bonus := float(result.details.get("award_bonus", 0.0))
	assert_float(award_bonus).is_equal_approx(2.0, 0.1)
	print("[TEST] All-American 1st: +%.1f OVR" % award_bonus)


func test_all_american_second_team_bonus() -> void:
	# All-American 2nd: +1.0 OVR
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(50.0, 0.5, 3, ["all_american_second"])

	var result := modifier.calculate(ctx)

	var award_bonus := float(result.details.get("award_bonus", 0.0))
	assert_float(award_bonus).is_equal_approx(1.0, 0.1)
	print("[TEST] All-American 2nd: +%.1f OVR" % award_bonus)


func test_conference_poy_bonus() -> void:
	# Conference POY: +1.0 OVR
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(50.0, 0.5, 3, ["conference_poy"])

	var result := modifier.calculate(ctx)

	var award_bonus := float(result.details.get("award_bonus", 0.0))
	assert_float(award_bonus).is_equal_approx(1.0, 0.1)
	print("[TEST] Conference POY: +%.1f OVR" % award_bonus)


func test_combine_standout_bonus() -> void:
	# Combine standout: +0.5 OVR
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(50.0, 0.5, 3, ["combine_standout"])

	var result := modifier.calculate(ctx)

	var award_bonus := float(result.details.get("award_bonus", 0.0))
	assert_float(award_bonus).is_equal_approx(0.5, 0.1)
	print("[TEST] Combine standout: +%.1f OVR" % award_bonus)


func test_award_stacking_capped() -> void:
	# Multiple awards should stack but cap at 4.0 OVR
	var modifier := HypeModifier.new()
	var awards := [
		"heisman_winner",      # +3.0
		"all_american_first",  # +2.0
		"conference_poy",      # +1.0
		"combine_standout"     # +0.5
	]  # Total: 6.5, should cap at 4.0
	var ctx := _create_test_context(50.0, 0.5, 3, awards)

	var result := modifier.calculate(ctx)

	var award_bonus := float(result.details.get("award_bonus", 0.0))
	assert_float(award_bonus).is_less_equal(4.0)
	print("[TEST] Award stacking (6.5 uncapped): +%.1f OVR (capped)" % award_bonus)


func test_award_bonus_independent_of_susceptibility() -> void:
	# Award bonuses should be same regardless of team susceptibility
	var modifier := HypeModifier.new()
	var ctx_low := _create_test_context(50.0, 0.2, 3, ["heisman_winner"])
	var ctx_high := _create_test_context(50.0, 0.8, 3, ["heisman_winner"])

	var result_low := modifier.calculate(ctx_low)
	var result_high := modifier.calculate(ctx_high)

	var award_low := float(result_low.details.get("award_bonus", 0.0))
	var award_high := float(result_high.details.get("award_bonus", 0.0))

	assert_float(award_low).is_equal_approx(award_high, 0.01)
	print("[TEST] Award independent of susceptibility: %.1f = %.1f" % [award_low, award_high])


# =============================================================================
# TEST CASES - COMBINED SCENARIOS
# =============================================================================

func test_heisman_winner_high_hype_narrative_team_r1() -> void:
	# Best case: Heisman (hype 95), narrative team (0.8), R1
	# Hype: (95-50)/50 * 5.0 * 0.8 * 1.2 = +4.32
	# Award: +3.0
	# Total: ~+7.32 (capped at 9.0)
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(95.0, 0.8, 1, ["heisman_winner"])

	var result := modifier.calculate(ctx)

	assert_float(result.additive_bonus).is_greater(5.0)
	assert_float(result.additive_bonus).is_less_equal(9.0)
	print("[TEST] Best case (Heisman + high hype + narrative R1): +%.1f OVR" % result.additive_bonus)


func test_low_profile_player_analytics_team() -> void:
	# Small school stud (hype 30), analytics team (0.2), R3
	# Hype: (30-50)/50 * 3.0 * 0.2 * 0.8 = -0.19
	# Award: 0
	# Total: ~-0.19
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(30.0, 0.2, 3, [])

	var result := modifier.calculate(ctx)

	assert_float(result.additive_bonus).is_less(0.0)
	assert_float(result.additive_bonus).is_greater(-1.0)
	print("[TEST] Low profile + analytics: %.2f OVR" % result.additive_bonus)


func test_5_star_bust_narrative_team() -> void:
	# 5-star bust (hype 80, no awards), narrative team (0.8), R1
	# Still gets hype boost despite no verified awards
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(80.0, 0.8, 1, [])

	var result := modifier.calculate(ctx)

	assert_float(result.additive_bonus).is_greater(2.0)
	print("[TEST] 5-star bust (hype only): +%.2f OVR" % result.additive_bonus)


# =============================================================================
# TEST CASES - DETERMINISM
# =============================================================================

func test_determinism_same_inputs() -> void:
	# Same inputs should always produce same output
	var modifier := HypeModifier.new()
	var results: Array = []

	for i in range(10):
		var ctx := _create_test_context(75.0, 0.6, 2, ["all_american_first"])
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
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(50.0, 0.5, 1, [])
	ctx.phase = "free_agency"

	assert_bool(modifier.is_applicable(ctx)).is_false()
	print("[TEST] Not applicable for non-draft phase")


func test_not_applicable_invalid_round() -> void:
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(50.0, 0.5, 0, [])

	assert_bool(modifier.is_applicable(ctx)).is_false()
	print("[TEST] Not applicable for round 0")


func test_bounds_check() -> void:
	var modifier := HypeModifier.new()
	var bounds := modifier.get_bounds()

	assert_float(float(bounds["min"])).is_equal_approx(-3.0, 0.01)
	assert_float(float(bounds["max"])).is_equal_approx(9.0, 0.01)
	print("[TEST] Bounds: [%.1f, %.1f]" % [bounds["min"], bounds["max"]])


func test_modifier_metadata() -> void:
	var modifier := HypeModifier.new()

	assert_str(modifier.get_id()).is_equal("hype")
	assert_str(modifier.get_display_name()).is_equal("Media Hype")
	assert_int(modifier.get_priority()).is_equal(40)
	assert_bool("additive" in modifier.get_tags()).is_true()
	assert_bool("hype" in modifier.get_tags()).is_true()
	print("[TEST] Modifier metadata verified")


func test_empty_awards_array() -> void:
	# Empty awards array should not cause errors
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(70.0, 0.5, 3, [])

	var result := modifier.calculate(ctx)

	var award_bonus := float(result.details.get("award_bonus", 0.0))
	assert_float(award_bonus).is_equal_approx(0.0, 0.01)
	print("[TEST] Empty awards: +%.1f OVR award bonus" % award_bonus)


func test_unknown_award_ignored() -> void:
	# Unknown awards should be ignored (no bonus)
	var modifier := HypeModifier.new()
	var ctx := _create_test_context(50.0, 0.5, 3, ["fake_award_xyz"])

	var result := modifier.calculate(ctx)

	var award_bonus := float(result.details.get("award_bonus", 0.0))
	assert_float(award_bonus).is_equal_approx(0.0, 0.01)
	print("[TEST] Unknown award ignored: +%.1f OVR" % award_bonus)


func test_generate_team_susceptibility() -> void:
	# Test the static helper for generating team susceptibility
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Generate 100 susceptibilities and verify they're in valid ranges
	var categories := {"analytics_focused": 0, "balanced": 0, "narrative_driven": 0}
	for i in range(100):
		var result := HypeModifier.generate_team_susceptibility(rng)
		var category := String(result.get("category", ""))
		var susceptibility := float(result.get("susceptibility", 0.0))

		# Verify category is valid
		assert_bool(categories.has(category)).is_true()
		categories[category] += 1

		# Verify susceptibility is in valid range (0.15 to 0.85)
		assert_float(susceptibility).is_greater_equal(0.15)
		assert_float(susceptibility).is_less_equal(0.85)

	print("[TEST] Susceptibility distribution over 100 generations:")
	print("  Analytics: %d, Balanced: %d, Narrative: %d" % [
		categories["analytics_focused"],
		categories["balanced"],
		categories["narrative_driven"]
	])
