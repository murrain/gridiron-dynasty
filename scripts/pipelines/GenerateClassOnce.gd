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

const ConfigService = preload("res://autoloads/Config.gd")
const Rand = preload("res://autoloads/Rand.gd")
const ThreadPool = preload("res://autoloads/ThreadPool.gd")
const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")
const RecruitRater = preload("res://scripts/core/rating/RecruitRater.gd")
const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")

const USE_COLOR: bool = true
# Recruiting classes are stored 8 years after the "starting_year" baseline.
const CLASS_YEAR_OFFSET: int = 8

class OutputConfig:
	extends Resource

	@export var auto_scroll: bool = true
	@export var append_newline: bool = true
	@export var clear_on_run: bool = true
	@export var max_lines: int = 0

@export var output_label_path: NodePath = NodePath("OutputPanel/OutputScroll/OutputText")
@export var output_config: OutputConfig = OutputConfig.new()

var output_label: RichTextLabel

func _ready() -> void:
	output_label = get_node_or_null(output_label_path) as RichTextLabel
	run()

func _emit_output(text: String) -> void:
	if output_label == null:
		return
	var line := text
	if output_config.append_newline:
		line += "\n"
	output_label.append_text(line)
	_trim_output_lines()
	if output_config.auto_scroll:
		output_label.scroll_to_line(output_label.get_line_count())

func _trim_output_lines() -> void:
	if output_label == null:
		return
	if output_config.max_lines <= 0:
		return
	var lines := output_label.get_line_count()
	if lines <= output_config.max_lines:
		return
	var excess := lines - output_config.max_lines
	var buffer := output_label.get_parsed_text().split("\n", false)
	if excess >= buffer.size():
		output_label.clear()
		return
	buffer = buffer.slice(excess, buffer.size())
	output_label.clear()
	output_label.append_text("\n".join(buffer) + "\n")

func run() -> void:
	if output_label != null and output_config.clear_on_run:
		output_label.clear()
	# Force full config load once so downstream lookups are consistent.
	var config: Node = ConfigService.new()
	var _all_cfg: Dictionary = config.get_all()
	var main_cfg: Dictionary      = config.get_config("main")
	var positions: Dictionary     = config.get_config("positions")
	var stats_cfg: Dictionary     = config.get_config("stats")
	var names_cfg: Dictionary     = config.get_config("names")
	var scouts_cfg: Dictionary    = config.get_config("scouts")
	var combine_tests: Dictionary = config.get_config("combine_tests")


	var gen := PlayerGenerator.new()
	gen.main_cfg = main_cfg
	gen.positions_data = positions
	gen.stats_cfg = stats_cfg
	gen.names_cfg = names_cfg
	gen.class_rules = main_cfg.get("class_rules", {})
	gen.combine_tests = combine_tests
	gen.combine_tuning = combine_tests.get("defaults", {})

	var base_seed := _resolve_seed(main_cfg)

	# knobs
	var class_size := int(gen.class_rules.get("class_size", 2000))
	var gaussian_share := float(gen.class_rules.get("gaussian_share", 0.75))
	var max_freaks := int(gen.class_rules.get("max_freaks_per_class", 5))
	var freak_min := float(gen.class_rules.get("freak_percentile_min", 0.80))
	var freak_max := float(gen.class_rules.get("freak_percentile_max", 0.90))

	# 1) generate
	var players: Array = gen.generate_class(class_size, gaussian_share, _step_rng(base_seed, "generate"))

	# 2) freaks (single-threaded tagging usually fine; tiny workload)
	gen.assign_dynamic_freaks(players, max_freaks, freak_min, freak_max, _step_rng(base_seed, "freaks"))

	# 3) rate & rank (threaded internal)
	var rater := RecruitRater.new()
	rater.rate_and_rank(players, gen.positions_data, gen.class_rules)

	# Preview output with styled header
	var current_year := int(main_cfg.get("starting_year", 2025))
	var out_path := "res://configs/sports/american_football/CLASS_OF_%d.json" % (current_year + CLASS_YEAR_OFFSET)
	_emit_output("[center][font_size=18][b][color=#00ff00]✅ CLASS GENERATION COMPLETE[/color][/b][/font_size][/center]")
	_emit_output("[center]Generated [b]%d prospects[/b] → [i]%s[/i][/center]\n" % [players.size(), out_path])

	var scout_rng := _step_rng(base_seed, "scout_preview")
	_print_top_detailed(players, gen.positions_data, gen.stats_cfg, combine_tests, scouts_cfg, gen.class_rules, scout_rng, 10)
	_print_all_five_stars(players, gen.positions_data, gen.stats_cfg, combine_tests, scouts_cfg, gen.class_rules, scout_rng)

	# 4) copy potential (threaded)
	var copied := ThreadPool.map(players, func(p):
		if not p.has("potential") or (p["potential"] as Dictionary).is_empty():
			p["potential"] = (p["stats"] as Dictionary).duplicate(true)
		return p,
		config.threads_count()
	)
	for i in players.size():
		players[i] = copied[i]

	# 5) de-age (threaded wrapper in generator)
	gen.de_age_players(players, gen.positions_data, main_cfg.get("deage", {}), stats_cfg, _step_rng(base_seed, "de_age"))

	# 6) save
	gen.save_to_json(out_path, players)

func _resolve_seed(main_cfg: Dictionary) -> int:
	if main_cfg.has("random_seed"):
		return int(main_cfg["random_seed"])
	return int(main_cfg.get("starting_year", 2025))

func _step_rng(seed: int, label: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(seed ^ _fnv1a_64(label))
	return rng

func _fnv1a_64(text: String) -> int:
	var hash: int = -3750763034362895579
	var prime: int = 1099511628211
	for b in text.to_utf8_buffer():
		hash = int(hash ^ b) & -1
		hash = int(hash * prime) & -1
	return hash

# --- BBCode Formatting Helpers ---

## Color scheme for value-based semantic coloring
func _bbcode_color_for_value(v: float) -> String:
	if v >= 90.0: return "#00ff00"  # Bright green (elite)
	if v >= 80.0: return "#66ff66"  # Light green (great)
	if v >= 70.0: return "#99ff99"  # Pale green (good)
	if v >= 60.0: return "#ffff00"  # Yellow (above average)
	if v >= 50.0: return "#ffaa00"  # Orange (average)
	if v >= 40.0: return "#ff6600"  # Dark orange (below average)
	return "#ff0000"  # Red (poor)

## Wrap text in BBCode color tag
func _colored(text: String, color: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]

## Color value based on numeric score
func _colored_value(value: float, format_str: String = "%.2f") -> String:
	var formatted := format_str % value
	return _colored(formatted, _bbcode_color_for_value(value))

func _display_stat_name(stat: String) -> String:
	var words := stat.replace("_", " ").split(" ", false)
	var formatted: Array = []
	for word in words:
		var lower := word.to_lower()
		if lower == "iq":
			formatted.append("IQ")
		else:
			formatted.append(lower.capitalize())
	return " ".join(formatted)

## Create a simple 2-column key-value table row
func _kv_row(key: String, value: String, color_value: bool = false) -> String:
	return "[cell]%s[/cell][cell]%s[/cell]" % [key, value]

## Create a colored key-value row with numeric value
func _kv_row_scored(key: String, value: float) -> String:
	return "[cell]%s[/cell][cell]%s[/cell]" % [key, _colored_value(value)]

## Start a table with N columns
func _table_begin(columns: int = 2) -> String:
	return "[table=%d]" % columns

## End a table
func _table_end() -> String:
	return "[/table]"

## Create section header with visual emphasis
func _section_header(text: String, icon: String = "") -> String:
	var header := text if icon.is_empty() else "%s %s" % [icon, text]
	return "[b][font_size=16]%s[/font_size][/b]" % header

## Create subsection header
func _subsection_header(text: String) -> String:
	return "[b]%s[/b]" % text

## Utility functions
func _round2(x: float) -> float:
	return snappedf(x, 0.01)

func _fmt_height(height_in: float) -> String:
	var feet := int(height_in / 12.0)
	var inches_f := height_in - float(feet) * 12.0
	var inches := int(round(inches_f))
	if inches >= 12:
		feet += 1
		inches = 0
	return "%d'%d\"" % [feet, inches]

## Format physicals as BBCode table (3 columns for compact display)
func _fmt_physicals_threewide(phys: Dictionary) -> String:
	var items: Array = []

	var h: float = phys.get("height_in", 0.0)
	var w: float = phys.get("weight_lb", 0.0)
	var a: float = phys.get("arm_length_in", 0.0)
	var ws: float = phys.get("wingspan_in", 0.0)
	var hand: float = phys.get("hand_size_in", 0.0)

	if h > 0: items.append({"label": "Height", "value": _fmt_height(h)})
	if w > 0: items.append({"label": "Weight", "value": "%d lb" % int(round(w))})
	if a > 0: items.append({"label": "Arm", "value": "%.2f in" % _round2(a)})
	if ws > 0: items.append({"label": "Wingspan", "value": "%.2f in" % _round2(ws)})
	if hand > 0: items.append({"label": "Hand", "value": "%.2f in" % _round2(hand)})

	return _format_threewide_rows(items)

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

## Format stats block as BBCode table with color-coded values
func _fmt_stat_block_threewide(stats: Dictionary, keys: Array, title: String) -> String:
	if keys.is_empty():
		return ""

	var sorted_keys: Array = keys.duplicate()
	sorted_keys.sort()

	var items: Array = []
	for k in sorted_keys:
		var stat_name := String(k)
		var stat_value := float(stats.get(k, 0.0))
		items.append({
			"label": _display_stat_name(stat_name),
			"value": _colored_value(stat_value)
		})

	return _subsection_header(title) + "\n" + _format_threewide_rows(items)

func _collect_mental_keys(class_rules: Dictionary) -> Array:
	return class_rules.get("mental_keys", []) as Array

func _collect_hidden_keys(stats_cfg: Dictionary) -> Array:
	var keys: Array = []
	var extras: Array = [
		"confidence",
		"aggression",
		"leadership",
		"loyalty",
		"charisma",
		"football_IQ",
		"reaction_time",
		"clutch_factor"
	]

	for s in stats_cfg.get("stats", []):
		var sd: Dictionary = s
		var name := String(sd.get("name", ""))
		if sd.get("hidden", false) and not keys.has(name):
			keys.append(name)

	for extra in extras:
		if not keys.has(extra):
			keys.append(extra)

	return keys

## Print combine results as a clean table
func _format_combine_section(combine: Dictionary, combine_cfg: Dictionary) -> String:
	var tests: Dictionary = combine_cfg.get("tests", {}) as Dictionary
	var items: Array = []

	for key in tests.keys():
		if combine.has(key):
			var tcfg: Dictionary = tests[key] as Dictionary
			var disp_name := String(tcfg.get("display_name", key))
			var val: Variant = combine[key]
			items.append([disp_name, val])

	if items.is_empty():
		return ""

	var display_items: Array = []
	for item in items:
		display_items.append({
			"label": String(item[0]),
			"value": str(item[1])
		})

	return _subsection_header("🧪 Combine Results") + "\n" + _format_threewide_rows(display_items)

func _format_threewide_rows(items: Array) -> String:
	if items.is_empty():
		return ""

	var output := _table_begin(3)
	var idx := 0
	while idx < items.size():
		var row_items := items.slice(idx, min(idx + 3, items.size()))
		for entry in row_items:
			output += "[cell][b]%s[/b][/cell]" % String(entry.get("label", "")).to_upper()
		for _i in 3 - row_items.size():
			output += "[cell][/cell]"

		for entry in row_items:
			output += "[cell]%s[/cell]" % String(entry.get("value", ""))
		for _i in 3 - row_items.size():
			output += "[cell][/cell]"

		idx += 3
	output += _table_end()
	return output

func _format_scouts_section(
	player: Dictionary,
	scouts_cfg: Dictionary,
	positions_data: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	rng: RandomNumberGenerator
) -> String:
	var scouts: Array = (scouts_cfg.get("national_scouts", []) as Array)
	if scouts.is_empty():
		return ""

	var output := _section_header("Scout Opinions", "🕵️") + "\n"
	output += _table_begin(2)

	for s in scouts:
		var scout: Dictionary = s as Dictionary
		var scout_name := String(scout.get("name", "Scout"))
		var score := ScoutRuntime.score_player(scout, player, positions_data, stats_cfg, class_rules, rng)

		output += "[cell][b]%s[/b][/cell][cell]%s[/cell]" % [scout_name, _colored_value(score)]

	output += _table_end()
	return output

func _build_player_card_bbcode(
	p: Dictionary,
	positions_data: Dictionary,
	stats_cfg: Dictionary,
	combine_tests_cfg: Dictionary,
	scouts_cfg: Dictionary,
	class_rules: Dictionary,
	rng: RandomNumberGenerator
) -> String:
	var name_s := String(p.get("name","Unknown"))
	var pos_s := String(p.get("position","ATH"))
	var stars_i := int(p.get("star_rating",0))
	var rank_i := int(p.get("rank_overall",0))
	var comp_f := float(p.get("composite_score",0.0))
	var star_score_f := float(p.get("star_score",0.0))

	var header_line := "[b]#%d[/b] [color=#ffd700]%s[/color] [b]%s[/b] %s %s / %s" % [
		rank_i,
		"★".repeat(stars_i),
		name_s,
		pos_s,
		_colored_value(comp_f),
		_colored_value(star_score_f)
	]

	var output := "[bgcolor=#1a1a1a]" + "─".repeat(46) + "[/bgcolor]\n"
	output += header_line + "\n"
	output += "[color=#333333]" + "─".repeat(46) + "[/color]\n"

	# === PHYSICALS + COMBINE (side-by-side) ===
	var physicals := _subsection_header("💪 Physical Traits") + "\n"
	physicals += _fmt_physicals_threewide(p.get("physicals", {}) as Dictionary)

	var combine_block := ""
	if p.has("combine"):
		combine_block = _format_combine_section(p["combine"], combine_tests_cfg)

	var top_row := _table_begin(2)
	top_row += "[cell]%s[/cell]" % physicals
	top_row += "[cell]%s[/cell]" % combine_block
	top_row += _table_end()
	output += top_row + "\n"

	# === STATS ===
	var roles := _collect_role_sets(positions_data, pos_s)
	var core_keys: Array = roles.get("core", []) as Array
	var sec_keys: Array = roles.get("secondary", []) as Array
	var all_base := _all_base_stats(stats_cfg)
	var mental_keys := _collect_mental_keys(class_rules)
	var hidden_keys := _collect_hidden_keys(stats_cfg)

	var filtered_core: Array = []
	for k in core_keys:
		if not mental_keys.has(k) and not hidden_keys.has(k):
			filtered_core.append(k)
	var filtered_sec: Array = []
	for k in sec_keys:
		if not mental_keys.has(k) and not hidden_keys.has(k):
			filtered_sec.append(k)
	var union_cs: Array = filtered_core.duplicate()
	for k in filtered_sec:
		if not union_cs.has(k):
			union_cs.append(k)
	var other_keys: Array = []
	for k in all_base:
		if not union_cs.has(k) and not mental_keys.has(k) and not hidden_keys.has(k):
			other_keys.append(k)

	var stats: Dictionary = p.get("stats", {}) as Dictionary

	if not filtered_core.is_empty():
		output += _fmt_stat_block_threewide(stats, filtered_core, "⭐ Core Stats") + "\n"
	if not filtered_sec.is_empty():
		output += _fmt_stat_block_threewide(stats, filtered_sec, "🔹 Secondary Stats") + "\n"
	if not other_keys.is_empty():
		output += _fmt_stat_block_threewide(stats, other_keys, "○ Other Stats") + "\n"

	var mentals_present: Array = []
	for k in mental_keys:
		if stats.has(k):
			mentals_present.append(k)
	if not mentals_present.is_empty():
		output += _fmt_stat_block_threewide(stats, mentals_present, "🧠 Mental Stats") + "\n"

	var hidden_present: Array = []
	for k in hidden_keys:
		if stats.has(k) and not mentals_present.has(k):
			hidden_present.append(k)
	if not hidden_present.is_empty():
		output += _fmt_stat_block_threewide(stats, hidden_present, "🔒 Hidden & Mental") + "\n"

	# === SCOUT OPINIONS ===
	var scouts_section := _format_scouts_section(p, scouts_cfg, positions_data, stats_cfg, class_rules, rng)
	if not scouts_section.is_empty():
		output += scouts_section

	return output.rstrip("\n")

func print_player_detailed(
	p: Dictionary,
	positions_data: Dictionary,
	stats_cfg: Dictionary,
	combine_tests_cfg: Dictionary,
	scouts_cfg: Dictionary,
	class_rules: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	_emit_output(_build_player_card_bbcode(
		p,
		positions_data,
		stats_cfg,
		combine_tests_cfg,
		scouts_cfg,
		class_rules,
		rng
	))

func _format_player_grid(
	players: Array,
	positions_data: Dictionary,
	stats_cfg: Dictionary,
	combine_tests_cfg: Dictionary,
	scouts_cfg: Dictionary,
	class_rules: Dictionary,
	rng: RandomNumberGenerator
) -> String:
	var output := _table_begin(3)
	for p in players:
		var card := _build_player_card_bbcode(
			p as Dictionary,
			positions_data,
			stats_cfg,
			combine_tests_cfg,
			scouts_cfg,
			class_rules,
			rng
		)
		output += "[cell]%s[/cell]" % card
	var remainder := players.size() % 3
	if remainder != 0:
		for _i in 3 - remainder:
			output += "[cell][/cell]"
	output += _table_end()
	return output

func _print_top_detailed(
	players: Array,
	positions_data: Dictionary,
	stats_cfg: Dictionary,
	combine_tests_cfg: Dictionary,
	scouts_cfg: Dictionary,
	class_rules: Dictionary,
	rng: RandomNumberGenerator,
	top_n: int = 10
) -> void:
	var pool := players.filter(func(pp):
		var pos := String((pp as Dictionary).get("position",""))
		return pos != "K" and pos != "P"
	)
	var limit : int = min(top_n, pool.size())

	# Print section header with prominent styling
	_emit_output("\n\n[center][font_size=20][b]🏆 TOP %d PROSPECTS 🏆[/b][/font_size][/center]\n" % limit)

	var subset: Array = []
	for i in limit:
		subset.append(pool[i])
	_emit_output(_format_player_grid(subset, positions_data, stats_cfg, combine_tests_cfg, scouts_cfg, class_rules, rng))

func _print_all_five_stars(
	players: Array,
	positions_data: Dictionary,
	stats_cfg: Dictionary,
	combine_tests_cfg: Dictionary,
	scouts_cfg: Dictionary,
	class_rules: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var five := players.filter(func(pp):
		return int((pp as Dictionary).get("star_rating",0)) == 5
	)

	# Print section header with prominent styling
	_emit_output("\n\n[center][font_size=20][b][color=#ffd700]🌟 ALL 5-STAR RECRUITS (%d) 🌟[/color][/b][/font_size][/center]\n" % five.size())

	_emit_output(_format_player_grid(five, positions_data, stats_cfg, combine_tests_cfg, scouts_cfg, class_rules, rng))
