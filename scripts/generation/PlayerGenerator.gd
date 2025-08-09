extends Node
class_name PlayerGenerator

# Data loaded from config files
var positions_data: Dictionary = {}   # unified positions.json
var stats_cfg: Dictionary = {}        # stats.json (for _all_stat_names)
var names_cfg: Dictionary = {}        # names.json
var main_cfg: Dictionary = {}         # american_football/main.json (entry point)
var class_rules: Dictionary = {}      # main_cfg["class_rules"]

# -------------------------
# Entry
# -------------------------
func _ready() -> void:
	randomize()

	# --- load configs (update these calls to match your ConfigLoader) ---
	var cfg := ConfigLoader.new()
	main_cfg = cfg.load_main()                                  # res://configs/sports/american_football/main.json
	positions_data = cfg.load_positions()                       # res://configs/sports/american_football/positions.json
	stats_cfg = cfg.load_stats()                                 # res://configs/sports/american_football/stats.json
	names_cfg = cfg.load_names()                                 # res://configs/sports/american_football/names.json
	class_rules = main_cfg.get("class_rules", {})                # quotas + knobs

	# optional RNG control
	if main_cfg.has("random_seed"):
		seed(int(main_cfg["random_seed"]))

	# --- knobs from class_rules ---
	var class_size: int = int(class_rules.get("class_size", 2000))
	var gaussian_share: float = float(class_rules.get("gaussian_share", 0.75))
	var max_freaks: int = int(class_rules.get("max_freaks_per_class", 5))
	var freak_min: float = float(class_rules.get("freak_percentile_min", 0.80))
	var freak_max: float = float(class_rules.get("freak_percentile_max", 0.90))

	# --- pipeline ---
	var players: Array = generate_class(class_size, gaussian_share)

	assign_dynamic_freaks(players, max_freaks, freak_min, freak_max)

	# finished product → potential, then de-age to HS stats
	for p in players:
		if not p.has("potential") or (p["potential"] as Dictionary).is_empty():
			p["potential"] = (p["stats"] as Dictionary).duplicate(true)

	de_age_players(players, positions_data, main_cfg.get("deage", {}))

	# save with college grad year = starting_year + 8 (4 HS + 4 college)
	var current_year: int = int(main_cfg.get("starting_year", 2025))
	var college_grad_year: int = current_year + 8
	var out_path: String = "res://configs/sports/american_football/CLASS_OF_%d.json" % college_grad_year
	save_to_json(out_path, players)
	print("Generated ", players.size(), " prospects → ", out_path)

# -------------------------
# Class generation
# -------------------------
func generate_class(class_size: int, gaussian_share: float) -> Array:
	var players: Array = []
	var id_counter: int = 1

	# Pass 1: Quotas (position-locked) — read from class_rules.position_quotas
	var quotas: Dictionary = class_rules.get("position_quotas", {})
	for pos_key in quotas.keys():
		var pos: String = String(pos_key)
		var need: int = int(quotas[pos_key])
		for i in range(need):
			var p: Dictionary = _generate_for_position(pos)
			p["id"] = id_counter
			id_counter += 1
			players.append(p)

	# Pass 2 + 3: Fill to class_size
	var remaining: int = max(0, class_size - players.size())
	var gaussian_count: int = int(round(float(remaining) * gaussian_share))
	var chaos_count: int = max(0, remaining - gaussian_count)

	# Gaussian generalists → best-fit
	for i in range(gaussian_count):
		var p: Dictionary = generate_generalist(true)
		p["position"] = best_fit_position(p["stats"])
		p["gen_mode"] = "gauss"
		p["id"] = id_counter
		id_counter += 1
		players.append(p)

	# Weighted chaos → best-fit
	for i in range(chaos_count):
		var p: Dictionary = generate_generalist(false)
		p["position"] = best_fit_position(p["stats"])
		p["gen_mode"] = "chaos"
		p["id"] = id_counter
		id_counter += 1
		players.append(p)

	return players

# Expect: positions_data is the loaded unified positions.json Dictionary
# Uses StatHelpers.sample_with_caps(mu, sigma, cap_pct, percentile_source, role, outlier)
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

	# Assign all known stats; use distribution when provided, else a global fallback
	for stat_name in _all_stat_names():
		if dists.has(stat_name):
			var d: Dictionary = dists[stat_name]
			var mu: float = float(d["mu"])
			var sigma: float = float(d["sigma"])
			var cap_pct: float = float(d["cap_pct"])
			var role: String = String(d["role"])  # "core" | "secondary" | "other"
			var synthetic: Array = _synthetic_percentile_source()
			p["stats"][stat_name] = StatHelpers.sample_with_caps(mu, sigma, cap_pct, synthetic, role, outlier)
		else:
			p["stats"][stat_name] = clamp(StatHelpers.gaussian(55.0, 12.0), 0.0, 100.0)

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
			p["stats"][stat_name] = clamp(StatHelpers.gaussian(60.0, 12.0), 0.0, 100.0)
		else:
			if randf() < 0.30:
				p["stats"][stat_name] = randf_range(70.0, 100.0)
			else:
				p["stats"][stat_name] = randf_range(20.0, 90.0)
	return p

func best_fit_position(stats: Dictionary) -> String:
	var best_pos: String = "ATH"
	var best_score: float = -1e9
	# Derive candidate positions from positions_data keys
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

# Inject a few dynamic "anti-positional" freak boosts on NON-core stats per position
func assign_dynamic_freaks(players: Array, max_freaks: int, pmin: float, pmax: float) -> void:
	var count: int = randi_range(0, max(0, max_freaks))
	if count == 0:
		return

	# Group players by position
	var by_pos: Dictionary = {}
	for pos_key in positions_data.keys():
		by_pos[pos_key] = []
	for p in players:
		var arr: Array = by_pos.get(p["position"], [])
		arr.append(p)
		by_pos[p["position"]] = arr

	# Precompute core lists
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

		# Find target percentile within same-position peers
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
		pl["stats"][chosen] = max(cur, target_val)

		if not pl.has("hidden_traits"):
			pl["hidden_traits"] = []
		(pl["hidden_traits"] as Array).append("Freak:" + chosen)
		used[pl["id"]] = true

# De-age finished product ratings into HS-level stats using role-aware percentages
# positions_data: unified positions.json
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

			new_stats[stat] = hs_val
		p["stats"] = new_stats

# -------------------------
# Utils
# -------------------------
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