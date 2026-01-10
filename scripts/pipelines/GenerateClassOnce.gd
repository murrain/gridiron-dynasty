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
func _fmt_physicals_table(phys: Dictionary) -> String:
	var output := _table_begin(3)

	var h: float = phys.get("height_in", 0.0)
	var w: float = phys.get("weight_lb", 0.0)
	var a: float = phys.get("arm_length_in", 0.0)
	var ws: float = phys.get("wingspan_in", 0.0)
	var hand: float = phys.get("hand_size_in", 0.0)

	# Row 1: Height, Weight, Arm Length
	if h > 0: output += _kv_row("Height", _fmt_height(h))
	if w > 0: output += _kv_row("Weight", "%d lb" % int(round(w)))
	if a > 0: output += _kv_row("Arm", "%.2f in" % _round2(a))

	# Row 2: Wingspan, Hand Size (if present)
	if ws > 0: output += _kv_row("Wingspan", "%.2f in" % _round2(ws))
	if hand > 0: output += _kv_row("Hand", "%.2f in" % _round2(hand))

	output += _table_end()
	return output

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
func _fmt_stat_block_table(stats: Dictionary, keys: Array, title: String, columns: int = 4) -> String:
	if keys.is_empty(): return ""

	var sorted_keys: Array = keys.duplicate()
	sorted_keys.sort()

	var output := _subsection_header(title) + "\n"
	output += _table_begin(columns)

	for k in sorted_keys:
		var stat_name := String(k)
		var stat_value := float(stats.get(k, 0.0))
		output += _kv_row_scored(stat_name, stat_value)

	output += _table_end()
	return output

## Print combine results as a clean table
func _print_combine_section(combine: Dictionary, combine_cfg: Dictionary) -> void:
	var tests: Dictionary = combine_cfg.get("tests", {}) as Dictionary
	var items: Array = []

	for key in tests.keys():
		if combine.has(key):
			var tcfg: Dictionary = tests[key] as Dictionary
			var disp_name := String(tcfg.get("display_name", key))
			var val := combine[key]
			items.append([disp_name, val])

	if items.is_empty():
		return

	_emit_output("\n" + _subsection_header("🧪 Combine Results"))
	var output := _table_begin(4)  # 4 columns for compact display

	for item in items:
		var test_name := String(item[0])
		var test_value := str(item[1])
		output += _kv_row(test_name, test_value)

	output += _table_end()
	_emit_output(output)

func print_player_detailed(
	p: Dictionary,
	positions_data: Dictionary,
	stats_cfg: Dictionary,
	combine_tests_cfg: Dictionary,
	scouts_cfg: Dictionary,
	class_rules: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var name_s := String(p.get("name","Unknown"))
	var pos_s := String(p.get("position","ATH"))
	var stars_i := int(p.get("star_rating",0))
	var rank_i := int(p.get("rank_overall",0))
	var comp_f := float(p.get("composite_score",0.0))
	var star_score_f := float(p.get("star_score",0.0))

	# === PLAYER HEADER ===
	_emit_output("\n[bgcolor=#1a1a1a]" + "=".repeat(80) + "[/bgcolor]")

	# Player identity table (rank, stars, name, position)
	var header := _table_begin(4)
	header += _kv_row("[b]Rank[/b]", "[b]#%d[/b]" % rank_i)
	header += _kv_row("[b]Stars[/b]", "[b][color=#ffd700]" + "★".repeat(stars_i) + "[/color][/b]")
	header += _kv_row("[b]Name[/b]", "[b][font_size=14]%s[/font_size][/b]" % name_s)
	header += _kv_row("[b]Position[/b]", "[b][font_size=14]%s[/font_size][/b]" % pos_s)
	header += _table_end()
	_emit_output(header)

	# Key metrics table (composite and star score - color coded)
	var metrics := _table_begin(2)
	metrics += "[cell][b]Composite Score[/b][/cell][cell][b]%s[/b][/cell]" % _colored_value(comp_f)
	metrics += "[cell][b]Star Score[/b][/cell][cell][b]%s[/b][/cell]" % _colored_value(star_score_f)
	metrics += _table_end()
	_emit_output(metrics)

	# === PHYSICALS ===
	_emit_output("\n" + _section_header("Physical Attributes", "💪"))
	_emit_output(_fmt_physicals_table(p.get("physicals", {}) as Dictionary))

	# === COMBINE ===
	if p.has("combine"):
		_print_combine_section(p["combine"], combine_tests_cfg)

	# === STATS ===
	_emit_output("\n" + _section_header("Player Stats", "📊"))

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

	# Core stats (most important for position)
	if not core_keys.is_empty():
		var blk_core := _fmt_stat_block_table(stats, core_keys, "⭐ Core Stats", 4)
		_emit_output(blk_core)

	# Secondary stats (situational/positional)
	if not sec_keys.is_empty():
		var blk_sec := _fmt_stat_block_table(stats, sec_keys, "🔹 Secondary Stats", 4)
		_emit_output("\n" + blk_sec)

	# Other stats (less important for this position)
	if not other_keys.is_empty():
		var blk_other := _fmt_stat_block_table(stats, other_keys, "○ Other Stats", 4)
		_emit_output("\n" + blk_other)

	# === MENTALS & TAGS ===
	_emit_output("\n" + _section_header("Intangibles", "🧠"))
	var mentals_avg_f := float(p.get("mentals_avg", 0.0))
	var tags_arr: Array = p.get("tags", []) as Array

	var intangibles := _table_begin(2)
	intangibles += _kv_row_scored("[b]Mental Rating[/b]", mentals_avg_f)
	if not tags_arr.is_empty():
		intangibles += _kv_row("[b]Tags[/b]", "[color=#00aaff]%s[/color]" % ", ".join(tags_arr))
	intangibles += _table_end()
	_emit_output(intangibles)

	# === SCOUT OPINIONS ===
	_print_scouts_section(p, scouts_cfg, positions_data, stats_cfg, class_rules, rng)

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

	for i in limit:
		print_player_detailed(pool[i] as Dictionary, positions_data, stats_cfg, combine_tests_cfg, scouts_cfg, class_rules, rng)

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

	for p in five:
		print_player_detailed(p as Dictionary, positions_data, stats_cfg, combine_tests_cfg, scouts_cfg, class_rules, rng)

## Print scout opinions in a clean table with color-coded scores
func _print_scouts_section(
	player: Dictionary,
	scouts_cfg: Dictionary,
	positions_data: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var scouts: Array = (scouts_cfg.get("national_scouts", []) as Array)
	if scouts.is_empty():
		return

	_emit_output("\n" + _section_header("Scout Opinions", "🕵️"))

	var output := _table_begin(3)  # 3 columns for compact display

	for s in scouts:
		var scout: Dictionary = s as Dictionary
		var scout_name := String(scout.get("name", "Scout"))
		var score := ScoutRuntime.score_player(scout, player, positions_data, stats_cfg, class_rules, rng)

		# Color-code scout opinion based on score
		output += "[cell][b]%s[/b][/cell][cell]%s[/cell]" % [scout_name, _colored_value(score)]

	output += _table_end()
	_emit_output(output)
