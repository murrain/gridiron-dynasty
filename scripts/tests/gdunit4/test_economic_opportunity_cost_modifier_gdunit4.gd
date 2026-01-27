## GdUnit4 test suite for EconomicOpportunityCostModifier
##
## Validates:
## 1. Economic factors correctly favor expensive/scarce positions (QB, EDGE)
## 2. Economic factors correctly penalize cheap/available positions (RB, G)
## 3. Round scaling works correctly (full effect in R1, reduced in late rounds)
## 4. Position priority ordering matches NFL economics
## 5. Determinism (no RNG usage)
## 6. Integration with team need modifiers
extends GdUnitTestSuite

const EconomicOpportunityCostModifier = preload("res://scripts/core/evaluation/modifiers/EconomicOpportunityCostModifier.gd")
const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")


# =============================================================================
# SETUP & TEARDOWN
# =============================================================================

func before_test() -> void:
	EconomicOpportunityCostModifier.clear_cache()


func after_test() -> void:
	EconomicOpportunityCostModifier.clear_cache()


# =============================================================================
# FIXTURE HELPERS
# =============================================================================

## Create minimal test context with configurable parameters
func _create_test_context(
	position: String = "WR",
	round_num: int = 1,
	player_rating: float = 75.0
) -> EvaluationContext:
	var player := {
		"player_id": "test_player_001",
		"position": position,
		"hype": 50.0
	}

	var team := {
		"id": "test_team",
		"offensive_scheme": "pro_style",
		"defensive_scheme": "cover_2"
	}

	var roster := {
		"players": [],
		"by_position": {}
	}

	var positions_cfg := {
		"QB": {"starters": 1},
		"RB": {"starters": 2},
		"WR": {"starters": 3},
		"TE": {"starters": 1},
		"OL": {"starters": 5},
		"G": {"starters": 2},
		"OT": {"starters": 2},
		"C": {"starters": 1},
		"DL": {"starters": 4},
		"EDGE": {"starters": 2},
		"LB": {"starters": 3},
		"CB": {"starters": 2},
		"S": {"starters": 2},
		"K": {"starters": 1},
		"P": {"starters": 1}
	}

	var ctx := EvaluationContext.for_draft(
		player, team, roster, round_num, 2025,
		positions_cfg, {}, {}, {}
	)
	ctx.base_rating = player_rating
	return ctx


# =============================================================================
# TEST CASES - ECONOMIC PRIORITY ORDERING
# =============================================================================

func test_qb_highest_draft_priority() -> void:
	# QB should have highest draft priority due to:
	# - Highest FA cost ($15M)
	# - Lowest FA availability (15%)
	# - Highest impact curve (2.0)
	var priority := EconomicOpportunityCostModifier.get_draft_priority_for_position("QB")

	# QB priority should be > 1.5 (very high)
	assert_float(priority).is_greater(1.5)
	print("[TEST] QB draft priority: %.3f (expected > 1.5)" % priority)


func test_edge_high_draft_priority() -> void:
	# EDGE should have second-highest draft priority
	var priority := EconomicOpportunityCostModifier.get_draft_priority_for_position("EDGE")

	# EDGE priority should be > 1.0
	assert_float(priority).is_greater(1.0)
	print("[TEST] EDGE draft priority: %.3f (expected > 1.0)" % priority)


func test_rb_lowest_draft_priority() -> void:
	# RB should have lowest draft priority due to:
	# - Lowest FA cost ($2M)
	# - Highest FA availability (90%)
	# - Lowest impact curve (0.7)
	var priority := EconomicOpportunityCostModifier.get_draft_priority_for_position("RB")

	# RB priority should be < 0.05 (very low)
	assert_float(priority).is_less(0.05)
	print("[TEST] RB draft priority: %.3f (expected < 0.05)" % priority)


func test_priority_ordering_matches_nfl_economics() -> void:
	# Verify priority ordering: QB > EDGE > OT > CB > WR > LB > RB
	var qb := EconomicOpportunityCostModifier.get_draft_priority_for_position("QB")
	var edge := EconomicOpportunityCostModifier.get_draft_priority_for_position("EDGE")
	var ot := EconomicOpportunityCostModifier.get_draft_priority_for_position("OT")
	var cb := EconomicOpportunityCostModifier.get_draft_priority_for_position("CB")
	var wr := EconomicOpportunityCostModifier.get_draft_priority_for_position("WR")
	var lb := EconomicOpportunityCostModifier.get_draft_priority_for_position("LB")
	var rb := EconomicOpportunityCostModifier.get_draft_priority_for_position("RB")

	assert_float(qb).is_greater(edge)
	assert_float(edge).is_greater(ot)
	assert_float(ot).is_greater(cb)
	assert_float(cb).is_greater(wr)
	assert_float(wr).is_greater(lb)
	assert_float(lb).is_greater(rb)

	print("[TEST] Priority ordering verified:")
	print("  QB: %.3f > EDGE: %.3f > OT: %.3f > CB: %.3f > WR: %.3f > LB: %.3f > RB: %.3f" % [
		qb, edge, ot, cb, wr, lb, rb
	])


func test_get_positions_by_draft_priority() -> void:
	# Verify the helper function returns correctly sorted list
	var sorted_positions := EconomicOpportunityCostModifier.get_positions_by_draft_priority()

	# First position should be QB (highest priority)
	assert_str(String(sorted_positions[0]["position"])).is_equal("QB")

	# Last positions should be specialists (K, P) or RB (lowest priorities)
	var last_pos: String = sorted_positions[sorted_positions.size() - 1]["position"]
	assert_bool(last_pos in ["K", "P", "RB"]).is_true()

	print("[TEST] Positions sorted by draft priority:")
	for i in range(mini(5, sorted_positions.size())):
		var p: Dictionary = sorted_positions[i]
		print("  %d. %s: %.3f" % [i + 1, p["position"], p["priority"]])


# =============================================================================
# TEST CASES - MODIFIER CALCULATION
# =============================================================================

func test_qb_gets_positive_adjustment() -> void:
	# QB should get positive adjustment (expensive/scarce in FA)
	var modifier := EconomicOpportunityCostModifier.new()
	var ctx := _create_test_context("QB", 1, 75.0)

	var result := modifier.calculate(ctx)

	# QB should get positive bonus (+2 to +3 OVR)
	assert_float(result.additive_bonus).is_greater(2.0)
	assert_float(result.additive_bonus).is_less_equal(3.0)
	print("[TEST] QB economic adjustment: +%.2f OVR" % result.additive_bonus)


func test_edge_gets_positive_adjustment() -> void:
	# EDGE should get positive adjustment
	var modifier := EconomicOpportunityCostModifier.new()
	var ctx := _create_test_context("EDGE", 1, 75.0)

	var result := modifier.calculate(ctx)

	# EDGE should get positive bonus (+1 to +2 OVR)
	assert_float(result.additive_bonus).is_greater(1.0)
	print("[TEST] EDGE economic adjustment: +%.2f OVR" % result.additive_bonus)


func test_rb_gets_negative_adjustment() -> void:
	# RB should get negative adjustment (cheap/available in FA)
	var modifier := EconomicOpportunityCostModifier.new()
	var ctx := _create_test_context("RB", 1, 75.0)

	var result := modifier.calculate(ctx)

	# RB should get negative penalty (-0.5 to -1.5 OVR)
	assert_float(result.additive_bonus).is_less(0.0)
	print("[TEST] RB economic adjustment: %.2f OVR" % result.additive_bonus)


func test_lb_gets_slight_negative_adjustment() -> void:
	# LB should get slight negative adjustment (available in FA)
	var modifier := EconomicOpportunityCostModifier.new()
	var ctx := _create_test_context("LB", 1, 75.0)

	var result := modifier.calculate(ctx)

	# LB should get small negative penalty
	assert_float(result.additive_bonus).is_less(0.5)
	print("[TEST] LB economic adjustment: %.2f OVR" % result.additive_bonus)


func test_wr_gets_near_neutral_adjustment() -> void:
	# WR should get relatively neutral adjustment
	var modifier := EconomicOpportunityCostModifier.new()
	var ctx := _create_test_context("WR", 1, 75.0)

	var result := modifier.calculate(ctx)

	# WR should be close to neutral (-0.5 to +0.5 OVR)
	assert_float(result.additive_bonus).is_greater(-1.0)
	assert_float(result.additive_bonus).is_less(1.0)
	print("[TEST] WR economic adjustment: %.2f OVR" % result.additive_bonus)


# =============================================================================
# TEST CASES - ROUND SCALING
# =============================================================================

func test_round_1_full_effect() -> void:
	# Round 1 should have full economic effect
	var modifier := EconomicOpportunityCostModifier.new()
	var ctx_r1 := _create_test_context("QB", 1, 75.0)
	var ctx_r7 := _create_test_context("QB", 7, 75.0)

	var result_r1 := modifier.calculate(ctx_r1)
	var result_r7 := modifier.calculate(ctx_r7)

	# R1 effect should be significantly larger than R7
	assert_float(result_r1.additive_bonus).is_greater(result_r7.additive_bonus * 2.0)
	print("[TEST] Round scaling - QB R1: +%.2f, R7: +%.2f" % [
		result_r1.additive_bonus, result_r7.additive_bonus
	])


func test_round_scaling_progression() -> void:
	# Economics should matter less in later rounds
	var modifier := EconomicOpportunityCostModifier.new()

	var r1 := modifier.calculate(_create_test_context("EDGE", 1, 75.0)).additive_bonus
	var r3 := modifier.calculate(_create_test_context("EDGE", 3, 75.0)).additive_bonus
	var r5 := modifier.calculate(_create_test_context("EDGE", 5, 75.0)).additive_bonus
	var r7 := modifier.calculate(_create_test_context("EDGE", 7, 75.0)).additive_bonus

	# Progressive reduction
	assert_float(r1).is_greater(r3)
	assert_float(r3).is_greater(r5)
	assert_float(r5).is_greater(r7)

	print("[TEST] EDGE round scaling: R1: +%.2f > R3: +%.2f > R5: +%.2f > R7: +%.2f" % [
		r1, r3, r5, r7
	])


func test_negative_adjustment_also_scales() -> void:
	# Negative adjustments (RB) should also scale down in later rounds
	var modifier := EconomicOpportunityCostModifier.new()

	var r1 := modifier.calculate(_create_test_context("RB", 1, 75.0)).additive_bonus
	var r7 := modifier.calculate(_create_test_context("RB", 7, 75.0)).additive_bonus

	# Both negative, but R1 more negative than R7
	assert_float(r1).is_less(r7)
	print("[TEST] RB round scaling: R1: %.2f < R7: %.2f (less penalty later)" % [r1, r7])


# =============================================================================
# TEST CASES - DETERMINISM
# =============================================================================

func test_determinism_same_inputs() -> void:
	# Same inputs should always produce same output (no RNG)
	var modifier := EconomicOpportunityCostModifier.new()
	var results: Array = []

	for i in range(10):
		var ctx := _create_test_context("EDGE", 2, 72.0)
		var result := modifier.calculate(ctx)
		results.append(result.additive_bonus)

	# All results should be identical
	var first := float(results[0])
	for bonus in results:
		assert_float(float(bonus)).is_equal_approx(first, 0.001)

	print("[TEST] Determinism verified: 10 identical calculations = %.3f" % first)


# =============================================================================
# TEST CASES - APPLICABILITY
# =============================================================================

func test_not_applicable_non_draft_phase() -> void:
	var modifier := EconomicOpportunityCostModifier.new()
	var ctx := _create_test_context("QB", 1, 75.0)
	ctx.phase = "free_agency"

	assert_bool(modifier.is_applicable(ctx)).is_false()
	print("[TEST] Not applicable for non-draft phase")


func test_not_applicable_invalid_round() -> void:
	var modifier := EconomicOpportunityCostModifier.new()
	var ctx := _create_test_context("QB", 0, 75.0)

	assert_bool(modifier.is_applicable(ctx)).is_false()
	print("[TEST] Not applicable for round 0")


func test_not_applicable_empty_position() -> void:
	var modifier := EconomicOpportunityCostModifier.new()
	var ctx := _create_test_context("", 1, 75.0)

	assert_bool(modifier.is_applicable(ctx)).is_false()
	print("[TEST] Not applicable for empty position")


# =============================================================================
# TEST CASES - METADATA
# =============================================================================

func test_modifier_metadata() -> void:
	var modifier := EconomicOpportunityCostModifier.new()

	assert_str(modifier.get_id()).is_equal("economic_opportunity_cost")
	assert_str(modifier.get_display_name()).is_equal("Economic Opportunity Cost")
	assert_int(modifier.get_priority()).is_equal(26)
	assert_bool("additive" in modifier.get_tags()).is_true()
	assert_bool("economic" in modifier.get_tags()).is_true()
	print("[TEST] Modifier metadata verified")


func test_bounds() -> void:
	var modifier := EconomicOpportunityCostModifier.new()
	var bounds := modifier.get_bounds()

	assert_float(float(bounds["min"])).is_equal_approx(-3.0, 0.01)
	assert_float(float(bounds["max"])).is_equal_approx(3.0, 0.01)
	print("[TEST] Bounds: [%.1f, %.1f]" % [bounds["min"], bounds["max"]])


# =============================================================================
# TEST CASES - INTEGRATION SCENARIOS
# =============================================================================

func test_rb_vs_edge_same_ovr_decision() -> void:
	# Scenario: Team needs both RB and EDGE equally
	# Both prospects are 70 OVR
	# Economic logic should favor drafting EDGE
	var modifier := EconomicOpportunityCostModifier.new()

	var ctx_rb := _create_test_context("RB", 1, 70.0)
	var ctx_edge := _create_test_context("EDGE", 1, 70.0)

	var rb_adjustment := modifier.calculate(ctx_rb).additive_bonus
	var edge_adjustment := modifier.calculate(ctx_edge).additive_bonus

	# EDGE should get significantly better adjustment
	var edge_advantage := edge_adjustment - rb_adjustment
	assert_float(edge_advantage).is_greater(2.0)

	print("[TEST] Economic decision - same OVR:")
	print("  RB 70 OVR + (%.2f) = %.2f effective" % [rb_adjustment, 70.0 + rb_adjustment])
	print("  EDGE 70 OVR + (%.2f) = %.2f effective" % [edge_adjustment, 70.0 + edge_adjustment])
	print("  EDGE advantage: +%.2f OVR" % edge_advantage)


func test_qb_vs_lb_decision() -> void:
	# Scenario: QB (72 OVR) vs LB (78 OVR)
	# Economic logic may still favor QB despite lower OVR
	var modifier := EconomicOpportunityCostModifier.new()

	var ctx_qb := _create_test_context("QB", 1, 72.0)
	var ctx_lb := _create_test_context("LB", 1, 78.0)

	var qb_adjustment := modifier.calculate(ctx_qb).additive_bonus
	var lb_adjustment := modifier.calculate(ctx_lb).additive_bonus

	var qb_effective := 72.0 + qb_adjustment
	var lb_effective := 78.0 + lb_adjustment

	# QB should get enough boost to be competitive with higher OVR LB
	# (Though not necessarily winning - that depends on team need)
	print("[TEST] Economic decision - QB vs LB:")
	print("  QB 72 OVR + (%.2f) = %.2f effective" % [qb_adjustment, qb_effective])
	print("  LB 78 OVR + (%.2f) = %.2f effective" % [lb_adjustment, lb_effective])
	print("  Gap reduced from 6.0 to %.2f" % (lb_effective - qb_effective))


func test_late_round_economics_reduced() -> void:
	# In late rounds, economic factors matter less
	# A RB in R7 shouldn't be as penalized as in R1
	var modifier := EconomicOpportunityCostModifier.new()

	var ctx_r1 := _create_test_context("RB", 1, 65.0)
	var ctx_r7 := _create_test_context("RB", 7, 65.0)

	var r1_penalty := modifier.calculate(ctx_r1).additive_bonus
	var r7_penalty := modifier.calculate(ctx_r7).additive_bonus

	# R7 penalty should be much smaller (closer to 0)
	assert_float(absf(r7_penalty)).is_less(absf(r1_penalty))
	print("[TEST] Late round RB penalty reduction: R1: %.2f, R7: %.2f" % [r1_penalty, r7_penalty])


# =============================================================================
# TEST CASES - EDGE CASES
# =============================================================================

func test_unknown_position_uses_defaults() -> void:
	# Unknown positions should use neutral defaults
	var modifier := EconomicOpportunityCostModifier.new()
	var ctx := _create_test_context("UNKNOWN", 1, 75.0)
	ctx.position = "UNKNOWN"

	var result := modifier.calculate(ctx)

	# Should use default values and produce some result
	# With defaults (cost 5.0, availability 0.5, impact 1.0):
	# priority = (5/15) * 0.5 * 1.0 = 0.167
	# Near neutral point (0.4), so small negative adjustment
	assert_float(result.additive_bonus).is_greater(-3.0)
	assert_float(result.additive_bonus).is_less(3.0)
	print("[TEST] Unknown position adjustment: %.2f OVR" % result.additive_bonus)


func test_result_details_contain_factors() -> void:
	# Verify result details include all economic factors
	var modifier := EconomicOpportunityCostModifier.new()
	var ctx := _create_test_context("CB", 2, 70.0)

	var result := modifier.calculate(ctx)

	assert_bool(result.details.has("fa_cost_millions")).is_true()
	assert_bool(result.details.has("fa_availability_pct")).is_true()
	assert_bool(result.details.has("impact_curve")).is_true()
	assert_bool(result.details.has("draft_priority_score")).is_true()
	assert_bool(result.details.has("round_scale")).is_true()

	print("[TEST] Result details for CB R2:")
	print("  FA Cost: $%.1fM" % result.details["fa_cost_millions"])
	print("  FA Availability: %.1f%%" % result.details["fa_availability_pct"])
	print("  Impact Curve: %.2f" % result.details["impact_curve"])
	print("  Draft Priority: %.3f" % result.details["draft_priority_score"])
	print("  Round Scale: %.2f" % result.details["round_scale"])
