## One-shot class generation + rating + printing (threaded).
##
## This script ties the pipeline together:
##   1) Generate players (threaded in PlayerGenerator).
##   2) Rate + rank (threaded in RecruitRater).
##   3) Print a detailed Top N and all 5★.
##   4) Copy potential → HS baseline and de-age (threaded).
##   5) Save to JSON.
##
## Example:
## [codeblock]
## var scene := GenerateOnce.new()
## add_child(scene)
## scene.run()
## [/codeblock]
extends Node

const USE_COLOR: bool = true
const CombineCalculator = preload("res://scripts/rating/CombineCalculator.gd")

func run() -> void:
	var all_cfg: Dictionary = Config.get_all()
	var main_cfg: Dictionary      = Config.get_config("main")
	var positions: Dictionary     = Config.get_config("positions")
	var stats_cfg: Dictionary     = Config.get_config("stats")
	var names_cfg: Dictionary     = Config.get_config("names")
	var scouts_cfg: Dictionary    = Config.get_config("scouts")
	var combine_tests: Dictionary = Config.get_config("combine_tests")


	var gen := PlayerGenerator.new()
	gen.main_cfg = main_cfg
	gen.positions_data = positions
	gen.stats_cfg = stats_cfg
	gen.names_cfg = names_cfg
	gen.class_rules = main_cfg.get("class_rules", {})
	gen.combine_tests = combine_tests
	gen.combine_tuning = combine_tests.get("defaults", {})

	# RNG seeding
	if main_cfg.has("random_seed"):
		seed(int(main_cfg["random_seed"]))
	else:
		randomize()

	# knobs
	var class_size := int(gen.class_rules.get("class_size", 2000))
	var gaussian_share := float(gen.class_rules.get("gaussian_share", 0.75))
	var max_freaks := int(gen.class_rules.get("max_freaks_per_class", 5))
	var freak_min := float(gen.class_rules.get("freak_percentile_min", 0.80))
	var freak_max := float(gen.class_rules.get("freak_percentile_max", 0.90))

	# 1) generate
	var players: Array = gen.generate_class(class_size, gaussian_share)

	# 2) freaks (single-threaded tagging usually fine; tiny workload)
	gen.assign_dynamic_freaks(players, max_freaks, freak_min, freak_max)

	# 3) rate & rank (threaded internal)
	var rater := RecruitRater.new()
	rater.rate_and_rank(players, gen.positions_data, gen.class_rules)

	# preview output
	var current_year := int(main_cfg.get("starting_year", 2025))
	var out_path := "res://configs/sports/american_football/CLASS_OF_%d.json" % (current_year + 8)
	print("✅ Generated ", players.size(), " prospects → ", out_path)

	_print_top_detailed(players, gen.positions_data, gen.stats_cfg, combine_tests, scouts_cfg, gen.class_rules, 10)
	_print_all_five_stars(players, gen.positions_data, gen.stats_cfg, combine_tests, scouts_cfg, gen.class_rules)

	# 4) copy potential (threaded)
	var copied := ThreadPool.map(players, func(p):
		if not p.has("potential") or (p["potential"] as Dictionary).is_empty():
			p["potential"] = (p["stats"] as Dictionary).duplicate(true)
		return p
	, App.threads_count())
	for i in players.size():
		players[i] = copied[i]

	# 5) de-age (threaded wrapper in generator)
	gen.de_age_players(players, gen.positions_data, main_cfg.get("deage", {}))

	# 6) save
	gen.save_to_json(out_path, players)

# --- Printing helpers below (same interface, documented) ---

func _round2(x: float) -> float:
	return snappedf(x, 0.01)

func _join_array(parts: Array, sep: String) -> String:
	var out := ""
	for i in range(parts.size()):
		out += String(parts[i])
		if i < parts.size() - 1:
			out += sep
	return out

func _ansi(code: String, text: String) -> String:
	var esc := char(27)
	return esc + "[" + code + "m" + text + esc + "[0m"

func _color_code_for_score(v: float) -> String:
	if v >= 90.0: return "1;32"
	if v >= 80.0: return "32"
	if v >= 60.0: return "33"
	if v >= 40.0: return "31"
	return "1;31"

func _fmt_kv_colored(key: String, value: float) -> String:
	var label := "%-16s" % (key + ":")
	var num := "%6.2f" % value
	return label + " " + (_ansi(_color_code_for_score(value), num) if USE_COLOR else num)

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
			var disp_name := String(tcfg.get("display_name", key))
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

func print_player_detailed(
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
	var blk_core := _fmt_stat_block(stats, core_keys, "Core", 6)
	if blk_core != "": print(blk_core)
	var blk_sec := _fmt_stat_block(stats, sec_keys, "Secondary", 6)
	if blk_sec != "": print(blk_sec)
	var blk_other := _fmt_stat_block(stats, other_keys, "Other", 6)
	if blk_other != "": print(blk_other)

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
		print_player_detailed(pool[i] as Dictionary, positions_data, stats_cfg, combine_tests_cfg, scouts_cfg, class_rules)

func _print_all_five_stars(players: Array, positions_data: Dictionary, stats_cfg: Dictionary, combine_tests_cfg: Dictionary, scouts_cfg: Dictionary, class_rules: Dictionary) -> void:
	var five := players.filter(func(pp):
		return int((pp as Dictionary).get("star_rating",0)) == 5
	)
	print("\n🌟 All 5★ recruits (%d):\n" % five.size())
	for p in five:
		print_player_detailed(p as Dictionary, positions_data, stats_cfg, combine_tests_cfg, scouts_cfg, class_rules)

func _print_scouts_section(player: Dictionary, scouts_cfg: Dictionary, positions_data: Dictionary, stats_cfg: Dictionary, class_rules: Dictionary) -> void:
	var scouts: Array = (scouts_cfg.get("national_scouts", []) as Array)
	if scouts.is_empty():
		return
	print("\n🕵️ What the scouts say:")
	var cells: Array = []
	for s in scouts:
		var scout: Dictionary = s as Dictionary
		var scout_name := String(scout.get("name", "Scout"))
		# let your Scout resource/class handle perception+valuation internally
		var score := ScoutRuntime.score_player(scout, player, positions_data, stats_cfg, class_rules)
		cells.append("%s: %.2f" % [scout_name, score])
	for i in range(0, cells.size(), 5):
		print("   " + "   ".join(cells.slice(i, i + 5)))

func _ready() -> void:
	run()
