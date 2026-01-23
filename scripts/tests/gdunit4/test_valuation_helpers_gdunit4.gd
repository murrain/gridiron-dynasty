extends GdUnitTestSuite
class_name TestValuationHelpersGdUnit4

const ValuationHelpers = preload("res://scripts/core/valuation/ValuationHelpers.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

## Test valuation_range with positive base value
func test_valuation_range_positive_base() -> void:
	var result := ValuationHelpers.valuation_range(100.0, 0.15)

	assert_that(result).contains_key("min")
	assert_that(result).contains_key("max")
	assert_float(result["min"]).is_equal(85.0)  # 100 - 15
	assert_float(result["max"]).is_equal(115.0)  # 100 + 15

## Test valuation_range with zero base value
func test_valuation_range_zero_base() -> void:
	var result := ValuationHelpers.valuation_range(0.0, 0.15)

	assert_float(result["min"]).is_equal(0.0)
	assert_float(result["max"]).is_equal(0.0)

## Test valuation_range with negative base value
func test_valuation_range_negative_base() -> void:
	var result := ValuationHelpers.valuation_range(-100.0, 0.15)

	# Delta = abs(-100) * 0.15 = 15
	# lo = -100 - 15 = -115, hi = -100 + 15 = -85
	assert_float(result["min"]).is_equal(-115.0)
	assert_float(result["max"]).is_equal(-85.0)

## Test valuation_range with min_value constraint
func test_valuation_range_min_constraint() -> void:
	var result := ValuationHelpers.valuation_range(100.0, 0.20, 90.0)

	# Natural min would be 80, but constrained to 90
	assert_float(result["min"]).is_equal(90.0)
	assert_float(result["max"]).is_equal(120.0)

## Test valuation_range with max_value constraint
func test_valuation_range_max_constraint() -> void:
	var result := ValuationHelpers.valuation_range(100.0, 0.20, -INF, 110.0)

	# Natural max would be 120, but constrained to 110
	assert_float(result["min"]).is_equal(80.0)
	assert_float(result["max"]).is_equal(110.0)

## Test valuation_range with both constraints
func test_valuation_range_both_constraints() -> void:
	var result := ValuationHelpers.valuation_range(100.0, 0.20, 85.0, 115.0)

	assert_float(result["min"]).is_equal(85.0)
	assert_float(result["max"]).is_equal(115.0)

## Test valuation_range with inverted constraints (max < min)
func test_valuation_range_inverted_constraints() -> void:
	var result := ValuationHelpers.valuation_range(100.0, 0.10, 95.0, 85.0)

	# When hi < lo after constraints, they should be swapped
	assert_float(result["min"]).is_less_equal(result["max"])

## Test valuation_range with zero variance
func test_valuation_range_zero_variance() -> void:
	var result := ValuationHelpers.valuation_range(100.0, 0.0)

	assert_float(result["min"]).is_equal(100.0)
	assert_float(result["max"]).is_equal(100.0)

## Test valuation_range with large variance
func test_valuation_range_large_variance() -> void:
	var result := ValuationHelpers.valuation_range(100.0, 0.50)

	assert_float(result["min"]).is_equal(50.0)
	assert_float(result["max"]).is_equal(150.0)

## Test est_value produces value within range
func test_est_value_within_range() -> void:
	var eval_dict := {
		"base_value": 100.0,
		"variance_pct": 0.15,
		"min_value": -INF,
		"max_value": INF
	}

	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)
	var value := ValuationHelpers.est_value(eval_dict, rng)

	# Value should be between 85 and 115
	assert_float(value).is_greater_equal(85.0)
	assert_float(value).is_less_equal(115.0)

## Test est_value is deterministic with same seed
func test_est_value_deterministic() -> void:
	var eval_dict := {
		"base_value": 100.0,
		"variance_pct": 0.15
	}

	var rng1 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var value1 := ValuationHelpers.est_value(eval_dict, rng1)

	var rng2 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var value2 := ValuationHelpers.est_value(eval_dict, rng2)

	assert_float(value1).is_equal(value2)

## Test est_value with different seeds produces different values
func test_est_value_different_seeds() -> void:
	var eval_dict := {
		"base_value": 100.0,
		"variance_pct": 0.15
	}

	var rng1 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var value1 := ValuationHelpers.est_value(eval_dict, rng1)

	var rng2 := TestHelpersGdUnit4.create_seeded_rng(54321)
	var value2 := ValuationHelpers.est_value(eval_dict, rng2)

	# Different seeds should produce different values
	assert_float(value1).is_not_equal(value2)

## Test est_value with zero variance returns base_value
func test_est_value_zero_variance() -> void:
	var eval_dict := {
		"base_value": 100.0,
		"variance_pct": 0.0
	}

	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)
	var value := ValuationHelpers.est_value(eval_dict, rng)

	assert_float(value).is_equal(100.0)

## Test est_value respects min_value constraint
func test_est_value_min_constraint() -> void:
	var eval_dict := {
		"base_value": 50.0,
		"variance_pct": 0.50,  # Range would be 25-75
		"min_value": 40.0
	}

	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	# Run multiple times to check min constraint
	for i in range(10):
		rng.seed = 12345 + i
		var value := ValuationHelpers.est_value(eval_dict, rng)
		assert_float(value).is_greater_equal(40.0)

## Test est_value respects max_value constraint
func test_est_value_max_constraint() -> void:
	var eval_dict := {
		"base_value": 50.0,
		"variance_pct": 0.50,  # Range would be 25-75
		"max_value": 60.0
	}

	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	# Run multiple times to check max constraint
	for i in range(10):
		rng.seed = 12345 + i
		var value := ValuationHelpers.est_value(eval_dict, rng)
		assert_float(value).is_less_equal(60.0)

## Test est_value with missing fields uses defaults
func test_est_value_missing_fields() -> void:
	var eval_dict := {}

	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)
	var value := ValuationHelpers.est_value(eval_dict, rng)

	# Should use default base_value (0.0) and variance_pct (0.0)
	assert_float(value).is_equal(0.0)

## Test valuation_range is deterministic
func test_valuation_range_deterministic() -> void:
	var result1 := ValuationHelpers.valuation_range(100.0, 0.15)
	var result2 := ValuationHelpers.valuation_range(100.0, 0.15)
	var result3 := ValuationHelpers.valuation_range(100.0, 0.15)

	assert_that(result1).is_equal(result2)
	assert_that(result2).is_equal(result3)

## Test valuation_range with very small variance
func test_valuation_range_small_variance() -> void:
	var result := ValuationHelpers.valuation_range(1000.0, 0.001)

	assert_float(result["min"]).is_equal(999.0)
	assert_float(result["max"]).is_equal(1001.0)

## Test valuation_range with variance over 100%
func test_valuation_range_large_variance_over_100() -> void:
	var result := ValuationHelpers.valuation_range(100.0, 1.5)

	# 150% variance: min = -50, max = 250
	assert_float(result["min"]).is_equal(-50.0)
	assert_float(result["max"]).is_equal(250.0)

## Test est_value multiple samples stay within range
func test_est_value_multiple_samples() -> void:
	var eval_dict := {
		"base_value": 100.0,
		"variance_pct": 0.20
	}

	# Generate 100 samples and verify all are within range
	for i in range(100):
		var rng := TestHelpersGdUnit4.create_seeded_rng(1000 + i)
		var value := ValuationHelpers.est_value(eval_dict, rng)
		assert_float(value).is_greater_equal(80.0)
		assert_float(value).is_less_equal(120.0)
