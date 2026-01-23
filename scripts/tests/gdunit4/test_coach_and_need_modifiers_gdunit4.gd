extends GdUnitTestSuite
class_name TestCoachAndNeedModifiersGdUnit4

## Tests for CoachMindsetModifier and PositionNeedModifier
##
## These simpler modifiers are tested together for efficiency.
##
## Validates:
## - Coach mindset preferences (offense/defense/specialist)
## - Position need calculations
## - Roster depth analysis
## - Hard cap enforcement

const CoachMindsetModifier = preload("res://scripts/core/evaluation/modifiers/CoachMindsetModifier.gd")
const PositionNeedModifier = preload("res://scripts/core/evaluation/modifiers/PositionNeedModifier.gd")
const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# =============================================================================
# COACH MINDSET MODIFIER TESTS
# =============================================================================

func test_coach_mindset_has_correct_id() -> void:
	var modifier := CoachMindsetModifier.new()
	assert_string(modifier.get_id()).is_equal("coach_mindset")


func test_coach_mindset_has_correct_priority() -> void:
	var modifier := CoachMindsetModifier.new()
	# Should run after scheme fit (50), late in pipeline
	assert_int(modifier.get_priority()).is_equal(60)


func test_coach_mindset_not_applicable_without_specialty() -> void:
	var modifier := CoachMindsetModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB")
	var team := {"coach": {}}  # No specialty
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})

	assert_bool(modifier.is_applicable(ctx)).is_false()


func test_coach_mindset_applicable_with_specialty() -> void:
	var modifier := CoachMindsetModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB")
	var team := {"coach": {"specialty_position": "Offense"}}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})

	assert_bool(modifier.is_applicable(ctx)).is_true()


func test_defensive_coach_boosts_defensive_players() -> void:
	var modifier := CoachMindsetModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "EDGE", 21, 75.0)
	var team := {"coach": {"specialty_position": "Defense"}}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 75.0

	var result := modifier.calculate(ctx)

	# Defensive coach should boost defensive player
	assert_float(result.multiplier).is_greater(1.0)


func test_offensive_coach_boosts_offensive_players() -> void:
	var modifier := CoachMindsetModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "WR", 21, 75.0)
	var team := {"coach": {"specialty_position": "Offense"}}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 75.0

	var result := modifier.calculate(ctx)

	# Offensive coach should boost offensive player
	assert_float(result.multiplier).is_greater(1.0)


func test_defensive_coach_penalizes_offensive_players() -> void:
	var modifier := CoachMindsetModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 75.0)
	var team := {"coach": {"specialty_position": "Defense"}}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 75.0

	var result := modifier.calculate(ctx)

	# Defensive coach should slightly penalize offensive player
	assert_float(result.multiplier).is_less(1.0)


func test_position_specialist_heavily_boosts_matching_position() -> void:
	var modifier := CoachMindsetModifier.new()
	var qb_player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 80.0)
	var team := {"coach": {"specialty_position": "QB"}}
	var ctx := EvaluationContext.for_draft(qb_player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 80.0

	var result := modifier.calculate(ctx)

	# QB specialist should heavily boost QB prospect
	assert_float(result.multiplier).is_greater_equal(1.10)


func test_elite_players_get_larger_coach_boost() -> void:
	var modifier := CoachMindsetModifier.new()

	# Elite defensive player (80+ OVR)
	var elite_player := TestHelpersGdUnit4.create_test_player("P001", "EDGE", 21, 85.0)
	var team := {"coach": {"specialty_position": "Defense"}}
	var ctx_elite := EvaluationContext.for_draft(elite_player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx_elite.base_rating = 85.0
	var result_elite := modifier.calculate(ctx_elite)

	# Average defensive player (<78 OVR)
	var avg_player := TestHelpersGdUnit4.create_test_player("P002", "EDGE", 21, 70.0)
	var ctx_avg := EvaluationContext.for_draft(avg_player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx_avg.base_rating = 70.0
	var result_avg := modifier.calculate(ctx_avg)

	# Elite player should get larger boost
	assert_float(result_elite.multiplier).is_greater(result_avg.multiplier)


func test_coach_mindset_dampened_in_free_agency() -> void:
	var modifier := CoachMindsetModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "EDGE", 25, 75.0)
	var team := {"coach": {"specialty_position": "Defense"}}

	# Draft context
	var ctx_draft := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx_draft.base_rating = 75.0
	var result_draft := modifier.calculate(ctx_draft)

	# FA context
	var ctx_fa := EvaluationContext.for_free_agency(player, team, {}, 2025, {}, {})
	ctx_fa.base_rating = 75.0
	var result_fa := modifier.calculate(ctx_fa)

	# Draft should have stronger effect than FA
	var draft_deviation := absf(result_draft.multiplier - 1.0)
	var fa_deviation := absf(result_fa.multiplier - 1.0)

	assert_float(draft_deviation).is_greater_equal(fa_deviation)


# =============================================================================
# POSITION NEED MODIFIER TESTS
# =============================================================================

func test_position_need_has_correct_id() -> void:
	var modifier := PositionNeedModifier.new()
	assert_string(modifier.get_id()).is_equal("position_need")


func test_position_need_has_correct_priority() -> void:
	var modifier := PositionNeedModifier.new()
	# Should run early (before scheme fit, coach mindset)
	assert_int(modifier.get_priority()).is_equal(30)


func test_position_need_applicable_when_position_set() -> void:
	var modifier := PositionNeedModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB")
	var ctx := EvaluationContext.for_draft(player, {}, {}, 1, 2025, {}, {}, {}, {})

	assert_bool(modifier.is_applicable(ctx)).is_true()


func test_position_need_not_applicable_when_position_empty() -> void:
	var modifier := PositionNeedModifier.new()
	var ctx := EvaluationContext.new()
	ctx.position = ""

	assert_bool(modifier.is_applicable(ctx)).is_false()


func test_position_at_hard_cap_returns_zero_multiplier() -> void:
	var modifier := PositionNeedModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB")

	# Roster at hard cap for QB (assume max is 3)
	var roster := {
		"by_position": {
			"QB": [
				{"player_id": "QB1"},
				{"player_id": "QB2"},
				{"player_id": "QB3"}
			]
		}
	}

	var ctx := EvaluationContext.for_draft(player, {}, roster, 1, 2025, {}, {}, {}, {})

	var result := modifier.calculate(ctx)

	# At hard cap, should block (0.0 multiplier)
	assert_float(result.multiplier).is_equal(0.0)
	assert_that(result.details).has("blocked")
	assert_bool(result.details["blocked"]).is_true()


func test_position_overstocked_returns_low_multiplier() -> void:
	var modifier := PositionNeedModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "CB")

	# Roster overstocked (above ideal, below cap)
	var roster := {
		"by_position": {
			"CB": [
				{"player_id": "CB1"},
				{"player_id": "CB2"},
				{"player_id": "CB3"},
				{"player_id": "CB4"}
			]
		}
	}

	var ctx := EvaluationContext.for_draft(player, {}, roster, 1, 2025, {}, {}, {}, {})

	var result := modifier.calculate(ctx)

	# Overstocked should penalize (< 1.0)
	assert_float(result.multiplier).is_less(1.0)


func test_position_at_ideal_depth_returns_neutral_multiplier() -> void:
	var modifier := PositionNeedModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB")

	# Roster at ideal depth (assume ideal is 2)
	var roster := {
		"by_position": {
			"QB": [
				{"player_id": "QB1"},
				{"player_id": "QB2"}
			]
		}
	}

	var ctx := EvaluationContext.for_draft(player, {}, roster, 1, 2025, {}, {}, {}, {})

	var result := modifier.calculate(ctx)

	# At ideal, should be slightly below neutral (0.95)
	assert_float(result.multiplier).is_equal_approx(0.95, 0.05)


func test_position_below_ideal_returns_positive_multiplier() -> void:
	var modifier := PositionNeedModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "EDGE")

	# Roster below ideal (only 1 player)
	var roster := {
		"by_position": {
			"EDGE": [
				{"player_id": "EDGE1"}
			]
		}
	}

	var ctx := EvaluationContext.for_draft(player, {}, roster, 1, 2025, {}, {}, {}, {})

	var result := modifier.calculate(ctx)

	# Below ideal should boost (> 1.0)
	assert_float(result.multiplier).is_greater(1.0)


func test_position_critical_need_returns_high_multiplier() -> void:
	var modifier := PositionNeedModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB")

	# Roster with zero QBs
	var roster := {
		"by_position": {
			"QB": []
		}
	}

	var ctx := EvaluationContext.for_draft(player, {}, roster, 1, 2025, {}, {}, {}, {})

	var result := modifier.calculate(ctx)

	# Critical need should provide maximum boost (1.5)
	assert_float(result.multiplier).is_equal(1.5)
	assert_string(result.reason).contains("Critical need")


func test_position_need_dampened_in_early_draft_rounds() -> void:
	var modifier := PositionNeedModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "WR")

	# Roster with 0 WRs (critical need)
	var roster := {
		"by_position": {
			"WR": []
		}
	}

	# Round 1 (BPA philosophy)
	var ctx_r1 := EvaluationContext.for_draft(player, {}, roster, 1, 2025, {}, {}, {}, {})
	var result_r1 := modifier.calculate(ctx_r1)

	# Round 5 (need matters more)
	var ctx_r5 := EvaluationContext.for_draft(player, {}, roster, 5, 2025, {}, {}, {}, {})
	var result_r5 := modifier.calculate(ctx_r5)

	# Early rounds should dampen need effect (closer to 1.0)
	var r1_deviation := absf(result_r1.multiplier - 1.0)
	var r5_deviation := absf(result_r5.multiplier - 1.0)

	assert_float(r5_deviation).is_greater_equal(r1_deviation)


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

func test_coach_and_need_modifiers_stack_correctly() -> void:
	var coach_mod := CoachMindsetModifier.new()
	var need_mod := PositionNeedModifier.new()

	var player := TestHelpersGdUnit4.create_test_player("P001", "EDGE", 21, 80.0)
	var team := {"coach": {"specialty_position": "Defense"}}
	var roster := {
		"by_position": {
			"EDGE": []  # Critical need
		}
	}

	var ctx := EvaluationContext.for_draft(player, team, roster, 3, 2025, {}, {}, {}, {})
	ctx.base_rating = 80.0

	var need_result := need_mod.calculate(ctx)
	var coach_result := coach_mod.calculate(ctx)

	# Both should provide boosts
	assert_float(need_result.multiplier).is_greater(1.0)
	assert_float(coach_result.multiplier).is_greater(1.0)

	# Combined effect (multiplicative)
	var combined := need_result.multiplier * coach_result.multiplier
	assert_float(combined).is_greater(1.2)


# =============================================================================
# DETERMINISM TESTS
# =============================================================================

func test_coach_mindset_is_deterministic() -> void:
	var modifier := CoachMindsetModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 82.0)
	var team := {"coach": {"specialty_position": "QB"}}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 82.0

	var result1 := modifier.calculate(ctx)
	var result2 := modifier.calculate(ctx)

	assert_float(result1.multiplier).is_equal(result2.multiplier)


func test_position_need_is_deterministic() -> void:
	var modifier := PositionNeedModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "RB")
	var roster := {
		"by_position": {
			"RB": [{"player_id": "RB1"}]
		}
	}
	var ctx := EvaluationContext.for_draft(player, {}, roster, 2, 2025, {}, {}, {}, {})

	var result1 := modifier.calculate(ctx)
	var result2 := modifier.calculate(ctx)

	assert_float(result1.multiplier).is_equal(result2.multiplier)


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_coach_mindset_handles_missing_specialty_gracefully() -> void:
	var modifier := CoachMindsetModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB")
	var team := {"coach": {}}  # No specialty
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})

	# Should not be applicable, no error
	assert_bool(modifier.is_applicable(ctx)).is_false()


func test_position_need_handles_missing_roster_position() -> void:
	var modifier := PositionNeedModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "TE")
	var roster := {
		"by_position": {}  # No positions defined
	}
	var ctx := EvaluationContext.for_draft(player, {}, roster, 1, 2025, {}, {}, {}, {})

	var result := modifier.calculate(ctx)

	# Should treat as critical need (0 players)
	assert_float(result.multiplier).is_equal(1.5)


func test_position_need_handles_empty_roster() -> void:
	var modifier := PositionNeedModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "WR")
	var roster := {}  # Completely empty
	var ctx := EvaluationContext.for_draft(player, {}, roster, 1, 2025, {}, {}, {}, {})

	var result := modifier.calculate(ctx)

	# Should handle gracefully, treat as critical need
	assert_object(result).is_not_null()
	assert_float(result.multiplier).is_greater_equal(1.0)
