extends GdUnitTestSuite
class_name TestEvaluationModifierGdUnit4

## Tests for EvaluationModifier base class and ModifierResult
##
## Validates:
## - ModifierResult creation and properties
## - Base modifier interface contract
## - Modifier metadata (ID, name, description, priority)
## - Bounds validation
## - Applicability checks

const EvaluationModifier = preload("res://scripts/core/evaluation/EvaluationModifier.gd")
const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# =============================================================================
# MODIFIER RESULT TESTS
# =============================================================================

func test_modifier_result_initializes_with_defaults() -> void:
	var result := EvaluationModifier.ModifierResult.new()

	assert_float(result.multiplier).is_equal(1.0)
	assert_string(result.reason).is_empty()
	assert_that(result.details).is_equal({})


func test_modifier_result_initializes_with_values() -> void:
	var details := {"key": "value", "number": 42}
	var result := EvaluationModifier.ModifierResult.new(1.25, "Test reason", details)

	assert_float(result.multiplier).is_equal(1.25)
	assert_string(result.reason).is_equal("Test reason")
	assert_that(result.details).is_equal(details)


func test_modifier_result_is_neutral_detects_neutral_multiplier() -> void:
	var test_cases := [
		{"mult": 1.0, "is_neutral": true},
		{"mult": 1.0005, "is_neutral": true},  # Within tolerance
		{"mult": 0.9995, "is_neutral": true},  # Within tolerance
		{"mult": 1.1, "is_neutral": false},
		{"mult": 0.9, "is_neutral": false},
		{"mult": 1.5, "is_neutral": false},
	]

	for case in test_cases:
		var result := EvaluationModifier.ModifierResult.new(case["mult"])
		assert_bool(result.is_neutral()).override_failure_message(
			"Multiplier %.4f neutral check should be %s" % [case["mult"], case["is_neutral"]]
		).is_equal(case["is_neutral"])


# =============================================================================
# BASE MODIFIER INTERFACE TESTS
# =============================================================================

func test_base_modifier_has_default_id() -> void:
	var modifier := EvaluationModifier.new()
	assert_string(modifier.get_id()).is_equal("base_modifier")


func test_base_modifier_has_display_name() -> void:
	var modifier := EvaluationModifier.new()
	assert_string(modifier.get_display_name()).is_not_empty()


func test_base_modifier_has_description() -> void:
	var modifier := EvaluationModifier.new()
	assert_string(modifier.get_description()).is_not_empty()


func test_base_modifier_has_priority() -> void:
	var modifier := EvaluationModifier.new()
	assert_int(modifier.get_priority()).is_equal(100)


func test_base_modifier_returns_empty_tags() -> void:
	var modifier := EvaluationModifier.new()
	assert_array(modifier.get_tags()).is_empty()


func test_base_modifier_has_bounds() -> void:
	var modifier := EvaluationModifier.new()
	var bounds := modifier.get_bounds()

	assert_that(bounds).has("min")
	assert_that(bounds).has("max")
	assert_float(bounds["min"]).is_equal(0.6)
	assert_float(bounds["max"]).is_equal(1.4)


func test_base_modifier_is_applicable_by_default() -> void:
	var modifier := EvaluationModifier.new()
	var ctx := EvaluationContext.new()

	assert_bool(modifier.is_applicable(ctx)).is_true()


func test_base_modifier_calculate_returns_neutral_result() -> void:
	var modifier := EvaluationModifier.new()
	var ctx := EvaluationContext.new()

	var result := modifier.calculate(ctx)

	assert_object(result).is_not_null()
	assert_float(result.multiplier).is_equal(1.0)
	assert_bool(result.is_neutral()).is_true()


func test_base_modifier_is_configurable() -> void:
	var modifier := EvaluationModifier.new()
	assert_bool(modifier.is_configurable()).is_true()


func test_base_modifier_has_config_schema() -> void:
	var modifier := EvaluationModifier.new()
	var schema := modifier.get_config_schema()

	assert_that(schema).is_not_null()
	assert_that(schema).has("enabled")


# =============================================================================
# CUSTOM MODIFIER TESTS (Test modifier implementation patterns)
# =============================================================================

func test_custom_modifier_can_override_id() -> void:
	var modifier := TestModifier.new()
	assert_string(modifier.get_id()).is_equal("test_modifier")


func test_custom_modifier_can_override_priority() -> void:
	var modifier := TestModifier.new()
	assert_int(modifier.get_priority()).is_equal(50)


func test_custom_modifier_can_set_tags() -> void:
	var modifier := TestModifier.new()
	var tags := modifier.get_tags()

	assert_array(tags).is_not_empty()
	assert_array(tags).contains(["test", "custom"])


func test_custom_modifier_can_implement_applicability() -> void:
	var modifier := TestModifier.new()

	# Should be applicable when position is QB
	var qb_player := TestHelpersGdUnit4.create_test_player("P001", "QB")
	var ctx_qb := EvaluationContext.new()
	ctx_qb.player = qb_player
	ctx_qb.position = "QB"
	assert_bool(modifier.is_applicable(ctx_qb)).is_true()

	# Should not be applicable for other positions
	var rb_player := TestHelpersGdUnit4.create_test_player("P002", "RB")
	var ctx_rb := EvaluationContext.new()
	ctx_rb.player = rb_player
	ctx_rb.position = "RB"
	assert_bool(modifier.is_applicable(ctx_rb)).is_false()


func test_custom_modifier_can_implement_calculate() -> void:
	var modifier := TestModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 85.0)
	var ctx := EvaluationContext.new()
	ctx.player = player
	ctx.position = "QB"
	ctx.base_rating = 85.0

	var result := modifier.calculate(ctx)

	assert_object(result).is_not_null()
	assert_float(result.multiplier).is_greater(1.0)
	assert_string(result.reason).is_not_empty()


func test_custom_modifier_can_set_custom_bounds() -> void:
	var modifier := TestModifier.new()
	var bounds := modifier.get_bounds()

	assert_float(bounds["min"]).is_equal(0.8)
	assert_float(bounds["max"]).is_equal(1.2)


# =============================================================================
# MODIFIER RESULT EDGE CASES
# =============================================================================

func test_modifier_result_handles_negative_multipliers() -> void:
	# Negative multipliers are technically invalid but should be representable
	var result := EvaluationModifier.ModifierResult.new(-0.5, "Penalty")

	assert_float(result.multiplier).is_equal(-0.5)
	assert_bool(result.is_neutral()).is_false()


func test_modifier_result_handles_zero_multiplier() -> void:
	# Zero multiplier represents complete blocking
	var result := EvaluationModifier.ModifierResult.new(0.0, "Blocked")

	assert_float(result.multiplier).is_equal(0.0)
	assert_bool(result.is_neutral()).is_false()


func test_modifier_result_handles_large_multipliers() -> void:
	var result := EvaluationModifier.ModifierResult.new(5.0, "Huge boost")

	assert_float(result.multiplier).is_equal(5.0)
	assert_bool(result.is_neutral()).is_false()


func test_modifier_result_details_can_store_complex_data() -> void:
	var details := {
		"number": 42,
		"float": 3.14,
		"string": "test",
		"array": [1, 2, 3],
		"nested": {"a": 1, "b": 2}
	}
	var result := EvaluationModifier.ModifierResult.new(1.0, "Test", details)

	assert_that(result.details).is_equal(details)
	assert_int(result.details["number"]).is_equal(42)
	assert_array(result.details["array"]).contains([1, 2, 3])
	assert_that(result.details["nested"]).is_equal({"a": 1, "b": 2})


# =============================================================================
# TEST MODIFIER IMPLEMENTATION (Used for testing custom modifier patterns)
# =============================================================================

class TestModifier extends EvaluationModifier:
	func get_id() -> String:
		return "test_modifier"

	func get_display_name() -> String:
		return "Test Modifier"

	func get_description() -> String:
		return "A test modifier for unit testing"

	func get_priority() -> int:
		return 50

	func get_tags() -> Array:
		return ["test", "custom"]

	func get_bounds() -> Dictionary:
		return {"min": 0.8, "max": 1.2}

	func is_applicable(ctx: EvaluationContext) -> bool:
		# Only applicable to QB
		return ctx.position == "QB"

	func calculate(ctx: EvaluationContext) -> ModifierResult:
		# Simple boost for high-rated QBs
		var rating := ctx.base_rating
		var multiplier := 1.0
		if rating >= 80.0:
			multiplier = 1.1
		return ModifierResult.new(multiplier, "QB boost", {"rating": rating})
