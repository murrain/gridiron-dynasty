## GdUnit4 test suite for ValueCurve
##
## Tests exponential curves, tiered exponential, linear fallback,
## elite thresholds, tier boundaries, and determinism.
extends GdUnitTestSuite

const ValueCurve = preload("res://scripts/core/valuation/ValueCurve.gd")


func test_exponential_curve_growth() -> void:
	var config := {
		"curve_type": "exponential",
		"base_value": 1.0,
		"exponent": 2.5
	}

	var value_50 := ValueCurve.score_to_market_value(50.0, config)
	var value_75 := ValueCurve.score_to_market_value(75.0, config)
	var value_90 := ValueCurve.score_to_market_value(90.0, config)
	var value_100 := ValueCurve.score_to_market_value(100.0, config)

	# Values should increase non-linearly
	assert_float(value_75).is_greater(value_50 * 1.5)
	assert_float(value_90).is_greater(value_75 * 1.5)
	assert_float(value_100).is_greater(value_90)

	# Verify the maximum value at score 100
	assert_float(value_100).is_equal_approx(100.0, 0.0001)


func test_exponential_elite_threshold() -> void:
	var config := {
		"curve_type": "exponential",
		"base_value": 1.0,
		"exponent": 2.5,
		"elite_threshold": 92.0,
		"elite_multiplier_boost": 1.5
	}

	var value_91 := ValueCurve.score_to_market_value(91.0, config)
	var value_92 := ValueCurve.score_to_market_value(92.0, config)

	# Calculate what 92 would be without elite boost
	var config_no_boost := config.duplicate()
	config_no_boost["elite_multiplier_boost"] = 1.0
	var value_92_no_boost := ValueCurve.score_to_market_value(92.0, config_no_boost)

	# Score at 92 should have elite boost applied
	assert_float(value_92).is_equal_approx(value_92_no_boost * 1.5, 0.0001)

	# Score at 91 should NOT have elite boost
	var value_91_expected := ValueCurve.score_to_market_value(91.0, config_no_boost)
	assert_float(value_91).is_equal_approx(value_91_expected, 0.0001)


func test_tiered_exponential_growth() -> void:
	var config := {
		"curve_type": "tiered_exponential",
		"base_value": 1.0,
		"tiers": [
			{"min": 0, "max": 60, "multiplier": 0.5, "exponent": 1.0},
			{"min": 60, "max": 75, "multiplier": 1.0, "exponent": 1.3},
			{"min": 75, "max": 85, "multiplier": 2.0, "exponent": 1.8},
			{"min": 85, "max": 92, "multiplier": 4.0, "exponent": 2.2},
			{"min": 92, "max": 100, "multiplier": 10.0, "exponent": 3.0}
		],
		"elite_threshold": 92,
		"elite_multiplier_boost": 1.0  # No boost for this test
	}

	var value_30 := ValueCurve.score_to_market_value(30.0, config)
	var value_60 := ValueCurve.score_to_market_value(60.0, config)
	var value_75 := ValueCurve.score_to_market_value(75.0, config)
	var value_85 := ValueCurve.score_to_market_value(85.0, config)
	var value_92 := ValueCurve.score_to_market_value(92.0, config)
	var value_98 := ValueCurve.score_to_market_value(98.0, config)

	# Each tier should produce higher values
	assert_float(value_60).is_greater(value_30)
	assert_float(value_75).is_greater(value_60)
	assert_float(value_85).is_greater(value_75)
	assert_float(value_92).is_greater(value_85)
	assert_float(value_98).is_greater(value_92)

	# Higher tiers should have higher per-point value increase
	var increase_60_75: float = (value_75 - value_60) / 15.0  # 15 point range
	var increase_85_92: float = (value_92 - value_85) / 7.0   # 7 point range
	assert_float(increase_85_92).is_greater(increase_60_75)


func test_tiered_exponential_elite_boost() -> void:
	var config := {
		"curve_type": "tiered_exponential",
		"base_value": 1.0,
		"tiers": [
			{"min": 0, "max": 60, "multiplier": 0.5, "exponent": 1.0},
			{"min": 60, "max": 75, "multiplier": 1.0, "exponent": 1.3},
			{"min": 75, "max": 85, "multiplier": 2.0, "exponent": 1.8},
			{"min": 85, "max": 92, "multiplier": 4.0, "exponent": 2.2},
			{"min": 92, "max": 100, "multiplier": 10.0, "exponent": 3.0}
		],
		"elite_threshold": 92,
		"elite_multiplier_boost": 1.5
	}

	var value_91 := ValueCurve.score_to_market_value(91.0, config)
	var value_92 := ValueCurve.score_to_market_value(92.0, config)

	# Calculate what 92 would be without elite boost
	var config_no_boost := config.duplicate(true)
	config_no_boost["elite_multiplier_boost"] = 1.0
	var value_92_no_boost := ValueCurve.score_to_market_value(92.0, config_no_boost)

	# Elite boost should apply at threshold
	assert_float(value_92).is_equal_approx(value_92_no_boost * 1.5, 0.001)


func test_tier_boundary_continuity() -> void:
	var config := {
		"curve_type": "tiered_exponential",
		"base_value": 1.0,
		"tiers": [
			{"min": 0, "max": 60, "multiplier": 0.5, "exponent": 1.0},
			{"min": 60, "max": 75, "multiplier": 1.0, "exponent": 1.3},
			{"min": 75, "max": 85, "multiplier": 2.0, "exponent": 1.8},
			{"min": 85, "max": 92, "multiplier": 4.0, "exponent": 2.2},
			{"min": 92, "max": 100, "multiplier": 10.0, "exponent": 3.0}
		],
		"elite_threshold": 100,  # Disable elite boost for this test
		"elite_multiplier_boost": 1.0
	}

	# Test boundary at 60: value just below should be close to value at boundary
	var value_59_99 := ValueCurve.score_to_market_value(59.99, config)
	var value_60_00 := ValueCurve.score_to_market_value(60.0, config)
	var value_60_01 := ValueCurve.score_to_market_value(60.01, config)

	# Values should increase monotonically (no sudden drops)
	assert_float(value_60_00).is_greater_equal(value_59_99)
	assert_float(value_60_01).is_greater_equal(value_60_00)

	# Test boundary at 75
	var value_74_99 := ValueCurve.score_to_market_value(74.99, config)
	var value_75_00 := ValueCurve.score_to_market_value(75.0, config)
	var value_75_01 := ValueCurve.score_to_market_value(75.01, config)

	assert_float(value_75_00).is_greater_equal(value_74_99)
	assert_float(value_75_01).is_greater_equal(value_75_00)

	# Test boundary at 85
	var value_84_99 := ValueCurve.score_to_market_value(84.99, config)
	var value_85_00 := ValueCurve.score_to_market_value(85.0, config)
	var value_85_01 := ValueCurve.score_to_market_value(85.01, config)

	assert_float(value_85_00).is_greater_equal(value_84_99)
	assert_float(value_85_01).is_greater_equal(value_85_00)

	# Test boundary at 92
	var value_91_99 := ValueCurve.score_to_market_value(91.99, config)
	var value_92_00 := ValueCurve.score_to_market_value(92.0, config)
	var value_92_01 := ValueCurve.score_to_market_value(92.01, config)

	assert_float(value_92_00).is_greater_equal(value_91_99)
	assert_float(value_92_01).is_greater_equal(value_92_00)


func test_linear_fallback() -> void:
	var config := {
		"curve_type": "linear",
		"base_value": 10.0,
		"per_point": 2.0
	}

	var value_0 := ValueCurve.score_to_market_value(0.0, config)
	var value_50 := ValueCurve.score_to_market_value(50.0, config)
	var value_100 := ValueCurve.score_to_market_value(100.0, config)

	# Linear: value = base + score * per_point
	assert_float(value_0).is_equal_approx(10.0, 0.0001)
	assert_float(value_50).is_equal_approx(110.0, 0.0001)
	assert_float(value_100).is_equal_approx(210.0, 0.0001)


func test_determinism() -> void:
	var config := {
		"curve_type": "tiered_exponential",
		"base_value": 1.0,
		"tiers": [
			{"min": 0, "max": 60, "multiplier": 0.5, "exponent": 1.0},
			{"min": 60, "max": 75, "multiplier": 1.0, "exponent": 1.3},
			{"min": 75, "max": 85, "multiplier": 2.0, "exponent": 1.8},
			{"min": 85, "max": 92, "multiplier": 4.0, "exponent": 2.2},
			{"min": 92, "max": 100, "multiplier": 10.0, "exponent": 3.0}
		],
		"elite_threshold": 92,
		"elite_multiplier_boost": 1.5
	}

	# Run the same calculation multiple times
	var results: Array = []
	for i in range(5):
		results.append(ValueCurve.score_to_market_value(87.5, config))

	# All results should be identical
	for i in range(1, results.size()):
		assert_float(float(results[i])).is_equal_approx(float(results[0]), 0.0001)


func test_score_boundaries() -> void:
	var config := {
		"curve_type": "exponential",
		"base_value": 1.0,
		"exponent": 2.5
	}

	var value_0 := ValueCurve.score_to_market_value(0.0, config)
	var value_100 := ValueCurve.score_to_market_value(100.0, config)
	var value_negative := ValueCurve.score_to_market_value(-10.0, config)
	var value_over := ValueCurve.score_to_market_value(110.0, config)

	# Score 0 should produce 0 value (0^exponent = 0)
	assert_float(value_0).is_equal_approx(0.0, 0.0001)

	# Score 100 should produce base * 100 (1^exponent * 100)
	assert_float(value_100).is_equal_approx(100.0, 0.0001)

	# Negative scores should clamp to 0
	assert_float(value_negative).is_equal_approx(0.0, 0.0001)

	# Scores over 100 should clamp to 100
	assert_float(value_over).is_equal_approx(value_100, 0.0001)


func test_elite_players_worth_more() -> void:
	var config := {
		"curve_type": "tiered_exponential",
		"base_value": 1.0,
		"tiers": [
			{"min": 0, "max": 60, "multiplier": 0.5, "exponent": 1.0},
			{"min": 60, "max": 75, "multiplier": 1.0, "exponent": 1.3},
			{"min": 75, "max": 85, "multiplier": 2.0, "exponent": 1.8},
			{"min": 85, "max": 92, "multiplier": 4.0, "exponent": 2.2},
			{"min": 92, "max": 100, "multiplier": 10.0, "exponent": 3.0}
		],
		"elite_threshold": 92,
		"elite_multiplier_boost": 1.5
	}

	# Mid-tier player (score 75)
	var value_mid := ValueCurve.score_to_market_value(75.0, config)

	# Elite player (score 98)
	var value_elite := ValueCurve.score_to_market_value(98.0, config)

	# Elite should be at least 5x mid-tier (per acceptance criteria)
	var ratio: float = value_elite / maxf(value_mid, 0.001)
	assert_float(ratio).is_greater_equal(5.0)
