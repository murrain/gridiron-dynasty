extends RefCounted
class_name ValuationHelpers

static func valuation_range(
	base_value: float,
	variance_pct: float,
	min_value: float = -INF,
	max_value: float = INF
) -> Dictionary:
	var delta: float = abs(base_value) * variance_pct
	var lo: float = base_value - delta
	var hi: float = base_value + delta
	lo = max(lo, min_value)
	hi = min(hi, max_value)
	if hi < lo:
		var tmp: float = lo
		lo = hi
		hi = tmp
	return {"min": lo, "max": hi}

static func est_value(eval: Dictionary, rng: RandomNumberGenerator) -> float:
	var base := float(eval.get("base_value", 0.0))
	var variance_pct := float(eval.get("variance_pct", 0.0))
	var min_value := float(eval.get("min_value", -INF))
	var max_value := float(eval.get("max_value", INF))
	var range := valuation_range(base, variance_pct, min_value, max_value)
	return rng.randf_range(float(range["min"]), float(range["max"]))
