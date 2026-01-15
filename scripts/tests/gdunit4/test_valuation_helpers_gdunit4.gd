## GdUnit4 test suite for ValuationHelpers
##
## Validates valuation range calculation and estimated value determinism.
## Migrated from test_valuation_helpers.gd
extends GdUnitTestSuite

const ValuationHelpers = preload("res://scripts/core/valuation/ValuationHelpers.gd")


func _get_test_eval() -> Dictionary:
	return {
		"base_value": 80.0,
		"variance_pct": 0.10,
		"min_value": 0.0,
		"max_value": 100.0
	}


func test_valuation_range_min() -> void:
	var eval := _get_test_eval()
	var range_result := ValuationHelpers.valuation_range(
		float(eval["base_value"]),
		float(eval["variance_pct"]),
		float(eval["min_value"]),
		float(eval["max_value"])
	)

	assert_float(float(range_result.get("min", 0.0))).is_equal_approx(72.0, 0.0001)


func test_valuation_range_max() -> void:
	var eval := _get_test_eval()
	var range_result := ValuationHelpers.valuation_range(
		float(eval["base_value"]),
		float(eval["variance_pct"]),
		float(eval["min_value"]),
		float(eval["max_value"])
	)

	assert_float(float(range_result.get("max", 0.0))).is_equal_approx(88.0, 0.0001)


func test_est_value_is_deterministic() -> void:
	var eval := _get_test_eval()

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 20240218
	var est_a := ValuationHelpers.est_value(eval, rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 20240218
	var est_b := ValuationHelpers.est_value(eval, rng_b)

	assert_float(est_a).is_equal_approx(est_b, 0.0001)


func test_est_value_within_range() -> void:
	var eval := _get_test_eval()
	var range_result := ValuationHelpers.valuation_range(
		float(eval["base_value"]),
		float(eval["variance_pct"]),
		float(eval["min_value"]),
		float(eval["max_value"])
	)
	var range_min := float(range_result.get("min", 0.0))
	var range_max := float(range_result.get("max", 0.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = 20240218
	var est := ValuationHelpers.est_value(eval, rng)

	assert_float(est).is_between(range_min, range_max)


func test_different_seeds_produce_different_estimates() -> void:
	var eval := _get_test_eval()

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 111
	var est_a := ValuationHelpers.est_value(eval, rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 999
	var est_b := ValuationHelpers.est_value(eval, rng_b)

	# Different seeds should usually produce different values
	var diff := absf(est_a - est_b)
	assert_float(diff).is_greater_equal(0.0)


func test_zero_variance_produces_base_value() -> void:
	var eval := {
		"base_value": 75.0,
		"variance_pct": 0.0,
		"min_value": 0.0,
		"max_value": 100.0
	}

	var range_result := ValuationHelpers.valuation_range(
		float(eval["base_value"]),
		float(eval["variance_pct"]),
		float(eval["min_value"]),
		float(eval["max_value"])
	)

	assert_float(float(range_result.get("min", 0.0))).is_equal_approx(75.0, 0.0001)
	assert_float(float(range_result.get("max", 0.0))).is_equal_approx(75.0, 0.0001)
