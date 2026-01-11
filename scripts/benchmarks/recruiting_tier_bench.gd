extends SceneTree
## Performance benchmark for tier-based recruiting system
##
## Measures:
## - Baseline recruiting time (without tier system / uniform eval budgets)
## - Tier-based recruiting time (with tier-specific filtering and eval budgets)
## - Speedup ratio (expected: 2.47x from plan)
## - Total time savings (expected: 2,942ms/year on 20-year simulation)
##
## Usage:
##   godot --headless --script scripts/benchmarks/recruiting_tier_bench.gd
##
## Expected Results (from approved plan):
##   - Baseline: 4940ms/year recruiting, 31,200 evaluations/year
##   - Tier-based: 1998ms/year recruiting, 11,540 evaluations/year
##   - Speedup: 2.47x (63% reduction in evaluations)
##   - 20-year time: 175.6s → 116.8s (save 58.8s)

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")
const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")
const RecruitRater = preload("res://scripts/core/rating/RecruitRater.gd")
const ConfigService = preload("res://autoloads/Config.gd")

# Benchmark configuration
const BENCHMARK_YEARS := 5  # Run 5 years of recruiting to get stable averages
const NUM_RECRUITS_PER_YEAR := 2000  # Realistic recruit pool size
const NUM_COLLEGES := 130  # Full FBS college count
const WARMUP_RUNS := 1  # Warmup iterations before timed runs

var _results: Dictionary = {}

func _init() -> void:
	print("=" .repeat(80))
	print("TIER-BASED RECRUITING PERFORMANCE BENCHMARK")
	print("=" .repeat(80))
	print()

	# Load configurations
	var config_service := ConfigService.new()
	var colleges_cfg := config_service.get_config("world/colleges")
	var positions_cfg := config_service.get_config("positions")
	var stats_cfg := config_service.get_config("stats")
	var scouts_cfg := config_service.get_config("scouts")
	var main_cfg := config_service.get_config("main")
	var class_rules: Dictionary = main_cfg.get("class_rules", {})

	# Check if tier system is implemented
	var tier_recruiting_cfg: Dictionary = colleges_cfg.get("tier_recruiting", {})
	var tier_system_available := not tier_recruiting_cfg.is_empty()

	if not tier_system_available:
		print("WARNING: tier_recruiting config not found in colleges.json")
		print("Cannot measure tier-based performance without implementation.")
		print("Showing baseline performance only.")
		print()

	# Generate test data once for all benchmarks
	print("Generating test data...")
	var test_data := _generate_test_data(positions_cfg, stats_cfg, class_rules, main_cfg)
	var recruits: Array = test_data["recruits"]
	var colleges: Array = test_data["colleges"]
	print("  - Generated %d recruits" % recruits.size())
	print("  - Loaded %d colleges" % colleges.size())
	print()

	# Warmup
	print("Warming up (JIT compilation, cache population)...")
	for i in range(WARMUP_RUNS):
		_run_single_recruiting_cycle(
			recruits.duplicate(true),
			colleges,
			colleges_cfg,
			positions_cfg,
			stats_cfg,
			class_rules,
			scouts_cfg,
			12345,
			2025,
			false  # Sequential for warmup
		)
	print("  Warmup complete")
	print()

	# Benchmark 1: Baseline (simulated without tier filtering)
	print("=" .repeat(80))
	print("BENCHMARK 1: BASELINE (Uniform Eval Budgets)")
	print("=" .repeat(80))
	var baseline_time := _run_baseline_benchmark(
		recruits,
		colleges,
		colleges_cfg,
		positions_cfg,
		stats_cfg,
		class_rules,
		scouts_cfg
	)
	print()

	# Benchmark 2: Tier-based (with tier filtering and eval budgets)
	if tier_system_available:
		print("=" .repeat(80))
		print("BENCHMARK 2: TIER-BASED (Filtered Eval Budgets)")
		print("=" .repeat(80))
		var tier_time := _run_tier_benchmark(
			recruits,
			colleges,
			colleges_cfg,
			positions_cfg,
			stats_cfg,
			class_rules,
			scouts_cfg
		)
		print()

		# Summary comparison
		_print_comparison_summary(baseline_time, tier_time)
	else:
		print("Skipping tier-based benchmark (not yet implemented)")

	print()
	print("=" .repeat(80))
	print("BENCHMARK COMPLETE")
	print("=" .repeat(80))

	# Exit cleanly
	quit(0)

## Run baseline benchmark (simulates uniform eval budgets)
func _run_baseline_benchmark(
	recruits: Array,
	colleges: Array,
	colleges_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	scouts_cfg: Dictionary
) -> float:
	print("Configuration: All colleges use board_limit × 2 eval budget (uniform)")
	print("Expected: ~4940ms/year, 31,200 evaluations/year")
	print()

	# Create baseline config (no tier_recruiting section)
	var baseline_cfg := colleges_cfg.duplicate(true)
	if baseline_cfg.has("tier_recruiting"):
		baseline_cfg.erase("tier_recruiting")  # Remove tier config to simulate baseline

	var total_time_ms := 0.0
	var year_times := []

	for year_idx in range(BENCHMARK_YEARS):
		var year := 2025 + year_idx
		var seed := 10000 + year_idx

		# Duplicate recruits for each year (avoid state mutations)
		var year_recruits := recruits.duplicate(true)

		var start_time := Time.get_ticks_msec()

		var _result := _run_single_recruiting_cycle(
			year_recruits,
			colleges,
			baseline_cfg,
			positions_cfg,
			stats_cfg,
			class_rules,
			scouts_cfg,
			seed,
			year,
			true  # Use parallel for realistic performance
		)

		var elapsed_ms := float(Time.get_ticks_msec() - start_time)
		year_times.append(elapsed_ms)
		total_time_ms += elapsed_ms

		print("  Year %d: %.2f ms" % [year, elapsed_ms])

	var avg_time_ms := total_time_ms / float(BENCHMARK_YEARS)
	var min_time: float = year_times.min()
	var max_time: float = year_times.max()

	print()
	print("Baseline Results:")
	print("  - Average: %.2f ms/year" % avg_time_ms)
	print("  - Min:     %.2f ms/year" % min_time)
	print("  - Max:     %.2f ms/year" % max_time)
	print("  - Total:   %.2f ms (%d years)" % [total_time_ms, BENCHMARK_YEARS])

	_results["baseline_avg_ms"] = avg_time_ms
	_results["baseline_total_ms"] = total_time_ms

	return avg_time_ms

## Run tier-based benchmark (with tier filtering and eval budgets)
func _run_tier_benchmark(
	recruits: Array,
	colleges: Array,
	colleges_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	scouts_cfg: Dictionary
) -> float:
	print("Configuration: Tier-specific eval budgets and filtering")
	print("Expected: ~1998ms/year, 11,540 evaluations/year (2.47x speedup)")
	print()

	var total_time_ms := 0.0
	var year_times := []

	for year_idx in range(BENCHMARK_YEARS):
		var year := 2025 + year_idx
		var seed := 10000 + year_idx

		# Duplicate recruits for each year
		var year_recruits := recruits.duplicate(true)

		var start_time := Time.get_ticks_msec()

		var _result := _run_single_recruiting_cycle(
			year_recruits,
			colleges,
			colleges_cfg,  # Contains tier_recruiting section
			positions_cfg,
			stats_cfg,
			class_rules,
			scouts_cfg,
			seed,
			year,
			true  # Use parallel for realistic performance
		)

		var elapsed_ms := float(Time.get_ticks_msec() - start_time)
		year_times.append(elapsed_ms)
		total_time_ms += elapsed_ms

		print("  Year %d: %.2f ms" % [year, elapsed_ms])

	var avg_time_ms := total_time_ms / float(BENCHMARK_YEARS)
	var min_time: float = year_times.min()
	var max_time: float = year_times.max()

	print()
	print("Tier-Based Results:")
	print("  - Average: %.2f ms/year" % avg_time_ms)
	print("  - Min:     %.2f ms/year" % min_time)
	print("  - Max:     %.2f ms/year" % max_time)
	print("  - Total:   %.2f ms (%d years)" % [total_time_ms, BENCHMARK_YEARS])

	_results["tier_avg_ms"] = avg_time_ms
	_results["tier_total_ms"] = total_time_ms

	return avg_time_ms

## Print comparison summary with expected vs actual results
func _print_comparison_summary(baseline_ms: float, tier_ms: float) -> void:
	print("=" .repeat(80))
	print("PERFORMANCE COMPARISON")
	print("=" .repeat(80))
	print()

	var speedup := baseline_ms / tier_ms if tier_ms > 0.0 else 0.0
	var time_saved_ms := baseline_ms - tier_ms
	var reduction_pct := (time_saved_ms / baseline_ms) * 100.0 if baseline_ms > 0.0 else 0.0

	print("Measured Results:")
	print("  - Baseline:     %.2f ms/year" % baseline_ms)
	print("  - Tier-based:   %.2f ms/year" % tier_ms)
	print("  - Speedup:      %.2fx" % speedup)
	print("  - Time saved:   %.2f ms/year" % time_saved_ms)
	print("  - Reduction:    %.1f%%" % reduction_pct)
	print()

	# Calculate 20-year simulation projections
	var baseline_20yr_s := (baseline_ms * 20.0) / 1000.0
	var tier_20yr_s := (tier_ms * 20.0) / 1000.0
	var savings_20yr_s := baseline_20yr_s - tier_20yr_s

	print("20-Year Simulation Projection:")
	print("  - Baseline:     %.1f seconds (recruiting only)" % baseline_20yr_s)
	print("  - Tier-based:   %.1f seconds (recruiting only)" % tier_20yr_s)
	print("  - Time saved:   %.1f seconds" % savings_20yr_s)
	print()

	# Compare against expected results from plan
	var expected_speedup := 2.47
	var expected_baseline_ms := 4940.0
	var expected_tier_ms := 1998.0

	print("Expected Results (from plan):")
	print("  - Baseline:     %.2f ms/year" % expected_baseline_ms)
	print("  - Tier-based:   %.2f ms/year" % expected_tier_ms)
	print("  - Speedup:      %.2fx" % expected_speedup)
	print("  - Evaluations:  31,200 → 11,540 (63% reduction)")
	print()

	# Validation
	print("Validation:")
	if speedup >= expected_speedup * 0.8:  # Allow 20% margin
		print("  ✓ PASSED: Achieved %.2fx speedup (target: %.2fx)" % [speedup, expected_speedup])
	else:
		print("  ⚠ WARNING: Achieved %.2fx speedup, expected %.2fx" % [speedup, expected_speedup])

	if reduction_pct >= 50.0:  # Expect at least 50% reduction
		print("  ✓ PASSED: %.1f%% reduction in recruiting time" % reduction_pct)
	else:
		print("  ⚠ WARNING: Only %.1f%% reduction, expected ~60-70%%" % reduction_pct)

	print()

	# Additional insights
	print("Performance Notes:")
	print("  - Tier system should show larger gains on realistic 2000-recruit pools")
	print("  - Speedup improves with better filtering (more recruits filtered out)")
	print("  - Regional filtering (low tier) provides additional speedup")
	print("  - Parallel execution may show different speedup ratios due to overhead")

## Run a single recruiting cycle (helper)
func _run_single_recruiting_cycle(
	recruits: Array,
	colleges: Array,
	colleges_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	scouts_cfg: Dictionary,
	seed: int,
	year: int,
	use_parallel: bool
) -> Dictionary:
	var pipeline := CollegeRecruiting.new()

	var result := pipeline.run(
		recruits,
		colleges,
		colleges_cfg,
		positions_cfg,
		stats_cfg,
		class_rules,
		scouts_cfg,
		seed,
		year,
		use_parallel
	)

	return result

## Generate test data for benchmarks
func _generate_test_data(
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	# Generate realistic recruit pool
	var generator := PlayerGenerator.new()
	generator.main_cfg = main_cfg
	generator.positions_data = positions_cfg
	generator.stats_cfg = stats_cfg
	generator.names_cfg = {}  # Skip names for benchmark
	generator.class_rules = class_rules

	var base_seed := int(main_cfg.get("random_seed", 2025))
	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed

	var gaussian_share := float(class_rules.get("gaussian_share", 0.75))

	# Generate recruits
	print("  Generating %d recruits..." % NUM_RECRUITS_PER_YEAR)
	var recruits: Array = generator.generate_class(NUM_RECRUITS_PER_YEAR, gaussian_share, rng)

	# Rate recruits (needed for composite_score filtering)
	var rater := RecruitRater.new()
	rater.rate_and_rank(recruits, positions_cfg, class_rules, 4)  # Use 4 threads

	# Assign home regions to recruits (needed for regional filtering)
	var regions := ["south", "midwest", "west", "northeast"]
	for i in range(recruits.size()):
		var recruit: Dictionary = recruits[i]
		recruit["home_region"] = regions[i % regions.size()]

	# Load colleges from config
	var config_service := ConfigService.new()
	var world_colleges_cfg := config_service.get_config("world/colleges")
	var colleges_list: Array = world_colleges_cfg.get("colleges", [])

	# Ensure we have tier information for colleges
	var colleges := []
	for college_data in colleges_list:
		var college: Dictionary = college_data
		# Ensure tier is set based on eliteness if missing
		if not college.has("tier"):
			var eliteness := float(college.get("eliteness", 50.0))
			if eliteness >= 88.0:
				college["tier"] = "elite"
			elif eliteness >= 76.0:
				college["tier"] = "power"
			elif eliteness >= 62.0:
				college["tier"] = "mid"
			else:
				college["tier"] = "low"
		colleges.append(college)

	# Limit to NUM_COLLEGES for consistent benchmarking
	if colleges.size() > NUM_COLLEGES:
		colleges = colleges.slice(0, NUM_COLLEGES)

	return {
		"recruits": recruits,
		"colleges": colleges
	}
