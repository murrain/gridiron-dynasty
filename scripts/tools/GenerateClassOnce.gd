extends Node

# Optional: run in editor via the "play scene" button
# @tool

func run() -> void:
	# 1) Load configs
	var loader := ConfigLoader.new()
	var main_cfg: Dictionary = loader.load_main()                  # res://configs/sports/american_football/main.json
	var positions: Dictionary = loader.load_positions()            # res://configs/sports/american_football/positions.json
	var stats_cfg: Dictionary = loader.load_stats()                # res://configs/sports/american_football/stats.json
	var names_cfg: Dictionary = loader.load_names()                # res://configs/sports/american_football/names.json

	# 2) Create & wire the generator
	var gen := PlayerGenerator.new()
	gen.main_cfg = main_cfg
	gen.positions_data = positions
	gen.stats_cfg = stats_cfg
	gen.names_cfg = names_cfg
	gen.class_rules = main_cfg.get("class_rules", {})

	# Optional: seed RNG if present
	if main_cfg.has("random_seed"):
		seed(int(main_cfg["random_seed"]))
	else:
		randomize()

	# 3) Pull knobs from class rules
	var class_size: int = int(gen.class_rules.get("class_size", 2000))
	var gaussian_share: float = float(gen.class_rules.get("gaussian_share", 0.75))
	var max_freaks: int = int(gen.class_rules.get("max_freaks_per_class", 5))
	var freak_min: float = float(gen.class_rules.get("freak_percentile_min", 0.80))
	var freak_max: float = float(gen.class_rules.get("freak_percentile_max", 0.90))

	# 4) Generate the finished products (quota → gauss → chaos)
	var players: Array = gen.generate_class(class_size, gaussian_share)

	# 5) Inject dynamic freaks
	gen.assign_dynamic_freaks(players, max_freaks, freak_min, freak_max)

	var current_year: int = int(main_cfg.get("starting_year", 2025))
	var college_grad_year: int = current_year + 8
	var out_path: String = "res://configs/sports/american_football/CLASS_OF_%d.json" % college_grad_year

	# 8) Log a quick preview
	print("✅ Generated ", players.size(), " prospects → ", out_path)
	# After rating & ranking
	var rater := RecruitRater.new()
	rater.rate_and_rank(players, gen.positions_data, gen.class_rules)

	# Print a clean Top 10 (skip K/P)
	_print_top_detailed(players, gen.positions_data, gen.stats_cfg, 10)

	# Optionally also list all 5-star recruits
	_print_all_five_stars(players, gen.positions_data, gen.stats_cfg)
	
	# 6) Copy finished → potential, then de-age to HS stats
	for p in players:
		if not p.has("potential") or (p["potential"] as Dictionary).is_empty():
			p["potential"] = (p["stats"] as Dictionary).duplicate(true)

	gen.de_age_players(players, gen.positions_data, main_cfg.get("deage", {}))
	
	# 7) Save as CLASS_OF_%Y.json (HS 4y + College 4y)
	gen.save_to_json(out_path, players)

# ---------------------------
# Console helpers
# ---------------------------

func _round2(x: float) -> float:
	return snappedf(x, 0.01)

func _join_array(parts: Array, sep: String) -> String:
	var out := ""
	for i in range(parts.size()):
		out += String(parts[i])
		if i < parts.size() - 1:
			out += sep
	return out

func _fmt_height(height_in: float) -> String:
	var feet: int = int(height_in / 12.0)
	var inches_f: float = height_in - float(feet) * 12.0
	var inches: int = int(round(inches_f))
	# handle 5'11.9" -> 6'0"
	if inches >= 12:
		feet += 1
		inches = 0
	return "%d'%d\"" % [feet, inches]

func _fmt_physicals(phys: Dictionary) -> String:
	var h: float = phys.get("height_in", 0.0)
	var w: float = phys.get("weight_lb", 0.0)
	var a: float = phys.get("arm_length_in", 0.0)
	var ws: float = phys.get("wingspan_in", 0.0)
	var hand: float = phys.get("hand_size_in", 0.0)
	var parts: Array = []
	if h != null: parts.append("Ht " + _fmt_height(float(h)))
	if w != null: parts.append("Wt " + str(int(round(float(w)))) + " lb")
	if a != null: parts.append("Arm " + str(_round2(float(a))) + " in")
	if ws != null: parts.append("Wing " + str(_round2(float(ws))) + " in")
	if hand != null: parts.append("Hand " + str(_round2(float(hand))) + " in")
	return _join_array(parts, "  |  ")

func _collect_role_sets(positions_data: Dictionary, pos: String) -> Dictionary:
	var spec: Dictionary = positions_data.get(pos, {}) as Dictionary
	var dists: Dictionary = spec.get("distributions", {}) as Dictionary
	var core_list: Array = (spec.get("core_stats", []) as Array).duplicate()
	# Add any stat explicitly marked role:"core" in distributions
	for k in dists.keys():
		if String((dists[k] as Dictionary).get("role","other")) == "core" and not core_list.has(k):
			core_list.append(k)
	var secondary_list: Array = []
	for k in dists.keys():
		if String((dists[k] as Dictionary).get("role","other")) == "secondary":
			secondary_list.append(k)
	return {"core": core_list, "secondary": secondary_list}

func _all_base_stats(stats_cfg: Dictionary) -> Array:
	var names: Array = []
	for s in stats_cfg.get("stats", []):
		var sd: Dictionary = s
		if sd.get("type","base") == "base":
			names.append(sd["name"])
	return names

func _fmt_stat_block(stats: Dictionary, keys: Array, title: String, per_row: int = 6) -> String:
	if keys.is_empty():
		return ""
	var lines: Array = []
	lines.append("• " + title + ":")
	# stable order
	var sorted_keys: Array = keys.duplicate()
	sorted_keys.sort()
	var row: Array = []
	for i in range(sorted_keys.size()):
		var k: String = String(sorted_keys[i])
		var v: float = float(stats.get(k, 0.0))
		row.append("%-16s %6.2f" % [k + ":", v])
		if (i + 1) % per_row == 0:
			lines.append("  " + _join_array(row, "  "))
			row.clear()
	if not row.is_empty():
		lines.append("  " + _join_array(row, "  "))
	return _join_array(lines, "\n")

func print_player_detailed(p: Dictionary, positions_data: Dictionary, stats_cfg: Dictionary) -> void:
	var player_name: String = String(p.get("name","Unknown"))  # avoid shadowing Node.name
	var pos: String = String(p.get("position","ATH"))
	var stars: int = int(p.get("star_rating", 0))
	var rank: int = int(p.get("rank_overall", 0))
	var comp: float = float(p.get("composite_score", 0.0))
	var star_score: float = float(p.get("star_score", 0.0))

	# header
	print("──────────────────────────────────────────────────────────────────────────────")
	print("%2d) ★%d  %-24s [%s]    comp:%6.2f   star:%6.2f" % [rank, stars, player_name, pos, comp, star_score])

	# physicals
	var phys: Dictionary = p.get("physicals", {}) as Dictionary
	print("    " + _fmt_physicals(phys))

	# role sets
	var roles: Dictionary = _collect_role_sets(positions_data, pos)
	var core_keys: Array = roles["core"]
	var secondary_keys: Array = roles["secondary"]
	# other = all base stats minus (core ∪ secondary)
	var all_base: Array = _all_base_stats(stats_cfg)
	var other_keys: Array = []
	var core_set: Array = core_keys.duplicate()
	for k in secondary_keys:
		if not core_set.has(k):
			core_set.append(k)
	for k in all_base:
		if not core_set.has(k):
			other_keys.append(k)

	# blocks
	var st: Dictionary = p.get("stats", {}) as Dictionary
	var blk_core: String = _fmt_stat_block(st, core_keys, "Core")
	if blk_core != "": print(blk_core)
	var blk_sec: String = _fmt_stat_block(st, secondary_keys, "Secondary")
	if blk_sec != "": print(blk_sec)
	var blk_other: String = _fmt_stat_block(st, other_keys, "Other")
	if blk_other != "": print(blk_other)

	# mentals summary & tags
	var mentals_avg: float = float(p.get("mentals_avg", 0.0))
	var tags: Array = p.get("tags", []) as Array
	if not tags.is_empty():
		print("• Mentals: %5.2f   • Tags: %s" % [mentals_avg, _join_array(tags, ", ")])
	else:
		print("• Mentals: %5.2f" % mentals_avg)

# Print top N non-specialists with full blocks
func _print_top_detailed(players: Array, positions_data: Dictionary, stats_cfg: Dictionary, top_n: int = 10) -> void:
	# exclude K/P
	var pool: Array = players.filter(func(pp):
		var pos := String((pp as Dictionary).get("position",""))
		return pos != "K" and pos != "P"
	)
	var limit: int = min(top_n, pool.size())
	print("\n🏆 Top %d (detailed):\n" % limit)
	for i in range(limit):
		print_player_detailed(pool[i], positions_data, stats_cfg)

# Or print all 5★ in descending order
func _print_all_five_stars(players: Array, positions_data: Dictionary, stats_cfg: Dictionary) -> void:
	var five: Array = players.filter(func(pp): return int((pp as Dictionary).get("star_rating",0)) == 5)
	print("\n🌟 All 5★ recruits (%d):\n" % five.size())
	for p in five:
		print_player_detailed(p, positions_data, stats_cfg)

func _ready() -> void:
	# Auto-run when the scene plays
	run()