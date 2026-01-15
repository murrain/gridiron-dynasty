## GdUnit4 test suite for StatHelpers
##
## Validates statistical helper functions for player generation.
## Migrated from test_stathelpers.gd
extends GdUnitTestSuite

const StatHelpers = preload("res://scripts/generation/StatHelpers.gd")


func test_gaussian_is_deterministic() -> void:
	var rng1 = RandomNumberGenerator.new()
	rng1.seed = 7
	var rng2 = RandomNumberGenerator.new()
	rng2.seed = 7
	var g1 = StatHelpers.gaussian(0.0, 1.0, rng1)
	var g2 = StatHelpers.gaussian(0.0, 1.0, rng2)
	assert_float(g1).is_equal_approx(g2, 0.0001)


func test_clamp01_lower_bound() -> void:
	assert_float(StatHelpers.clamp01(-5.0)).is_equal(0.0)


func test_clamp01_upper_bound() -> void:
	assert_float(StatHelpers.clamp01(150.0)).is_equal(100.0)


func test_percentile_value_empty_returns_zero() -> void:
	assert_float(StatHelpers.percentile_value([], 0.5)).is_equal(0.0)


func test_percentile_value_picks_median() -> void:
	assert_float(StatHelpers.percentile_value([10, 20, 30], 0.5)).is_equal(20.0)


func test_sample_with_caps_respects_caps() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var values = [10.0, 20.0, 30.0, 40.0]
	var outlier = {"prob": 1.0, "max_pct": 1.0}
	var v = StatHelpers.sample_with_caps(50.0, 0.0, 0.5, values, "other", outlier, rng)
	assert_float(v).is_between(0.0, 40.0)


func test_sample_with_caps_core_uses_cap() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var values = [10.0, 20.0, 30.0, 40.0]
	var outlier = {"prob": 1.0, "max_pct": 1.0}
	var v = StatHelpers.sample_with_caps(50.0, 0.0, 0.25, values, "core", outlier, rng)
	assert_float(v).is_equal(20.0)
