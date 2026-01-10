extends RefCounted

func run(t: TestHelpers) -> void:
	var player := {
		"position": "WR",
		"stats": {"speed": 95.0, "acceleration": 92.0, "strength": 60.0, "fatigue": 50.0, "morale": 60.0},
		"physicals": {"weight_lb": 190.0}
	}

	var tests_cfg := {
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

	var combine_cfg := {
		"adjustments": {
			"fatigue_time_pct_per_100": 0.1,
			"fatigue_power_pct_per_100": 0.1,
			"morale_boon_pct_per_100": 0.05,
			"boom_bust_day_sigma": 0.0,
			"boom_bust_sigma_mult": 1.0
		}
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var out := CombineCalculator.compute_all(player, combine_cfg, tests_cfg, rng)
	t.assert_true(out.has("forty"), "compute_all should return forty")
	t.assert_true(out.has("bench"), "compute_all should return bench")
	t.assert_between(float(out.get("forty")), 4.0, 5.0, "forty should be clamped to bounds")
	t.assert_eq(int(out.get("bench")), int(out.get("bench")), "bench should be integer")

	var merged := CombineCalculator._merged_with_defaults({"map": {"min": 1}}, {"map": {"min": 2, "max": 3}})
	var merged_map := merged.get("map", {}) as Dictionary
	t.assert_eq(merged_map.get("min"), 1, "_merged_with_defaults should allow overrides")
	t.assert_eq(merged_map.get("max"), 3, "_merged_with_defaults keeps defaults")

	var scalar := CombineCalculator._weighted_skill_scalar(player, {"inputs": [{"src": "stat", "name": "speed", "weight": 1.0}]})
	t.assert_between(scalar, 0.9, 1.0, "_weighted_skill_scalar uses stats")

	var curve := CombineCalculator._apply_curve(0.5, {"curve": {"mode": "ease_out_quart"}})
	t.assert_between(curve, 0.5, 1.0, "_apply_curve should reshape value")

	var mapped := CombineCalculator._map_scalar_to_output(0.5, {"map": {"min": 0, "max": 10, "invert": true, "mode": "lerp"}})
	t.assert_eq(mapped, 5.0, "_map_scalar_to_output should invert")

	var bounded := CombineCalculator._format_and_clamp(4.1234, {"precision": 2, "bounds": {"min": 4.0, "max": 4.2}})
	t.assert_eq(bounded, 4.12, "_format_and_clamp should snap precision")

	t.assert_eq(CombineCalculator._inv_lerp(0.0, 10.0, 5.0), 0.5, "_inv_lerp mid")
