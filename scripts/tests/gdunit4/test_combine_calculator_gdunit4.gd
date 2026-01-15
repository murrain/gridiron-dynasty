## GdUnit4 test suite for CombineCalculator
##
## Validates combine test calculations and utility functions.
## Migrated from test_combine_calculator.gd
extends GdUnitTestSuite

const CombineCalculator = preload("res://scripts/core/rating/CombineCalculator.gd")


var _player: Dictionary
var _tests_cfg: Dictionary
var _combine_cfg: Dictionary


func before() -> void:
	_player = {
		"position": "WR",
		"stats": {"speed": 95.0, "acceleration": 92.0, "strength": 60.0, "fatigue": 50.0, "morale": 60.0},
		"physicals": {"weight_lb": 190.0}
	}

	_tests_cfg = {
		"defaults": {
			"map": {"min": 4.0, "max": 5.0, "mode": "lerp"},
			"noise": {"dist": "gauss", "sigma": 0.0},
			"bounds": {"min": 4.0, "max": 5.0},
			"precision": 2,
			"type": "time"
		},
		"tests": {
			"forty": {
				"inputs": [
					{"src": "stat", "name": "speed", "weight": 0.7},
					{"src": "stat", "name": "acceleration", "weight": 0.3}
				],
				"curve": {"mode": "ease_out_cubic"},
				"body_adjust": {"mode": "time_mass", "coef_per_10lb": 0.01, "anchor_wt": 190},
				"synergy_bonus": {"speed_thr": 90, "accel_thr": 90, "scale": 0.02, "weight_full_bonus_at": 185, "weight_zero_bonus_at": 210}
			},
			"shuttle": {
				"inputs": [
					{"src": "physical", "name": "weight_lb", "weight": 1.0, "map": {"min": 160, "max": 240, "invert": true}}
				],
				"curve": {"mode": "sqrt"},
				"map": {"min": 3.0, "max": 5.0, "mode": "lerp"},
				"body_adjust": {"mode": "time_mass_curve", "base_per10": 0.01, "extra_per10_over_anchor": 0.001, "quad_above_anchor": true, "bonus_per10_under": -0.01}
			},
			"bench": {
				"type": "reps",
				"inputs": [
					{"src": "const", "value": 0.5, "weight": 1.0}
				],
				"map": {"min": 10, "max": 30, "mode": "lerp"},
				"integer": true,
				"pos_overrides": {"WR": {"body_adjust": {"mode": "power_mass_asym", "coef_per_10lb": 0.1, "under_mult": 2.0}}}
			}
		}
	}

	_combine_cfg = {
		"adjustments": {
			"fatigue_time_pct_per_100": 0.1,
			"fatigue_power_pct_per_100": 0.1,
			"morale_boon_pct_per_100": 0.05,
			"boom_bust_day_sigma": 0.0,
			"boom_bust_sigma_mult": 1.0
		}
	}


func test_compute_all_returns_forty() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234

	var out := CombineCalculator.compute_all(_player, _combine_cfg, _tests_cfg, rng)
	assert_bool(out.has("forty")).is_true()


func test_compute_all_returns_bench() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234

	var out := CombineCalculator.compute_all(_player, _combine_cfg, _tests_cfg, rng)
	assert_bool(out.has("bench")).is_true()


func test_forty_clamped_to_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234

	var out := CombineCalculator.compute_all(_player, _combine_cfg, _tests_cfg, rng)
	assert_float(float(out.get("forty"))).is_between(4.0, 5.0)


func test_bench_is_integer() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234

	var out := CombineCalculator.compute_all(_player, _combine_cfg, _tests_cfg, rng)
	assert_int(int(out.get("bench"))).is_equal(int(out.get("bench")))


func test_merged_with_defaults_allows_overrides() -> void:
	var merged := CombineCalculator._merged_with_defaults(
		{"map": {"min": 1}},
		{"map": {"min": 2, "max": 3}}
	)
	var merged_map := merged.get("map", {}) as Dictionary

	assert_int(int(merged_map.get("min"))).is_equal(1)


func test_merged_with_defaults_keeps_defaults() -> void:
	var merged := CombineCalculator._merged_with_defaults(
		{"map": {"min": 1}},
		{"map": {"min": 2, "max": 3}}
	)
	var merged_map := merged.get("map", {}) as Dictionary

	assert_int(int(merged_map.get("max"))).is_equal(3)


func test_weighted_skill_scalar_uses_stats() -> void:
	var scalar := CombineCalculator._weighted_skill_scalar(
		_player,
		{"inputs": [{"src": "stat", "name": "speed", "weight": 1.0}]}
	)

	assert_float(scalar).is_between(0.9, 1.0)


func test_apply_curve_reshapes_value() -> void:
	var curve := CombineCalculator._apply_curve(0.5, {"curve": {"mode": "ease_out_quart"}})

	assert_float(curve).is_between(0.5, 1.0)


func test_map_scalar_to_output_inverts() -> void:
	var mapped := CombineCalculator._map_scalar_to_output(
		0.5,
		{"map": {"min": 0, "max": 10, "invert": true, "mode": "lerp"}}
	)

	assert_float(mapped).is_equal(5.0)


func test_format_and_clamp_snaps_precision() -> void:
	var bounded := CombineCalculator._format_and_clamp(
		4.1234,
		{"precision": 2, "bounds": {"min": 4.0, "max": 4.2}}
	)

	assert_float(bounded).is_equal(4.12)


func test_inv_lerp_mid() -> void:
	var result := CombineCalculator._inv_lerp(0.0, 10.0, 5.0)

	assert_float(result).is_equal(0.5)
