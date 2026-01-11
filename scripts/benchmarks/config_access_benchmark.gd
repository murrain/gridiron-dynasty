extends Node

## Benchmark script demonstrating config access optimization (Task F6).
##
## This script compares the performance of repeated dictionary lookups
## versus pre-extracted config values.
##
## Expected results:
##   - Repeated dict access: ~5us per lookup
##   - Pre-extracted access: ~0.5us per lookup
##   - Speedup: ~10x faster

const Config = preload("res://autoloads/Config.gd")
const DevelopmentConfig = preload("res://scripts/support/config/DevelopmentConfig.gd")
const RetirementConfig = preload("res://scripts/support/config/RetirementConfig.gd")

const ITERATIONS := 10000
const POSITIONS := ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S"]

func _ready() -> void:
	print("=" * 80)
	print("Config Access Optimization Benchmark (Task F6)")
	print("=" * 80)
	print()

	var config := Config.new()
	var positions_cfg := config.get_config("positions")
	var main_cfg := config.get_config("main")

	# Warm up
	_benchmark_repeated_access(positions_cfg, main_cfg, 100)
	_benchmark_pre_extracted_access(positions_cfg, main_cfg, 100)

	print("Running benchmarks with %d iterations per position..." % ITERATIONS)
	print()

	# Method 1: Repeated dictionary access (current baseline)
	var time1 := _benchmark_repeated_access(positions_cfg, main_cfg, ITERATIONS)
	print("Method 1 (Repeated dict access): %d us total, %.2f us per lookup" % [
		time1,
		float(time1) / (ITERATIONS * POSITIONS.size())
	])

	# Method 2: Pre-extracted config (optimized)
	var time2 := _benchmark_pre_extracted_access(positions_cfg, main_cfg, ITERATIONS)
	print("Method 2 (Pre-extracted):        %d us total, %.2f us per lookup" % [
		time2,
		float(time2) / (ITERATIONS * POSITIONS.size())
	])

	print()
	var speedup := float(time1) / float(time2) if time2 > 0 else 0.0
	var improvement := ((float(time1) - float(time2)) / float(time1) * 100.0) if time1 > 0 else 0.0
	print("Speedup: %.2fx faster" % speedup)
	print("Improvement: %.1f%% reduction in access time" % improvement)
	print()

	# Estimate impact on full simulation
	var players_per_year := 10000  # Typical high school player count
	var lookups_per_player := 20  # Approximate lookups per player per year
	var total_lookups := players_per_year * lookups_per_player

	var baseline_time_ms := (time1 * total_lookups) / (ITERATIONS * POSITIONS.size()) / 1000.0
	var optimized_time_ms := (time2 * total_lookups) / (ITERATIONS * POSITIONS.size()) / 1000.0
	var savings_ms := baseline_time_ms - optimized_time_ms

	print("Estimated impact on 10k player simulation:")
	print("  Baseline:  %.1f ms" % baseline_time_ms)
	print("  Optimized: %.1f ms" % optimized_time_ms)
	print("  Savings:   %.1f ms (%.1f%% faster)" % [savings_ms, improvement])
	print()

	print("=" * 80)
	print("Benchmark complete. Press Ctrl+C to exit.")
	print("=" * 80)

	# Don't quit immediately so results can be seen
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

## Benchmark: Repeated dictionary access (baseline)
func _benchmark_repeated_access(positions_cfg: Dictionary, main_cfg: Dictionary, iterations: int) -> int:
	var start := Time.get_ticks_usec()

	for _i in range(iterations):
		for pos in POSITIONS:
			# Simulate typical config accesses in _apply_development
			var pos_cfg: Dictionary = positions_cfg.get(pos, {}) as Dictionary
			var dev_cfg: Dictionary = pos_cfg.get("development", {}) as Dictionary
			var _peak_age := int(dev_cfg.get("peak_age", 26))
			var _decline_start := int(dev_cfg.get("decline_start", 30))
			var _curve := String(dev_cfg.get("curve", "mid"))

			var dev_global: Dictionary = main_cfg.get("development", {}) as Dictionary
			var _base_min := float(main_cfg.get("annual_base_progress_min", 1.0))
			var _base_max := float(main_cfg.get("annual_base_progress_max", 4.0))
			var _cap := float(main_cfg.get("annual_progress_cap", 6.0))

	var elapsed := Time.get_ticks_usec() - start
	return elapsed

## Benchmark: Pre-extracted config access (optimized)
func _benchmark_pre_extracted_access(positions_cfg: Dictionary, main_cfg: Dictionary, iterations: int) -> int:
	# Pre-extract once (this cost is amortized across all players)
	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)
	var ret_config := RetirementConfig.new(main_cfg)

	var start := Time.get_ticks_usec()

	for _i in range(iterations):
		for pos in POSITIONS:
			# Optimized config accesses (O(1) member access)
			var _peak_age := dev_config.peak_age(pos)
			var _decline_start := dev_config.decline_start(pos)
			var _curve := dev_config.curve_name(pos)

			var base_range := dev_config.base_progress_range()
			var _base_min := base_range.x
			var _base_max := base_range.y
			var _cap := dev_config.progress_cap()

	var elapsed := Time.get_ticks_usec() - start
	return elapsed
