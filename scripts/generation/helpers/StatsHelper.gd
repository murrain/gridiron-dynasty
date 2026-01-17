extends RefCounted
class_name StatsHelper
## StatsHelper
## - roll_all(stats_cfg, pos, positions_data, gaussian_share) -> Dictionary
## Uses per-position overrides when available in positions_data[pos].distributions[stat].
## Fallback to stats_cfg.stats[*] defaults (expects {name, mu, sigma, min, max}).
##
## STAT BOUND PHILOSOPHY (v3.0):
##
## 1. VIABILITY MINIMUMS ("viability_min"):
##    - Physical/mechanical requirements to play the position
##    - Below this, the player literally cannot function
##    - Example: QB with throw_power < 40 can't physically throw NFL distance
##    - Example: OL with strength < 35 gets destroyed every snap
##
## 2. INTANGIBLE VARIANCE (no floor beyond viability):
##    - Mental/decision-making stats allowed to vary widely
##    - Creates emergent failure scenarios
##    - Example: 5★ QB recruit with 85 throw_power but 25 football_IQ → bust
##    - Example: Elite athlete WR with 95 speed but 30 route_running → underperforms
##
## 3. SMART DEFAULTS (when min/max not specified):
##    - If "viability_min" exists: use it as floor, no ceiling
##    - Otherwise: use 3-sigma for reasonable variance
##    - Always clamp final result to 0-100
##
## This creates realistic player archetypes:
##   - Physically gifted but mentally limited
##   - Smart but physically limited
##   - Balanced but mediocre
##   - Rare: elite in everything

static func _sample_gauss(
	mu: float,
	sigma: float,
	lo: float,
	hi: float,
	rng: RandomNumberGenerator
) -> float:
	if sigma <= 0.0:
		return clamp(mu, lo, hi)
	var noise: float = rng.randfn(0.0, sigma)
	return clamp(mu + noise, lo, hi)

static func _sample_mix(
	mu: float,
	sigma: float,
	lo: float,
	hi: float,
	gaussian_share: float,
	rng: RandomNumberGenerator
) -> float:
	gaussian_share = clamp(gaussian_share, 0.0, 1.0)
	var roll: float = rng.randf()
	if roll < gaussian_share:
		return _sample_gauss(mu, sigma, lo, hi, rng)
	# light uniform tail for outliers
	return rng.randf_range(lo, hi)

static func roll_all(
	stats_cfg: Dictionary,
	pos: String,
	positions_data: Dictionary,
	gaussian_share: float,
	rng: RandomNumberGenerator
) -> Dictionary:
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

		# Check for viability_min (physical requirement to play position)
		var viability_min: Variant = d.get("viability_min", null)

		# Smart bound selection:
		var default_min: float
		var default_max: float

		if viability_min != null:
			# Viability floor exists: use it as hard minimum, no maximum
			# This allows intangibles to vary widely while preventing unplayable players
			default_min = float(viability_min)
			default_max = 100.0
		else:
			# No viability floor: use 3-sigma for reasonable variance
			# 3-sigma captures 99.7% of normal distribution
			default_min = maxf(0.0, mu - 3.0 * sg)
			default_max = minf(100.0, mu + 3.0 * sg)

		var lo := float(d.get("min", row.get("min", default_min)))
		var hi := float(d.get("max", row.get("max", default_max)))

		var v := _sample_mix(mu, sg, lo, hi, gaussian_share, rng)
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

## ============================================================================
## CHAOS GENERATION (20% of players)
## ============================================================================
## Generate a "chaos" player: stats first with uniform distribution, then
## find best-fit position based on core stat scores.
##
## RNG CONSUMPTION PATTERN:
##   - 1 call per stat in all_stats array (randf_range for uniform sampling)
##   - Potentially 1 call per viability-adjusted stat (randf_range for small bump)
##
## This creates emergent player types that don't fit standard templates,
## enabling occasional diamonds-in-the-rough or position converts.

static func generate_chaos_player(
	all_stats: Array,
	positions_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var stats := {}

	# Generate ALL stats with uniform distribution [25, 95]
	# RNG: one randf_range call per stat
	for stat_name in all_stats:
		stats[stat_name] = rng.randf_range(25.0, 95.0)

	# Find best-fit position based on core stat scores
	var position = _find_best_fit_position(stats, positions_cfg)

	# Ensure viability for the chosen position (may bump stats slightly)
	# RNG: potentially one randf_range call per stat with viability_min
	stats = _ensure_viability(stats, position, positions_cfg, rng)

	return {"position": position, "stats": stats, "generation_mode": "chaos"}

## Find the position whose core stats best match the player's raw stats.
## Uses deterministic iteration order (sorted keys) for reproducibility.
static func _find_best_fit_position(stats: Dictionary, positions_cfg: Dictionary) -> String:
	var position_keys = positions_cfg.keys()
	position_keys.sort()  # CRITICAL for determinism: ensure consistent iteration order

	var best_position = ""
	var best_score = -999999.0

	for position in position_keys:
		var score = _score_position_fit(stats, position, positions_cfg)
		if score > best_score:
			best_score = score
			best_position = position

	# Fallback to first position if somehow no match found
	return best_position if best_position != "" else position_keys[0]

## Score how well a player's stats fit a position.
## Simple sum of core stat values - higher is better fit.
static func _score_position_fit(stats: Dictionary, position: String, positions_cfg: Dictionary) -> float:
	var pos_cfg = positions_cfg.get(position, {})
	var core_stats = pos_cfg.get("core_stats", []) as Array

	var score = 0.0
	for stat in core_stats:
		if stats.has(stat):
			score += float(stats[stat])  # Simple sum of core stats

	return score

## Ensure player meets viability minimums for the chosen position.
## If a stat is below viability_min, bump it up slightly.
##
## RNG: one randf_range call per stat that needs adjustment
static func _ensure_viability(
	stats: Dictionary,
	position: String,
	positions_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var pos_cfg = positions_cfg.get(position, {})
	var dists = pos_cfg.get("distributions", {}) as Dictionary

	# Sort keys for deterministic iteration order
	var dist_keys = dists.keys()
	dist_keys.sort()

	for stat_name in dist_keys:
		var dist = dists[stat_name] as Dictionary
		if dist.has("viability_min"):
			var min_val = float(dist["viability_min"])
			var current = float(stats.get(stat_name, 0.0))
			if current < min_val:
				# Bump to viability_min plus small random offset [0, 10]
				# This ensures player can function while preserving some variance
				stats[stat_name] = min_val + rng.randf_range(0.0, 10.0)

	return stats
