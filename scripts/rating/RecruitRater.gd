extends Node
class_name RecruitRater

# Rates players (adds composite_score, star_rating, rank_overall, rank_in_pos).
# Keep this module decoupled from generation.
func rate_and_rank(
	players: Array,                       # Array<Dictionary>
	positions_data: Dictionary,
	class_rules: Dictionary
) -> void:
	var rules: Dictionary = class_rules.get("recruiting", {})

	# ---- weights (global, with optional per-position overrides) ----
	var w_core: float      = float(rules.get("w_core", 0.55))
	var w_secondary: float = float(rules.get("w_secondary", 0.20))
	var w_mentals: float   = float(rules.get("w_mentals", 0.15))
	var w_physicals: float = float(rules.get("w_physicals", 0.10))
	var risk_cap: float    = float(rules.get("risk_cap", 10.0))
	var weights_by_pos: Dictionary = rules.get("weights_by_pos", {})  # optional

	var mental_keys: Array = rules.get("mental_keys", [
		"awareness","decision_making","discipline","work_ethic",
		"coachability","focus","composure","anticipation"
	])

	var physical_keys: Array = rules.get("physical_keys", [
		"height_in","weight_lb","arm_length_in","wingspan_in","hand_size_in"
	])

	# Position-percentile thresholds for stars
	var star_thresholds: Dictionary = rules.get("star_thresholds", {
		"5": 0.98, "4": 0.90, "3": 0.70, "2": 0.40, "1": 0.15
	})

	var cap_specialists_to_3: bool = bool(rules.get("cap_specialists_to_3_stars", true))

	# ---- cache role lists per position ----
	var role_cache: Dictionary = {}
	for pos_key in positions_data.keys():
		var pos: String = String(pos_key)
		var spec: Dictionary = positions_data[pos]
		var dists: Dictionary = spec.get("distributions", {})
		var core: Array = (spec.get("core_stats", []) as Array).duplicate()
		var secondary: Array = []
		for k in dists.keys():
			var role: String = String((dists[k] as Dictionary).get("role","other"))
			if role == "secondary":
				secondary.append(k)
		role_cache[pos] = { "core": core, "secondary": secondary }

	# ---- cache physical mu/sigma per position for z-scores ----
	var phys_mu: Dictionary = {}  # pos -> {k: mu}
	var phys_sd: Dictionary = {}  # pos -> {k: sd}
	for pos_key in positions_data.keys():
		var pos: String = String(pos_key)
		var ph: Dictionary = positions_data[pos].get("physicals", {}) as Dictionary
		var mu_map: Dictionary = {}
		var sd_map: Dictionary = {}
		for k in ph.keys():
			var cfgp: Dictionary = ph[k] as Dictionary
			mu_map[k] = float(cfgp.get("mu", 0.0))
			sd_map[k] = max(0.0001, float(cfgp.get("sigma", 1.0)))
		phys_mu[pos] = mu_map
		phys_sd[pos] = sd_map

	# ---- 1) compute composite for each player ----
	for p in players:
		var pos: String = String(p.get("position","ATH"))
		var sdict: Dictionary = p.get("stats", {}) as Dictionary
		var roles: Dictionary = role_cache.get(pos, {"core":[],"secondary":[]}) as Dictionary
		var core_list: Array = roles["core"] as Array
		var sec_list: Array  = roles["secondary"] as Array

		# allow per-position weight overrides
		var w: Dictionary = _weights_for_pos(pos, w_core, w_secondary, w_mentals, w_physicals, weights_by_pos)

		var core_avg: float = _avg_keys(sdict, core_list)
		var sec_avg: float  = _avg_keys(sdict, sec_list)
		var mental_avg: float = _avg_keys(sdict, mental_keys)

		# physicals index via z-mean -> [0..100]
		var pphys: Dictionary = p.get("physicals", {}) as Dictionary
		var pmu: Dictionary = phys_mu.get(pos, {}) as Dictionary
		var psd: Dictionary = phys_sd.get(pos, {}) as Dictionary
		var zs: Array = []  # Array<float>
		for k in physical_keys:
			if pphys.has(k) and pmu.has(k) and psd.has(k):
				var z: float = (float(pphys[k]) - float(pmu[k])) / float(psd[k])
				zs.append(z)
		var z_mean: float = 0.0
		if not zs.is_empty():
			for z in zs:
				z_mean += float(z)
			z_mean /= float(zs.size())
		var physical_idx: float = clamp(50.0 + 12.0 * z_mean, 0.0, 100.0)

		# simple risk penalty
		var injury_prone: float = float(sdict.get("injury_proneness", 50.0))
		var discipline: float   = float(sdict.get("discipline", 50.0))
		var risk: float = 0.0
		risk += (injury_prone - 50.0) * 0.08
		risk += max(0.0, 60.0 - discipline) * 0.1
		risk = clamp(risk, 0.0, risk_cap)

		var raw: float = core_avg * float(w["core"]) + sec_avg * float(w["secondary"]) + mental_avg * float(w["mentals"]) + physical_idx * float(w["physicals"])
		var wsum: float = max(0.0001, float(w["core"]) + float(w["secondary"]) + float(w["mentals"]) + float(w["physicals"]))
		var comp: float = clamp(raw / wsum, 0.0, 100.0)
		comp = max(0.0, comp - risk)

		p["composite_score"] = _round2(comp)
		p["core_avg"]        = _round2(core_avg)
		p["secondary_avg"]   = _round2(sec_avg)
		p["mentals_avg"]     = _round2(mental_avg)
		p["physicals_index"] = _round2(physical_idx)

	# ---- 2) stars by position percentile; also rank_in_pos ----
	var by_pos: Dictionary = {}
	for p in players:
		var pos: String = String(p.get("position","ATH"))
		if not by_pos.has(pos):
			by_pos[pos] = []
		(by_pos[pos] as Array).append(p)

	for pos_key in by_pos.keys():
		var group: Array = by_pos[pos_key] as Array

		# sorted values for percentile
		var vals: Array = []  # Array<float>
		for p in group:
			vals.append(float((p as Dictionary).get("composite_score", 0.0)))
		vals.sort()

		# rank within position
		group.sort_custom(func(a, b):
			return float((a as Dictionary).get("composite_score",0.0)) > float((b as Dictionary).get("composite_score",0.0))
		)
		for i in range(group.size()):
			(group[i] as Dictionary)["rank_in_pos"] = i + 1

		# assign stars
		for p in group:
			var v: float = float((p as Dictionary).get("composite_score", 0.0))
			var pct: float = _percentile_in_sorted(vals, v)
			(p as Dictionary)["star_rating"] = _stars_from_percentile(pct, star_thresholds, String((p as Dictionary).get("position","")), cap_specialists_to_3)

	# ---- 3) overall ranking ----
	players.sort_custom(func(a, b):
		return float((a as Dictionary).get("composite_score",0.0)) > float((b as Dictionary).get("composite_score",0.0))
	)
	for i in range(players.size()):
		(players[i] as Dictionary)["rank_overall"] = i + 1


# ---------- helpers ----------

func _weights_for_pos(pos: String, wc: float, ws: float, wm: float, wp: float, overrides: Dictionary) -> Dictionary:
	if overrides.has(pos):
		var o: Dictionary = overrides[pos] as Dictionary
		return {
			"core": float(o.get("w_core", wc)),
			"secondary": float(o.get("w_secondary", ws)),
			"mentals": float(o.get("w_mentals", wm)),
			"physicals": float(o.get("w_physicals", wp))
		}
	return { "core": wc, "secondary": ws, "mentals": wm, "physicals": wp }

func _avg_keys(src: Dictionary, keys: Array) -> float:
	if keys.is_empty():
		return 0.0
	var s: float = 0.0
	var n: int = 0
	for k in keys:
		if src.has(k):
			s += float(src[k])
			n += 1
	return (s / float(n)) if n > 0 else 0.0

func _percentile_in_sorted(sorted_vals: Array, v: float) -> float:
	var n: int = sorted_vals.size()
	if n == 0:
		return 0.0
	var i: int = 0
	while i < n and v > float(sorted_vals[i]):
		i += 1
	return clamp(float(i) / float(max(1, n - 1)), 0.0, 1.0)

func _stars_from_percentile(pct: float, thresholds: Dictionary, pos: String, cap_specialists_to_3: bool) -> int:
	# Optionally dampen K/P stars
	if cap_specialists_to_3 and (pos == "K" or pos == "P"):
		if pct >= float(thresholds.get("4", 0.90)): return 3
		if pct >= float(thresholds.get("3", 0.70)): return 2
		if pct >= float(thresholds.get("2", 0.40)): return 1
		return 0
	if pct >= float(thresholds.get("5", 0.98)): return 5
	if pct >= float(thresholds.get("4", 0.90)): return 4
	if pct >= float(thresholds.get("3", 0.70)): return 3
	if pct >= float(thresholds.get("2", 0.40)): return 2
	if pct >= float(thresholds.get("1", 0.15)): return 1
	return 0

func _round2(x: float) -> float:
	return snappedf(x, 0.01)