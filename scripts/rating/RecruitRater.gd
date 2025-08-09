extends Node
class_name RecruitRater

# Produces on each player:
#  - core_avg, secondary_avg, mentals_avg, athletic_avg
#  - athletic_pct (within-position percentile, 0..1)
#  - composite_score (0..100)  [athlete-first, position-fair, calibrated]
#  - star_score (0..100)       [hybrid: core-heavy + composite]
#  - star_rating (0..5)        [pos-value adjusted, w/ exceptional override]
#  - rank_in_pos (by composite), rank_overall (by composite)
#  - tags += "EliteCore" when core_avg >= elite_core_threshold

func rate_and_rank(players: Array, positions_data: Dictionary, class_rules: Dictionary) -> void:
	# ---- recruiting knobs ----
	var rules: Dictionary = class_rules.get("recruiting", {}) as Dictionary

	# Readiness weights (used only for interim composite in star_score hybrid if needed)
	var risk_cap: float    = float(rules.get("risk_cap", 10.0))

	# Athlete-centric composite weights
	var comp_w_global: Dictionary = rules.get("composite_weights", {
		"athletic": 0.40, "core": 0.30, "secondary": 0.20, "mentals": 0.10
	}) as Dictionary
	var comp_w_by_pos: Dictionary = rules.get("composite_weights_by_pos", {}) as Dictionary
	var athletic_keys: Array = rules.get("athletic_keys", [
		"speed","acceleration","agility","balance","vertical_jump","broad_jump","strength"
	]) as Array
	var synergy_gain: float = float(rules.get("composite_synergy_gain", 0.15))
	var use_size_adj_speed: bool = bool(rules.get("use_size_adjusted_speed", true))

	# Calibration knobs
	var calib: Dictionary = rules.get("composite_calibration", {}) as Dictionary
	var shrink: float = float(calib.get("shrink_to_mean", 0.60))
	var g_bias: float = float(calib.get("global_bias", 0.0))
	var floor_v: float = float(calib.get("floor", 30.0))
	var cap_v:   float = float(calib.get("cap", 92.0))
	var bias_by_pos: Dictionary = calib.get("bias_by_pos", {}) as Dictionary

	# Star knobs
	var star_thresholds: Dictionary = rules.get("star_thresholds", {
		"5": 0.98, "4": 0.90, "3": 0.70, "2": 0.40, "1": 0.15
	}) as Dictionary
	var cap_specialists_to_3: bool = bool(rules.get("cap_specialists_to_3_stars", true))
	var star_w: Dictionary = rules.get("star_weights", {"core":0.60, "composite":0.40}) as Dictionary
	var star_core_w: float = float(star_w.get("core", 0.60))
	var star_comp_w: float = float(star_w.get("composite", 0.40))
	var star_wsum: float = max(0.0001, star_core_w + star_comp_w)

	var pos_value: Dictionary = rules.get("position_value", {}) as Dictionary
	var exceptional: Dictionary = rules.get("exceptional_override", {
		"star_score_min": 92.0,
		"athletic_pct_min": 0.90,
		"allow_for_positions": ["RB","TE","S","LB","WR","CB","OL","DL","QB"],
		"ignore_specialist_cap": false
	}) as Dictionary

	# Mental/physical inputs
	var mental_keys: Array = rules.get("mental_keys", [
		"awareness","decision_making","discipline","work_ethic",
		"coachability","focus","composure","anticipation"
	]) as Array
	var physical_keys: Array = rules.get("physical_keys", [
		"height_in","weight_lb","arm_length_in","wingspan_in","hand_size_in"
	]) as Array

	# ---- cache roles per position ----
	var role_cache: Dictionary = {}
	for pos_key in positions_data.keys():
		var pos: String = String(pos_key)
		var spec: Dictionary = positions_data[pos] as Dictionary
		var dists: Dictionary = spec.get("distributions", {}) as Dictionary
		var core: Array = (spec.get("core_stats", []) as Array).duplicate()
		var secondary: Array = []
		for k in dists.keys():
			var role: String = String((dists[k] as Dictionary).get("role","other"))
			if role == "secondary":
				secondary.append(k)
		role_cache[pos] = { "core": core, "secondary": secondary }

	# ---- cache physical mu/sigma for z-index ----
	var phys_mu: Dictionary = {}
	var phys_sd: Dictionary = {}
	for pos_key2 in positions_data.keys():
		var pos2: String = String(pos_key2)
		var ph: Dictionary = positions_data[pos2].get("physicals", {}) as Dictionary
		var mu_map: Dictionary = {}
		var sd_map: Dictionary = {}
		for k in ph.keys():
			var cfgp: Dictionary = ph[k] as Dictionary
			mu_map[k] = float(cfgp.get("mu", 0.0))
			sd_map[k] = max(0.0001, float(cfgp.get("sigma", 1.0)))
		phys_mu[pos2] = mu_map
		phys_sd[pos2] = sd_map

	# ---- pass 1: compute aggregates per player (no composite yet) ----
	for p in players:
		var pos3: String = String(p.get("position","ATH"))
		var sdict: Dictionary = p.get("stats", {}) as Dictionary
		var roles: Dictionary = role_cache.get(pos3, {"core":[],"secondary":[]}) as Dictionary
		var core_list: Array = roles["core"] as Array
		var sec_list: Array  = roles["secondary"] as Array

		# Averages
		var core_avg: float     = _avg_keys(sdict, core_list)
		var sec_avg: float      = _avg_keys(sdict, sec_list)
		var mental_avg: float   = _avg_keys(sdict, mental_keys)
		var athletic_avg: float = _avg_keys(sdict, athletic_keys)

		# Phys index (z-mean → 0..100)
		var pphys: Dictionary = p.get("physicals", {}) as Dictionary
		var pmu: Dictionary = phys_mu.get(pos3, {}) as Dictionary
		var psd: Dictionary = phys_sd.get(pos3, {}) as Dictionary
		var zs: Array = []
		for k in physical_keys:
			if pphys.has(k) and pmu.has(k) and psd.has(k):
				var z: float = (float(pphys[k]) - float(pmu[k])) / float(psd[k])
				zs.append(z)
		var z_mean: float = 0.0
		if not zs.is_empty():
			for z in zs: z_mean += float(z)
			z_mean /= float(zs.size())
		var physical_idx: float = clamp(50.0 + 12.0 * z_mean, 0.0, 100.0)

		# Risk (kept simple)
		var injury_prone: float = float(sdict.get("injury_proneness", 50.0))
		var discipline: float   = float(sdict.get("discipline", 50.0))
		var risk: float = 0.0
		risk += (injury_prone - 50.0) * 0.08
		risk += max(0.0, 60.0 - discipline) * 0.1
		risk = clamp(risk, 0.0, risk_cap)

		# Store aggregates
		p["core_avg"]        = _round2(core_avg)
		p["secondary_avg"]   = _round2(sec_avg)
		p["mentals_avg"]     = _round2(mental_avg)
		p["physicals_index"] = _round2(physical_idx)
		p["athletic_avg"]    = _round2(athletic_avg)
		p["__risk"]          = risk  # internal

		# Elite core tag now (independent of composite)
		if core_avg >= float(rules.get("elite_core_threshold", 90.0)):
			if not p.has("tags"): p["tags"] = []
			(p["tags"] as Array).append("EliteCore")

	# ---- group by position ----
	var by_pos: Dictionary = {}
	for p2 in players:
		var posn: String = String((p2 as Dictionary).get("position","ATH"))
		if not by_pos.has(posn): by_pos[posn] = []
		(by_pos[posn] as Array).append(p2)

	# ---- pass 2: within-position percentiles → athlete-first composite ----
	for pos_key3 in by_pos.keys():
		var group: Array = by_pos[pos_key3] as Array

		# Collect raw arrays for percentiles
		var cores: Array = []
		var secs: Array  = []
		var ments: Array = []
		var aths: Array  = []
		var size_speed: Array = []  # optional

		for gp in group:
			var d: Dictionary = gp as Dictionary
			cores.append(float(d.get("core_avg", 0.0)))
			secs.append(float(d.get("secondary_avg", 0.0)))
			ments.append(float(d.get("mentals_avg", 0.0)))
			aths.append(float(d.get("athletic_avg", 0.0)))
			if use_size_adj_speed:
				var spd: float = float((d.get("stats", {}) as Dictionary).get("speed", 50.0))
				var wt:  float = float((d.get("physicals", {}) as Dictionary).get("weight_lb", 190.0))
				var idx: float = clamp(spd * (wt / 300.0), 0.0, 100.0)  # crude size-adjusted speed index
				size_speed.append(idx)

		cores.sort(); secs.sort(); ments.sort(); aths.sort()
		if use_size_adj_speed: size_speed.sort()

		for gp in group:
			var d2: Dictionary = gp as Dictionary
			var core_pct: float = _percentile_in_sorted(cores,  float(d2.get("core_avg", 0.0)))
			var sec_pct:  float = _percentile_in_sorted(secs,   float(d2.get("secondary_avg", 0.0)))
			var men_pct:  float = _percentile_in_sorted(ments,  float(d2.get("mentals_avg", 0.0)))
			var ath_pct:  float = _percentile_in_sorted(aths,   float(d2.get("athletic_avg", 0.0)))
			d2["athletic_pct"] = ath_pct

			# Optional blend of size-adjusted speed
			if use_size_adj_speed:
				var spd2: float = float((d2.get("stats", {}) as Dictionary).get("speed", 50.0))
				var wt2:  float = float((d2.get("physicals", {}) as Dictionary).get("weight_lb", 190.0))
				var idx2: float = clamp(spd2 * (wt2 / 300.0), 0.0, 100.0)
				var szp: float = _percentile_in_sorted(size_speed, idx2)
				ath_pct = clamp(0.85 * ath_pct + 0.15 * szp, 0.0, 1.0)

			# Diminishing returns & synergy
			var ath_eff: float = pow(ath_pct, 0.90)
			var core_eff: float = pow(core_pct, 0.95)
			var sec_eff:  float = pow(sec_pct, 1.00)
			var men_eff:  float = pow(men_pct, 0.85)

			# Weights (per-position or global)
			var cw: Dictionary = comp_w_by_pos.get(String(pos_key3), comp_w_global) as Dictionary
			var w_ath: float = float(cw.get("athletic", 0.40))
			var w_cor: float = float(cw.get("core", 0.30))
			var w_sec: float = float(cw.get("secondary", 0.20))
			var w_men: float = float(cw.get("mentals", 0.10))
			var w_sum: float = max(0.0001, w_ath + w_cor + w_sec + w_men)

			var synergy: float = sqrt(max(0.0, ath_eff * core_eff))
			var comp_pct: float = (w_ath*ath_eff + w_cor*core_eff + w_sec*sec_eff + w_men*men_eff) / w_sum
			comp_pct = comp_pct * (1.0 + synergy_gain * (synergy - 0.5))  # +/- around 0.5 baseline

			# Calibration
			var centered: float = comp_pct - 0.5
			var shrunk: float = 0.5 + shrink * centered
			var pos_bias: float = float(bias_by_pos.get(String(pos_key3), 0.0))
			var comp_points: float = shrunk * 100.0 + g_bias + pos_bias
			d2["composite_score"] = _round2(clamp(comp_points, floor_v, cap_v))

	# ---- pass 3: star_score (hybrid of core + final composite), stars, ranks ----
	# star_score needs final composite, so compute now
	for p3 in players:
		var cavg: float = float((p3 as Dictionary).get("core_avg", 0.0))
		var comp_final: float = float((p3 as Dictionary).get("composite_score", 0.0))
		var star_score: float = ((cavg * star_core_w) + (comp_final * star_comp_w)) / star_wsum
		(p3 as Dictionary)["star_score"] = _round2(star_score)

	# regroup (already have by_pos)
	for pos_key4 in by_pos.keys():
		var group2: Array = by_pos[pos_key4] as Array
		var pos_label: String = String(pos_key4)

		# rank_in_pos by final composite (readiness)
		group2.sort_custom(func(a, b):
			return float((a as Dictionary).get("composite_score",0.0)) > float((b as Dictionary).get("composite_score",0.0))
		)
		for i in range(group2.size()):
			(group2[i] as Dictionary)["rank_in_pos"] = i + 1

		# stars via percentile of position-value-adjusted star_score within position
		var raw_star_vals: Array = []
		for gp2 in group2:
			var d3: Dictionary = gp2 as Dictionary
			var base_star: float = float(d3.get("star_score", 0.0))
			var pv: float = float(pos_value.get(pos_label, 1.0))
			raw_star_vals.append(base_star * pv)
		raw_star_vals.sort()

		for gp3 in group2:
			var d4: Dictionary = gp3 as Dictionary
			var base_star2: float = float(d4.get("star_score", 0.0))
			var pv2: float = float(pos_value.get(pos_label, 1.0))
			var adj_star: float = base_star2 * pv2
			var pct_star: float = _percentile_in_sorted(raw_star_vals, adj_star)

			var stars: int = _stars_from_percentile(pct_star, star_thresholds, pos_label, cap_specialists_to_3)

			# Exceptional override
			var allow_positions: Array = exceptional.get("allow_for_positions", []) as Array
			var ok_pos: bool = allow_positions.has(pos_label)
			var ath_pct_ok: bool = float(d4.get("athletic_pct", 0.0)) >= float(exceptional.get("athletic_pct_min", 0.90))
			var star_score_ok: bool = float(d4.get("star_score", 0.0)) >= float(exceptional.get("star_score_min", 92.0))
			var is_specialist: bool = (pos_label == "K" or pos_label == "P")
			var ignore_sp_cap: bool = bool(exceptional.get("ignore_specialist_cap", false))

			if ok_pos and ath_pct_ok and star_score_ok:
				if not is_specialist or ignore_sp_cap:
					stars = max(stars, 5)

			d4["star_rating"] = stars

	# overall ranking by composite
	players.sort_custom(func(a, b):
		return float((a as Dictionary).get("composite_score",0.0)) > float((b as Dictionary).get("composite_score",0.0))
	)
	for i2 in range(players.size()):
		(players[i2] as Dictionary)["rank_overall"] = i2 + 1


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