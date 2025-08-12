## Runtime adapter to score a player with the data-only scout JSON entries.
##
## This bridges JSON-based scout profiles to your in-memory scoring routine.
## If you already turned `Scout.gd` into a Resource and instantiate those,
## you can drop this adapter and call your resource directly.
extends RefCounted
class_name ScoutRuntime

## Scores a player using a JSON scout dictionary (from scouts.json).
## Internally performs perception noise + potential/current blending and
## calls the SAME rater math for comparability.
##
## Example:
## [codeblock]
## var scouts_cfg := App.cfg("football/scouts")
## var scout := (scouts_cfg["national_scouts"] as Array)[0]
## var score := ScoutRuntime.score_player(scout, player, positions, stats_cfg, class_rules)
## [/codeblock]
static func score_player(scout: Dictionary, player: Dictionary, positions_data: Dictionary, stats_cfg: Dictionary, class_rules: Dictionary) -> float:
	# 1) perceive current and potential separately (re-using your measurement_difficulty)
	var base_skill := float(scout.get("base_skill", 0.55))
	var tape_grinder := float(scout.get("tape_grinder", 0.25))
	var risk_aversion := float(scout.get("risk_aversion", 0.10))
	var overr_ath := float(scout.get("overrate_athletes", 0.0))
	var stat_skill: Dictionary = scout.get("stat_skill", {}) as Dictionary
	var est_mult: Dictionary = scout.get("estimation_multipliers", {}) as Dictionary
	var val_mult: Dictionary = scout.get("valuation_multipliers", {}) as Dictionary

	var curr := _perceive(player, stats_cfg, base_skill, stat_skill, est_mult, 0.80)
	var pot := _perceive_potential(player, stats_cfg, base_skill, stat_skill, est_mult, 0.70)

	# 2) blend current/potential (scout-specific)
	var pot_bias : float = clamp(0.15 + 0.35 * tape_grinder - 0.20 * risk_aversion, 0.0, 0.5)
	var blended := _blend_stats(curr, pot, pot_bias)

	# 3) apply valuation multipliers (scout “values” certain stats higher)
	for k in blended["stats"].keys():
		var m := float(val_mult.get(k, 1.0))
		blended["stats"][k] = clamp(float(blended["stats"][k]) * m, 0.0, 100.0)

	# 4) compute composite (no cohort percentiles; compute() will fallback to avg→pct)
	var res := RecruitRater.compute(blended, positions_data, {}, class_rules, {})
	return float(res.get("composite", 0.0))

# --- helpers for ScoutRuntime ---

static func _perceive(player: Dictionary, stats_cfg: Dictionary, base_skill: float, stat_skill: Dictionary, est_mult: Dictionary, ctx_quality: float) -> Dictionary:
	var p2 := player.duplicate(true)
	var stats: Dictionary = p2.get("stats", {}) as Dictionary
	var list: Array = (stats_cfg.get("stats", []) as Array)
	for row in list:
		var it: Dictionary = row
		var sname := String(it.get("name",""))
		var md := float(it.get("measurement_difficulty", 0.5))
		var skill : float = clamp(float(stat_skill.get(sname, base_skill)), 0.0, 1.0)
		var sigma : float = (1.0 - md) * (1.0 - skill) * 12.0 * (1.0 - ctx_quality)
		var est := float(stats.get(sname, 50.0))
		if sigma > 0.0:
			est += StatHelpers.gaussian(0.0, sigma)
		var mult := float(est_mult.get(sname, 1.0))
		stats[sname] = clamp(est * mult, 0.0, 100.0)
	p2["stats"] = stats
	return p2

static func _perceive_potential(player: Dictionary, stats_cfg: Dictionary, base_skill: float, stat_skill: Dictionary, est_mult: Dictionary, ctx_quality: float) -> Dictionary:
	var p2 := player.duplicate(true)
	var curr: Dictionary = p2.get("stats", {}) as Dictionary
	var pot: Dictionary = p2.get("potential", curr) as Dictionary
	var list: Array = (stats_cfg.get("stats", []) as Array)
	var out_stats: Dictionary = {}
	for row in list:
		var it: Dictionary = row
		var sname := String(it.get("name",""))
		var md := float(it.get("measurement_difficulty", 0.5))
		var skill : float = clamp(float(stat_skill.get(sname, base_skill)), 0.0, 1.0)
		var sigma : float = (1.0 - md) * (1.0 - skill) * 12.0 * (1.0 - ctx_quality)
		var est := float(pot.get(sname, curr.get(sname, 50.0)))
		if sigma > 0.0:
			est += StatHelpers.gaussian(0.0, sigma)
		var mult := float(est_mult.get(sname, 1.0))
		out_stats[sname] = clamp(est * mult, 0.0, 100.0)
	p2["stats"] = out_stats
	return p2

static func _blend_stats(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := a.duplicate(true)
	var sa: Dictionary = a.get("stats", {}) as Dictionary
	var sb: Dictionary = b.get("stats", {}) as Dictionary
	var keys := sa.keys()
	for k in sb.keys():
		if not keys.has(k): keys.append(k)
	for k in keys:
		var va := float(sa.get(k, 50.0))
		var vb := float(sb.get(k, 50.0))
		out["stats"][k] = clamp(va * (1.0 - t) + vb * t, 0.0, 100.0)
	return out