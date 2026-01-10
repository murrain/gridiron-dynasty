extends SceneTree
## Performance Benchmark Suite
##
## Measures execution time and memory usage for core simulation systems.
## All benchmarks use fixed seeds for reproducibility.
##
## Usage:
##   godot --headless -s res://scripts/tests/BenchmarkRunner.gd
##
## Output:
##   - Human-readable summary to console
##   - JSON results to user://benchmarks/benchmark_TIMESTAMP.json
##   - Baseline comparison if baseline exists

const Config = preload("res://autoloads/Config.gd")
const Rand = preload("res://autoloads/Rand.gd")
const DraftClassGenerator = preload("res://scripts/generation/DraftClassGenerator.gd")
const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")
const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")
const BootstrapWorld = preload("res://scripts/pipelines/BootstrapWorld.gd")
const HighSchoolSeason = preload("res://scripts/world/HighSchoolSeason.gd")
const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")

# Fixed seed for reproducibility
const BENCHMARK_SEED := 0xBENCH_2026

# Benchmark configuration
const PLAYER_GEN_CLASS_SIZE := 2000
const SCOUT_EVAL_SAMPLE_SIZE := 100
const LIFECYCLE_BATCH_SIZE := 1000
const MEMORY_SAMPLE_SIZE := 10000

var _results: Dictionary = {}
var _config_instance: Node = null

func _init() -> void:
	print("=" * 80)
	print("GRIDIRON DYNASTY - PERFORMANCE BENCHMARK SUITE")
	print("=" * 80)
	print("")

	var start_time := Time.get_ticks_usec()

	# Run all benchmark categories
	_results["metadata"] = _collect_metadata()
	_results["phase_timing"] = _run_phase_timing_benchmarks()
	_results["operations"] = _run_operation_benchmarks()
	_results["bootstrap"] = _run_bootstrap_benchmarks()
	_results["memory"] = _run_memory_benchmarks()

	var total_time := Time.get_ticks_usec() - start_time
	_results["metadata"]["total_benchmark_time_ms"] = total_time / 1000.0

	# Save results and compare to baseline
	var output_path := _save_results()
	_print_summary()
	_compare_to_baseline(output_path)

	print("")
	print("=" * 80)
	print("BENCHMARK COMPLETE")
	print("Results saved to: %s" % output_path)
	print("=" * 80)

	quit(0)

func _collect_metadata() -> Dictionary:
	return {
		"timestamp": Time.get_datetime_string_from_system(),
		"timestamp_unix": Time.get_unix_time_from_system(),
		"godot_version": Engine.get_version_info(),
		"seed": BENCHMARK_SEED,
		"platform": OS.get_name(),
		"processor_count": OS.get_processor_count()
	}

# ============================================================================
# PHASE TIMING BENCHMARKS
# ============================================================================

func _run_phase_timing_benchmarks() -> Dictionary:
	print("\n[1/4] PHASE TIMING BENCHMARKS")
	print("-" * 80)

	var results := {}

	# Benchmark individual phases from AdvanceWorldYear
	results["hs_generation"] = _benchmark_hs_generation()
	results["hs_season"] = _benchmark_hs_season()
	results["college_recruiting"] = _benchmark_college_recruiting()

	return results

func _benchmark_hs_generation() -> Dictionary:
	print("  - High School Generation...", " " * 40)

	var world_state := {}
	var year := 2025
	var seed := BENCHMARK_SEED

	var start := Time.get_ticks_usec()

	# Generate draft class (which happens in HS generation)
	var generator := DraftClassGenerator.new()
	var players := generator.generate_for_year(year, seed)

	var elapsed := Time.get_ticks_usec() - start

	print("    %d players in %.2f ms" % [players.size(), elapsed / 1000.0])

	return {
		"time_us": elapsed,
		"time_ms": elapsed / 1000.0,
		"players_generated": players.size(),
		"us_per_player": float(elapsed) / players.size()
	}

func _benchmark_hs_season() -> Dictionary:
	print("  - High School Season...", " " * 40)

	# Setup: Generate players and schools
	var generator := DraftClassGenerator.new()
	var players := generator.generate_for_year(2025, BENCHMARK_SEED)

	# Create minimal schools
	var schools: Array = []
	for i in range(100):
		schools.append({
			"id": "hs_%d" % i,
			"name": "School %d" % i,
			"region": "midwest"
		})

	# Assign players to schools
	for i in range(players.size()):
		var p: Dictionary = players[i]
		p["hs_school_id"] = "hs_%d" % (i % schools.size())
		p["hs_year"] = 4  # Seniors
		p["eligibility_status"] = "hs_senior"
		players[i] = p

	var config := _get_config()
	var positions_cfg := config.get_config("positions")
	var main_cfg := config.get_config("main")
	var stats_cfg := config.get_config("stats")
	var hs_cfg := config.get_config("world/high_schools")

	var rng := RandomNumberGenerator.new()
	rng.seed = BENCHMARK_SEED

	var start := Time.get_ticks_usec()

	var season := HighSchoolSeason.new()
	var output := season.run(players, schools, positions_cfg, main_cfg, stats_cfg, hs_cfg, BENCHMARK_SEED, 2025)

	var elapsed := Time.get_ticks_usec() - start

	var graduates := (output.get("graduates", []) as Array).size()
	print("    %d graduates in %.2f ms" % [graduates, elapsed / 1000.0])

	return {
		"time_us": elapsed,
		"time_ms": elapsed / 1000.0,
		"input_players": players.size(),
		"graduates": graduates,
		"us_per_player": float(elapsed) / players.size()
	}

func _benchmark_college_recruiting() -> Dictionary:
	print("  - College Recruiting...", " " * 40)

	# Setup: Generate recruits
	var generator := DraftClassGenerator.new()
	var players := generator.generate_for_year(2025, BENCHMARK_SEED)

	# Convert to recruit profiles
	var recruits: Array = []
	for p in players:
		var recruit := {
			"player_id": p.get("player_id", ""),
			"name": p.get("name", ""),
			"position": p.get("position", ""),
			"home_region": "midwest",
			"hs_school_id": "hs_1",
			"eligibility_status": "hs_graduate",
			"hs_grad_year": 2025,
			"stats": p.get("stats", {}),
			"potential": p.get("potential", {}),
			"physicals": p.get("physicals", {}),
			"ratings": {
				"composite_score": 50.0,
				"star_score": 3.0,
				"core_avg": 50.0
			}
		}
		recruits.append(recruit)

	# Create minimal colleges
	var colleges: Array = []
	for i in range(32):
		colleges.append({
			"id": "college_%d" % i,
			"name": "College %d" % i,
			"prestige": 50.0,
			"region": "midwest"
		})

	var config := _get_config()
	var positions_cfg := config.get_config("positions")
	var main_cfg := config.get_config("main")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var colleges_cfg := config.get_config("world/colleges")

	var start := Time.get_ticks_usec()

	var pipeline := CollegeRecruiting.new()
	var output := pipeline.run(
		recruits,
		colleges,
		colleges_cfg,
		positions_cfg,
		stats_cfg,
		main_cfg.get("class_rules", {}),
		scouts_cfg,
		BENCHMARK_SEED,
		2025
	)

	var elapsed := Time.get_ticks_usec() - start

	var commitments := (output.get("commitments", []) as Array).size()
	print("    %d commitments in %.2f ms" % [commitments, elapsed / 1000.0])

	return {
		"time_us": elapsed,
		"time_ms": elapsed / 1000.0,
		"input_recruits": recruits.size(),
		"colleges": colleges.size(),
		"commitments": commitments,
		"us_per_recruit": float(elapsed) / recruits.size()
	}

# ============================================================================
# OPERATION BENCHMARKS
# ============================================================================

func _run_operation_benchmarks() -> Dictionary:
	print("\n[2/4] OPERATION BENCHMARKS")
	print("-" * 80)

	var results := {}

	results["player_generation"] = _benchmark_player_generation()
	results["scout_evaluation"] = _benchmark_scout_evaluation()
	results["lifecycle_advancement"] = _benchmark_lifecycle_advancement()

	return results

func _benchmark_player_generation() -> Dictionary:
	print("  - Player Generation (%d players)..." % PLAYER_GEN_CLASS_SIZE)

	var start := Time.get_ticks_usec()

	var generator := DraftClassGenerator.new()
	var players := generator.generate_for_year(2025, BENCHMARK_SEED)

	var elapsed := Time.get_ticks_usec() - start

	print("    Generated %d players in %.2f ms (%.2f us/player)" % [
		players.size(),
		elapsed / 1000.0,
		float(elapsed) / players.size()
	])

	return {
		"time_us": elapsed,
		"time_ms": elapsed / 1000.0,
		"players_generated": players.size(),
		"us_per_player": float(elapsed) / players.size()
	}

func _benchmark_scout_evaluation() -> Dictionary:
	print("  - Scout Evaluation (%d players)..." % SCOUT_EVAL_SAMPLE_SIZE)

	# Setup: Generate sample players
	var generator := DraftClassGenerator.new()
	var all_players := generator.generate_for_year(2025, BENCHMARK_SEED)
	var sample_players := all_players.slice(0, SCOUT_EVAL_SAMPLE_SIZE)

	var config := _get_config()
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var main_cfg := config.get_config("main")
	var class_rules := main_cfg.get("class_rules", {})

	# Get a sample scout
	var national_scouts: Array = scouts_cfg.get("national_scouts", [])
	if national_scouts.is_empty():
		return {"error": "No scouts configured"}
	var scout: Dictionary = national_scouts[0]

	var rng := RandomNumberGenerator.new()
	rng.seed = BENCHMARK_SEED

	var start := Time.get_ticks_usec()

	# Evaluate each player
	var scores: Array = []
	for player in sample_players:
		var score := ScoutRuntime.score_player(
			scout,
			player,
			positions_cfg,
			stats_cfg,
			class_rules,
			rng
		)
		scores.append(score)

	var elapsed := Time.get_ticks_usec() - start

	print("    Evaluated %d players in %.2f ms (%.2f us/player)" % [
		sample_players.size(),
		elapsed / 1000.0,
		float(elapsed) / sample_players.size()
	])

	return {
		"time_us": elapsed,
		"time_ms": elapsed / 1000.0,
		"players_evaluated": sample_players.size(),
		"us_per_evaluation": float(elapsed) / sample_players.size(),
		"avg_score": _array_avg(scores)
	}

func _benchmark_lifecycle_advancement() -> Dictionary:
	print("  - Lifecycle Advancement (%d players)..." % LIFECYCLE_BATCH_SIZE)

	# Setup: Generate players
	var generator := DraftClassGenerator.new()
	var all_players := generator.generate_for_year(2025, BENCHMARK_SEED)
	var sample_players := all_players.slice(0, LIFECYCLE_BATCH_SIZE)

	# Set player ages
	for i in range(sample_players.size()):
		var p: Dictionary = sample_players[i]
		p["age"] = 22  # Typical NFL rookie age
		sample_players[i] = p

	var config := _get_config()
	var positions_cfg := config.get_config("positions")
	var main_cfg := config.get_config("main")
	var stats_cfg := config.get_config("stats")

	var rng := RandomNumberGenerator.new()
	rng.seed = BENCHMARK_SEED

	var start := Time.get_ticks_usec()

	var result := PlayerLifecycle.advance_one_year(
		sample_players,
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng
	)

	var elapsed := Time.get_ticks_usec() - start

	var retired := (result.get("retired", []) as Array).size()
	print("    Advanced %d players in %.2f ms (%.2f us/player, %d retired)" % [
		sample_players.size(),
		elapsed / 1000.0,
		float(elapsed) / sample_players.size(),
		retired
	])

	return {
		"time_us": elapsed,
		"time_ms": elapsed / 1000.0,
		"players_advanced": sample_players.size(),
		"retired": retired,
		"us_per_player": float(elapsed) / sample_players.size()
	}

# ============================================================================
# BOOTSTRAP BENCHMARKS
# ============================================================================

func _run_bootstrap_benchmarks() -> Dictionary:
	print("\n[3/4] BOOTSTRAP BENCHMARKS")
	print("-" * 80)
	print("  NOTE: These are end-to-end tests and may take several minutes")
	print("")

	var results := {}

	results["bootstrap_5_year"] = _benchmark_bootstrap_5_year()
	results["bootstrap_20_year"] = _benchmark_bootstrap_20_year()

	return results

func _benchmark_bootstrap_5_year() -> Dictionary:
	print("  - 5-Year Bootstrap...")

	var start := Time.get_ticks_usec()

	var bootstrap := BootstrapWorld.new()
	bootstrap.years_back = 5
	var result := bootstrap.run()

	var elapsed := Time.get_ticks_usec() - start

	var active := (result.get("active_players", []) as Array).size()
	var retired := (result.get("retired_players", []) as Array).size()

	print("    Completed in %.2f seconds" % (elapsed / 1_000_000.0))
	print("    Active: %d, Retired: %d" % [active, retired])

	return {
		"time_us": elapsed,
		"time_ms": elapsed / 1000.0,
		"time_seconds": elapsed / 1_000_000.0,
		"active_players": active,
		"retired_players": retired,
		"total_players": active + retired
	}

func _benchmark_bootstrap_20_year() -> Dictionary:
	print("  - 20-Year Bootstrap (full simulation)...")

	var start := Time.get_ticks_usec()

	var bootstrap := BootstrapWorld.new()
	bootstrap.years_back = 20
	var result := bootstrap.run()

	var elapsed := Time.get_ticks_usec() - start

	var active := (result.get("active_players", []) as Array).size()
	var retired := (result.get("retired_players", []) as Array).size()

	print("    Completed in %.2f seconds" % (elapsed / 1_000_000.0))
	print("    Active: %d, Retired: %d" % [active, retired])

	return {
		"time_us": elapsed,
		"time_ms": elapsed / 1000.0,
		"time_seconds": elapsed / 1_000_000.0,
		"active_players": active,
		"retired_players": retired,
		"total_players": active + retired
	}

# ============================================================================
# MEMORY BENCHMARKS
# ============================================================================

func _run_memory_benchmarks() -> Dictionary:
	print("\n[4/4] MEMORY BENCHMARKS")
	print("-" * 80)

	var results := {}

	results["player_memory"] = _benchmark_player_memory()
	results["world_state_memory"] = _benchmark_world_state_memory()

	return results

func _benchmark_player_memory() -> Dictionary:
	print("  - Player Memory Usage (%d players)..." % MEMORY_SAMPLE_SIZE)

	# Generate sample players
	var generator := DraftClassGenerator.new()
	var players: Array = []

	# Generate in batches to reach sample size
	var batches_needed := ceili(float(MEMORY_SAMPLE_SIZE) / PLAYER_GEN_CLASS_SIZE)
	for i in range(batches_needed):
		var batch := generator.generate_for_year(2025 + i, BENCHMARK_SEED + i)
		players.append_array(batch)

	players = players.slice(0, MEMORY_SAMPLE_SIZE)

	# Estimate memory per player (rough calculation)
	var json_string := JSON.stringify(players[0])
	var bytes_per_player := json_string.length() * 2  # UTF-16 approximation
	var total_mb := (players.size() * bytes_per_player) / (1024.0 * 1024.0)

	print("    ~%.2f MB for %d players (~%.2f KB/player)" % [
		total_mb,
		players.size(),
		bytes_per_player / 1024.0
	])

	return {
		"sample_size": players.size(),
		"estimated_bytes_per_player": bytes_per_player,
		"estimated_total_mb": total_mb,
		"estimated_kb_per_player": bytes_per_player / 1024.0
	}

func _benchmark_world_state_memory() -> Dictionary:
	print("  - World State Memory (5-year bootstrap)...")

	var bootstrap := BootstrapWorld.new()
	bootstrap.years_back = 5
	var result := bootstrap.run()

	# Estimate world state memory
	var active := result.get("active_players", [])
	var retired := result.get("retired_players", [])

	var json_active := JSON.stringify(active)
	var json_retired := JSON.stringify(retired)

	var active_mb := (json_active.length() * 2) / (1024.0 * 1024.0)
	var retired_mb := (json_retired.length() * 2) / (1024.0 * 1024.0)
	var total_mb := active_mb + retired_mb

	print("    Active: %.2f MB, Retired: %.2f MB, Total: %.2f MB" % [
		active_mb,
		retired_mb,
		total_mb
	])

	return {
		"active_players": (active as Array).size(),
		"retired_players": (retired as Array).size(),
		"estimated_active_mb": active_mb,
		"estimated_retired_mb": retired_mb,
		"estimated_total_mb": total_mb
	}

# ============================================================================
# OUTPUT AND COMPARISON
# ============================================================================

func _save_results() -> String:
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("benchmarks"):
		dir.make_dir("benchmarks")

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var filename := "benchmark_%s.json" % timestamp
	var path := "user://benchmarks/%s" % filename

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write benchmark results: %s" % path)
		return ""

	file.store_string(JSON.stringify(_results, "\t"))
	file.close()

	# Also save as "latest" for easy comparison
	var latest_path := "user://benchmarks/benchmark_latest.json"
	var latest_file := FileAccess.open(latest_path, FileAccess.WRITE)
	if latest_file != null:
		latest_file.store_string(JSON.stringify(_results, "\t"))
		latest_file.close()

	return path

func _compare_to_baseline(current_path: String) -> void:
	var baseline_path := "user://benchmarks/benchmark_baseline.json"

	if not FileAccess.file_exists(baseline_path):
		print("\nNo baseline found. To set current run as baseline:")
		print("  cp %s %s" % [
			ProjectSettings.globalize_path(current_path),
			ProjectSettings.globalize_path(baseline_path)
		])
		return

	var baseline_file := FileAccess.open(baseline_path, FileAccess.READ)
	if baseline_file == null:
		return

	var baseline_json := baseline_file.get_as_text()
	baseline_file.close()

	var baseline_results = JSON.parse_string(baseline_json)
	if baseline_results == null:
		push_error("Failed to parse baseline JSON")
		return

	print("\n" + "=" * 80)
	print("BASELINE COMPARISON")
	print("=" * 80)

	_compare_category(baseline_results, _results, "operations", "player_generation")
	_compare_category(baseline_results, _results, "operations", "scout_evaluation")
	_compare_category(baseline_results, _results, "operations", "lifecycle_advancement")
	_compare_category(baseline_results, _results, "bootstrap", "bootstrap_5_year")
	_compare_category(baseline_results, _results, "bootstrap", "bootstrap_20_year")

	print("=" * 80)

func _compare_category(baseline: Dictionary, current: Dictionary, category: String, key: String) -> void:
	var baseline_cat: Dictionary = baseline.get(category, {})
	var current_cat: Dictionary = current.get(category, {})

	var baseline_bench: Dictionary = baseline_cat.get(key, {})
	var current_bench: Dictionary = current_cat.get(key, {})

	if baseline_bench.is_empty() or current_bench.is_empty():
		return

	var baseline_time := float(baseline_bench.get("time_ms", 0.0))
	var current_time := float(current_bench.get("time_ms", 0.0))

	if baseline_time == 0.0:
		return

	var pct_change := ((current_time - baseline_time) / baseline_time) * 100.0
	var status := "OK"

	if pct_change > 10.0:
		status = "REGRESSION"
	elif pct_change < -10.0:
		status = "IMPROVEMENT"

	print("  %s: %.2f ms -> %.2f ms (%+.1f%%) [%s]" % [
		key,
		baseline_time,
		current_time,
		pct_change,
		status
	])

func _print_summary() -> void:
	print("\n" + "=" * 80)
	print("BENCHMARK SUMMARY")
	print("=" * 80)

	print("\nPhase Timing:")
	_print_bench(_results["phase_timing"], "hs_generation", "HS Generation")
	_print_bench(_results["phase_timing"], "hs_season", "HS Season")
	_print_bench(_results["phase_timing"], "college_recruiting", "College Recruiting")

	print("\nOperations:")
	_print_bench(_results["operations"], "player_generation", "Player Generation")
	_print_bench(_results["operations"], "scout_evaluation", "Scout Evaluation")
	_print_bench(_results["operations"], "lifecycle_advancement", "Lifecycle Advancement")

	print("\nBootstrap:")
	_print_bench(_results["bootstrap"], "bootstrap_5_year", "5-Year Bootstrap", true)
	_print_bench(_results["bootstrap"], "bootstrap_20_year", "20-Year Bootstrap", true)

	print("\nMemory:")
	var mem := _results["memory"]
	var player_mem: Dictionary = mem.get("player_memory", {})
	var world_mem: Dictionary = mem.get("world_state_memory", {})
	print("  Player Memory:     ~%.2f KB/player" % player_mem.get("estimated_kb_per_player", 0.0))
	print("  World State (5yr): ~%.2f MB" % world_mem.get("estimated_total_mb", 0.0))

	print("\nTotal Benchmark Time: %.2f seconds" % (_results["metadata"]["total_benchmark_time_ms"] / 1000.0))

func _print_bench(category: Dictionary, key: String, label: String, use_seconds: bool = false) -> void:
	var bench: Dictionary = category.get(key, {})
	if bench.is_empty():
		return

	if use_seconds:
		print("  %-25s %.2f seconds" % [label + ":", bench.get("time_seconds", 0.0)])
	else:
		print("  %-25s %.2f ms" % [label + ":", bench.get("time_ms", 0.0)])

func _get_config() -> Node:
	if _config_instance == null:
		_config_instance = Config.new()
	return _config_instance

func _array_avg(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var sum := 0.0
	for v in arr:
		sum += float(v)
	return sum / arr.size()
