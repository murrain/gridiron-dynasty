## Dry-run scene helper to bootstrap world history and summarize key signals.
extends Node
class_name WorldHistoryPreview

const DEFAULT_HISTORY_YEARS: int = 20
const PRO_READY_MIN_AGE: int = 22
const PRO_READY_MAX_AGE: int = 32

class OutputConfig:
	extends Resource

	@export var auto_scroll: bool = true
	@export var append_newline: bool = true
	@export var clear_on_run: bool = true
	@export var max_lines: int = 0

@export var history_years: int = DEFAULT_HISTORY_YEARS
@export var output_label_path: NodePath = NodePath("OutputPanel/OutputScroll/OutputText")
@export var output_config: OutputConfig = OutputConfig.new()

var output_label: RichTextLabel

func _ready() -> void:
	output_label = get_node_or_null(output_label_path) as RichTextLabel
	run()

func run() -> Dictionary:
	if output_label != null and output_config.clear_on_run:
		output_label.clear()

	var _cfg_all: Dictionary = Config.get_all()
	var main_cfg: Dictionary = Config.get_config("main")
	var positions_cfg: Dictionary = Config.get_config("positions")
	var stats_cfg: Dictionary = Config.get_config("stats")

	var start_year := int(main_cfg.get("starting_year", 2025))
	var base_seed := int(main_cfg.get("random_seed", 0))
	var years := max(1, history_years)
	var first_year := start_year - years + 1

	_emit_output("🌎 Bootstrapping world history %d → %d (%d seasons)" % [first_year, start_year, years])

	var world_state: Dictionary = {}
	var yearly_results: Array = []
	var advance := AdvanceWorldYear.new()
	for year in range(first_year, start_year + 1):
		var year_seed := _resolve_year_seed(base_seed, year)
		var output := advance.run(world_state, year, year_seed)
		world_state = output.get("world_state", world_state)
		yearly_results.append(output)

	_emit_output("✅ Ran %d world years." % yearly_results.size())

	var bootstrap := BootstrapWorld.new()
	bootstrap.years_back = years
	var pro_state: Dictionary = bootstrap.run()

	var latest_recruits := _latest_recruit_pool(world_state, start_year, first_year)
	var buckets := _bucket_recruit_scores(latest_recruits)
	var program_summary := _summarize_college_classes(world_state, latest_recruits)
	var pro_snapshot := _build_pro_snapshot(pro_state, positions_cfg, stats_cfg)

	_emit_output("")
	_emit_output("=== World State Snapshot ===")
	_emit_output("High schools: %d" % _count_array(world_state.get("hs_schools", [])))
	_emit_output("High school players (active): %d" % _count_array(world_state.get("hs_players", [])))
	_emit_output("Colleges: %d" % _count_array(world_state.get("colleges", [])))
	_emit_output("Latest recruit pool: %d" % latest_recruits.size())

	_emit_output("")
	_emit_output("=== Recruit Skill Distribution (latest pool) ===")
	for label in buckets.keys():
		_emit_output("%s: %d" % [label, int(buckets[label])])

	_emit_output("")
	_emit_output("=== College Programs (proxy for team heat) ===")
	_emit_output("Hot programs (avg recruit composite score):")
	_emit_program_rankings(program_summary, true, 5)
	_emit_output("Cold programs (avg recruit composite score):")
	_emit_program_rankings(program_summary, false, 5)

	_emit_output("")
	_emit_output("=== Pro-Level Player Pool (draft-class bootstrap) ===")
	_emit_pro_snapshot(pro_snapshot)

	return {
		"years": years,
		"first_year": first_year,
		"current_year": start_year,
		"world_state": world_state,
		"yearly_results": yearly_results,
		"latest_recruits": latest_recruits,
		"recruit_buckets": buckets,
		"program_summary": program_summary,
		"pro_snapshot": pro_snapshot
	}

func _emit_output(text: String) -> void:
	if output_label == null:
		print(text)
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

func _resolve_year_seed(base_seed: int, year: int) -> int:
	if base_seed != 0:
		return Rand.splitmix64(base_seed ^ year)
	return Rand.splitmix64(year)

func _count_array(value) -> int:
	if value == null:
		return 0
	return (value as Array).size()

func _latest_recruit_pool(world_state: Dictionary, start_year: int, first_year: int) -> Array:
	var recruit_pool: Dictionary = world_state.get("hs_recruit_pool", {}) as Dictionary
	for year in range(start_year, first_year - 1, -1):
		if recruit_pool.has(year):
			return recruit_pool[year] as Array
	return []

func _bucket_recruit_scores(recruits: Array) -> Dictionary:
	var buckets := {
		"90+": 0,
		"80-89": 0,
		"70-79": 0,
		"<70": 0
	}
	for recruit in recruits:
		var r: Dictionary = recruit
		var ratings: Dictionary = r.get("ratings", {}) as Dictionary
		var score := float(ratings.get("composite_score", 0.0))
		if score >= 90.0:
			buckets["90+"] += 1
		elif score >= 80.0:
			buckets["80-89"] += 1
		elif score >= 70.0:
			buckets["70-79"] += 1
		else:
			buckets["<70"] += 1
	return buckets

func _summarize_college_classes(world_state: Dictionary, recruits: Array) -> Array:
	var classes: Dictionary = world_state.get("college_classes", {}) as Dictionary
	if classes.is_empty():
		return []
	var recruit_lookup := _recruit_lookup(recruits)
	var college_lookup := _college_lookup(world_state.get("colleges", []) as Array)
	var summary: Array = []
	for college_id in classes.keys():
		var cls: Dictionary = classes[college_id] as Dictionary
		var players: Array = cls.get("players", []) as Array
		var total := 0.0
		var count := 0
		for pid in players:
			var recruit: Dictionary = recruit_lookup.get(String(pid), {}) as Dictionary
			if recruit.is_empty():
				continue
			var ratings: Dictionary = recruit.get("ratings", {}) as Dictionary
			total += float(ratings.get("composite_score", 0.0))
			count += 1
		var avg := total / float(count) if count > 0 else 0.0
		var college_name := String(college_lookup.get(String(college_id), college_id))
		summary.append({
			"college_id": college_id,
			"college_name": college_name,
			"avg_score": avg,
			"class_size": players.size()
		})
	return summary

func _emit_program_rankings(summary: Array, descending: bool, limit: int) -> void:
	if summary.is_empty():
		_emit_output("- None (no college classes yet).")
		return
	var sorted: Array = summary.duplicate()
	sorted.sort_custom(func(a, b):
		var av := float((a as Dictionary).get("avg_score", 0.0))
		var bv := float((b as Dictionary).get("avg_score", 0.0))
		return av > bv if descending else av < bv
	)
	var count := min(limit, sorted.size())
	for i in range(count):
		var entry: Dictionary = sorted[i]
		_emit_output("- %s | avg: %.2f | class: %d" % [
			String(entry.get("college_name", "Unknown")),
			float(entry.get("avg_score", 0.0)),
			int(entry.get("class_size", 0))
		])

func _recruit_lookup(recruits: Array) -> Dictionary:
	var lookup := {}
	for recruit in recruits:
		var r: Dictionary = recruit
		var pid := String(r.get("player_id", ""))
		if pid != "":
			lookup[pid] = r
	return lookup

func _college_lookup(colleges: Array) -> Dictionary:
	var lookup := {}
	for college in colleges:
		var c: Dictionary = college
		var cid := String(c.get("id", ""))
		if cid != "":
			lookup[cid] = String(c.get("name", cid))
	return lookup

func _build_pro_snapshot(pro_state: Dictionary, positions_cfg: Dictionary, stats_cfg: Dictionary) -> Dictionary:
	var active: Array = pro_state.get("active_players", []) as Array
	var retired: Array = pro_state.get("retired_players", []) as Array
	var pro_ready := []
	for player in active:
		var p: Dictionary = player
		var age := int(p.get("age", 0))
		if age >= PRO_READY_MIN_AGE and age <= PRO_READY_MAX_AGE:
			pro_ready.append(p)

	var top_players := _top_players_by_core_rating(pro_ready, positions_cfg, stats_cfg, 10)
	return {
		"active_count": active.size(),
		"retired_count": retired.size(),
		"pro_ready_count": pro_ready.size(),
		"top_players": top_players
	}

func _emit_pro_snapshot(snapshot: Dictionary) -> void:
	_emit_output("Active players: %d" % int(snapshot.get("active_count", 0)))
	_emit_output("Retired players: %d" % int(snapshot.get("retired_count", 0)))
	_emit_output("Pro-ready cohort (age %d-%d): %d" % [
		PRO_READY_MIN_AGE,
		PRO_READY_MAX_AGE,
		int(snapshot.get("pro_ready_count", 0))
	])

	var top_players: Array = snapshot.get("top_players", []) as Array
	if top_players.is_empty():
		_emit_output("Top pro-ready players: None")
		return
	_emit_output("Top pro-ready players (core rating):")
	for entry in top_players:
		_emit_output("- %s (%s) age %d | core %.1f" % [
			String(entry.get("name", "Unknown")),
			String(entry.get("position", "")),
			int(entry.get("age", 0)),
			float(entry.get("core_rating", 0.0))
		])

func _top_players_by_core_rating(players: Array, positions_cfg: Dictionary, stats_cfg: Dictionary, limit: int) -> Array:
	var scored: Array = []
	for player in players:
		var p: Dictionary = player
		var score := _core_rating(p, positions_cfg, stats_cfg)
		var entry := p.duplicate()
		entry["core_rating"] = score
		scored.append(entry)
	scored.sort_custom(func(a, b):
		return float((a as Dictionary).get("core_rating", 0.0)) > float((b as Dictionary).get("core_rating", 0.0))
	)
	if scored.size() > limit:
		return scored.slice(0, limit)
	return scored

func _core_rating(player: Dictionary, positions_cfg: Dictionary, stats_cfg: Dictionary) -> float:
	var position := String(player.get("position", ""))
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var core_stats: Array = pos_cfg.get("core_stats", []) as Array
	var stats: Dictionary = player.get("stats", {}) as Dictionary
	if core_stats.is_empty():
		return _mean_of_stats(stats, stats_cfg)
	var total := 0.0
	var count := 0
	for stat in core_stats:
		if stats.has(stat):
			total += float(stats.get(stat, 0.0))
			count += 1
	if count == 0:
		return _mean_of_stats(stats, stats_cfg)
	return total / float(count)

func _mean_of_stats(stats: Dictionary, stats_cfg: Dictionary) -> float:
	var stat_defs := _stat_defs(stats_cfg)
	var total := 0.0
	var count := 0
	for key in stats.keys():
		if stat_defs.has(key) and stat_defs[key].get("type", "base") != "base":
			continue
		var val := stats.get(key)
		if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
			total += float(val)
			count += 1
	return (total / float(count)) if count > 0 else 0.0

func _stat_defs(stats_cfg: Dictionary) -> Dictionary:
	var out := {}
	for row in stats_cfg.get("stats", []):
		var d: Dictionary = row
		var name := String(d.get("name", ""))
		if name != "":
			out[name] = d
	return out
