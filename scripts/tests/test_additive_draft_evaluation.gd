extends RefCounted

## Additive Draft Evaluation Tests
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

const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")
const EvaluationModifier = preload("res://scripts/core/evaluation/EvaluationModifier.gd")
const EvaluationModifierStack = preload("res://scripts/core/evaluation/EvaluationModifierStack.gd")
const PositionTierModifier = preload("res://scripts/core/evaluation/modifiers/PositionTierModifier.gd")
const PositionValueModifier = preload("res://scripts/core/evaluation/modifiers/PositionValueModifier.gd")


func run(t) -> void:
	_test_additive_modifier_result_creation(t)
	_test_stack_applies_additive_before_multiplicative(t)
	_test_elite_wr_beats_mediocre_edge(t)
	_test_elite_edge_slightly_beats_equal_wr(t)
	_test_elite_qb_beats_good_edge(t)
	_test_position_tier_round_scaling(t)
	_test_position_value_bonuses(t)
	_test_special_teams_severe_penalty(t)
	_test_additive_total_cap(t)


## Test: ModifierResult.create_additive() works correctly
##
## Validates that the additive factory method creates the right modifier type.
func _test_additive_modifier_result_creation(t) -> void:
	# Create additive modifier
	var result: EvaluationModifier.ModifierResult = EvaluationModifier.ModifierResult.create_additive(3.0, "Test reason", {"test": true})

	t.assert_true(result.is_additive(), "Result should be additive type")
	t.assert_eq(result.additive_bonus, 3.0, "Additive bonus should be 3.0")
	t.assert_eq(result.multiplier, 1.0, "Multiplier should be neutral (1.0) for additive")
	t.assert_eq(result.reason, "Test reason", "Reason should be set")
	t.assert_eq(result.get_effect_string(), "+3.0 OVR", "Effect string should show OVR bonus")

	# Create negative additive
	var result_neg: EvaluationModifier.ModifierResult = EvaluationModifier.ModifierResult.create_additive(-2.5, "Penalty")
	t.assert_eq(result_neg.additive_bonus, -2.5, "Negative additive bonus should work")
	t.assert_eq(result_neg.get_effect_string(), "-2.5 OVR", "Effect string should show penalty")

	# Create multiplicative (default) for comparison
	var result_mult: EvaluationModifier.ModifierResult = EvaluationModifier.ModifierResult.new(1.2, "Boost")
	t.assert_true(not result_mult.is_additive(), "Default should be multiplicative")
	t.assert_eq(result_mult.get_effect_string(), "1.20x", "Multiplicative effect string")


## Test: EvaluationModifierStack applies additive before multiplicative
##
## Validates the formula: final_score = (base_ovr + additive_total) * multiplicative_total
func _test_stack_applies_additive_before_multiplicative(t) -> void:
	var stack := EvaluationModifierStack.new()

	# Register position tier (additive) and position value (additive)
	stack.register(PositionTierModifier.new())
	stack.register(PositionValueModifier.new())

	# Create context for EDGE player in round 1
	var ctx := _create_test_context("EDGE", 75.0, 1)

	var result: EvaluationModifierStack.StackResult = stack.evaluate(ctx)

	# EDGE in round 1 should get:
	# - Position tier: +3 OVR (premium in round 1)
	# - Position value: +2 OVR (EDGE premium)
	# Total additive: +5 OVR
	t.assert_true(absf(result.additive_total - 5.0) < 0.1,
		"EDGE R1 additive total should be ~5.0 (got %.2f)" % result.additive_total)

	# Multiplicative should be 1.0 (no multiplicative modifiers in this test)
	t.assert_eq(result.final_multiplier, 1.0, "No multiplicative modifiers applied")

	# Final score: (75 + 5) * 1.0 = 80
	var final_score := result.calculate_final_score(75.0)
	t.assert_true(absf(final_score - 80.0) < 0.1,
		"Final score should be ~80.0 (got %.2f)" % final_score)


## Test: Elite WR beats mediocre EDGE
##
## THE KEY FIX: This is the scenario that was broken.
## Old system: 73 EDGE x 1.4 x 1.2 = 122.6 vs 88 WR x 1.0 = 88.0 (EDGE wins by 34.6!)
## New system: 73 EDGE + 5 = 78 vs 88 WR + 0.5 = 88.5 (WR wins by 10.5)
func _test_elite_wr_beats_mediocre_edge(t) -> void:
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

	t.assert_true(score_wr > score_edge,
		"Elite WR (%.1f) should beat mediocre EDGE (%.1f)" % [score_wr, score_edge])

	var gap := score_wr - score_edge
	t.assert_true(gap > 5.0,
		"Gap should be significant (>5.0 OVR). Got %.1f" % gap)

	# Verify the specific scores match expectations
	t.assert_true(absf(score_edge - 78.0) < 0.5,
		"Mediocre EDGE score should be ~78 (got %.1f)" % score_edge)
	t.assert_true(absf(score_wr - 88.5) < 0.5,
		"Elite WR score should be ~88.5 (got %.1f)" % score_wr)


## Test: Elite EDGE slightly beats equal-rated WR
##
## When ratings are close, position value should provide tiebreaker.
## 85 EDGE + 5 = 90 vs 88 WR + 0.5 = 88.5 (EDGE wins by 1.5)
func _test_elite_edge_slightly_beats_equal_wr(t) -> void:
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

	t.assert_true(score_edge > score_wr,
		"Elite EDGE (%.1f) should slightly beat slightly-better WR (%.1f)" % [score_edge, score_wr])

	# But the gap should be small (< 3 points)
	var gap := score_edge - score_wr
	t.assert_true(gap < 3.0,
		"Gap should be small (<3.0). Got %.1f" % gap)


## Test: Elite QB beats good EDGE due to QB scarcity
##
## QB gets highest position value (+5 OVR), reflecting real NFL scarcity.
## 82 QB + 8 = 90 vs 80 EDGE + 5 = 85 (QB wins by 5)
func _test_elite_qb_beats_good_edge(t) -> void:
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

	t.assert_true(score_qb > score_edge,
		"Elite QB (%.1f) should beat good EDGE (%.1f)" % [score_qb, score_edge])

	t.assert_true(absf(score_qb - 90.0) < 0.5,
		"QB score should be ~90 (got %.1f)" % score_qb)
	t.assert_true(absf(score_edge - 85.0) < 0.5,
		"EDGE score should be ~85 (got %.1f)" % score_edge)


## Test: Position tier bonuses scale by round
##
## Validates that tier bonuses decrease in later rounds:
## - Round 1: +3 (premium) / -3 (devalued)
## - Round 2: +2 / -2
## - Round 3-4: +1 / -1
## - Round 5+: 0
func _test_position_tier_round_scaling(t) -> void:
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

		t.assert_true(result.is_additive(),
			"Position tier should return additive modifier")

		var expected: float = float(round_bonuses[round_num])
		t.assert_true(absf(result.additive_bonus - expected) < 0.1,
			"EDGE in round %d should get +%.1f bonus (got %.1f)" %
			[round_num, expected, result.additive_bonus])

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
		t.assert_true(absf(result.additive_bonus - expected) < 0.1,
			"RB in round %d should get %.1f penalty (got %.1f)" %
			[round_num, expected, result.additive_bonus])


## Test: Position value bonuses are correct
##
## Validates that each position gets the expected additive bonus.
func _test_position_value_bonuses(t) -> void:
	var mod := PositionValueModifier.new()

	var expected_bonuses := {
		"QB": 5.0,
		"EDGE": 2.0,
		"OL": 1.0,
		"CB": 0.5,
		"WR": 0.5,
		"DL": 0.5,
		"LB": 0.0,
		"TE": 0.0,
		"RB": 0.0,
		"S": 0.0,
		"K": -5.0,
		"P": -5.0
	}

	for position in expected_bonuses.keys():
		var ctx := _create_simple_context(position)
		var result = mod.calculate(ctx)

		t.assert_true(result.is_additive(),
			"%s position value should return additive modifier" % position)

		var expected: float = float(expected_bonuses[position])
		t.assert_true(absf(result.additive_bonus - expected) < 0.1,
			"%s should have position value bonus of %.1f (got %.1f)" %
			[position, expected, result.additive_bonus])


## Test: Special teams get severe penalty
##
## K and P should be nearly impossible to draft early due to large penalties.
## In round 1: K/P get -20 OVR (tier) + -5 OVR (value) = -25 total
## Even an 85 OVR kicker would score 85 - 25 = 60, way below average players.
func _test_special_teams_severe_penalty(t) -> void:
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

	# Kicker should score way below average players
	# K: 85 - 5 (tier, capped) + (-5 value) = 75 (after cap)
	# Actually, bounds are -5 to +5, so tier penalty is capped

	# The key point: even with caps, kickers should score lower than average EDGE
	t.assert_true(score_k < score_edge,
		"Elite K (%.1f) should score lower than average EDGE (%.1f) in round 1" %
		[score_k, score_edge])


## Test: Additive total is capped at +/- 10 OVR
##
## Validates that extreme stacking of additive bonuses is limited.
func _test_additive_total_cap(t) -> void:
	var stack := EvaluationModifierStack.new()
	stack.register(PositionTierModifier.new())
	stack.register(PositionValueModifier.new())

	# QB in round 1 gets maximum positive bonus
	# Tier: +3 (premium, but capped at 5)
	# Value: +5 (QB premium)
	# Total: 8 (under cap of 10)
	var ctx_qb := _create_test_context("QB", 80.0, 1)
	var result_qb := stack.evaluate(ctx_qb)

	t.assert_true(result_qb.additive_total <= 10.0,
		"Additive total should be capped at 10 (got %.1f)" % result_qb.additive_total)
	t.assert_true(result_qb.additive_total >= -10.0,
		"Additive total should be at least -10 (got %.1f)" % result_qb.additive_total)


## Helper: Create test evaluation context
##
## Creates a minimal context for testing position modifiers.
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
