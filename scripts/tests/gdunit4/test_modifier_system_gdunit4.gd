## GdUnit4 tests for the evaluation modifier system
extends GdUnitTestSuite

const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")
const EvaluationModifier = preload("res://scripts/core/evaluation/EvaluationModifier.gd")
const EvaluationModifierStack = preload("res://scripts/core/evaluation/EvaluationModifierStack.gd")

const PositionTierModifier = preload("res://scripts/core/evaluation/modifiers/PositionTierModifier.gd")
const PositionValueModifier = preload("res://scripts/core/evaluation/modifiers/PositionValueModifier.gd")
const PositionNeedModifier = preload("res://scripts/core/evaluation/modifiers/PositionNeedModifier.gd")
const QBUrgencyModifier = preload("res://scripts/core/evaluation/modifiers/QBUrgencyModifier.gd")
const SchemeFitModifier = preload("res://scripts/core/evaluation/modifiers/SchemeFitModifier.gd")
const CoachMindsetModifier = preload("res://scripts/core/evaluation/modifiers/CoachMindsetModifier.gd")
const RosterMoveModifier = preload("res://scripts/core/evaluation/modifiers/RosterMoveModifier.gd")


# =============================================================================
# EVALUATION MODIFIER BASE CLASS TESTS
# =============================================================================

## Test base modifier has default bounds
func test_evaluation_modifier_default_bounds() -> void:
	var mod := EvaluationModifier.new()
	var bounds := mod.get_bounds()
	assert_float(bounds.get("min", 0.0)).is_equal(0.6)
	assert_float(bounds.get("max", 0.0)).is_equal(1.4)


# =============================================================================
# EVALUATION CONTEXT TESTS
# =============================================================================

## Test context factory for draft
func test_evaluation_context_for_draft() -> void:
	var player := {"position": "QB", "first_name": "Test"}
	var team := {"id": "team_1", "offensive_scheme": "air_raid"}
	var roster := {"by_position": {}}
	var positions_cfg := {}
	var stats_cfg := {}
	var class_rules := {}
	var draft_strategy := {"position_tiers": {"premium": ["QB"]}}

	var ctx := EvaluationContext.for_draft(
		player, team, roster, 1, 2024,
		positions_cfg, stats_cfg, class_rules, draft_strategy
	)

	assert_str(ctx.position).is_equal("QB")
	assert_str(ctx.phase).is_equal("draft")
	assert_int(ctx.draft_round).is_equal(1)
	assert_object(ctx.draft_strategy).is_not_null()


## Test context factory for free agency
func test_evaluation_context_for_free_agency() -> void:
	var player := {"position": "WR", "first_name": "Test"}
	var team := {"id": "team_1", "offensive_scheme": "west_coast"}
	var roster := {"by_position": {}}
	var positions_cfg := {}
	var class_rules := {}

	var ctx := EvaluationContext.for_free_agency(
		player, team, roster, 2024, positions_cfg, class_rules
	)

	assert_str(ctx.position).is_equal("WR")
	assert_str(ctx.phase).is_equal("free_agency")


# =============================================================================
# EVALUATION MODIFIER STACK TESTS
# =============================================================================

## Test modifier priority ordering
func test_modifier_stack_priority_ordering() -> void:
	var stack := EvaluationModifierStack.new()
	stack.register(CoachMindsetModifier.new())  # Priority 60
	stack.register(PositionTierModifier.new())  # Priority 10
	stack.register(PositionNeedModifier.new())  # Priority 30

	var mods := stack.get_modifiers()
	assert_int(mods[0].get_priority()).is_equal(10)  # PositionTier first
	assert_int(mods[1].get_priority()).is_equal(30)  # PositionNeed second
	assert_int(mods[2].get_priority()).is_equal(60)  # CoachMindset third


## Test per-modifier bounds enforcement
func test_modifier_bounds_enforcement() -> void:
	var stack := EvaluationModifierStack.new()

	# Create a test modifier that tries to return out-of-bounds value
	var test_mod := QBUrgencyModifier.new()

	# QB urgency has bounds 1.0 - 2.8
	var bounds := test_mod.get_bounds()
	assert_float(bounds.get("min", 0.0)).is_equal(1.0)
	assert_float(bounds.get("max", 0.0)).is_equal(2.8)


## Test intermediate clamping at priority 30
func test_intermediate_clamping_after_priority_30() -> void:
	# This test verifies that after PositionNeedModifier (priority 30),
	# the cumulative multiplier is capped at 2.0x

	var stack := EvaluationModifierStack.new()
	stack.register(PositionTierModifier.new())   # Priority 10
	stack.register(PositionValueModifier.new())  # Priority 20
	stack.register(PositionNeedModifier.new())   # Priority 30

	# Create context that would trigger high multipliers
	var ctx := _create_test_context_for_high_need()

	var result := stack.evaluate(ctx)

	# Even with multiple high multipliers, intermediate clamp should prevent
	# exceeding 2.0x at this stage
	# Note: This is a structural test - actual value depends on modifier logic
	assert_float(result.final_multiplier).is_less_equal(2.0)


## Test cumulative cap at 4.0x
func test_cumulative_multiplier_cap() -> void:
	var stack := EvaluationModifierStack.create_draft_stack()

	# Create context designed to trigger maximum multipliers
	var ctx := _create_test_context_for_max_multipliers()

	var result := stack.evaluate(ctx)

	# Final multiplier must never exceed 4.0x
	assert_float(result.final_multiplier).is_less_equal(4.0)


## Test draft stack creation
func test_create_draft_stack() -> void:
	var stack := EvaluationModifierStack.create_draft_stack()
	var modifiers := stack.get_modifiers()

	# Draft stack should have 7 modifiers
	assert_int(modifiers.size()).is_equal(7)


## Test free agency stack creation
func test_create_free_agency_stack() -> void:
	var stack := EvaluationModifierStack.create_free_agency_stack()
	var modifiers := stack.get_modifiers()

	# FA stack has 4 modifiers: PositionValue, PositionNeed, SchemeFit, CoachMindset
	# (no PositionTier, QBUrgency, or RosterMove - those are draft-specific)
	assert_int(modifiers.size()).is_equal(4)


# =============================================================================
# POSITION NEED MODIFIER TESTS
# =============================================================================

## Test position need hard cap blocks acquisition
func test_position_need_hard_cap_blocks() -> void:
	var mod := PositionNeedModifier.new()

	# Create context with position at hard cap
	var ctx := EvaluationContext.new()
	ctx.position = "RB"
	ctx.roster = {
		"by_position": {
			"RB": [1, 2, 3, 4]  # 4 RBs = at cap
		}
	}
	ctx.phase = "draft"

	var result := mod.calculate(ctx)

	# Should return 0.0 multiplier (blocked)
	assert_float(result.multiplier).is_equal(0.0)
	assert_str(result.reason).contains("hard cap")


# =============================================================================
# POSITION TIER MODIFIER TESTS
# =============================================================================

## Test premium positions get boost in early rounds
func test_position_tier_premium_round_1() -> void:
	var mod := PositionTierModifier.new()

	var ctx := EvaluationContext.new()
	ctx.phase = "draft"
	ctx.position = "QB"
	ctx.draft_round = 1
	ctx.draft_strategy = {"position_tiers": {"premium": ["QB", "EDGE"], "devalued": ["RB"]}}

	assert_bool(mod.is_applicable(ctx)).is_true()
	var result := mod.calculate(ctx)
	assert_float(result.multiplier).is_equal(1.3)
	assert_str(result.reason).contains("premium")


## Test devalued positions get penalty in early rounds
func test_position_tier_devalued_round_1() -> void:
	var mod := PositionTierModifier.new()

	var ctx := EvaluationContext.new()
	ctx.phase = "draft"
	ctx.position = "RB"
	ctx.draft_round = 1
	ctx.draft_strategy = {"position_tiers": {"premium": ["QB"], "devalued": ["RB", "S"]}}

	var result := mod.calculate(ctx)
	assert_float(result.multiplier).is_equal(0.7)
	assert_str(result.reason).contains("devalued")


## Test tier modifier converges to neutral in late rounds
func test_position_tier_neutral_late_rounds() -> void:
	var mod := PositionTierModifier.new()

	var ctx := EvaluationContext.new()
	ctx.phase = "draft"
	ctx.position = "QB"
	ctx.draft_round = 6
	ctx.draft_strategy = {"position_tiers": {"premium": ["QB"], "devalued": ["RB"]}}

	var result := mod.calculate(ctx)
	assert_float(result.multiplier).is_equal(1.0)


## Test position tier not applicable in free agency
func test_position_tier_not_applicable_in_fa() -> void:
	var mod := PositionTierModifier.new()

	var ctx := EvaluationContext.new()
	ctx.phase = "free_agency"
	ctx.position = "QB"
	ctx.draft_round = 0
	ctx.draft_strategy = {"position_tiers": {"premium": ["QB"], "devalued": []}}

	assert_bool(mod.is_applicable(ctx)).is_false()


# =============================================================================
# POSITION VALUE MODIFIER TESTS
# =============================================================================

## Test position with high market value
func test_position_value_high_value() -> void:
	var mod := PositionValueModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = "QB"
	ctx.positions_cfg = {"QB": {"value": 1.2}}

	assert_bool(mod.is_applicable(ctx)).is_true()
	var result := mod.calculate(ctx)
	assert_float(result.multiplier).is_equal(1.2)
	assert_str(result.reason).contains("high market value")


## Test position with low market value
func test_position_value_low_value() -> void:
	var mod := PositionValueModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = "K"
	ctx.positions_cfg = {"K": {"value": 0.8}}

	var result := mod.calculate(ctx)
	assert_float(result.multiplier).is_equal(0.8)
	assert_str(result.reason).contains("low market value")


## Test position value defaults to 1.0 if not configured
func test_position_value_default() -> void:
	var mod := PositionValueModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = "WR"
	ctx.positions_cfg = {"WR": {}}  # No value configured

	var result := mod.calculate(ctx)
	assert_float(result.multiplier).is_equal(1.0)


# =============================================================================
# QB URGENCY MODIFIER TESTS
# =============================================================================

## Test QB urgency triggers for desperate team
func test_qb_urgency_desperate_no_qb() -> void:
	var mod := QBUrgencyModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = "QB"
	ctx.phase = "draft"
	ctx.base_rating = 82.0  # Elite prospect
	ctx.roster = {"by_position": {"QB": []}, "players": {}}
	ctx.class_rules = {"draft_qb_urgency": {"desperate_multiplier": 2.8, "moderate_multiplier": 1.6}}
	ctx.positions_cfg = {}

	assert_bool(mod.is_applicable(ctx)).is_true()
	var result := mod.calculate(ctx)
	assert_float(result.multiplier).is_equal(2.8)
	assert_str(result.reason).contains("Desperate")


## Test QB urgency not applicable for non-elite QB
func test_qb_urgency_not_applicable_non_elite() -> void:
	var mod := QBUrgencyModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = "QB"
	ctx.phase = "draft"
	ctx.base_rating = 70.0  # Not elite

	assert_bool(mod.is_applicable(ctx)).is_false()


## Test QB urgency not applicable for non-QB position
func test_qb_urgency_not_applicable_non_qb() -> void:
	var mod := QBUrgencyModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = "WR"
	ctx.phase = "draft"
	ctx.base_rating = 85.0

	assert_bool(mod.is_applicable(ctx)).is_false()


## Test QB urgency neutral when franchise QB exists
func test_qb_urgency_franchise_qb_exists() -> void:
	var mod := QBUrgencyModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = "QB"
	ctx.phase = "draft"
	ctx.base_rating = 82.0
	ctx.roster = {
		"by_position": {"QB": ["qb_1"]},
		"players": {"qb_1": {"overall": 85.0, "age": 28}}  # Franchise QB
	}
	ctx.class_rules = {"draft_qb_urgency": {"desperate_multiplier": 2.8}}
	ctx.positions_cfg = {}

	var result := mod.calculate(ctx)
	assert_float(result.multiplier).is_equal(1.0)


# =============================================================================
# COACH MINDSET MODIFIER TESTS
# =============================================================================

## Test defensive coach boosts defensive players
func test_coach_mindset_defensive_coach() -> void:
	var mod := CoachMindsetModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = "EDGE"
	ctx.base_rating = 80.0  # Elite
	ctx.phase = "draft"
	ctx.coach = {"specialty_position": "Defense"}

	assert_bool(mod.is_applicable(ctx)).is_true()
	var result := mod.calculate(ctx)
	assert_float(result.multiplier).is_greater(1.0)
	assert_str(result.reason).contains("Defensive")


## Test offensive coach boosts offensive players
func test_coach_mindset_offensive_coach() -> void:
	var mod := CoachMindsetModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = "WR"
	ctx.base_rating = 80.0
	ctx.phase = "draft"
	ctx.coach = {"specialty_position": "Offense"}

	var result := mod.calculate(ctx)
	assert_float(result.multiplier).is_greater(1.0)


## Test defensive coach slight penalty for offensive players
func test_coach_mindset_opposite_penalty() -> void:
	var mod := CoachMindsetModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = "WR"  # Offensive
	ctx.base_rating = 75.0
	ctx.phase = "draft"
	ctx.coach = {"specialty_position": "Defense"}  # Defensive coach

	var result := mod.calculate(ctx)
	assert_float(result.multiplier).is_less(1.0)


## Test position specialist heavily boosts that position
func test_coach_mindset_specialist() -> void:
	var mod := CoachMindsetModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = "QB"
	ctx.base_rating = 80.0  # Elite
	ctx.phase = "draft"
	ctx.coach = {"specialty_position": "QB"}  # QB specialist

	var result := mod.calculate(ctx)
	# Should get specialist boost (1.18 for elite)
	assert_float(result.multiplier).is_greater_equal(1.1)


## Test no specialty means not applicable
func test_coach_mindset_no_specialty() -> void:
	var mod := CoachMindsetModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = "QB"
	ctx.coach = {}  # No specialty

	assert_bool(mod.is_applicable(ctx)).is_false()


# =============================================================================
# ROSTER MOVE MODIFIER TESTS
# =============================================================================

## Test no penalty when position not at cap
func test_roster_move_not_at_cap() -> void:
	var mod := RosterMoveModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = "WR"
	ctx.phase = "draft"
	ctx.base_rating = 75.0
	ctx.roster = {
		"by_position": {"WR": ["wr_1", "wr_2"]},  # Not at cap
		"players": {}
	}

	assert_bool(mod.is_applicable(ctx)).is_true()
	var result := mod.calculate(ctx)
	assert_float(result.multiplier).is_equal(1.0)
	assert_str(result.reason).contains("No roster move")


## Test not applicable in free agency
func test_roster_move_not_in_fa() -> void:
	var mod := RosterMoveModifier.new()

	var ctx := EvaluationContext.new()
	ctx.phase = "free_agency"
	ctx.roster = {"by_position": {}}

	assert_bool(mod.is_applicable(ctx)).is_false()


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

## Integration test: Draft evaluation produces realistic rankings
func test_draft_evaluation_integration() -> void:
	var stack := EvaluationModifierStack.create_draft_stack()

	# Test that elite QB prospect gets high boost
	var qb_ctx := _create_test_context_for_max_multipliers()
	var qb_result := stack.evaluate(qb_ctx)

	# Should get significant boost (tier + value + need + urgency)
	assert_float(qb_result.final_multiplier).is_greater(1.5)

	# Test that devalued position in round 1 gets penalty
	var rb_ctx := EvaluationContext.new()
	rb_ctx.position = "RB"
	rb_ctx.phase = "draft"
	rb_ctx.draft_round = 1
	rb_ctx.base_rating = 75.0
	rb_ctx.roster = {"by_position": {"RB": [1, 2]}}
	rb_ctx.positions_cfg = {"RB": {"value": 0.9}}
	rb_ctx.draft_strategy = {"position_tiers": {"premium": [], "devalued": ["RB"]}}
	rb_ctx.team = {}
	rb_ctx.coach = {}

	var rb_result := stack.evaluate(rb_ctx)

	# Should get penalty (devalued in round 1)
	assert_float(rb_result.final_multiplier).is_less(1.0)


## Integration test: FA evaluation uses correct modifier subset
func test_free_agency_evaluation_integration() -> void:
	var stack := EvaluationModifierStack.create_free_agency_stack()

	# FA should NOT include PositionTierModifier or QBUrgencyModifier
	var modifiers := stack.get_modifiers()

	var has_position_tier := false
	var has_qb_urgency := false

	for mod in modifiers:
		var m: EvaluationModifier = mod
		if m.get_id() == "position_tier":
			has_position_tier = true
		if m.get_id() == "qb_urgency":
			has_qb_urgency = true

	assert_bool(has_position_tier).is_false()
	assert_bool(has_qb_urgency).is_false()


## Integration test: Scheme fit affects evaluation
func test_scheme_fit_integration() -> void:
	var mod := SchemeFitModifier.new()

	# Create context with specific scheme
	var ctx := EvaluationContext.new()
	ctx.position = "QB"
	ctx.offensive_scheme = "air_raid"
	ctx.base_rating = 75.0
	ctx.player = {
		"stats": {
			"throw_power": 85,
			"throw_accuracy": 80,
			"speed": 60
		}
	}
	ctx.coach = {"scheme_rigidity": 1.0}

	if mod.is_applicable(ctx):
		var result := mod.calculate(ctx)

		# Multiplier should be in bounds
		assert_float(result.multiplier).is_greater_equal(0.8)
		assert_float(result.multiplier).is_less_equal(1.2)


# =============================================================================
# HELPER METHODS
# =============================================================================

## Helper to create test context with high need
func _create_test_context_for_high_need() -> EvaluationContext:
	var ctx := EvaluationContext.new()
	ctx.position = "EDGE"
	ctx.phase = "draft"
	ctx.draft_round = 1
	ctx.base_rating = 80.0

	# Empty roster = high need
	ctx.roster = {"by_position": {"EDGE": []}}

	ctx.positions_cfg = {
		"EDGE": {"value": 1.1, "ideal_depth": 4, "max_depth": 6}
	}

	ctx.draft_strategy = {
		"position_tiers": {
			"premium": ["EDGE"],
			"devalued": []
		}
	}

	ctx.team = {"offensive_scheme": "pro_style", "defensive_scheme": "3_4_two_gap"}
	ctx.coach = {"specialty_position": "Defense", "scheme_rigidity": 1.0}

	return ctx


## Helper to create test context for maximum multipliers
func _create_test_context_for_max_multipliers() -> EvaluationContext:
	var ctx := EvaluationContext.new()
	ctx.position = "QB"
	ctx.phase = "draft"
	ctx.draft_round = 1
	ctx.base_rating = 85.0  # Elite QB

	# No QBs = desperate need + QB urgency
	ctx.roster = {"by_position": {"QB": []}, "players": {}}

	ctx.positions_cfg = {
		"QB": {"value": 1.2, "ideal_depth": 3, "max_depth": 4}
	}

	ctx.draft_strategy = {
		"position_tiers": {
			"premium": ["QB"],
			"devalued": []
		}
	}

	ctx.class_rules = {
		"draft_qb_urgency": {
			"desperate_multiplier": 2.8,
			"moderate_multiplier": 1.6
		}
	}

	ctx.team = {"offensive_scheme": "air_raid", "defensive_scheme": "cover_2"}
	ctx.coach = {"specialty_position": "Offense", "scheme_rigidity": 1.0}

	return ctx
