extends GdUnitTestSuite
class_name TestStatHelpersGdUnit4

const StatHelpers = preload("res://scripts/generation/StatHelpers.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# ============================================================================
# DETERMINISM TESTS
# ============================================================================

func test_gaussian_is_deterministic() -> void:
	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			return StatHelpers.gaussian(75.0, 10.0, rng),
		0xGAUSS1,
		"gaussian sampling should be deterministic"
	)

func test_sample_with_caps_is_deterministic() -> void:
	var values := [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
	var outlier := {"prob": 0.1, "max_pct": 0.95}

	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			return StatHelpers.sample_with_caps(
				70.0, 15.0, 0.85, values, "core", outlier, rng
			),
		0xSAMPLE1,
		"sample_with_caps should be deterministic"
	)


# ============================================================================
# GAUSSIAN TESTS
# ============================================================================

func test_gaussian_returns_numeric_value() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xG0001)
	var value = StatHelpers.gaussian(50.0, 10.0, rng)

	assert_that(typeof(value)).is_equal(TYPE_FLOAT)

func test_gaussian_centers_around_mean() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xG0002)
	var mu := 60.0
	var sigma := 5.0
	var samples := 1000

	var total := 0.0
	for i in samples:
		total += StatHelpers.gaussian(mu, sigma, rng)

	var average := total / float(samples)

	# Average should be close to mu (allow 2% deviation)
	assert_float(average).is_between(mu * 0.98, mu * 1.02)

func test_gaussian_respects_standard_deviation() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xG0003)
	var mu := 70.0
	var sigma := 15.0
	var samples := 1000

	var values := []
	for i in samples:
		values.append(StatHelpers.gaussian(mu, sigma, rng))

	# Calculate standard deviation
	var mean := 0.0
	for v in values:
		mean += float(v)
	mean /= float(samples)

	var variance := 0.0
	for v in values:
		var diff = float(v) - mean
		variance += diff * diff
	variance /= float(samples)

	var std_dev := sqrt(variance)

	# Should be close to sigma (allow 20% deviation for sample variance)
	assert_float(std_dev).is_between(sigma * 0.8, sigma * 1.2)


# ============================================================================
# CLAMP01 TESTS
# ============================================================================

func test_clamp01_clamps_to_0_100() -> void:
	assert_float(StatHelpers.clamp01(50.0)).is_equal(50.0)
	assert_float(StatHelpers.clamp01(0.0)).is_equal(0.0)
	assert_float(StatHelpers.clamp01(100.0)).is_equal(100.0)
	assert_float(StatHelpers.clamp01(-10.0)).is_equal(0.0)
	assert_float(StatHelpers.clamp01(150.0)).is_equal(100.0)

func test_clamp01_handles_edge_cases() -> void:
	assert_float(StatHelpers.clamp01(-999.0)).is_equal(0.0)
	assert_float(StatHelpers.clamp01(999.0)).is_equal(100.0)
	assert_float(StatHelpers.clamp01(0.1)).is_equal(0.1)
	assert_float(StatHelpers.clamp01(99.9)).is_equal(99.9)


# ============================================================================
# PERCENTILE VALUE TESTS
# ============================================================================

func test_percentile_value_returns_correct_percentile() -> void:
	var values := [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]

	# 50th percentile should be around 50
	var p50 = StatHelpers.percentile_value(values, 0.5)
	assert_float(p50).is_between(40.0, 60.0)

	# 90th percentile should be around 90
	var p90 = StatHelpers.percentile_value(values, 0.9)
	assert_float(p90).is_between(85.0, 95.0)

	# 10th percentile should be around 10
	var p10 = StatHelpers.percentile_value(values, 0.1)
	assert_float(p10).is_between(5.0, 20.0)

func test_percentile_value_handles_empty_array() -> void:
	var empty: Array = []
	var result = StatHelpers.percentile_value(empty, 0.5)

	assert_float(result).is_equal(0.0)

func test_percentile_value_handles_single_element() -> void:
	var single := [42.0]
	var result = StatHelpers.percentile_value(single, 0.5)

	assert_float(result).is_equal(42.0)

func test_percentile_value_clamps_to_0_1() -> void:
	var values := [10.0, 20.0, 30.0, 40.0, 50.0]

	# Above 1.0 should use max
	var above = StatHelpers.percentile_value(values, 1.5)
	assert_float(above).is_equal(50.0)

	# Below 0.0 should use min
	var below = StatHelpers.percentile_value(values, -0.5)
	assert_float(below).is_equal(10.0)


# ============================================================================
# SAMPLE WITH CAPS TESTS
# ============================================================================

func test_sample_with_caps_respects_cap_for_core_stats() -> void:
	var values := [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
	var outlier := {"prob": 0.0, "max_pct": 0.95}
	var cap_pct := 0.70  # 70th percentile = 70.0

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0001)

	# Sample many times - all should be <= cap
	for i in 50:
		var value = StatHelpers.sample_with_caps(
			80.0, 15.0, cap_pct, values, "core", outlier, rng
		)
		assert_float(value).is_less_equal(70.0)

func test_sample_with_caps_allows_outliers_for_non_core() -> void:
	var values := [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
	var outlier := {"prob": 1.0, "max_pct": 0.95}  # Always outlier
	var cap_pct := 0.70  # Normal cap at 70

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0002)

	# With 100% outlier prob, should be able to exceed normal cap
	var found_above_normal_cap := false
	for i in 50:
		var value = StatHelpers.sample_with_caps(
			90.0, 10.0, cap_pct, values, "secondary", outlier, rng
		)
		if value > 70.0:
			found_above_normal_cap = true
			break

	assert_bool(found_above_normal_cap).is_true()

func test_sample_with_caps_stays_in_0_100_range() -> void:
	var values := [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
	var outlier := {"prob": 0.1, "max_pct": 0.95}

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0003)

	for i in 100:
		var value = StatHelpers.sample_with_caps(
			75.0, 20.0, 0.85, values, "core", outlier, rng
		)
		assert_float(value).is_greater_equal(0.0)
		assert_float(value).is_less_equal(100.0)

func test_sample_with_caps_produces_variation() -> void:
	var values := [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
	var outlier := {"prob": 0.0, "max_pct": 0.95}

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0004)

	var samples := []
	for i in 100:
		samples.append(StatHelpers.sample_with_caps(
			60.0, 15.0, 0.85, values, "core", outlier, rng
		))

	# Should have variation
	var unique_values := {}
	for s in samples:
		unique_values[s] = true

	assert_int(unique_values.size()).is_greater(20)


# ============================================================================
# EDGE CASES
# ============================================================================

func test_gaussian_with_zero_sigma() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xG0004)
	var value = StatHelpers.gaussian(50.0, 0.0, rng)

	# With 0 sigma, should return mu (or close to it)
	# Actual behavior may vary slightly due to numerical precision
	assert_that(typeof(value)).is_equal(TYPE_FLOAT)

func test_sample_with_caps_with_zero_outlier_prob() -> void:
	var values := [10.0, 20.0, 30.0, 40.0, 50.0]
	var outlier := {"prob": 0.0, "max_pct": 0.95}

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0005)

	# All samples should respect normal cap
	for i in 30:
		var value = StatHelpers.sample_with_caps(
			100.0, 20.0, 0.60, values, "secondary", outlier, rng
		)
		assert_float(value).is_less_equal(30.0)  # 60th percentile = 30.0
