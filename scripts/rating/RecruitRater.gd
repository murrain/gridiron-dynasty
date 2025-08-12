## RecruitRater.gd
## Thread-safe, athlete-first composite rater with cohort-aware calibration.
## - Use `rate_and_rank(players, positions_data, class_rules, threads)` for the whole class.
## - Use `RecruitRater.compute(player, positions_data, {}, class_rules, percentiles)` for one-off ratings
##   (optionally passing cohort percentiles).
##
## Example (whole class):
## [codeblock]
## var rater := RecruitRater.new()
## rater.rate_and_rank(players, positions_data, class_rules,  App.threads_count())
## [/codeblock]
##
## Example (single player, fallback percentiles from averages):
## [codeblock]
## var result := RecruitRater.compute(player, positions_data, {}, class_rules, {})
## print(result["composite"])  # 0..100
## [/codeblock]
extends RefCounted
class_name RecruitRater

# ----------------------------
# Public: whole-class rating (threaded)
# ----------------------------
func rate_and_rank(
	players: Array,
	positions_data: Dictionary,
	class_rules: Dictionary,
	threads: int = 1
) -> void:
	var rules: Dictionary = class_rules.get("recruiting", {}) as Dictionary

	# knobs used in both paths
	var athletic_keys: Array = rules.get("athletic_keys", [
		"speed","acceleration","agility","balance","vertical_jump","broad_jump","strength"
	]) as Array
	var mental_keys: Array = rules.get("mental_keys", [
		"awareness","decision_making","discipline","work_ethic","coachability","focus","composure","anticipation"
	]) as Array
	var risk_cap: float = float(rules.get("risk_cap", 10.0))
	var use_size_adj_speed: bool = bool(rules.get("use_size_adjusted_speed", true))

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
		"star_score_min": 92.0, "athletic_pct_min": 0.90,
		"allow_for_positions": ["RB","TE","S","LB","WR","CB","OL","DL","QB"],
		"ignore_specialist_cap": false
	}) as Dictionary

	# cache roles (position → {core, secondary})
	var role_cache: Dictionary = {}
	for pos_key in positions_data.keys():
		var pos_cache_key: String = String(pos_key)
		role_cache[pos_cache_key] = _roles_for_pos(positions_data, pos_cache_key)

	# ---------- PASS 1: per-player aggregates (threaded) ----------
	var aggregated: Array = ThreadPool.map(
		players,
		func(p):
			return _aggregate_one(
				p as Dictionary,
				role_cache,
				mental_keys,
				athletic_keys,
				risk_cap
			),
		max(1, threads)
	)

	# write the aggregates back in input order
	for i in range(players.size()):
		var p: Dictionary = players[i] as Dictionary
		var ag: Dictionary = aggregated[i] as Dictionary

		p["core_avg"]      = _round2(float(ag.get("core_avg", 0.0)))
		p["secondary_avg"] = _round2(float(ag.get("secondary_avg", 0.0)))
		p["mentals_avg"]   = _round2(float(ag.get("mentals_avg", 0.0)))
		p["athletic_avg"]  = _round2(float(ag.get("athletic_avg", 0.0)))
		p["__risk"]        = float(ag.get("__risk", 0.0))

		# elite core tag
		var elite_core_threshold: float = float(rules.get("elite_core_threshold", 90.0))
		if float(p["core_avg"]) >= elite_core_threshold:
			if not p.has("tags"):
				p["tags"] = []
			var tags_arr: Array = p["tags"] as Array
			if not tags_arr.has("EliteCore"):
				tags_arr.append("EliteCore")
				p["tags"] = tags_arr

	# ---------- group by position ----------
	var by_pos: Dictionary = {}
	for p2 in players:
		var pos2: String = String((p2 as Dictionary).get("position","ATH"))
		if not by_pos.has(pos2):
			by_pos[pos2] = []
		(by_pos[pos2] as Array).append(p2)

	# ---------- PASS 2: percentiles per position, composite ----------
	for pos_key in by_pos.keys():
		var group: Array = by_pos[pos_key] as Array

		# cohort arrays
		var cores: Array = []
		var secs:  Array = []
		var ments: Array = []
		var aths:  Array = []
		var size_speed: Array = []

		for g in group:
			var d: Dictionary = g as Dictionary
			cores.append(float(d.get("core_avg", 0.0)))
			secs.append(float(d.get("secondary_avg", 0.0)))
			ments.append(float(d.get("mentals_avg", 0.0)))
			aths.append(float(d.get("athletic_avg", 0.0)))
			if use_size_adj_speed:
				var spd: float = float((d.get("stats", {}) as Dictionary).get("speed", 50.0))
				var wt:  float = float((d.get("physicals", {}) as Dictionary).get("weight_lb", 190.0))
				size_speed.append(clamp(spd * (wt / 300.0), 0.0, 100.0))

		cores.sort(); secs.sort(); ments.sort(); aths.sort()
		if use_size_adj_speed:
			size_speed.sort()

		# compute composite per player (serial is fine here; small N per pos)
		for g2 in group:
			var d2: Dictionary = g2 as Dictionary
			var core_pct: float = _percentile_in_sorted(cores,  float(d2.get("core_avg", 0.0)))
			var sec_pct:  float = _percentile_in_sorted(secs,   float(d2.get("secondary_avg", 0.0)))
			var men_pct:  float = _percentile_in_sorted(ments,  float(d2.get("mentals_avg", 0.0)))
			var ath_pct:  float = _percentile_in_sorted(aths,   float(d2.get("athletic_avg", 0.0)))

			if use_size_adj_speed:
				var spd2: float = float((d2.get("stats", {}) as Dictionary).get("speed", 50.0))
				var wt2:  float = float((d2.get("physicals", {}) as Dictionary).get("weight_lb", 190.0))
				var idx2: float = clamp(spd2 * (wt2 / 300.0), 0.0, 100.0)
				var szp: float  = _percentile_in_sorted(size_speed, idx2)
				ath_pct = clamp(0.85 * ath_pct + 0.15 * szp, 0.0, 1.0)

			d2["athletic_pct"] = ath_pct  # keep for downstream logic/printing

			var percentiles: Dictionary = {
				"pos": String(pos_key),
				"core_pct": core_pct,
				"sec_pct": sec_pct,
				"men_pct": men_pct,
				"ath_pct": ath_pct
			}
			var res: Dictionary = RecruitRater.compute(
				d2, positions_data, {}, class_rules, percentiles
			) as Dictionary

			d2["composite_score"] = _round2(float(res.get("composite", 0.0)))
			var star_score: float = (
				float(d2.get("core_avg",0.0)) * star_core_w
				+ float(d2["composite_score"]) * star_comp_w
			) / star_wsum
			d2["star_score"] = _round2(star_score)

	# ---------- PASS 3: stars & ranks ----------
	for pos3 in by_pos.keys():
		var arr: Array = by_pos[pos3] as Array
		var pos_lab: String = String(pos3)

		# rank in position by composite
		arr.sort_custom(func(a, b):
			return float((a as Dictionary).get("composite_score",0.0)) > float((b as Dictionary).get("composite_score",0.0))
		)
		for i in range(arr.size()):
			(arr[i] as Dictionary)["rank_in_pos"] = i + 1

		# star distribution within position (pos-value adjusted)
		var basis: Array = []
		for d in arr:
			var ss_val: float = float((d as Dictionary).get("star_score", 0.0))
			var pv: float = float(pos_value.get(pos_lab, 1.0))
			basis.append(ss_val * pv)
		basis.sort()

		for d2 in arr:
			var ss2: float = float(d2.get("star_score", 0.0))
			var pv2: float = float(pos_value.get(pos_lab, 1.0))
			var pct: float = _percentile_in_sorted(basis, ss2 * pv2)
			var stars: int = _stars_from_percentile(pct, star_thresholds, pos_lab, cap_specialists_to_3)

			# exceptional override
			var allow_positions: Array = exceptional.get("allow_for_positions", []) as Array
			var ok_pos: bool = allow_positions.has(pos_lab)
			var ath_ok: bool = float(d2.get("athletic_pct",0.0)) >= float(exceptional.get("athletic_pct_min", 0.90))
			var star_ok: bool = float(d2.get("star_score",0.0))   >= float(exceptional.get("star_score_min", 92.0))
			var is_spec: bool = (pos_lab == "K" or pos_lab == "P")
			var ignore_cap: bool = bool(exceptional.get("ignore_specialist_cap", false))
			if ok_pos and ath_ok and star_ok:
				if not is_spec or ignore_cap:
					stars = max(stars, 5)

			d2["star_rating"] = stars

	# overall rank by composite
	players.sort_custom(func(a, b):
		return float((a as Dictionary).get("composite_score",0.0)) > float((b as Dictionary).get("composite_score",0.0))
	)
	for i2 in range(players.size()):
		(players[i2] as Dictionary)["rank_overall"] = i2 + 1


# ----------------------------
# Public: single-player compute
# (cohort-aware if percentiles provided; otherwise falls back to avg/100)
# ----------------------------
static func compute(
	player: Dictionary,
	positions_data: Dictionary,
	stats_cfg_unused: Dictionary = {},     # kept for API symmetry
	class_rules: Dictionary = {},
	percentiles: Dictionary = {}           # {pos, core_pct, sec_pct, men_pct, ath_pct}
) -> Dictionary:
	var rec: Dictionary = class_rules.get("recruiting", {}) as Dictionary
	var comp_w: Dictionary = rec.get("composite_weights", {
		"athletic": 0.40, "core": 0.30, "secondary": 0.20, "mentals": 0.10
	}) as Dictionary
	var synergy_gain: float = float(rec.get("composite_synergy_gain", 0.15))

	var calib: Dictionary = rec.get("composite_calibration", {}) as Dictionary
	var shrink: float = float(calib.get("shrink_to_mean", 0.60))
	var g_bias: float = float(calib.get("global_bias", 0.0))
	var floor_v: float = float(calib.get("floor", 30.0))
	var cap_v:   float = float(calib.get("cap", 92.0))
	var bias_by_pos: Dictionary = calib.get("bias_by_pos", {}) as Dictionary

	var athletic_keys: Array = rec.get("athletic_keys", [
		"speed","acceleration","agility","balance","vertical_jump","broad_jump","strength"
	]) as Array
	var mental_keys: Array = rec.get("mental_keys", [
		"awareness","decision_making","discipline","work_ethic",
		"coachability","focus","composure","anticipation"
	]) as Array

	var pos: String = String(percentiles.get("pos", String(player.get("position","ATH"))))
	var roles: Dictionary = _roles_for_pos(positions_data, pos)
	var stats: Dictionary = player.get("stats", {}) as Dictionary

	var core_avg: float = _avg_keys(stats, roles.get("core", []) as Array)
	var sec_avg: float  = _avg_keys(stats, roles.get("secondary", []) as Array)
	var men_avg: float  = _avg_keys(stats, mental_keys)
	var ath_avg: float  = _avg_keys(stats, athletic_keys)

	# percentiles: provided by caller (cohort) or fallback to avg/100
	var core_pct: float = float(percentiles.get("core_pct", clamp(core_avg / 100.0, 0.0, 1.0)))
	var sec_pct:  float = float(percentiles.get("sec_pct",  clamp(sec_avg  / 100.0, 0.0, 1.0)))
	var men_pct:  float = float(percentiles.get("men_pct",  clamp(men_avg  / 100.0, 0.0, 1.0)))
	var ath_pct:  float = float(percentiles.get("ath_pct",  clamp(ath_avg  / 100.0, 0.0, 1.0)))

	# diminishing returns & synergy
	var ath_eff: float = pow(ath_pct, 0.90)
	var core_eff: float = pow(core_pct, 0.95)
	var sec_eff:  float = pow(sec_pct,  1.00)
	var men_eff:  float = pow(men_pct,  0.85)

	var w_ath: float = float(comp_w.get("athletic", 0.40))
	var w_cor: float = float(comp_w.get("core", 0.30))
	var w_sec: float = float(comp_w.get("secondary", 0.20))
	var w_men: float = float(comp_w.get("mentals", 0.10))
	var w_sum: float = max(0.0001, w_ath + w_cor + w_sec + w_men)

	var synergy: float = sqrt(max(0.0, ath_eff * core_eff))
	var comp_pct: float = (w_ath*ath_eff + w_cor*core_eff + w_sec*sec_eff + w_men*men_eff) / w_sum
	comp_pct = comp_pct * (1.0 + synergy_gain * (synergy - 0.5))

	# calibration to points
	var centered: float = comp_pct - 0.5
	var shrunk: float = 0.5 + shrink * centered
	var pos_bias: float = float(bias_by_pos.get(pos, 0.0))
	var comp_points: float = shrunk * 100.0 + g_bias + pos_bias
	var composite: float = _round2(clamp(comp_points, floor_v, cap_v))

	return {
		"composite": composite,
		"core_avg": _round2(core_avg),
		"secondary_avg": _round2(sec_avg),
		"mentals_avg": _round2(men_avg),
		"athletic_avg": _round2(ath_avg)
	}


# ----------------------------
# Thread worker: compute aggregates for one player
# Returns only the derived fields; caller writes them back.
# ----------------------------
static func _aggregate_one(
	player: Dictionary,
	role_cache: Dictionary,
	mental_keys: Array,
	athletic_keys: Array,
	risk_cap: float
) -> Dictionary:
	var pos: String = String(player.get("position","ATH"))
	var roles: Dictionary = role_cache.get(pos, {"core":[],"secondary":[]}) as Dictionary
	var stats: Dictionary = player.get("stats", {}) as Dictionary

	var core_avg: float = _avg_keys(stats, roles.get("core", []) as Array)
	var sec_avg: float  = _avg_keys(stats, roles.get("secondary", []) as Array)
	var mental_avg: float = _avg_keys(stats, mental_keys)
	var athletic_avg: float = _avg_keys(stats, athletic_keys)

	var injury_prone: float = float(stats.get("injury_proneness", 50.0))
	var discipline: float   = float(stats.get("discipline", 50.0))
	var risk: float = 0.0
	risk += (injury_prone - 50.0) * 0.08
	risk += max(0.0, 60.0 - discipline) * 0.1
	risk = clamp(risk, 0.0, risk_cap)

	return {
		"core_avg": core_avg,
		"secondary_avg": sec_avg,
		"mentals_avg": mental_avg,
		"athletic_avg": athletic_avg,
		"__risk": risk
	}


# ----------------------------
# Helpers
# ----------------------------
static func _roles_for_pos(positions_data: Dictionary, pos: String) -> Dictionary:
	var spec: Dictionary = positions_data.get(pos, {}) as Dictionary
	var dists: Dictionary = spec.get("distributions", {}) as Dictionary
	var core_list: Array = (spec.get("core_stats", []) as Array).duplicate()
	var secondary_list: Array = []
	for k in dists.keys():
		var role: String = String((dists[k] as Dictionary).get("role","other"))
		if role == "secondary" and not core_list.has(k):
			secondary_list.append(k)
	return {"core": core_list, "secondary": secondary_list}

static func _avg_keys(src: Dictionary, keys: Array) -> float:
	if keys.is_empty():
		return 0.0
	var s: float = 0.0
	var n: int = 0
	for k in keys:
		if src.has(k):
			s += float(src[k])
			n += 1
	return (s / float(n)) if n > 0 else 0.0

static func _percentile_in_sorted(sorted_vals: Array, v: float) -> float:
	var n: int = sorted_vals.size()
	if n == 0:
		return 0.0
	var i: int = 0
	while i < n and v > float(sorted_vals[i]):
		i += 1
	return clamp(float(i) / float(max(1, n - 1)), 0.0, 1.0)

static func _stars_from_percentile(pct: float, thresholds: Dictionary, pos: String, cap_specialists_to_3: bool) -> int:
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

static func _round2(x: float) -> float:
	return snappedf(x, 0.01)
