# res://scripts/generation/StatHelpers.gd
extends RefCounted
class_name StatHelpers

static func gaussian(mu: float, sigma: float) -> float:
	var u1: float = max(1e-9, randf())
	var u2: float = randf()
	var z: float = sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)
	return mu + sigma * z

static func clamp01(v: float) -> float:
	return clamp(v, 0.0, 100.0)

static func percentile_value(sorted_vals: Array, pct: float) -> float:
	# Accepts an Array[float]; we'll read defensively in case it's mixed.
	if sorted_vals.is_empty():
		return 0.0
	var size_f: float = float(sorted_vals.size() - 1)
	var idx: int = int(round(clamp(pct, 0.0, 1.0) * size_f))
	var val: float = float(sorted_vals[idx])
	return val

static func sample_with_caps(
		mu: float,
		sigma: float,
		cap_pct: float,
		values_for_percentile: Array,
		role: String,
		outlier: Dictionary
	) -> float:
	var v: float = clamp(gaussian(mu, sigma), 0.0, 100.0)
	var cap_val: float = percentile_value(values_for_percentile, cap_pct)

	if role == "core":
		return min(v, cap_val)

	var prob: float = float(outlier.get("prob", 0.0))
	if randf() < prob:
		var max_pct: float = float(outlier.get("max_pct", cap_pct))
		var rare_cap: float = percentile_value(values_for_percentile, max_pct)
		return min(v, rare_cap)

	return min(v, cap_val)