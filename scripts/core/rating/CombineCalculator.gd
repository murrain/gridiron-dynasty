extends RefCounted
class_name CombineCalculator
##
## CombineCalculator
## - compute_all(player, combine_cfg, tests_cfg) -> Dictionary of { test_key: value }
## - tests_cfg is the WHOLE combine_tests.json (with "defaults" and "tests")
## - combine_cfg is your main.json["combine_tuning"] (optional) for context adjustments
##

static func compute_all(player: Dictionary, combine_cfg: Dictionary, tests_cfg: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var defaults: Dictionary = tests_cfg.get("defaults", {}) as Dictionary
	var tests: Dictionary = tests_cfg.get("tests", {}) as Dictionary
	if tests.is_empty():
		return out

	for key in tests.keys():
		var test_cfg: Dictionary = (tests[key] as Dictionary).duplicate(true)
		out[key] = _compute_single(player, test_cfg, defaults, combine_cfg)

	return out


# -----------------------------
# Core per-test computation
# -----------------------------
static func _compute_single(player: Dictionary, test_cfg: Dictionary, defaults: Dictionary, combine_cfg: Dictionary) -> float:
	# Merge defaults in (test fields win)
	var cfg: Dictionary = _merged_with_defaults(test_cfg, defaults)

	# 1) Build a skill scalar t in [0..1] from weighted inputs + curve shaping
	var t: float = _weighted_skill_scalar(player, cfg)
	t = _apply_curve(t, cfg)

	# 2) Map scalar to test units (time / inches / reps / score / index)
	var value: float = _map_scalar_to_output(t, cfg)

	# 3) Add stochastic noise
	value = _apply_noise(value, cfg)

	# 4) Apply body/position adjustments (mass-aware)
	value = _apply_body_adjust(player, value, cfg)

	# 5) Apply contextual adjustments (fatigue/morale/boom-bust)
	value = _apply_context_adjustments(player, value, cfg, combine_cfg)

	# 5.5) Optional synergy bonus (e.g., elite speed+accel shave hundredths)
	value = _apply_synergy_bonus(player, value, cfg)

	# 6) Clamp to bounds, precision/integer formatting
	value = _format_and_clamp(value, cfg)

	return value


# -----------------------------
# Helpers: config merge & inputs
# -----------------------------
static func _merged_with_defaults(test_cfg: Dictionary, defaults: Dictionary) -> Dictionary:
	var merged: Dictionary = defaults.duplicate(true)
	for k in test_cfg.keys():
		var v: Variant = test_cfg[k]
		# deep-merge simple dicts we expect (map, noise, bounds, body_adjust, pos_overrides, curve, synergy_bonus)
		if merged.has(k) and merged[k] is Dictionary and v is Dictionary:
			var inner: Dictionary = merged[k] as Dictionary
			for kk in (v as Dictionary).keys():
				inner[kk] = (v as Dictionary)[kk]
			merged[k] = inner
		else:
			merged[k] = v
	return merged

static func _weighted_skill_scalar(player: Dictionary, cfg: Dictionary) -> float:
	var inputs: Array = cfg.get("inputs", []) as Array
	if inputs.is_empty():
		return 0.5

	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var phys: Dictionary = player.get("physicals", {}) as Dictionary

	var sum_w: float = 0.0
	var acc: float = 0.0
	for item in inputs:
		var it: Dictionary = item
		var w: float = float(it.get("weight", 1.0))
		if w <= 0.0:
			continue

		var src: String = String(it.get("src", "stat"))
		var v_norm: float = 0.5

		if src == "stat":
			var sname: String = String(it.get("name", ""))
			var sval: float = float(stats.get(sname, 50.0))
			v_norm = clamp(sval / 100.0, 0.0, 1.0)

		elif src == "physical":
			var pname: String = String(it.get("name", ""))
			var pval: float = float(phys.get(pname, 0.0))
			if it.has("map"):
				var imap: Dictionary = it["map"] as Dictionary
				var imin: float = float(imap.get("min", 0.0))
				var imax: float = float(imap.get("max", 100.0))
				var inv: bool = bool(imap.get("invert", false))
				var t: float = _inv_lerp(imin, imax, pval)
				if inv:
					t = 1.0 - t
				v_norm = clamp(t, 0.0, 1.0)
			else:
				v_norm = clamp(_inv_lerp(0.0, 100.0, pval), 0.0, 1.0)

		elif src == "const":
			v_norm = clamp(float(it.get("value", 0.5)), 0.0, 1.0)

		acc += v_norm * w
		sum_w += w

	if sum_w <= 0.0:
		return 0.5
	return clamp(acc / sum_w, 0.0, 1.0)


# -----------------------------
# Helpers: scalar curve shaping
# -----------------------------
static func _apply_curve(t: float, cfg: Dictionary) -> float:
	var curve: Dictionary = cfg.get("curve", {}) as Dictionary
	var mode: String = String(curve.get("mode", "none"))
	match mode:
		"ease_out_quart":
			# pushes mid-high values down unless truly elite; keeps 0 & 1 fixed
			var x: float = clamp(t, 0.0, 1.0)
			return 1.0 - pow(1.0 - x, 4.0)
		"ease_out_cubic":
			var x2: float = clamp(t, 0.0, 1.0)
			return 1.0 - pow(1.0 - x2, 3.0)
		"sqrt":
			return sqrt(max(0.0, t))
		"none":
			return t
		_:
			return t


# -----------------------------
# Helpers: mapping / noise
# -----------------------------
static func _map_scalar_to_output(t: float, cfg: Dictionary) -> float:
	var mapd: Dictionary = cfg.get("map", {}) as Dictionary
	var mode: String = String(mapd.get("mode", "lerp"))

	if mode == "none":
		var typ_str: String = String(cfg.get("type", "index"))
		if typ_str == "index":
			return t * 100.0
		return t

	var min_v: float = float(mapd.get("min", 0.0))
	var max_v: float = float(mapd.get("max", 100.0))
	var invert: bool = bool(mapd.get("invert", false))
	var s: float = t
	if invert:
		s = 1.0 - s
	return lerp(min_v, max_v, s)

static func _apply_noise(value: float, cfg: Dictionary) -> float:
	var noise: Dictionary = cfg.get("noise", {}) as Dictionary
	var dist: String = String(noise.get("dist","none"))
	if dist == "gauss":
		var sigma: float = float(noise.get("sigma", 0.0))
		if sigma > 0.0:
			value += StatHelpers.gaussian(0.0, sigma)
	return value


# -----------------------------
# Helpers: body / position adjust
# -----------------------------
static func _apply_body_adjust(player: Dictionary, value: float, cfg: Dictionary) -> float:
	var pos: String = String(player.get("position", "ATH"))
	var body_adj: Dictionary = cfg.get("body_adjust", {}) as Dictionary

	# Optional: merge position override body_adjust if present
	var pos_over_all: Dictionary = cfg.get("pos_overrides", {}) as Dictionary
	var pos_over: Dictionary = pos_over_all.get(pos, {}) as Dictionary
	if pos_over.has("body_adjust"):
		var ov: Dictionary = pos_over["body_adjust"] as Dictionary
		for k in ov.keys():
			body_adj[k] = ov[k]

	var mode: String = String(body_adj.get("mode", "none"))
	if mode == "none":
		return value

	var phys: Dictionary = player.get("physicals", {}) as Dictionary
	var wt: float = float(phys.get("weight_lb", 0.0))
	var anchor: float = float(body_adj.get("anchor_wt", 200.0))
	var delta10: float = (wt - anchor) / 10.0

	match mode:
		"time_mass_curve":
			var base_per10: float = float(body_adj.get("base_per10", 0.0))
			var extra_per10_over: float = float(body_adj.get("extra_per10_over_anchor", 0.0))
			var quad: bool = bool(body_adj.get("quad_above_anchor", true))
			var bonus_under: float = float(body_adj.get("bonus_per10_under", 0.0)) # negative -> faster when lighter

			if delta10 >= 0.0:
				var extra: float = extra_per10_over * (delta10 if not quad else (delta10 * delta10))
				value += delta10 * base_per10 + extra
			else:
				# modest bonus for being under anchor
				value += delta10 * (-bonus_under)  # delta10 negative; bonus_under usually negative too

		"time_mass":
			var coef: float = float(body_adj.get("coef_per_10lb", 0.0))
			value += delta10 * coef

		"power_mass_asym":
			var coef: float = float(body_adj.get("coef_per_10lb", 0.0))
			value += delta10 * coef
			
			if delta10 < 0.0:
				value += delta10 * coef * float(body_adj.get("under_mult", 2.0))
			else:
				value += delta10 * coef

		_:
			pass

	return value


# -----------------------------
# Helpers: synergy (e.g., speed+accel -> tiny time bonus)
# -----------------------------
static func _apply_synergy_bonus(player: Dictionary, value: float, cfg: Dictionary) -> float:
	var syn: Dictionary = cfg.get("synergy_bonus", {}) as Dictionary
	if syn.is_empty():
		return value
	if String(cfg.get("type", "index")) != "time":
		return value

	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var phys: Dictionary = player.get("physicals", {}) as Dictionary

	var sp: float = float(stats.get("speed", 0.0))
	var ac: float = float(stats.get("acceleration", 0.0))
	var sp_thr: float = float(syn.get("speed_thr", 90.0))
	var ac_thr: float = float(syn.get("accel_thr", 90.0))
	var scale: float = float(syn.get("scale", 0.03))

	# how far above thresholds (0..1), soft-capped
	var sp_over: float = max(0.0, (sp - sp_thr) / 10.0)
	var ac_over: float = max(0.0, (ac - ac_thr) / 10.0)
	sp_over = clamp(sp_over, 0.0, 1.0)
	ac_over = clamp(ac_over, 0.0, 1.0)

	var base_bonus: float = scale * sp_over * ac_over

	# fade with weight
	var w: float = float(phys.get("weight_lb", 999.0))
	var w_full: float = float(syn.get("weight_full_bonus_at", 195.0))
	var w_zero: float = float(syn.get("weight_zero_bonus_at", 210.0))
	var w_factor: float = 1.0
	if w >= w_zero:
		w_factor = 0.0
	elif w > w_full:
		var denom: float = max(1.0, (w_zero - w_full))
		w_factor = clamp(1.0 - (w - w_full) / denom, 0.0, 1.0)

	return value - base_bonus * w_factor


# -----------------------------
# Helpers: context adjustments
# -----------------------------
static func _apply_context_adjustments(player: Dictionary, value: float, cfg: Dictionary, combine_cfg: Dictionary) -> float:
	if combine_cfg.is_empty():
		return value

	var adj: Dictionary = combine_cfg.get("adjustments", {}) as Dictionary
	if adj.is_empty():
		return value

	var typ: String = String(cfg.get("type", "index"))
	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var fatigue: float = float(stats.get("fatigue", 50.0))
	var morale: float = float(stats.get("morale", 50.0))

	var fat_time_pct: float = float(adj.get("fatigue_time_pct_per_100", 0.0))
	var fat_pow_pct: float  = float(adj.get("fatigue_power_pct_per_100", 0.0))
	var morale_pct: float   = float(adj.get("morale_boon_pct_per_100", 0.0))

	var fat_scale: float = clamp(fatigue / 100.0, 0.0, 1.0)
	var mor_scale: float = clamp(morale / 100.0, 0.0, 1.0)

	match typ:
		"time":
			value *= (1.0 + fat_time_pct * fat_scale - morale_pct * mor_scale)
		"power", "reps", "score", "index":
			value *= (1.0 - fat_pow_pct * fat_scale + morale_pct * mor_scale)
		_:
			pass

	# Optional boom/bust day variance (tiny extra sigma)
	var bb_sigma: float = float(adj.get("boom_bust_day_sigma", 0.0))
	var bb_mult: float  = float(adj.get("boom_bust_sigma_mult", 1.0))
	var bb: float = bb_sigma * bb_mult
	if bb > 0.0:
		var bump: float = StatHelpers.gaussian(0.0, bb)
		value *= (1.0 + bump)

	return value


# -----------------------------
# Helpers: clamp & format
# -----------------------------
static func _format_and_clamp(value: float, cfg: Dictionary) -> float:
	var bounds: Dictionary = cfg.get("bounds", {}) as Dictionary
	if not bounds.is_empty():
		var bmin: float = float(bounds.get("min", -1e12))
		var bmax: float = float(bounds.get("max",  1e12))
		value = clamp(value, bmin, bmax)

	if bool(cfg.get("integer", false)):
		return float(int(round(value)))

	var prec: int = int(cfg.get("precision", 2))
	var step: float = pow(10.0, -prec)
	return snappedf(value, step)


# -----------------------------
# Math utils
# -----------------------------
static func _inv_lerp(a: float, b: float, v: float) -> float:
	if a == b:
		return 0.0
	return (v - a) / (b - a)
