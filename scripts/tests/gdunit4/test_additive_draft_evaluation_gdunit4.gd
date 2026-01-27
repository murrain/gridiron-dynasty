## GdUnit4 test suite for Additive Draft Evaluation System
##
## Validates the additive modifier system ensures player quality dominates
## over position bonuses, fixing the bug where a mediocre EDGE would score
## higher than an elite WR due to multiplicative position bonuses.
##
## Key scenarios tested:
## - Elite WR (88 OVR) beats mediocre EDGE (73 OVR)
## - Elite players at any position compete for top picks
## - Position bonuses are meaningful but not overwhelming (+/- 5 OVR max)
## - The formula is: final_score = (base_ovr + additive_total) * multiplicative_total
extends GdUnitTestSuite

const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")
const EvaluationModifierStack = preload("res://scripts/core/evaluation/EvaluationModifierStack.gd")
const PositionTierModifier = preload("res://scripts/core/evaluation/modifiers/PositionTierModifier.gd")
const PositionValueModifier = preload("res://scripts/core/evaluation/modifiers/PositionValueModifier.gd")
const EvaluationModifier = preload("res://scripts/core/evaluation/EvaluationModifier.gd")


## Test: ModifierResult.create_additive() works correctly
func test_additive_modifier_result_creation() -> void:
	# Create additive modifier
	var result := EvaluationModifier.ModifierResult.create_additive(3.0, "Test reason", {"test": true})

	assert_bool(result.is_additive()).is_true()
	assert_float(result.additive_bonus).is_equal(3.0)
	assert_float(result.multiplier).is_equal(1.0)
	assert_str(result.reason).is_equal("Test reason")
	assert_str(result.get_effect_string()).is_equal("+3.0 OVR")

	# Create negative additive
	var result_neg := EvaluationModifier.ModifierResult.create_additive(-2.5, "Penalty")
	assert_float(result_neg.additive_bonus).is_equal(-2.5)
	assert_str(result_neg.get_effect_string()).is_equal("-2.5 OVR")

	# Create multiplicative (default) for comparison
	var result_mult := EvaluationModifier.ModifierResult.new(1.2, "Boost")
	assert_bool(result_mult.is_additive()).is_false()
	assert_str(result_mult.get_effect_string()).is_equal("1.20x")


## Test: EvaluationModifierStack applies additive before multiplicative
func test_stack_applies_additive_before_multiplicative() -> void:
	var stack := EvaluationModifierStack.new()

	# Register position tier (additive) and position value (additive)
	stack.register(PositionTierModifier.new())
	stack.register(PositionValueModifier.new())

	# Create context for EDGE player in round 1
	var ctx := _create_test_context("EDGE", 75.0, 1)

	var result := stack.evaluate(ctx)

	# EDGE in round 1 should get:
	# - Position tier: +3 OVR (premium in round 1)
	# - Position value: +2 OVR (EDGE premium)
	# Total additive: +5 OVR
	assert_float(result.additive_total).is_equal_approx(5.0, 0.1)

	# Multiplicative should be 1.0 (no multiplicative modifiers in this test)
	assert_float(result.final_multiplier).is_equal(1.0)

	# Final score: (75 + 5) * 1.0 = 80
	var final_score := result.calculate_final_score(75.0)
	assert_float(final_score).is_equal_approx(80.0, 0.1)


## Test: Elite WR beats mediocre EDGE
##
## THE KEY FIX: This is the scenario that was broken.
## Old system: 73 EDGE x 1.4 x 1.2 = 122.6 vs 88 WR x 1.0 = 88.0 (EDGE wins by 34.6!)
## New system: 73 EDGE + 5 = 78 vs 88 WR + 0.5 = 88.5 (WR wins by 10.5)
func test_elite_wr_beats_mediocre_edge() -> void:
	var stack := EvaluationModifierStack.new()
	stack.register(PositionTierModifier.new())
	stack.register(PositionValueModifier.new())

	# Mediocre EDGE (73 OVR) - 9th best EDGE in the draft class
	var ctx_edge := _create_test_context("EDGE", 73.0, 1)
	var result_edge := stack.evaluate(ctx_edge)
	var score_edge := result_edge.calculate_final_score(73.0)

	# Elite WR (88 OVR) - #1 WR in the draft class
	var ctx_wr := _create_test_context("WR", 88.0, 1)
	var result_wr := stack.evaluate(ctx_wr)
	var score_wr := result_wr.calculate_final_score(88.0)

	# EDGE: 73 + 3 (tier) + 2 (value) = 78
	# WR: 88 + 0 (tier) + 0.5 (value) = 88.5
	# WR should win by ~10.5 points

	assert_float(score_wr).is_greater(score_edge)

	var gap := score_wr - score_edge
	assert_float(gap).is_greater(5.0)

	# Verify the specific scores match expectations
	assert_float(score_edge).is_equal_approx(78.0, 0.5)
	assert_float(score_wr).is_equal_approx(88.5, 0.5)


## Test: Elite EDGE slightly beats equal-rated WR
##
## When ratings are close, position value should provide tiebreaker.
## 85 EDGE + 5 = 90 vs 88 WR + 0.5 = 88.5 (EDGE wins by 1.5)
func test_elite_edge_slightly_beats_equal_wr() -> void:
	var stack := EvaluationModifierStack.new()
	stack.register(PositionTierModifier.new())
	stack.register(PositionValueModifier.new())

	# Elite EDGE (85 OVR)
	var ctx_edge := _create_test_context("EDGE", 85.0, 1)
	var result_edge := stack.evaluate(ctx_edge)
	var score_edge := result_edge.calculate_final_score(85.0)

	# Elite WR (88 OVR) - still a better player
	var ctx_wr := _create_test_context("WR", 88.0, 1)
	var result_wr := stack.evaluate(ctx_wr)
	var score_wr := result_wr.calculate_final_score(88.0)

	# EDGE: 85 + 3 + 2 = 90
	# WR: 88 + 0 + 0.5 = 88.5
	# EDGE slightly edges out WR (pun intended)

	assert_float(score_edge).is_greater(score_wr)

	# But the gap should be small (< 3 points)
	var gap := score_edge - score_wr
	assert_float(gap).is_less(3.0)


## Test: Elite QB beats good EDGE due to QB scarcity
##
## QB gets highest position value (+5 OVR), reflecting real NFL scarcity.
## 82 QB + 8 = 90 vs 80 EDGE + 5 = 85 (QB wins by 5)
func test_elite_qb_beats_good_edge() -> void:
	var stack := EvaluationModifierStack.new()
	stack.register(PositionTierModifier.new())
	stack.register(PositionValueModifier.new())

	# Elite QB (82 OVR)
	var ctx_qb := _create_test_context("QB", 82.0, 1)
	var result_qb := stack.evaluate(ctx_qb)
	var score_qb := result_qb.calculate_final_score(82.0)

	# Good EDGE (80 OVR)
	var ctx_edge := _create_test_context("EDGE", 80.0, 1)
	var result_edge := stack.evaluate(ctx_edge)
	var score_edge := result_edge.calculate_final_score(80.0)

	# QB: 82 + 3 (tier) + 5 (value) = 90
	# EDGE: 80 + 3 (tier) + 2 (value) = 85

	assert_float(score_qb).is_greater(score_edge)
	assert_float(score_qb).is_equal_approx(90.0, 0.5)
	assert_float(score_edge).is_equal_approx(85.0, 0.5)


## Test: Position tier bonuses scale by round - Premium positions
func test_position_tier_round_scaling_premium() -> void:
	var mod := PositionTierModifier.new()

	# Test premium position (EDGE) across rounds
	var round_bonuses := {
		1: 3.0,
		2: 2.0,
		3: 1.0,
		4: 1.0,
		5: 0.0,
		7: 0.0
	}

	for round_num in round_bonuses.keys():
		var ctx := _create_test_context("EDGE", 75.0, round_num)
		var result = mod.calculate(ctx)

		assert_bool(result.is_additive()).is_true()

		var expected: float = float(round_bonuses[round_num])
		assert_float(result.additive_bonus).is_equal_approx(expected, 0.1)


## Test: Position tier bonuses scale by round - Devalued positions
func test_position_tier_round_scaling_devalued() -> void:
	var mod := PositionTierModifier.new()

	# Test devalued position (RB) across rounds
	var devalued_penalties := {
		1: -3.0,
		2: -2.0,
		3: -1.0,
		4: -1.0,
		5: 0.0
	}

	for round_num in devalued_penalties.keys():
		var ctx := _create_test_context("RB", 75.0, round_num)
		var result = mod.calculate(ctx)

		var expected: float = float(devalued_penalties[round_num])
		assert_float(result.additive_bonus).is_equal_approx(expected, 0.1)


## Test: Position value bonuses are correct for premium positions
func test_position_value_bonuses_premium() -> void:
	var mod := PositionValueModifier.new()

	var premium_bonuses := {
		"QB": 5.0,
		"EDGE": 2.0,
		"OL": 1.0,
		"CB": 0.5,
		"WR": 0.5,
		"DL": 0.5
	}

	for position in premium_bonuses.keys():
		var ctx := _create_simple_context(position)
		var result = mod.calculate(ctx)

		assert_bool(result.is_additive()).is_true()

		var expected: float = float(premium_bonuses[position])
		assert_float(result.additive_bonus).is_equal_approx(expected, 0.1)


## Test: Position value bonuses are correct for neutral/devalued positions
func test_position_value_bonuses_neutral() -> void:
	var mod := PositionValueModifier.new()

	var neutral_bonuses := {
		"LB": 0.0,
		"TE": 0.0,
		"RB": 0.0,
		"S": 0.0,
		"K": -5.0,
		"P": -5.0
	}

	for position in neutral_bonuses.keys():
		var ctx := _create_simple_context(position)
		var result = mod.calculate(ctx)

		assert_bool(result.is_additive()).is_true()

		var expected: float = float(neutral_bonuses[position])
		assert_float(result.additive_bonus).is_equal_approx(expected, 0.1)


## Test: Special teams get severe penalty
##
## K and P should be nearly impossible to draft early due to large penalties.
func test_special_teams_severe_penalty() -> void:
	var stack := EvaluationModifierStack.new()
	stack.register(PositionTierModifier.new())
	stack.register(PositionValueModifier.new())

	# Elite kicker (85 OVR) in round 1
	var ctx_k := _create_test_context("K", 85.0, 1)
	var result_k := stack.evaluate(ctx_k)
	var score_k := result_k.calculate_final_score(85.0)

	# Average EDGE (70 OVR) in round 1
	var ctx_edge := _create_test_context("EDGE", 70.0, 1)
	var result_edge := stack.evaluate(ctx_edge)
	var score_edge := result_edge.calculate_final_score(70.0)

	# The key point: even with caps, kickers should score lower than average EDGE
	assert_float(score_k).is_less(score_edge)


## Test: Additive total is capped at +/- 10 OVR
func test_additive_total_cap() -> void:
	var stack := EvaluationModifierStack.new()
	stack.register(PositionTierModifier.new())
	stack.register(PositionValueModifier.new())

	# QB in round 1 gets maximum positive bonus
	var ctx_qb := _create_test_context("QB", 80.0, 1)
	var result_qb := stack.evaluate(ctx_qb)

	assert_float(result_qb.additive_total).is_less_equal(10.0)
	assert_float(result_qb.additive_total).is_greater_equal(-10.0)


## Test: Standard positions get neutral bonuses
func test_standard_positions_neutral() -> void:
	var stack := EvaluationModifierStack.new()
	stack.register(PositionTierModifier.new())
	stack.register(PositionValueModifier.new())

	# WR in round 1 (standard tier)
	var ctx_wr := _create_test_context("WR", 80.0, 1)
	var result_wr := stack.evaluate(ctx_wr)

	# WR should get:
	# - Position tier: 0 (standard)
	# - Position value: +0.5 (WR slight premium)
	# Total additive: +0.5 OVR
	assert_float(result_wr.additive_total).is_equal_approx(0.5, 0.1)

	# Final score: (80 + 0.5) * 1.0 = 80.5
	var final_score := result_wr.calculate_final_score(80.0)
	assert_float(final_score).is_equal_approx(80.5, 0.1)


## Helper: Create test evaluation context
func _create_test_context(position: String, base_rating: float, round_num: int) -> EvaluationContext:
	var ctx := EvaluationContext.new()
	ctx.position = position
	ctx.base_rating = base_rating
	ctx.phase = "draft"
	ctx.draft_round = round_num
	ctx.player = {"position": position}
	ctx.team = {}
	ctx.roster = {}

	# Set up draft strategy with position tiers (needed by PositionTierModifier)
	ctx.draft_strategy = {
		"position_tiers": {
			"premium": {
				"positions": ["QB", "EDGE", "OL", "CB"]
			},
			"standard": {
				"positions": ["WR", "DL", "LB"]
			},
			"devalued": {
				"positions": ["RB", "TE", "S"]
			},
			"special_teams": {
				"positions": ["K", "P"]
			}
		}
	}

	return ctx


## Helper: Create simple context for position value testing
func _create_simple_context(position: String) -> EvaluationContext:
	var ctx := EvaluationContext.new()
	ctx.position = position
	ctx.base_rating = 75.0
	ctx.phase = "draft"
	ctx.draft_round = 1
	ctx.player = {"position": position}
	ctx.team = {}
	ctx.roster = {}
	ctx.draft_strategy = {}

	return ctx
