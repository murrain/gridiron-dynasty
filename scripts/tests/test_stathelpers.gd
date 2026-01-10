extends RefCounted

func run(t: TestHelpers) -> void:
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 7
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 7
	var g1 := StatHelpers.gaussian(0.0, 1.0, rng1)
	var g2 := StatHelpers.gaussian(0.0, 1.0, rng2)
	t.assert_approx(g1, g2, 0.0001, "gaussian should be deterministic with seeded rng")

	t.assert_eq(StatHelpers.clamp01(-5.0), 0.0, "clamp01 lower bound")
	t.assert_eq(StatHelpers.clamp01(150.0), 100.0, "clamp01 upper bound")

	t.assert_eq(StatHelpers.percentile_value([], 0.5), 0.0, "percentile_value empty returns 0")
	t.assert_eq(StatHelpers.percentile_value([10, 20, 30], 0.5), 20.0, "percentile_value picks median")

	var values := [10.0, 20.0, 30.0, 40.0]
	var outlier := {"prob": 1.0, "max_pct": 1.0}
	var v := StatHelpers.sample_with_caps(50.0, 0.0, 0.5, values, "other", outlier, rng1)
	t.assert_between(v, 0.0, 40.0, "sample_with_caps respects caps")
	var v2 := StatHelpers.sample_with_caps(50.0, 0.0, 0.25, values, "core", outlier, rng1)
	t.assert_eq(v2, 20.0, "sample_with_caps core uses cap")
