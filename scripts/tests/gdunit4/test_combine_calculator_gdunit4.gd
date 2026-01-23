extends GdUnitTestSuite
class_name TestCombineCalculatorGdUnit4

## Tests for CombineCalculator - Combine performance calculations
##
## Validates:
## - Combine test computation from player stats
## - Multiple test types (time, power, reps, score, index)
## - Body adjustments (weight-based scaling)
## - Noise application with RNG
## - Bounds and precision enforcement
## - Determinism with fixed seeds

const CombineCalculator = preload("res://scripts/core/rating/CombineCalculator.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# =============================================================================
# BASIC COMPUTATION TESTS
# =============================================================================

func test_compute_all_returns_empty_dict_for_empty_tests() -> void:
	var player := TestHelpersGdUnit4.create_test_player()
	var combine_cfg := {}
	var tests_cfg := {"defaults": {}, "tests": {}}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var results := CombineCalculator.compute_all(player, combine_cfg, tests_cfg, rng)

	assert_that(results).is_equal({})


func test_compute_all_calculates_all_defined_tests() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 75.0)
	player["stats"] = {
		"speed": 80.0,
		"strength": 75.0,
		"acceleration": 78.0
	}
	player["physicals"] = {
		"height_in": 76,
		"weight_lb": 225
	}

	var tests_cfg := {
		"defaults": {
			"type": "time",
			"noise": {"dist": "none"},
			"bounds": {"min": 4.0, "max": 5.5},
			"precision": 2
		},
		"tests": {
			"forty_yard_dash": {
				"inputs": [
					{"src": "stat", "name": "speed", "weight": 0.7},
					{"src": "stat", "name": "acceleration", "weight": 0.3}
				],
				"map": {"mode": "lerp", "min": 5.5, "max": 4.3, "invert": true}
			},
			"bench_press": {
				"type": "reps",
				"inputs": [
					{"src": "stat", "name": "strength", "weight": 1.0}
				],
				"map": {"mode": "lerp", "min": 10.0, "max": 35.0},
				"bounds": {"min": 5, "max": 40},
				"integer": true
			}
		}
	}

	var combine_cfg := {}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var results := CombineCalculator.compute_all(player, combine_cfg, tests_cfg, rng)

	assert_that(results).has("forty_yard_dash")
	assert_that(results).has("bench_press")
	assert_float(results["forty_yard_dash"]).is_greater(0.0)
	assert_float(results["bench_press"]).is_greater(0.0)


# =============================================================================
# TEST TYPE TESTS (time, power, reps, score, index)
# =============================================================================

func test_time_test_produces_reasonable_values() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "RB", 21, 85.0)
	player["stats"]["speed"] = 90.0
	player["stats"]["acceleration"] = 88.0
	player["physicals"] = {"weight_lb": 210}

	var test_cfg := {
		"type": "time",
		"inputs": [
			{"src": "stat", "name": "speed", "weight": 0.7},
			{"src": "stat", "name": "acceleration", "weight": 0.3}
		],
		"map": {"mode": "lerp", "min": 5.0, "max": 4.2, "invert": true},
		"noise": {"dist": "none"},
		"bounds": {"min": 4.0, "max": 5.5},
		"precision": 2
	}

	var defaults := {}
	var combine_cfg := {}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng)

	# High speed should produce fast time (closer to 4.2)
	assert_float(result).is_greater_equal(4.0)
	assert_float(result).is_less_equal(5.0)


func test_power_test_produces_reasonable_values() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "DL", 21, 80.0)
	player["stats"]["strength"] = 85.0
	player["physicals"] = {"weight_lb": 300}

	var test_cfg := {
		"type": "power",
		"inputs": [
			{"src": "stat", "name": "strength", "weight": 1.0}
		],
		"map": {"mode": "lerp", "min": 20.0, "max": 40.0},
		"noise": {"dist": "none"},
		"bounds": {"min": 15, "max": 45},
		"precision": 1
	}

	var defaults := {}
	var combine_cfg := {}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng)

	# High strength should produce high vertical
	assert_float(result).is_greater_equal(20.0)
	assert_float(result).is_less_equal(40.0)


func test_reps_test_produces_integer_values() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "OL", 21, 80.0)
	player["stats"]["strength"] = 88.0
	player["physicals"] = {"weight_lb": 310}

	var test_cfg := {
		"type": "reps",
		"inputs": [
			{"src": "stat", "name": "strength", "weight": 1.0}
		],
		"map": {"mode": "lerp", "min": 15.0, "max": 35.0},
		"noise": {"dist": "none"},
		"bounds": {"min": 10, "max": 40},
		"integer": true
	}

	var defaults := {}
	var combine_cfg := {}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng)

	# Should be an integer
	assert_float(result).is_equal(float(int(result)))
	assert_float(result).is_greater_equal(10.0)
	assert_float(result).is_less_equal(40.0)


# =============================================================================
# BODY ADJUSTMENT TESTS
# =============================================================================

func test_heavier_players_have_slower_times() -> void:
	var light_player := TestHelpersGdUnit4.create_test_player("P001", "WR", 21, 80.0)
	light_player["stats"]["speed"] = 85.0
	light_player["physicals"] = {"weight_lb": 185}

	var heavy_player := TestHelpersGdUnit4.create_test_player("P002", "TE", 21, 80.0)
	heavy_player["stats"]["speed"] = 85.0  # Same speed
	heavy_player["physicals"] = {"weight_lb": 250}

	var test_cfg := {
		"type": "time",
		"inputs": [
			{"src": "stat", "name": "speed", "weight": 1.0}
		],
		"map": {"mode": "lerp", "min": 5.0, "max": 4.3, "invert": true},
		"noise": {"dist": "none"},
		"body_adjust": {
			"mode": "time_mass",
			"anchor_wt": 200.0,
			"coef_per_10lb": 0.02
		},
		"bounds": {"min": 4.0, "max": 5.5},
		"precision": 2
	}

	var defaults := {}
	var combine_cfg := {}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var light_result := CombineCalculator._compute_single(light_player, test_cfg, defaults, combine_cfg, rng)
	var heavy_result := CombineCalculator._compute_single(heavy_player, test_cfg, defaults, combine_cfg, rng)

	# Heavier player should have slower time (higher value)
	assert_float(heavy_result).is_greater(light_result)


func test_lighter_players_have_advantage_in_power_tests() -> void:
	var light_player := TestHelpersGdUnit4.create_test_player("P001", "CB", 21, 80.0)
	light_player["stats"]["strength"] = 70.0
	light_player["physicals"] = {"weight_lb": 180}

	var heavy_player := TestHelpersGdUnit4.create_test_player("P002", "DL", 21, 80.0)
	heavy_player["stats"]["strength"] = 70.0  # Same strength
	heavy_player["physicals"] = {"weight_lb": 290}

	var test_cfg := {
		"type": "power",
		"inputs": [
			{"src": "stat", "name": "strength", "weight": 1.0}
		],
		"map": {"mode": "lerp", "min": 20.0, "max": 40.0},
		"noise": {"dist": "none"},
		"body_adjust": {
			"mode": "power_mass_asym",
			"anchor_wt": 225.0,
			"coef_per_10lb": -0.5,
			"under_mult": 2.0
		},
		"bounds": {"min": 15, "max": 45},
		"precision": 1
	}

	var defaults := {}
	var combine_cfg := {}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var light_result := CombineCalculator._compute_single(light_player, test_cfg, defaults, combine_cfg, rng)
	var heavy_result := CombineCalculator._compute_single(heavy_player, test_cfg, defaults, combine_cfg, rng)

	# Lighter player should have advantage in vertical jump (higher value)
	assert_float(light_result).is_greater_equal(heavy_result - 1.0)


# =============================================================================
# NOISE APPLICATION TESTS (RNG)
# =============================================================================

func test_gaussian_noise_with_rng_produces_variation() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "RB", 21, 80.0)
	player["stats"]["speed"] = 85.0
	player["physicals"] = {"weight_lb": 210}

	var test_cfg := {
		"type": "time",
		"inputs": [
			{"src": "stat", "name": "speed", "weight": 1.0}
		],
		"map": {"mode": "lerp", "min": 5.0, "max": 4.3, "invert": true},
		"noise": {"dist": "gauss", "sigma": 0.05},
		"bounds": {"min": 4.0, "max": 5.5},
		"precision": 2
	}

	var defaults := {}
	var combine_cfg := {}

	# Run with different RNG seeds
	var rng1 := TestHelpersGdUnit4.create_seeded_rng(11111)
	var result1 := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng1)

	var rng2 := TestHelpersGdUnit4.create_seeded_rng(22222)
	var result2 := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng2)

	# Different seeds should produce different results (with noise)
	assert_float(result1).is_not_equal(result2)


func test_no_noise_produces_deterministic_result() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "RB", 21, 80.0)
	player["stats"]["speed"] = 85.0
	player["physicals"] = {"weight_lb": 210}

	var test_cfg := {
		"type": "time",
		"inputs": [
			{"src": "stat", "name": "speed", "weight": 1.0}
		],
		"map": {"mode": "lerp", "min": 5.0, "max": 4.3, "invert": true},
		"noise": {"dist": "none"},
		"bounds": {"min": 4.0, "max": 5.5},
		"precision": 2
	}

	var defaults := {}
	var combine_cfg := {}

	# Run with different RNG seeds - should produce same result (no noise)
	var rng1 := TestHelpersGdUnit4.create_seeded_rng(11111)
	var result1 := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng1)

	var rng2 := TestHelpersGdUnit4.create_seeded_rng(22222)
	var result2 := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng2)

	# Same player without noise should produce identical results
	assert_float(result1).is_equal(result2)


# =============================================================================
# DETERMINISM TESTS
# =============================================================================

func test_same_seed_produces_identical_results() -> void:
	TestHelpersGdUnit4.assert_deterministic(self, func(rng: RandomNumberGenerator):
		var player := TestHelpersGdUnit4.create_test_player("P001", "RB", 21, 80.0)
		player["stats"]["speed"] = 85.0
		player["stats"]["acceleration"] = 82.0
		player["physicals"] = {"weight_lb": 210}

		var tests_cfg := {
			"defaults": {
				"type": "time",
				"noise": {"dist": "gauss", "sigma": 0.03},
				"precision": 2
			},
			"tests": {
				"forty": {
					"inputs": [
						{"src": "stat", "name": "speed", "weight": 0.7},
						{"src": "stat", "name": "acceleration", "weight": 0.3}
					],
					"map": {"mode": "lerp", "min": 5.0, "max": 4.3, "invert": true},
					"bounds": {"min": 4.0, "max": 5.5}
				}
			}
		}

		var combine_cfg := {}
		return CombineCalculator.compute_all(player, combine_cfg, tests_cfg, rng)
	, 54321, "Combine calculation with noise")


# =============================================================================
# BOUNDS AND PRECISION TESTS
# =============================================================================

func test_results_clamped_to_min_bound() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "RB", 21, 80.0)
	player["stats"]["speed"] = 30.0  # Very low speed
	player["physicals"] = {"weight_lb": 250}

	var test_cfg := {
		"type": "time",
		"inputs": [
			{"src": "stat", "name": "speed", "weight": 1.0}
		],
		"map": {"mode": "lerp", "min": 6.0, "max": 4.2, "invert": true},
		"noise": {"dist": "none"},
		"bounds": {"min": 4.5, "max": 5.5},
		"precision": 2
	}

	var defaults := {}
	var combine_cfg := {}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng)

	# Should be clamped to min bound
	assert_float(result).is_greater_equal(4.5)


func test_results_clamped_to_max_bound() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "RB", 21, 80.0)
	player["stats"]["speed"] = 100.0  # Max speed
	player["physicals"] = {"weight_lb": 180}

	var test_cfg := {
		"type": "time",
		"inputs": [
			{"src": "stat", "name": "speed", "weight": 1.0}
		],
		"map": {"mode": "lerp", "min": 5.0, "max": 4.0, "invert": true},
		"noise": {"dist": "none"},
		"bounds": {"min": 4.0, "max": 4.5},
		"precision": 2
	}

	var defaults := {}
	var combine_cfg := {}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng)

	# Should be clamped to max bound
	assert_float(result).is_less_equal(4.5)


func test_precision_rounds_to_specified_decimals() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "RB", 21, 80.0)
	player["stats"]["speed"] = 85.0
	player["physicals"] = {"weight_lb": 210}

	var test_cfg := {
		"type": "time",
		"inputs": [
			{"src": "stat", "name": "speed", "weight": 1.0}
		],
		"map": {"mode": "lerp", "min": 5.0, "max": 4.3, "invert": true},
		"noise": {"dist": "none"},
		"bounds": {"min": 4.0, "max": 5.5},
		"precision": 2  # Two decimal places
	}

	var defaults := {}
	var combine_cfg := {}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng)

	# Result should have at most 2 decimal places
	var rounded := snappedf(result, 0.01)
	assert_float(result).is_equal(rounded)


func test_integer_flag_produces_whole_numbers() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "OL", 21, 80.0)
	player["stats"]["strength"] = 85.0
	player["physicals"] = {"weight_lb": 310}

	var test_cfg := {
		"type": "reps",
		"inputs": [
			{"src": "stat", "name": "strength", "weight": 1.0}
		],
		"map": {"mode": "lerp", "min": 15.0, "max": 35.0},
		"noise": {"dist": "none"},
		"bounds": {"min": 10, "max": 40},
		"integer": true
	}

	var defaults := {}
	var combine_cfg := {}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng)

	# Result should be an integer
	assert_float(result).is_equal(float(int(result)))


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_missing_stats_use_default_values() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "RB", 21, 80.0)
	player["stats"] = {}  # No stats
	player["physicals"] = {"weight_lb": 210}

	var test_cfg := {
		"type": "time",
		"inputs": [
			{"src": "stat", "name": "speed", "weight": 1.0}
		],
		"map": {"mode": "lerp", "min": 5.5, "max": 4.3, "invert": true},
		"noise": {"dist": "none"},
		"bounds": {"min": 4.0, "max": 6.0},
		"precision": 2
	}

	var defaults := {}
	var combine_cfg := {}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng)

	# Should use default stat value (50.0) and produce reasonable result
	assert_float(result).is_greater_equal(4.0)
	assert_float(result).is_less_equal(6.0)


func test_missing_physicals_handled_gracefully() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "RB", 21, 80.0)
	player["stats"]["speed"] = 85.0
	player["physicals"] = {}  # No physicals

	var test_cfg := {
		"type": "time",
		"inputs": [
			{"src": "stat", "name": "speed", "weight": 1.0}
		],
		"map": {"mode": "lerp", "min": 5.0, "max": 4.3, "invert": true},
		"noise": {"dist": "none"},
		"body_adjust": {
			"mode": "time_mass",
			"anchor_wt": 200.0,
			"coef_per_10lb": 0.02
		},
		"bounds": {"min": 4.0, "max": 5.5},
		"precision": 2
	}

	var defaults := {}
	var combine_cfg := {}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng)

	# Should handle missing weight (default to 0.0) and produce reasonable result
	assert_object(result).is_not_null()
	assert_float(result).is_greater_equal(4.0)
	assert_float(result).is_less_equal(5.5)


func test_empty_inputs_array_uses_default_scalar() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "RB", 21, 80.0)

	var test_cfg := {
		"type": "score",
		"inputs": [],  # No inputs
		"map": {"mode": "lerp", "min": 0.0, "max": 100.0},
		"noise": {"dist": "none"},
		"bounds": {"min": 0, "max": 100},
		"precision": 1
	}

	var defaults := {}
	var combine_cfg := {}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := CombineCalculator._compute_single(player, test_cfg, defaults, combine_cfg, rng)

	# Should use default scalar (0.5) and produce middle-range value
	assert_float(result).is_equal_approx(50.0, 10.0)
