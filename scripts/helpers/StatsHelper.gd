extends RefCounted
class_name StatsHelper
## StatsHelper
## - roll_all(stats_cfg, pos, positions_data, gaussian_share) -> Dictionary
## Uses per-position overrides when available in positions_data[pos].distributions[stat].
## Fallback to stats_cfg.stats[*] defaults (expects {name, mu, sigma, min, max}).

static func _sample_gauss(mu: float, sigma: float, lo: float, hi: float) -> float:
	if sigma <= 0.0:
		return clamp(mu, lo, hi)
	return clamp(mu + randfn(0.0, sigma), lo, hi)

static func _sample_mix(mu: float, sigma: float, lo: float, hi: float, gaussian_share: float) -> float:
	gaussian_share = clamp(gaussian_share, 0.0, 1.0)
	if randf() < gaussian_share:
		return _sample_gauss(mu, sigma, lo, hi)
	# light uniform tail for outliers
	return randf_range(lo, hi)

static func roll_all(stats_cfg: Dictionary, pos: String, positions_data: Dictionary, gaussian_share: float) -> Dictionary:
	var out: Dictionary = {}

	var pos_dist: Dictionary = positions_data.get(pos, {}).get("distributions", {}) as Dictionary
	var defs: Array = stats_cfg.get("stats", []) as Array

	for item in defs:
		var row: Dictionary = item as Dictionary
		var name: String = String(row.get("name",""))
		if name == "": 
			continue

		# prefer position-specific distribution when present
		var d: Dictionary = pos_dist.get(name, row) as Dictionary

		var mu := float(d.get("mu",    row.get("mu", 50.0)))
		var sg := float(d.get("sigma", row.get("sigma", 10.0)))
		var lo := float(d.get("min",   row.get("min",  0.0)))
		var hi := float(d.get("max",   row.get("max",100.0)))

		var v := _sample_mix(mu, sg, lo, hi, gaussian_share)
		out[name] = clamp(v, 0.0, 100.0)
	return out

static func apply_defaults(
	stats: Dictionary,
	stats_cfg: Dictionary,
	only_if_missing: bool = true
) -> int:
	var applied := 0
	if not stats_cfg.has("stats"):
		return applied

	for s in stats_cfg["stats"]:
		if not s is Dictionary:
			continue
		if not s.has("name") or not s.has("default"):
			continue

		var name: String = s["name"]

		if only_if_missing and stats.has(name):
			continue

		stats[name] = s["default"]
		applied += 1

	return applied