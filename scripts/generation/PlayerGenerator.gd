extends Node
class_name PlayerGenerator

# Inject these from your runner
var positions_data: Dictionary = {}   # unified positions.json (now with "archetypes")
var stats_cfg: Dictionary = {}        # stats.json (for _all_stat_names)
var names_cfg: Dictionary = {}        # names.json
var main_cfg: Dictionary = {}         # merged save config (save-overrides-main)
var class_rules: Dictionary = {}      # main_cfg["class_rules"]

var superstar_candidates: Array = []  # compact logs

const SPECIALISTS := ["K","P"]

# -------------------------------------------------------------------
# Public API
# -------------------------------------------------------------------

func generate_class(class_size: int, gaussian_share: float) -> Array:
	var players: Array = []
	var id_counter: int = 1

	# Pass 1: quotas (locked to position, archetype applied during sampling)
	var quotas: Dictionary = class_rules.get("position_quotas", {})
	for pos_key in quotas.keys():
		var pos: String = String(pos_key)
		var need: int = int(quotas[pos_key])
		for i in range(need):
			var p: Dictionary = _generate_for_position(pos)
			p["id"] = id_counter
			id_counter += 1
			if _qualifies_superstar(p, 85.0, false):
				add_tags(p, ["PotentialSuperstar"])
			players.append(p)

	# Pass 2 & 3: fill to class size (generalists → best-fit → archetype soft push)
	var remaining: int = max(0, class_size - players.size())
	var gaussian_count: int = int(round(float(remaining) * gaussian_share))
	var chaos_count: int = max(0, remaining - gaussian_count)

	for i in range(gaussian_count):
		var p: Dictionary = generate_generalist(true)
		_finalize_generalist(p)
		p["id"] = id_counter
		id_counter += 1
		players.append(p)

	for i in range(chaos_count):
		var p: Dictionary = generate_generalist(false)
		_finalize_generalist(p)
		p["id"] = id_counter
		id_counter += 1
		players.append(p)

	return players

# Compatibility wrapper
func generate_player_for_position(pos: String) -> Dictionary:
	return _generate_for_position(pos)

# -------------------------------------------------------------------
# Core generators
# -------------------------------------------------------------------

# Quota generator: samples directly from (base dists + archetype overrides)
func _generate_for_position(pos: String) -> Dictionary:
	var arche: String = _pick_archetype(pos)
	var eff_core: Array = _effective_core_stats(pos, arche)

	var adj_dists: Dictionary = _build_adjusted_dists(pos, arche)

	var p: Dictionary = {
		"id": 0,
		"name": random_name(),
		"position": pos,
		"gen_mode": "quota",
		"archetype": arche,
		"core_stats_effective": eff_core,
		"stats": {},
		"hidden_traits": []
	}

	# Sample ratings with adjusted distributions
	var outlier: Dictionary = positions_data.get(pos, {}).get("noncore_outlier", {})
	var synthetic: Array = _synthetic_percentile_source()
	for stat_name in _all_stat_names():
		if adj_dists.has(stat_name):
			var d: Dictionary = adj_dists[stat_name]
			var mu: float = float(d.get("mu", 55.0))
			var sigma: float = float(d.get("sigma", 10.0))
			var cap_pct: float = float(d.get("cap_pct", 0.99))
			var role_str: String = String(d.get("role", d.get("role_str", "other")))
			p["stats"][stat_name] = _round2(StatHelpers.sample_with_caps(mu, sigma, cap_pct, synthetic, role_str, outlier))
		else:
			p["stats"][stat_name] = _round2(clamp(StatHelpers.gaussian(55.0, 12.0), 0.0, 100.0))

	# Phys with bias
	p["physicals"] = _generate_physicals_with_bias(pos, arche)

	return p

# Generalist base sampler
func generate_generalist(use_gaussian: bool) -> Dictionary:
	var p: Dictionary = {
		"id": 0,
		"name": random_name(),
		"position": "ATH",
		"gen_mode": "generalist",
		"archetype": "",
		"core_stats_effective": [],
		"stats": {},
		"hidden_traits": []
	}
	for stat_name in _all_stat_names():
		if use_gaussian:
			p["stats"][stat_name] = _round2(clamp(StatHelpers.gaussian(60.0, 12.0), 0.0, 100.0))
		else:
			if randf() < 0.30:
				p["stats"][stat_name] = _round2(randf_range(70.0, 100.0))
			else:
				p["stats"][stat_name] = _round2(randf_range(20.0, 90.0))
	return p

# After best-fit, select archetype and softly push stats + bias physicals
func _finalize_generalist(p: Dictionary) -> void:
	p["position"] = best_fit_position(p["stats"])
	p["gen_mode"] = "gauss" if _is_gaussian_generalist(p) else "chaos"

	var pos: String = String(p["position"])
	var arche: String = _pick_archetype(pos)
	p["archetype"] = arche
	p["core_stats_effective"] = _effective_core_stats(pos, arche)

	# soft push existing stats toward archetype flavor (mu_add applied softly)
	_soft_nudge_stats_with_archetype(p["stats"], pos, arche, 1.0) # 1.0 = full mu_add; change to 0.6 if you want lighter touch

	# generate/bias physicals
	p["physicals"] = _generate_physicals_with_bias(pos, arche)

	if _qualifies_superstar(p, 85.0, false):
		add_tags(p, ["PotentialSuperstar"])

func _is_gaussian_generalist(p: Dictionary) -> bool:
	return String(p.get("gen_mode", "")) == "generalist" and _average_value(p["stats"]) >= 60.0

# -------------------------------------------------------------------
# Position fit & scoring
# -------------------------------------------------------------------

func best_fit_position(stats: Dictionary) -> String:
	var best_pos: String = "ATH"
	var best_score: float = -1e9
	for pos_key in positions_data.keys():
		var pos: String = String(pos_key)
		var score: float = _score_for_position(stats, pos)
		if score > best_score:
			best_score = score
			best_pos = pos
	return best_pos

func _score_for_position(stats: Dictionary, pos: String) -> float:
	var cores: Array = positions_data.get(pos, {}).get("core_stats", [])
	if cores.is_empty():
		return 0.0
	var s: float = 0.0
	for c in cores:
		s += float(stats.get(c, 0.0))
	return s / float(cores.size())

# -------------------------------------------------------------------
# Freaks (anti-positional boosts)
# -------------------------------------------------------------------

func assign_dynamic_freaks(players: Array, max_freaks: int, pmin: float, pmax: float) -> void:
	var count: int = randi_range(0, max(0, max_freaks))
	if count == 0:
		return

	# group by position
	var by_pos: Dictionary = {}
	for pos_key in positions_data.keys():
		by_pos[pos_key] = []
	for p in players:
		var arr: Array = by_pos.get(p["position"], [])
		arr.append(p)
		by_pos[p["position"]] = arr

	# precompute cores
	var pos_core: Dictionary = {}
	for pos_key in positions_data.keys():
		var base_core: Array = positions_data[pos_key].get("core_stats", [])
		pos_core[pos_key] = base_core

	var used: Dictionary = {}
	for i in range(count):
		var pool: Array = players.filter(func(pp): return not used.has((pp as Dictionary).get("id")))
		if pool.is_empty():
			break
		var pl: Dictionary = pool[randi() % pool.size()]
		var pos: String = String(pl["position"])
		var core: Array = pos_core.get(pos, [])
		var all_stats: Array = _all_stat_names()
		var non_core: Array = all_stats.filter(func(n): return not core.has(n))
		if non_core.is_empty():
			continue

		var chosen: String = String(non_core[randi() % non_core.size()])
		var vals: Array = []
		for q in by_pos.get(pos, []):
			var qd: Dictionary = q
			if (qd["stats"] as Dictionary).has(chosen):
				vals.append(float(qd["stats"][chosen]))
		vals.sort()
		if vals.is_empty():
			continue

		var target_pct: float = randf_range(pmin, pmax)
		var target_val: float = StatHelpers.percentile_value(vals, target_pct)
		var cur: float = float(pl["stats"].get(chosen, 0.0))
		pl["stats"][chosen] = _round2(max(cur, target_val))

		add_tags(pl, ["Freak:"+chosen])
		used[pl["id"]] = true

# -------------------------------------------------------------------
# De-aging finished products → HS stats
# -------------------------------------------------------------------

func de_age_players(players: Array, positions_data_in: Dictionary, deage_cfg: Dictionary) -> void:
	var cfgd: Dictionary = deage_cfg if deage_cfg != null else {}

	var floor_v: float = float(cfgd.get("floor", 20.0))
	var ceil_v: float  = float(cfgd.get("ceil", 100.0))
	var nmin: float    = float(cfgd.get("noise_min", -3.0))
	var nmax: float    = float(cfgd.get("noise_max",  3.0))

	var core_min: float = float(cfgd.get("core_pct_min", 0.60))
	var core_max: float = float(cfgd.get("core_pct_max", 0.75))
	var oth_min:  float = float(cfgd.get("other_pct_min", 0.40))
	var oth_max:  float = float(cfgd.get("other_pct_max", 0.65))

	var core_var: float = float(cfgd.get("core_var", 0.10))
	var oth_var:  float = float(cfgd.get("other_var", 0.20))

	for p in players:
		var pos: String = String(p.get("position", "ATH"))
		var spec: Dictionary = positions_data_in.get(pos, {})
		var dists: Dictionary = spec.get("distributions", {})
		var core_list: Array = []
		if p.has("core_stats_effective"):
			core_list = p["core_stats_effective"]
		else:
			core_list = spec.get("core_stats", [])

		var new_stats: Dictionary = {}
		for stat in (p["potential"] as Dictionary).keys():
			var finished_val: float = float(p["potential"][stat])

			var role: String = "other"
			if dists.has(stat):
				role = String((dists[stat] as Dictionary).get("role", "other"))
			elif core_list.has(stat):
				role = "core"

			var base_min: float = core_min if role == "core" else oth_min
			var base_max: float = core_max if role == "core" else oth_max
			var var_rng:  float = core_var if role == "core" else oth_var

			var base_pct: float = randf_range(base_min, base_max)
			var indiv_var: float = randf_range(-var_rng, var_rng)
			var final_pct: float = clamp(base_pct + indiv_var, 0.0, 1.0)
			var noise: float = randf_range(nmin, nmax)

			var hs_val: float = clamp(finished_val * final_pct + noise, 0.0, ceil_v)
			if finished_val >= floor_v * 1.25:
				hs_val = max(hs_val, floor_v)

			new_stats[stat] = _round2(hs_val)

		p["stats"] = new_stats

# -------------------------------------------------------------------
# Archetype helpers
# -------------------------------------------------------------------

func _pick_archetype(pos: String) -> String:
	var spec: Dictionary = positions_data.get(pos, {})
	var arcs: Dictionary = spec.get("archetypes", {})
	if arcs.is_empty():
		return ""
	var keys: Array = arcs.keys()
	var total: float = 0.0
	var weights: Array = []
	for k in keys:
		var w: float = float((arcs[k] as Dictionary).get("weight", 1.0))
		weights.append(w)
		total += w
	var r: float = randf() * total
	var accum: float = 0.0
	for i in range(keys.size()):
		accum += float(weights[i])
		if r <= accum:
			return String(keys[i])
	return String(keys.back())

func _effective_core_stats(pos: String, arche: String) -> Array:
	var spec: Dictionary = positions_data.get(pos, {})
	var arcs: Dictionary = spec.get("archetypes", {})
	if arche != "" and arcs.has(arche):
		var ov: Dictionary = arcs[arche]
		if ov.has("core_stats_override"):
			return (ov["core_stats_override"] as Array).duplicate()
	return (spec.get("core_stats", []) as Array).duplicate()

# Clone and apply dist_overrides -> returns adjusted distributions
func _build_adjusted_dists(pos: String, arche: String) -> Dictionary:
	var spec: Dictionary = positions_data.get(pos, {})
	var base: Dictionary = (spec.get("distributions", {}) as Dictionary).duplicate(true)
	var arcs: Dictionary = spec.get("archetypes", {})
	if arche == "" or not arcs.has(arche):
		return base

	var ov: Dictionary = arcs[arche]
	var dist_ov: Dictionary = ov.get("dist_overrides", {})
	if dist_ov.is_empty():
		return base

	var out: Dictionary = {}
	for k in base.keys():
		out[k] = (base[k] as Dictionary).duplicate(true)

	for stat_name in dist_ov.keys():
		var o: Dictionary = dist_ov[stat_name]
		if not out.has(stat_name):
			continue # only override existing distributions
		var d: Dictionary = (out[stat_name] as Dictionary)
		if o.has("mu_add"):
			d["mu"] = float(d.get("mu", 55.0)) + float(o["mu_add"])
		if o.has("sigma_mult"):
			d["sigma"] = float(d.get("sigma", 10.0)) * float(o["sigma_mult"])
		if o.has("role"):
			d["role"] = String(o["role"])
		if o.has("cap_pct"):
			d["cap_pct"] = float(o["cap_pct"])
		out[stat_name] = d
	return out

# Soft nudge: add mu_add to already-sampled stat values (generalists)
func _soft_nudge_stats_with_archetype(stats: Dictionary, pos: String, arche: String, scale: float = 1.0) -> void:
	if arche == "":
		return
	var spec: Dictionary = positions_data.get(pos, {})
	var arcs: Dictionary = spec.get("archetypes", {})
	if not arcs.has(arche):
		return
	var dist_ov: Dictionary = (arcs[arche] as Dictionary).get("dist_overrides", {})
	if dist_ov.is_empty():
		return
	for stat_name in dist_ov.keys():
		var o: Dictionary = dist_ov[stat_name]
		if o.has("mu_add") and stats.has(stat_name):
			var delta: float = float(o["mu_add"]) * scale
			stats[stat_name] = _round2(clamp(float(stats[stat_name]) + delta, 0.0, 100.0))

# Physicals with bias
func _generate_physicals_with_bias(pos: String, arche: String) -> Dictionary:
	var base: Dictionary = generate_physicals(pos)
	if arche == "":
		return base
	var spec: Dictionary = positions_data.get(pos, {})
	var arcs: Dictionary = spec.get("archetypes", {})
	if not arcs.has(arche):
		return base
	var pb: Dictionary = (arcs[arche] as Dictionary).get("phys_bias", {})
	if pb.is_empty():
		return base

	# Apply simple mu_add-like deltas, then clamp to pos ranges
	var phys_spec: Dictionary = spec.get("physicals", {})
	var out: Dictionary = base.duplicate()
	for key in pb.keys():
		var adj: Dictionary = pb[key]
		var delta: float = float(adj.get("mu_add", 0.0))
		if out.has(key):
			out[key] = _round2(_clamp_to_phys(float(out[key]) + delta, phys_spec.get(key, {})))
	return out

func _clamp_to_phys(v: float, cfg: Dictionary) -> float:
	var vmin: float = float(cfg.get("min", -1e9))
	var vmax: float = float(cfg.get("max", 1e9))
	var step: float = float(cfg.get("step", 0.1))
	return snappedf(clamp(v, vmin, vmax), step)

# -------------------------------------------------------------------
# Physicals base
# -------------------------------------------------------------------

func generate_physicals(pos: String) -> Dictionary:
	var spec: Dictionary = positions_data.get(pos, {})
	if spec.is_empty():
		spec = positions_data.get("ATH", {})
	var pphys: Dictionary = spec.get("physicals", {})
	var out: Dictionary = {}

	for key in pphys.keys():
		var cfg: Dictionary = pphys[key]
		var mu: float = float(cfg.get("mu", 0.0))
		var sigma: float = float(cfg.get("sigma", 1.0))
		var vmin: float = float(cfg.get("min", 0.0))
		var vmax: float = float(cfg.get("max", 9999.0))
		var step: float = float(cfg.get("step", 0.1))

		var val: float = clamp(StatHelpers.gaussian(mu, sigma), vmin, vmax)
		out[key] = _round2(snappedf(val, step))
	return out

# -------------------------------------------------------------------
# Superstar tagging
# -------------------------------------------------------------------

# require_all_core=false → average core >= threshold
func _qualifies_superstar(p: Dictionary, threshold: float = 85.0, require_all_core: bool = false) -> bool:
	var pos: String = String(p.get("position", "ATH"))
	if SPECIALISTS.has(pos):
		return false
	var cores: Array = []
	if p.has("core_stats_effective"):
		cores = p["core_stats_effective"]
	else:
		cores = positions_data.get(pos, {}).get("core_stats", [])
	if cores.is_empty():
		return false
	var stats: Dictionary = p.get("stats", {})
	if require_all_core:
		for c in cores:
			if float(stats.get(c, -1.0)) < threshold:
				return false
		return true
	# average
	var s: float = 0.0
	var cnt: int = 0
	for c in cores:
		if stats.has(c):
			s += float(stats[c])
			cnt += 1
	return (cnt > 0 and (s / float(cnt)) >= threshold)

# -------------------------------------------------------------------
# Tag utilities
# -------------------------------------------------------------------

func add_tags(p: Dictionary, tags: Array) -> void:
	if not p.has("tags"):
		p["tags"] = []
	var arr: Array = p["tags"]
	for t in tags:
		var tag: String = String(t)
		if not arr.has(tag):
			arr.append(tag)
	p["tags"] = arr

# -------------------------------------------------------------------
# Utils
# -------------------------------------------------------------------

func random_name() -> String:
	var f: Array = names_cfg.get("first_names", [])
	var l: Array = names_cfg.get("last_names", [])
	if f.is_empty() or l.is_empty():
		return "Player " + str(randi_range(1000, 9999))
	return "%s %s" % [f[randi() % f.size()], l[randi() % l.size()]]

func save_to_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func _all_stat_names() -> Array:
	var arr: Array = []
	for s in stats_cfg.get("stats", []):
		var sd: Dictionary = s
		if sd.get("type", "base") == "base":
			arr.append(sd["name"])
	return arr

func _synthetic_percentile_source() -> Array:
	var a: Array = []
	for i in range(0, 101):
		a.append(float(i))
	return a

func _average_value(d: Dictionary) -> float:
	var sumv: float = 0.0
	var n: int = 0
	for k in d.keys():
		sumv += float(d[k])
		n += 1
	return (sumv / float(max(1, n)))

func _round2(x: float) -> float:
	return snappedf(x, 0.01)