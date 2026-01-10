extends RefCounted

const ValuationHelpers = preload("res://scripts/core/valuation/ValuationHelpers.gd")

func run(t) -> void:
	var eval := {
		"base_value": 80.0,
		"variance_pct": 0.10,
		"min_value": 0.0,
		"max_value": 100.0
	}
	var range := ValuationHelpers.valuation_range(
		float(eval["base_value"]),
		float(eval["variance_pct"]),
		float(eval["min_value"]),
		float(eval["max_value"])
	)
	var range_min := float(range.get("min", 0.0))
	var range_max := float(range.get("max", 0.0))

	t.assert_approx(range_min, 72.0, 0.0001, "valuation range min matches expected")
	t.assert_approx(range_max, 88.0, 0.0001, "valuation range max matches expected")

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 20240218
	var est_a := ValuationHelpers.est_value(eval, rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 20240218
	var est_b := ValuationHelpers.est_value(eval, rng_b)

	t.assert_approx(est_a, est_b, 0.0001, "est_value is deterministic per seed")
	t.assert_between(est_a, range_min, range_max, "est_value stays within valuation range")
