extends GdUnitTestSuite
class_name TestValueCurveGdUnit4

const ValueCurve = preload("res://scripts/core/valuation/ValueCurve.gd")

## Test exponential curve produces higher values for higher scores
func test_exponential_curve_ascending() -> void:
	var config := {
		"curve_type": "exponential",
		"base_value": 1.0,
		"exponent": 2.0,
		"elite_threshold": 95.0,
		"elite_multiplier_boost": 1.0
	}

	var value_60 := ValueCurve.score_to_market_value(60.0, config)
	var value_80 := ValueCurve.score_to_market_value(80.0, config)
	var value_95 := ValueCurve.score_to_market_value(95.0, config)

	assert_float(value_80).is_greater(value_60)
	assert_float(value_95).is_greater(value_80)

## Test exponential curve with elite threshold boost
func test_exponential_curve_elite_boost() -> void:
	var config := {
		"curve_type": "exponential",
		"base_value": 1.0,
		"exponent": 2.0,
		"elite_threshold": 90.0,
		"elite_multiplier_boost": 2.0
	}

	var value_89 := ValueCurve.score_to_market_value(89.0, config)
	var value_90 := ValueCurve.score_to_market_value(90.0, config)

	# Elite boost should approximately double the value
	assert_float(value_90).is_greater(value_89 * 1.5)

## Test linear curve for backward compatibility
func test_linear_curve() -> void:
	var config := {
		"curve_type": "linear",
		"base_value": 100.0,
		"per_point": 10.0
	}

	var value_50 := ValueCurve.score_to_market_value(50.0, config)
	var value_60 := ValueCurve.score_to_market_value(60.0, config)
	var value_70 := ValueCurve.score_to_market_value(70.0, config)

	# Linear: base + score * per_point
	assert_float(value_50).is_equal(100.0 + 50.0 * 10.0)
	assert_float(value_60).is_equal(100.0 + 60.0 * 10.0)
	assert_float(value_70).is_equal(100.0 + 70.0 * 10.0)

## Test tiered exponential curve
func test_tiered_exponential_curve() -> void:
	var config := {
		"curve_type": "tiered_exponential",
		"base_value": 1.0,
		"elite_threshold": 95.0,
		"elite_multiplier_boost": 1.0,
		"tiers": [
			{"min": 0, "max": 50, "multiplier": 0.5, "exponent": 1.0},
			{"min": 50, "max": 75, "multiplier": 1.0, "exponent": 1.5},
			{"min": 75, "max": 100, "multiplier": 2.0, "exponent": 2.0}
		]
	}

	var value_25 := ValueCurve.score_to_market_value(25.0, config)
	var value_62 := ValueCurve.score_to_market_value(62.0, config)
	var value_87 := ValueCurve.score_to_market_value(87.0, config)

	# Values should increase across tiers
	assert_float(value_62).is_greater(value_25)
	assert_float(value_87).is_greater(value_62)

## Test that zero score returns zero value
func test_zero_score_returns_zero() -> void:
	var config := {
		"curve_type": "exponential",
		"base_value": 1.0,
		"exponent": 2.0,
		"elite_threshold": 95.0,
		"elite_multiplier_boost": 1.0
	}

	var value := ValueCurve.score_to_market_value(0.0, config)
	assert_float(value).is_equal(0.0)

## Test curve is monotonically increasing
func test_curve_monotonically_increasing() -> void:
	var config := {
		"curve_type": "exponential",
		"base_value": 1.0,
		"exponent": 2.5,
		"elite_threshold": 92.0,
		"elite_multiplier_boost": 1.5
	}

	var previous_value := 0.0
	for score in range(0, 101, 5):
		var value := ValueCurve.score_to_market_value(float(score), config)
		assert_float(value).is_greater_equal(previous_value)
		previous_value = value

## Test unknown curve type falls back to linear
func test_unknown_curve_type_fallback() -> void:
	var config := {
		"curve_type": "unknown_type",
		"base_value": 100.0,
		"per_point": 5.0
	}

	var value := ValueCurve.score_to_market_value(50.0, config)
	# Should fall back to linear: 100 + 50 * 5 = 350
	assert_float(value).is_equal(350.0)

## Test get_expected_values convenience method
func test_get_expected_values() -> void:
	var config := {
		"curve_type": "exponential",
		"base_value": 1.0,
		"exponent": 2.0,
		"elite_threshold": 92.0,
		"elite_multiplier_boost": 1.0
	}

	var expected := ValueCurve.get_expected_values(config)

	assert_that(expected).contains_key("score_60")
	assert_that(expected).contains_key("score_75")
	assert_that(expected).contains_key("score_85")
	assert_that(expected).contains_key("score_92")
	assert_that(expected).contains_key("score_98")

	# Verify they're in ascending order
	assert_float(expected["score_75"]).is_greater(expected["score_60"])
	assert_float(expected["score_85"]).is_greater(expected["score_75"])
	assert_float(expected["score_92"]).is_greater(expected["score_85"])
	assert_float(expected["score_98"]).is_greater(expected["score_92"])

## Test tiered curve with realistic valuation config
func test_realistic_tiered_curve() -> void:
	var config := {
		"curve_type": "tiered_exponential",
		"base_value": 1.0,
		"elite_threshold": 92,
		"elite_multiplier_boost": 1.5,
		"tiers": [
			{"min": 0, "max": 60, "multiplier": 0.5, "exponent": 1.0},
			{"min": 60, "max": 75, "multiplier": 1.0, "exponent": 1.3},
			{"min": 75, "max": 85, "multiplier": 2.0, "exponent": 1.8},
			{"min": 85, "max": 92, "multiplier": 4.0, "exponent": 2.2},
			{"min": 92, "max": 100, "multiplier": 10.0, "exponent": 3.0}
		]
	}

	var value_50 := ValueCurve.score_to_market_value(50.0, config)
	var value_70 := ValueCurve.score_to_market_value(70.0, config)
	var value_80 := ValueCurve.score_to_market_value(80.0, config)
	var value_88 := ValueCurve.score_to_market_value(88.0, config)
	var value_95 := ValueCurve.score_to_market_value(95.0, config)

	# Verify exponential growth
	assert_float(value_70).is_greater(value_50 * 1.5)
	assert_float(value_80).is_greater(value_70 * 1.5)
	assert_float(value_88).is_greater(value_80 * 1.5)

	# Elite players (92+) should be worth significantly more
	assert_float(value_95).is_greater(value_88 * 2.0)

## Test edge case: score above 100 is clamped
func test_score_clamping() -> void:
	var config := {
		"curve_type": "exponential",
		"base_value": 1.0,
		"exponent": 2.0,
		"elite_threshold": 92.0,
		"elite_multiplier_boost": 1.0
	}

	var value_100 := ValueCurve.score_to_market_value(100.0, config)
	var value_150 := ValueCurve.score_to_market_value(150.0, config)

	# Score above 100 should be clamped to 100
	assert_float(value_150).is_equal(value_100)

## Test curve with different exponents
func test_different_exponents() -> void:
	var config_linear := {
		"curve_type": "exponential",
		"base_value": 1.0,
		"exponent": 1.0,  # Linear growth
		"elite_threshold": 100.0,
		"elite_multiplier_boost": 1.0
	}

	var config_quadratic := {
		"curve_type": "exponential",
		"base_value": 1.0,
		"exponent": 2.0,  # Quadratic growth
		"elite_threshold": 100.0,
		"elite_multiplier_boost": 1.0
	}

	var linear_80 := ValueCurve.score_to_market_value(80.0, config_linear)
	var quadratic_80 := ValueCurve.score_to_market_value(80.0, config_quadratic)

	# Quadratic should be higher at high scores
	assert_float(quadratic_80).is_greater(linear_80)

## Test that curve is deterministic
func test_curve_deterministic() -> void:
	var config := {
		"curve_type": "exponential",
		"base_value": 1.0,
		"exponent": 2.5,
		"elite_threshold": 92.0,
		"elite_multiplier_boost": 1.5
	}

	var value1 := ValueCurve.score_to_market_value(75.0, config)
	var value2 := ValueCurve.score_to_market_value(75.0, config)
	var value3 := ValueCurve.score_to_market_value(75.0, config)

	assert_float(value1).is_equal(value2)
	assert_float(value2).is_equal(value3)

## Test tiered curve with empty tiers falls back to exponential
func test_tiered_curve_empty_tiers_fallback() -> void:
	var config := {
		"curve_type": "tiered_exponential",
		"base_value": 1.0,
		"exponent": 2.0,
		"elite_threshold": 92.0,
		"elite_multiplier_boost": 1.0,
		"tiers": []
	}

	var value := ValueCurve.score_to_market_value(75.0, config)
	# Should fall back to exponential and return a positive value
	assert_float(value).is_greater(0.0)
