extends Node
class_name PlayerGenerator

# Inject these from your runner (e.g., GenerateClassOnce.gd)
var positions_data: Dictionary = {}   # unified positions.json
var stats_cfg: Dictionary = {}        # stats.json (for _all_stat_names)
var names_cfg: Dictionary = {}        # names.json
var main_cfg: Dictionary = {}         # merged save config (save-overrides-main)
var class_rules: Dictionary = {}      # main_cfg["class_rules"]

var superstar_candidates: Array = []  # holds compact summaries for console/logs

# --------------------------------
# Public API
# --------------------------------

func generate_class(class_size: int, gaussian_share: float) -> Array:
	var players: Array = []
	var id_counter: int = 1

	# Pass 1: position quotas (locked to position)
	var quotas: Dictionary = class_rules.get("position_quotas", {})
	for pos_key in quotas.keys():
		var pos: String = String(pos_key)
		var need: int = int(quotas[pos_key])
		for i in range(need):
			var p: Dictionary = _generate_for_position(pos)
			id_counter = _finalize_player(p, "quota", false, players, id_counter)

	# Pass 2 & 3: fill remainder
	var remaining: int = max(0, class_size - players.size())
	var gaussian_count: int = int(round(float(remaining) * gaussian_share))
	var chaos_count: int = max(0, remaining - gaussian_count)

	id_counter = _emit_generalists(gaussian_count, true,  "gauss", players, id_counter)
	id_counter = _emit_generalists(chaos_count,   false, "chaos", players, id_counter)

	return players

# Compatibility wrapper if anything still calls the old name
func generate_player_for_position(pos: String) -> Dictionary:
	return _generate_for_position(pos)

# --------------------------------
# Core generators
# --------------------------------

# Expect positions_data[pos] to have: {distributions, noncore_outlier, core_stats?, physicals?}
func _generate_for_position(pos: String) -> Dictionary:
	var spec: Dictionary = positions_data.get(pos, {})
	var dists: Dictionary = spec.get("distributions", {})
	var outlier: Dictionary = spec.get("noncore_outlier", {})

	var p: Dictionary = {
		"id": 0,
		"name": random_name(),
		"position": pos,
		"gen_mode": "quota",
		"stats": {},
		"hidden_traits": []
	}

	# ratings
	for stat_name in _all_stat_names():
		if dists.has(stat_name):
			var d: Dictionary = dists[stat_name]
			var mu: float = float(d.get("mu", 55.0))
			var sigma: float = float(d.get("sigma", 12.0))
			var cap_pct: float = float(d.get("cap_pct", 1.0))
			var role: String = String(d.get("role", "other"))
			var synthetic: Array = _synthetic_percentile_source()
			p["stats"][stat_name] = _round2(StatHelpers.sample_with_caps(mu, sigma, cap_pct, synthetic, role, outlier))
		else:
			p["stats"][stat_name] = _round2(clamp(StatHelpers.gaussian(55.0, 12.0), 0.0, 100.0))

	# physicals (real units) from positions.json
	p["physicals"] = generate_physicals(pos)

	# superstar check on finished-product/current ratings
	if _qualifies_superstar(p, 85.0):
		_record_superstar(p)

	return p

func generate_generalist(use_gaussian: bool) -> Dictionary:
	var p: Dictionary = {
		"id": 0,
		"name": random_name(),
		"position": "ATH",
		"gen_mode": "generalist",
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

# --------------------------------
# DRY helpers for finalization & emission
# --------------------------------

func _finalize_player(p: Dictionary, mode: String, auto_fit: bool, players: Array, id_counter: int) -> int:
	# Decide position for generalists
	if auto_fit:
		p["position"] = best_fit_position(p["stats"])

	# Tag mode & id
	p["gen_mode"] = mode
	p["id"] = id_counter
	id_counter += 1

	# Ensure physicals exist
	if not p.has("physicals") or (p["physicals"] as Dictionary).is_empty():
		p["physicals"] = generate_physicals(String(p["position"]))

	# Superstar tag (based on finished-product/current ratings)
	if _qualifies_superstar(p, 85.0):
		_record_superstar(p)

	# Store
	players.append(p)
	return id_counter

func _emit_generalists(count: int, use_gaussian: bool, mode: String, players: Array, id_counter: int) -> int:
	for i in range(count):
		var p: Dictionary = generate_generalist(use_gaussian)
		id_counter = _finalize_player(p, mode, true, players, id_counter)
	return id_counter

# --------------------------------
# Position fit & scoring
# --------------------------------

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

# --------------------------------
# Freaks (anti-positional boosts)
# --------------------------------

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
		pos_core[pos_key] = positions_data[pos_key].get("core_stats", [])

	var used: Dictionary = {}
	for i in range(count):
		var pool: Array = players.filter(func(pp): return not used.has(pp["id"]))
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

		# find target percentile within same-position peers
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

		if not pl.has("hidden_traits"):
			pl["hidden_traits"] = []
		(pl["hidden_traits"] as Array).append("Freak:" + chosen)
		used[pl["id"]] = true

# --------------------------------
# De-aging finished products → HS stats
# --------------------------------

# deage_cfg: { core_pct_min/max, other_pct_min/max, core_var/other_var, noise_min/max, floor, ceil }
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
		var core_list: Array = spec.get("core_stats", [])

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

# --------------------------------
# Physicals from positions.json
# --------------------------------

func generate_physicals(pos: String) -> Dictionary:
	var spec: Dictionary = positions_data.get(pos, {})
	if spec.is_empty():
		spec = positions_data.get("ATH", {})  # optional ATH default if you add it
	var pphys: Dictionary = spec.get("physicals", {})
	var out: Dictionary = {}

	for key in pphys.keys():
		var cfg: Dictionary = pphys[key]
		var mu: float = float(cfg.get("mu", 0.0))
		var sigma: float = float(cfg.get("sigma", 1.0))
		var vmin: float = float(cfg.get("min", 0.0))
		var vmax: float = float(cfg.get("max", 9999.0))
		var step: float = float(cfg.get("step", 0.01))

		var val: float = clamp(StatHelpers.gaussian(mu, sigma), vmin, vmax)
		out[key] = _round2(snappedf(val, step))  # snap to step, then clean to 2dp
	return out

# --------------------------------
# Superstar detection
# --------------------------------

func _qualifies_superstar(p: Dictionary, threshold: float = 85.0, require_all_core: bool = false) -> bool:
	var pos: String = String(p.get("position", "ATH"))
	# Skip special teams positions
	if pos in ["K", "P"]:
		return false
	var cores: Array = positions_data.get(pos, {}).get("core_stats", [])
	if cores.is_empty():
		return false
	var stats: Dictionary = p.get("stats", {})
	if require_all_core:
		for c in cores:
			if float(stats.get(c, -1.0)) < threshold:
				return false
		return true
	# else: average core check
	var s: float = 0.0
	var cnt: int = 0
	for c in cores:
		if stats.has(c):
			s += float(stats[c])
			cnt += 1
	return (cnt > 0 and (s / float(cnt)) >= threshold)

func _record_superstar(p: Dictionary) -> void:
	if not p.has("tags"):
		p["tags"] = []
	(p["tags"] as Array).append("PotentialSuperstar")
	var pos: String = String(p.get("position", "ATH"))
	var cores: Array = positions_data.get(pos, {}).get("core_stats", [])
	var summary_core := {}
	for c in cores:
		if (p["stats"] as Dictionary).has(c):
			summary_core[c] = _round2(float(p["stats"][c]))
	superstar_candidates.append({
		"position": pos,
		"name": p.get("name","Unknown"),
		"core": summary_core
	})

# --------------------------------
# Utils
# --------------------------------

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

func _round2(x: float) -> float:
	return snappedf(x, 0.01)
