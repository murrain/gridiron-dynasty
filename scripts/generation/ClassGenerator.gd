extends Node
class_name ClassGenerator

signal step_started(name: String)
signal step_finished(name: String)
signal progress(pct: float, label: String)

const CombineCalculator = preload("res://scripts/rating/CombineCalculator.gd")

# Public fields (you can set these before calling run())
var main_cfg: Dictionary
var positions_cfg: Dictionary
var stats_cfg: Dictionary
var names_cfg: Dictionary
var scouts_cfg: Dictionary
var combine_tests_cfg: Dictionary
var class_rules: Dictionary

# Internal
var _players: Array = []

# ---------- Lifecycle / Orchestration ----------

func run(top_n:int=10) -> void:
	# Load configs if caller didn’t inject
	_load_cfg_if_needed()

	# RNG seed
	if main_cfg.has("random_seed"):
		seed(int(main_cfg["random_seed"]))
	else:
		randomize()

	# 1) Generate
	emit_signal("step_started", "generate")
	var class_size := int(class_rules.get("class_size", 2000))
	var gaussian_share := float(class_rules.get("gaussian_share", 0.75))
	_players = _generate_class(class_size, gaussian_share)
	emit_signal("step_finished", "generate")
	emit_signal("progress", 0.25, "generated %d players" % _players.size())

	# 2) Tag freaks
	emit_signal("step_started", "tag_freaks")
	_assign_dynamic_freaks(
		_players,
		int(class_rules.get("max_freaks_per_class", 5)),
		float(class_rules.get("freak_percentile_min", 0.80)),
		float(class_rules.get("freak_percentile_max", 0.90))
	)
	emit_signal("step_finished", "tag_freaks")
	emit_signal("progress", 0.35, "tagged freaks")

	# 3) Rate & rank
	emit_signal("step_started", "rate_rank")
	_rate_and_rank(_players)
	emit_signal("step_finished", "rate_rank")
	emit_signal("progress", 0.55, "rated & ranked")

	# 4) Copy potential → baseline (threaded)
	emit_signal("step_started", "copy_potential")
	_copy_potential_to_baseline(_players)
	emit_signal("step_finished", "copy_potential")
	emit_signal("progress", 0.65, "copied potential to baseline")

	# 5) De-age (threaded)
	emit_signal("step_started", "de_age")
	_de_age_players(
		_players,
		positions_cfg,
		main_cfg.get("deage", {}),
		stats_cfg
	)
	emit_signal("step_finished", "de_age")
	emit_signal("progress", 0.80, "de-aged players")

	# 6) Save
	emit_signal("step_started", "save")
	var out_path := _save_class_json(_players)
	emit_signal("step_finished", "save")
	emit_signal("progress", 0.90, "saved to %s" % out_path)

	# 7) Print preview
	_print_preview(_players, top_n)
	emit_signal("progress", 1.0, "done")

# ---------- Individual Steps (public if you want to call piecemeal) ----------

func generate_only(class_size:int, gaussian_share:float) -> Array:
	_load_cfg_if_needed()
	_players = _generate_class(class_size, gaussian_share)
	return _players

func rate_and_rank_only(players:Array) -> void:
	_rate_and_rank(players)

func copy_potential_only(players:Array) -> void:
	_copy_potential_to_baseline(players)

func de_age_only(players:Array) -> void:
	_de_age_players(players, positions_cfg, main_cfg.get("deage", {}), stats_cfg)

func save_only(players:Array) -> String:
	return _save_class_json(players)

# ---------- Impl ----------

func _load_cfg_if_needed() -> void:
	if main_cfg.is_empty():
		main_cfg = Config.get_config("main")
	if positions_cfg.is_empty():
		positions_cfg = Config.get_config("positions")
	if stats_cfg.is_empty():
		stats_cfg = Config.get_config("stats")
	if names_cfg.is_empty():
		names_cfg = Config.get_config("names")
	if scouts_cfg.is_empty():
		scouts_cfg = Config.get_config("scouts")
	if combine_tests_cfg.is_empty():
		combine_tests_cfg = Config.get_config("combine_tests")
	if class_rules.is_empty():
		class_rules = main_cfg.get("class_rules", {})

func _generate_class(class_size:int, gaussian_share:float) -> Array:
	var gen := PlayerGenerator.new()
	gen.main_cfg = main_cfg
	gen.positions_data = positions_cfg
	gen.stats_cfg = stats_cfg
	gen.names_cfg = names_cfg
	gen.class_rules = class_rules
	gen.combine_tests = combine_tests_cfg
	gen.combine_tuning = combine_tests_cfg.get("defaults", {})

	return gen.generate_class(class_size, gaussian_share)

func _assign_dynamic_freaks(players:Array, max_freaks:int, pmin:float, pmax:float) -> void:
	var gen := PlayerGenerator.new()
	gen.positions_data = positions_cfg
	gen.class_rules = class_rules
	gen.assign_dynamic_freaks(players, max_freaks, pmin, pmax)

func _rate_and_rank(players:Array) -> void:
	var rater := RecruitRater.new()
	rater.rate_and_rank(players, positions_cfg, class_rules)

func _copy_potential_to_baseline(players:Array) -> void:
	var copied := ThreadPool.map(players, func(p):
		if p == null:
			return p
		if not p.has("potential") or (p["potential"] as Dictionary).is_empty():
			p["potential"] = (p.get("stats", {}) as Dictionary).duplicate(true)
		return p
	, App.threads_count())
	for i in players.size():
		players[i] = copied[i]

func _de_age_players(players:Array, positions:Dictionary, deage_cfg:Dictionary, stats_cfg:Dictionary) -> void:
	var threads := App.threads_count()
	var deaged := ThreadPool.map(players, func(p):
		return DeAger.de_age(p, positions, deage_cfg, stats_cfg)
	, threads)
	for i in players.size():
		players[i] = deaged[i]

func _save_class_json(players:Array) -> String:
	var gen := PlayerGenerator.new()
	var current_year := int(main_cfg.get("starting_year", 2025))
	var out_path := "res://configs/sports/american_football/CLASS_OF_%d.json" % (current_year + 8)
	gen.save_to_json(out_path, players)
	return out_path

# ---------- Pretty Printing (lifted from your one-shot, minor tidy) ----------

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
	var feet := int(height_in / 12.0)
	var inches_f := height_in - float(feet) * 12.0
	var inches := int(round(inches_f))
	if inches >= 12:
		feet += 1
		inches = 0
	return "%d'%d\"" % [feet, inches]

func _fmt_physicals(phys: Dictionary) -> String:
	var h : float = phys.get("height_in", 0.0)
	var w : float = phys.get("weight_lb", 0.0)
	var a : float = phys.get("arm_length_in", 0.0)
	var ws : float = phys.get("wingspan_in", 0.0)
	var hand : float = phys.get("hand_size_in", 0.0)
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
	for k in dists.keys():
		if String((dists[k] as Dictionary).get("role","other")) == "core" and not core_list.has(k):
			core_list.append(k)
	var secondary_list: Array = []
	for k in dists.keys():
		if String((dists[k] as Dictionary).get("role","other")) == "secondary":
			if not core_list.has(k): secondary_list.append(k)
	return {"core": core_list, "secondary": secondary_list}

func _all_base_stats(stats_cfg: Dictionary) -> Array:
	var names: Array = []
	for s in stats_cfg.get("stats", []):
		var sd: Dictionary = s
		if sd.get("type","base") == "base":
			names.append(sd["name"])
	return names

func _fmt_stat_block(stats: Dictionary, keys: Array, title: String, per_row: int = 6) -> String:
	if keys.is_empty(): return ""
	var lines: Array = []; lines.append("• " + title + ":")
	var sorted_keys: Array = keys.duplicate(); sorted_keys.sort()
	var row: Array = []
	for i in sorted_keys.size():
		var k := String(sorted_keys[i])
		var v := float(stats.get(k, 0.0))
		row.append("%-16s %6.2f" % [k + ":", v])
		if (i + 1) % per_row == 0:
			lines.append("  " + _join_array(row, "  ")); row.clear()
	if not row.is_empty():
		lines.append("  " + _join_array(row, "  "))
	return _join_array(lines, "\n")

func _print_combine_section(combine: Dictionary, combine_cfg: Dictionary) -> void:
	print("\n🧪 Combine Results:")
	var tests: Dictionary = combine_cfg.get("tests", {}) as Dictionary
	var items: Array = []
	for key in tests.keys():
		if combine.has(key):
			var tcfg: Dictionary = tests[key] as Dictionary
			var disp_name := String(tcfg.get("display", key))
			var val := str(combine[key])
			items.append([disp_name, val])
	if items.is_empty(): return
	var max_name_len := 0; var max_val_len := 0
	for item in items:
		max_name_len = max(max_name_len, String(item[0]).length())
		max_val_len = max(max_val_len, String(item[1]).length())
	for i in range(0, items.size(), 3):
		var row_items: Array = items.slice(i, i + 3)
		var row_str := ""
		for cell in row_items:
			var name_pad := String(cell[0]).lpad(max_name_len)
			var val_pad := String(cell[1]).rpad(max_val_len)
			row_str += "%s: %s   " % [name_pad, val_pad]
		print("   " + row_str.strip_edges())

func _print_player_detailed(
	p: Dictionary,
	positions_data: Dictionary,
	stats_cfg: Dictionary,
	combine_tests_cfg: Dictionary,
	scouts_cfg: Dictionary,
	class_rules: Dictionary
) -> void:
	var name_s := String(p.get("name","Unknown"))
	var pos_s := String(p.get("position","ATH"))
	var stars_i := int(p.get("star_rating",0))
	var rank_i := int(p.get("rank_overall",0))
	var comp_f := float(p.get("composite_score",0.0))
	var star_score_f := float(p.get("star_score",0.0))

	print("──────────────────────────────────────────────────────────────────────────────")
	print("%2d) ★%d  %-24s [%s]    comp:%6.2f   star:%6.2f" % [rank_i, stars_i, name_s, pos_s, comp_f, star_score_f])
	print("    " + _fmt_physicals(p.get("physicals", {}) as Dictionary))
	if p.has("combine"): _print_combine_section(p["combine"], combine_tests_cfg)

	var roles := _collect_role_sets(positions_data, pos_s)
	var core_keys: Array = roles.get("core", []) as Array
	var sec_keys: Array = roles.get("secondary", []) as Array
	var all_base := _all_base_stats(stats_cfg)
	var union_cs: Array = core_keys.duplicate()
	for k in sec_keys:
		if not union_cs.has(k): union_cs.append(k)
	var other_keys: Array = []
	for k in all_base:
		if not union_cs.has(k): other_keys.append(k)

	var stats: Dictionary = p.get("stats", {}) as Dictionary
	if not core_keys.is_empty():
		print(_fmt_stat_block(stats, core_keys, "Core", 6))
	if not sec_keys.is_empty():
		print(_fmt_stat_block(stats, sec_keys, "Secondary", 6))
	if not other_keys.is_empty():
		print(_fmt_stat_block(stats, other_keys, "Other", 6))

	var mentals_avg_f := float(p.get("mentals_avg", 0.0))
	var tags_arr: Array = p.get("tags", []) as Array
	if tags_arr.is_empty():
		print("• Mentals: %5.2f" % mentals_avg_f)
	else:
		print("• Mentals: %5.2f   • Tags: %s" % [mentals_avg_f, ", ".join(tags_arr)])

	_print_scouts_section(p, scouts_cfg, positions_data, stats_cfg, class_rules)

func _print_top_detailed(players: Array, positions_data: Dictionary, stats_cfg: Dictionary, combine_tests_cfg: Dictionary, scouts_cfg: Dictionary, class_rules: Dictionary, top_n: int = 10) -> void:
	var pool := players.filter(func(pp):
		var pos := String((pp as Dictionary).get("position",""))
		return pos != "K" and pos != "P"
	)
	var limit : int = min(top_n, pool.size())
	print("\n🏆 Top %d (detailed):\n" % limit)
	for i in limit:
		_print_player_detailed(pool[i] as Dictionary, positions_data, stats_cfg, combine_tests_cfg, scouts_cfg, class_rules)

func _print_all_five_stars(players: Array, positions_data: Dictionary, stats_cfg: Dictionary, combine_tests_cfg: Dictionary, scouts_cfg: Dictionary, class_rules: Dictionary) -> void:
	var five := players.filter(func(pp):
		return int((pp as Dictionary).get("star_rating",0)) == 5
	)
	print("\n🌟 All 5★ recruits (%d):\n" % five.size())
	for p in five:
		_print_player_detailed(p as Dictionary, positions_data, stats_cfg, combine_tests_cfg, scouts_cfg, class_rules)

func _print_scouts_section(player: Dictionary, scouts_cfg: Dictionary, positions_data: Dictionary, stats_cfg: Dictionary, class_rules: Dictionary) -> void:
	var scouts: Array = (scouts_cfg.get("national_scouts", []) as Array)
	if scouts.is_empty():
		return
	print("\n🕵️ What the scouts say:")
	var cells: Array = []
	for s in scouts:
		var scout: Dictionary = s as Dictionary
		var scout_name := String(scout.get("name", "Scout"))
		var score := ScoutRuntime.score_player(scout, player, positions_data, stats_cfg, class_rules)
		cells.append("%s: %.2f" % [scout_name, score])
	for i in range(0, cells.size(), 5):
		print("   " + "   ".join(cells.slice(i, i + 5)))

func _print_preview(players:Array, top_n:int) -> void:
	var current_year := int(main_cfg.get("starting_year", 2025))
	var out_path := "res://configs/sports/american_football/CLASS_OF_%d.json" % (current_year + 8)
	print("\n✅ Generated %d prospects → %s" % [players.size(), out_path])
	_print_top_detailed(players, positions_cfg, stats_cfg, combine_tests_cfg, scouts_cfg, class_rules, top_n)
	_print_all_five_stars(players, positions_cfg, stats_cfg, combine_tests_cfg, scouts_cfg, class_rules)