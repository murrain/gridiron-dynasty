extends GdUnitTestSuite
class_name TestEvaluationModifierStackGdUnit4

## Tests for EvaluationModifierStack orchestration system
##
## Validates:
## - Modifier registration and sorting
## - Modifier evaluation and stacking
## - Configuration and enabling/disabling
## - Result calculation and tracking
## - Factory methods for different phases
## - Additive and multiplicative modifier handling

const EvaluationModifierStack = preload("res://scripts/core/evaluation/EvaluationModifierStack.gd")
const EvaluationModifier = preload("res://scripts/core/evaluation/EvaluationModifier.gd")
const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# =============================================================================
# REGISTRATION TESTS
# =============================================================================

func test_stack_starts_empty() -> void:
	var stack := EvaluationModifierStack.new()
	var modifiers := stack.get_modifiers()

	assert_array(modifiers).is_empty()


func test_register_adds_modifier_to_stack() -> void:
	var stack := EvaluationModifierStack.new()
	var modifier := TestMultiplicativeModifier.new(1.2, "test")

	stack.register(modifier)

	var modifiers := stack.get_modifiers()
	assert_array(modifiers).has_size(1)
	assert_object(modifiers[0]).is_same(modifier)


func test_register_all_adds_multiple_modifiers() -> void:
	var stack := EvaluationModifierStack.new()
	var mods := [
		TestMultiplicativeModifier.new(1.1, "mod1"),
		TestMultiplicativeModifier.new(1.2, "mod2"),
		TestMultiplicativeModifier.new(1.3, "mod3"),
	]

	stack.register_all(mods)

	var modifiers := stack.get_modifiers()
	assert_array(modifiers).has_size(3)


func test_modifiers_sorted_by_priority_after_registration() -> void:
	var stack := EvaluationModifierStack.new()
	var mod_high := PriorityModifier.new(10)  # Low number = high priority
	var mod_low := PriorityModifier.new(100)
	var mod_mid := PriorityModifier.new(50)

	# Register in random order
	stack.register(mod_low)
	stack.register(mod_high)
	stack.register(mod_mid)

	var modifiers := stack.get_modifiers()
	# Should be sorted: high (10), mid (50), low (100)
	assert_int((modifiers[0] as PriorityModifier).priority).is_equal(10)
	assert_int((modifiers[1] as PriorityModifier).priority).is_equal(50)
	assert_int((modifiers[2] as PriorityModifier).priority).is_equal(100)


func test_unregister_removes_modifier_by_id() -> void:
	var stack := EvaluationModifierStack.new()
	var modifier := TestMultiplicativeModifier.new(1.2, "remove_me")

	stack.register(modifier)
	assert_array(stack.get_modifiers()).has_size(1)

	var removed := stack.unregister("remove_me")

	assert_bool(removed).is_true()
	assert_array(stack.get_modifiers()).is_empty()


func test_unregister_returns_false_for_nonexistent_modifier() -> void:
	var stack := EvaluationModifierStack.new()

	var removed := stack.unregister("does_not_exist")

	assert_bool(removed).is_false()


func test_get_modifier_retrieves_by_id() -> void:
	var stack := EvaluationModifierStack.new()
	var modifier := TestMultiplicativeModifier.new(1.2, "find_me")

	stack.register(modifier)

	var found := stack.get_modifier("find_me")
	assert_object(found).is_not_null()
	assert_object(found).is_same(modifier)


func test_get_modifier_returns_null_for_nonexistent_id() -> void:
	var stack := EvaluationModifierStack.new()

	var found := stack.get_modifier("does_not_exist")

	assert_object(found).is_null()


# =============================================================================
# EVALUATION TESTS - MULTIPLICATIVE MODIFIERS
# =============================================================================

func test_evaluate_with_no_modifiers_returns_neutral_result() -> void:
	var stack := EvaluationModifierStack.new()
	var ctx := EvaluationContext.new()

	var result := stack.evaluate(ctx)

	assert_float(result.final_multiplier).is_equal(1.0)
	assert_float(result.additive_total).is_equal(0.0)
	assert_array(result.applied_modifiers).is_empty()


func test_evaluate_applies_single_multiplicative_modifier() -> void:
	var stack := EvaluationModifierStack.new()
	var modifier := TestMultiplicativeModifier.new(1.25, "boost")
	stack.register(modifier)

	var ctx := EvaluationContext.new()
	ctx.position = "QB"

	var result := stack.evaluate(ctx)

	assert_float(result.final_multiplier).is_equal(1.25)
	assert_array(result.applied_modifiers).has_size(1)


func test_evaluate_multiplies_multiple_multiplicative_modifiers() -> void:
	var stack := EvaluationModifierStack.new()
	stack.register(TestMultiplicativeModifier.new(1.2, "mod1"))
	stack.register(TestMultiplicativeModifier.new(1.1, "mod2"))
	stack.register(TestMultiplicativeModifier.new(1.05, "mod3"))

	var ctx := EvaluationContext.new()
	ctx.position = "QB"

	var result := stack.evaluate(ctx)

	# 1.2 * 1.1 * 1.05 = 1.386
	assert_float(result.final_multiplier).is_equal_approx(1.386, 0.001)


func test_evaluate_skips_disabled_modifiers() -> void:
	var stack := EvaluationModifierStack.new()
	stack.register(TestMultiplicativeModifier.new(1.2, "enabled"))
	stack.register(TestMultiplicativeModifier.new(2.0, "disabled"))

	# Disable the second modifier via config
	stack.configure({"disabled": {"enabled": false}})

	var ctx := EvaluationContext.new()
	ctx.position = "QB"

	var result := stack.evaluate(ctx)

	# Only the first modifier should apply
	assert_float(result.final_multiplier).is_equal(1.2)
	assert_array(result.applied_modifiers).has_size(1)
	assert_array(result.skipped_modifiers).has_size(1)


func test_evaluate_skips_non_applicable_modifiers() -> void:
	var stack := EvaluationModifierStack.new()
	var modifier := ConditionalModifier.new("QB")  # Only applies to QB
	stack.register(modifier)

	var ctx := EvaluationContext.new()
	ctx.position = "RB"  # Not a QB

	var result := stack.evaluate(ctx)

	assert_float(result.final_multiplier).is_equal(1.0)
	assert_array(result.applied_modifiers).is_empty()
	assert_array(result.skipped_modifiers).has_size(1)
	assert_string(result.skipped_modifiers[0]["reason"]).is_equal("not_applicable")


# =============================================================================
# EVALUATION TESTS - ADDITIVE MODIFIERS
# =============================================================================

func test_evaluate_applies_single_additive_modifier() -> void:
	var stack := EvaluationModifierStack.new()
	var modifier := TestAdditiveModifier.new(5.0, "bonus")
	stack.register(modifier)

	var ctx := EvaluationContext.new()
	ctx.position = "QB"

	var result := stack.evaluate(ctx)

	assert_float(result.additive_total).is_equal(5.0)
	assert_float(result.final_multiplier).is_equal(1.0)  # No multiplicative effect


func test_evaluate_sums_multiple_additive_modifiers() -> void:
	var stack := EvaluationModifierStack.new()
	stack.register(TestAdditiveModifier.new(3.0, "bonus1"))
	stack.register(TestAdditiveModifier.new(2.5, "bonus2"))
	stack.register(TestAdditiveModifier.new(-1.0, "penalty"))

	var ctx := EvaluationContext.new()
	ctx.position = "QB"

	var result := stack.evaluate(ctx)

	# 3.0 + 2.5 - 1.0 = 4.5
	assert_float(result.additive_total).is_equal(4.5)


func test_evaluate_combines_additive_and_multiplicative_modifiers() -> void:
	var stack := EvaluationModifierStack.new()
	stack.register(TestAdditiveModifier.new(5.0, "additive"))
	stack.register(TestMultiplicativeModifier.new(1.2, "multiplicative"))

	var ctx := EvaluationContext.new()
	ctx.position = "QB"

	var result := stack.evaluate(ctx)

	assert_float(result.additive_total).is_equal(5.0)
	assert_float(result.final_multiplier).is_equal(1.2)

	# Final score calculation: (base + 5.0) * 1.2
	var base_rating := 70.0
	var final_score := result.calculate_final_score(base_rating)
	# (70 + 5) * 1.2 = 90.0
	assert_float(final_score).is_equal(90.0)


# =============================================================================
# BOUNDS AND CLAMPING TESTS
# =============================================================================

func test_evaluate_clamps_multiplicative_modifier_to_bounds() -> void:
	var stack := EvaluationModifierStack.new()
	# Modifier tries to apply 10.0x but bounds are 0.6-1.4
	stack.register(BoundedModifier.new(10.0))

	var ctx := EvaluationContext.new()
	ctx.position = "QB"

	var result := stack.evaluate(ctx)

	# Should be clamped to max bound of 1.4
	assert_float(result.final_multiplier).is_equal(1.4)


func test_evaluate_clamps_additive_modifier_to_bounds() -> void:
	var stack := EvaluationModifierStack.new()
	# Modifier tries to add 100 OVR but bounds are -5 to +5
	stack.register(BoundedAdditiveModifier.new(100.0))

	var ctx := EvaluationContext.new()
	ctx.position = "QB"

	var result := stack.evaluate(ctx)

	# Should be clamped to max bound of 5.0
	assert_float(result.additive_total).is_equal(5.0)


func test_evaluate_applies_cumulative_cap_to_multiplicative_total() -> void:
	var stack := EvaluationModifierStack.new()
	# Register many high multipliers that would exceed 4.0x total
	stack.register(TestMultiplicativeModifier.new(2.0, "m1"))
	stack.register(TestMultiplicativeModifier.new(2.0, "m2"))
	stack.register(TestMultiplicativeModifier.new(2.0, "m3"))

	var ctx := EvaluationContext.new()
	ctx.position = "QB"

	var result := stack.evaluate(ctx)

	# 2.0 * 2.0 * 2.0 = 8.0, but should be capped at 4.0
	assert_float(result.final_multiplier).is_less_equal(4.0)


func test_evaluate_caps_additive_total_to_prevent_extremes() -> void:
	var stack := EvaluationModifierStack.new()
	# Add extreme positive bonuses
	for i in range(10):
		stack.register(TestAdditiveModifier.new(10.0, "bonus_%d" % i))

	var ctx := EvaluationContext.new()
	ctx.position = "QB"

	var result := stack.evaluate(ctx)

	# Total would be 100, but should be capped at 25
	assert_float(result.additive_total).is_less_equal(25.0)


# =============================================================================
# RESULT UTILITY TESTS
# =============================================================================

func test_stack_result_calculate_final_score_applies_formula_correctly() -> void:
	var result := EvaluationModifierStack.StackResult.new()
	result.additive_total = 5.0
	result.final_multiplier = 1.2

	var base_rating := 70.0
	var final_score := result.calculate_final_score(base_rating)

	# (70 + 5) * 1.2 = 90.0
	assert_float(final_score).is_equal(90.0)


func test_stack_result_get_active_modifiers_filters_neutral_modifiers() -> void:
	var result := EvaluationModifierStack.StackResult.new()
	result.applied_modifiers = [
		{"id": "m1", "multiplier": 1.2, "modifier_type": "multiplicative"},  # Active
		{"id": "m2", "multiplier": 1.0, "modifier_type": "multiplicative"},  # Neutral
		{"id": "m3", "additive_bonus": 5.0, "modifier_type": "additive"},    # Active
		{"id": "m4", "additive_bonus": 0.0, "modifier_type": "additive"},    # Neutral
	]

	var active := result.get_active_modifiers()

	# Should only include m1 and m3
	assert_array(active).has_size(2)


func test_stack_result_get_summary_generates_readable_text() -> void:
	var result := EvaluationModifierStack.StackResult.new()
	result.additive_total = 5.0
	result.final_multiplier = 1.2
	result.applied_modifiers = [
		{
			"id": "additive_mod",
			"additive_bonus": 5.0,
			"modifier_type": "additive"
		},
		{
			"id": "mult_mod",
			"multiplier": 1.2,
			"modifier_type": "multiplicative"
		}
	]

	var summary := result.get_summary()

	assert_string(summary).is_not_empty()
	assert_string(summary).contains("additive_mod")
	assert_string(summary).contains("mult_mod")


# =============================================================================
# CONFIGURATION TESTS
# =============================================================================

func test_configure_sets_config_dictionary() -> void:
	var stack := EvaluationModifierStack.new()
	var config := {"mod1": {"enabled": false}}

	stack.configure(config)

	# Should respect config during evaluation
	stack.register(TestMultiplicativeModifier.new(2.0, "mod1"))
	var ctx := EvaluationContext.new()
	ctx.position = "QB"

	var result := stack.evaluate(ctx)
	assert_float(result.final_multiplier).is_equal(1.0)  # Disabled, no effect


func test_is_modifier_enabled_returns_true_by_default() -> void:
	var stack := EvaluationModifierStack.new()

	assert_bool(stack.is_modifier_enabled("any_modifier")).is_true()


func test_is_modifier_enabled_respects_config() -> void:
	var stack := EvaluationModifierStack.new()
	stack.configure({"disabled_mod": {"enabled": false}})

	assert_bool(stack.is_modifier_enabled("disabled_mod")).is_false()
	assert_bool(stack.is_modifier_enabled("enabled_mod")).is_true()


# =============================================================================
# TAG-BASED QUERIES
# =============================================================================

func test_get_modifiers_by_tag_filters_correctly() -> void:
	var stack := EvaluationModifierStack.new()
	stack.register(TaggedModifier.new(["offense", "scheme"]))
	stack.register(TaggedModifier.new(["defense", "scheme"]))
	stack.register(TaggedModifier.new(["offense", "coach"]))

	var offense_mods := stack.get_modifiers_by_tag("offense")
	var scheme_mods := stack.get_modifiers_by_tag("scheme")

	assert_array(offense_mods).has_size(2)
	assert_array(scheme_mods).has_size(2)


# =============================================================================
# FACTORY METHOD TESTS
# =============================================================================

func test_create_draft_stack_loads_standard_modifiers() -> void:
	var stack := EvaluationModifierStack.create_draft_stack()

	# Should have loaded multiple modifiers
	var modifiers := stack.get_modifiers()
	assert_array(modifiers).is_not_empty()


func test_create_free_agency_stack_loads_fa_modifiers() -> void:
	var stack := EvaluationModifierStack.create_free_agency_stack()

	var modifiers := stack.get_modifiers()
	assert_array(modifiers).is_not_empty()


func test_create_trade_stack_loads_trade_modifiers() -> void:
	var stack := EvaluationModifierStack.create_trade_stack()

	var modifiers := stack.get_modifiers()
	assert_array(modifiers).is_not_empty()


# =============================================================================
# TEST MODIFIER IMPLEMENTATIONS
# =============================================================================

class TestMultiplicativeModifier extends EvaluationModifier:
	var mult: float
	var id_name: String

	func _init(p_mult: float, p_id: String) -> void:
		mult = p_mult
		id_name = p_id

	func get_id() -> String:
		return id_name

	func is_applicable(_ctx: EvaluationContext) -> bool:
		return true

	func calculate(_ctx: EvaluationContext) -> ModifierResult:
		return ModifierResult.new(mult, "Test multiplier")


class TestAdditiveModifier extends EvaluationModifier:
	var bonus: float
	var id_name: String

	func _init(p_bonus: float, p_id: String) -> void:
		bonus = p_bonus
		id_name = p_id

	func get_id() -> String:
		return id_name

	func is_applicable(_ctx: EvaluationContext) -> bool:
		return true

	func calculate(_ctx: EvaluationContext) -> ModifierResult:
		return ModifierResult.create_additive(bonus, "Test additive")


class PriorityModifier extends EvaluationModifier:
	var priority: int

	func _init(p_priority: int) -> void:
		priority = p_priority

	func get_id() -> String:
		return "priority_%d" % priority

	func get_priority() -> int:
		return priority


class ConditionalModifier extends EvaluationModifier:
	var required_position: String

	func _init(p_position: String) -> void:
		required_position = p_position

	func get_id() -> String:
		return "conditional_%s" % required_position

	func is_applicable(ctx: EvaluationContext) -> bool:
		return ctx.position == required_position

	func calculate(_ctx: EvaluationContext) -> ModifierResult:
		return ModifierResult.new(1.5, "Conditional boost")


class BoundedModifier extends EvaluationModifier:
	var mult: float

	func _init(p_mult: float) -> void:
		mult = p_mult

	func get_id() -> String:
		return "bounded"

	func get_bounds() -> Dictionary:
		return {"min": 0.6, "max": 1.4}

	func calculate(_ctx: EvaluationContext) -> ModifierResult:
		return ModifierResult.new(mult, "Bounded multiplier")


class BoundedAdditiveModifier extends EvaluationModifier:
	var bonus: float

	func _init(p_bonus: float) -> void:
		bonus = p_bonus

	func get_id() -> String:
		return "bounded_additive"

	func get_bounds() -> Dictionary:
		return {"min": -5.0, "max": 5.0}

	func calculate(_ctx: EvaluationContext) -> ModifierResult:
		return ModifierResult.create_additive(bonus, "Bounded additive")


class TaggedModifier extends EvaluationModifier:
	var tags: Array

	func _init(p_tags: Array) -> void:
		tags = p_tags

	func get_id() -> String:
		return "_".join(tags)

	func get_tags() -> Array:
		return tags

	func calculate(_ctx: EvaluationContext) -> ModifierResult:
		return ModifierResult.new(1.0, "Tagged modifier")
