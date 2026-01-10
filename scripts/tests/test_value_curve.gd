extends RefCounted

const ValueCurve = preload("res://scripts/core/valuation/ValueCurve.gd")


func run(t) -> void:
	_test_exponential_curve_growth(t)
	_test_exponential_elite_threshold(t)
	_test_tiered_exponential_growth(t)
	_test_tiered_exponential_elite_boost(t)
	_test_linear_fallback(t)
	_test_determinism(t)
	_test_score_boundaries(t)
	_test_elite_players_worth_more(t)


## Test that exponential curve shows non-linear growth
func _test_exponential_curve_growth(t) -> void:
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
	t.assert_true(value_75 > value_50 * 1.5, "75 score should be >1.5x the value of 50 score")
	t.assert_true(value_90 > value_75 * 1.5, "90 score should be >1.5x the value of 75 score")
	t.assert_true(value_100 > value_90, "100 score should exceed 90 score")

	# Verify the maximum value is 100 * base (at score 100 with exponent applied)
	t.assert_approx(value_100, 100.0, 0.0001, "Score 100 with exponent 2.5 produces expected value")


## Test elite threshold behavior in exponential curve
func _test_exponential_elite_threshold(t) -> void:
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
	t.assert_approx(value_92, value_92_no_boost * 1.5, 0.0001, "Elite boost applied at threshold")

	# Score at 91 should NOT have elite boost
	var value_91_expected := ValueCurve.score_to_market_value(91.0, config_no_boost)
	t.assert_approx(value_91, value_91_expected, 0.0001, "No elite boost below threshold")


## Test tiered exponential shows proper tier-based growth
func _test_tiered_exponential_growth(t) -> void:
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
	t.assert_true(value_60 > value_30, "Score 60 > Score 30")
	t.assert_true(value_75 > value_60, "Score 75 > Score 60")
	t.assert_true(value_85 > value_75, "Score 85 > Score 75")
	t.assert_true(value_92 > value_85, "Score 92 > Score 85")
	t.assert_true(value_98 > value_92, "Score 98 > Score 92")

	# Higher tiers should grow faster (non-linear)
	var growth_60_75: float = value_75 / maxf(value_60, 0.001)
	var growth_85_92: float = value_92 / maxf(value_85, 0.001)
	t.assert_true(growth_85_92 > growth_60_75, "Higher tiers grow faster than lower tiers")


## Test elite boost in tiered exponential
func _test_tiered_exponential_elite_boost(t) -> void:
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
	t.assert_approx(value_92, value_92_no_boost * 1.5, 0.001, "Elite boost applied in tiered exponential")


## Test linear fallback mode
func _test_linear_fallback(t) -> void:
	var config := {
		"curve_type": "linear",
		"base_value": 10.0,
		"per_point": 2.0
	}

	var value_0 := ValueCurve.score_to_market_value(0.0, config)
	var value_50 := ValueCurve.score_to_market_value(50.0, config)
	var value_100 := ValueCurve.score_to_market_value(100.0, config)

	# Linear: value = base + score * per_point
	t.assert_approx(value_0, 10.0, 0.0001, "Linear score 0 = base")
	t.assert_approx(value_50, 110.0, 0.0001, "Linear score 50 = base + 50*per_point")
	t.assert_approx(value_100, 210.0, 0.0001, "Linear score 100 = base + 100*per_point")


## Test that results are deterministic
func _test_determinism(t) -> void:
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
		t.assert_approx(results[i], results[0], 0.0001, "Deterministic result %d matches first" % i)


## Test boundary conditions (scores at 0 and 100)
func _test_score_boundaries(t) -> void:
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
	t.assert_approx(value_0, 0.0, 0.0001, "Score 0 produces 0 value")

	# Score 100 should produce base * 100 (1^exponent * 100)
	t.assert_approx(value_100, 100.0, 0.0001, "Score 100 produces max value")

	# Negative scores should clamp to 0
	t.assert_approx(value_negative, 0.0, 0.0001, "Negative scores clamp to 0")

	# Scores over 100 should clamp to 100
	t.assert_approx(value_over, value_100, 0.0001, "Scores over 100 clamp to 100")


## Test that elite players (top 5%) are worth significantly more than mid-tier
func _test_elite_players_worth_more(t) -> void:
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
	t.assert_true(ratio >= 5.0, "Elite player (98) should be worth at least 5x mid-tier (75), got %.2fx" % ratio)
