# Task F8: Performance Benchmark Suite

**Track**: Performance Optimization (Track F)
**Dependencies**: F1-F7 (All optimizations)
**Status**: Not started
**Estimated Effort**: 1 day
**Priority**: Validation (Required for measuring success)

## Purpose

Create a comprehensive benchmark suite to:
1. Measure baseline performance before optimizations
2. Track improvement after each optimization task
3. Catch performance regressions
4. Provide data for optimization decisions

## Benchmark Categories

### 1. Phase Timing Benchmarks

Measure time for each simulation phase:

```gdscript
class PhaseBenchmark:
    var phase_times: Dictionary = {}

    func benchmark_phases(years: int = 5, seed: int = 42) -> Dictionary:
        var advance := AdvanceWorldYear.new()
        var world_state := {}

        for year in range(2006, 2006 + years):
            var year_seed := Rand.splitmix64(seed ^ year)
            var phases := WorldCalendar.new().phases_for_year(year, ...)

            for phase in phases:
                var phase_id := String(phase.get("phase_id", ""))
                var start := Time.get_ticks_usec()

                # Run phase handler
                _run_phase(advance, world_state, year, year_seed, phase)

                var elapsed := Time.get_ticks_usec() - start
                _accumulate(phase_id, elapsed)

        return _summarize()

    func _summarize() -> Dictionary:
        var summary := {}
        for phase_id in phase_times.keys():
            var times: Array = phase_times[phase_id]
            summary[phase_id] = {
                "total_us": _sum(times),
                "avg_us": _avg(times),
                "min_us": times.min(),
                "max_us": times.max(),
                "count": times.size()
            }
        return summary
```

### 2. Operation Benchmarks

Measure specific operations:

```gdscript
func benchmark_player_generation(count: int = 2000, iterations: int = 3) -> Dictionary:
    var times: Array = []
    for i in range(iterations):
        var rng := RandomNumberGenerator.new()
        rng.seed = 42 + i

        var start := Time.get_ticks_usec()
        var gen := DraftClassGenerator.new()
        gen.generate_for_year(2025, rng.seed)
        var elapsed := Time.get_ticks_usec() - start

        times.append(elapsed)

    return {
        "operation": "player_generation",
        "count": count,
        "avg_us": _avg(times),
        "total_us": _sum(times),
        "per_player_us": _avg(times) / count
    }

func benchmark_scout_evaluation(pool_size: int = 200, iterations: int = 5) -> Dictionary:
    var players := _generate_test_players(pool_size)
    var scout := _create_test_scout()
    var times: Array = []

    for i in range(iterations):
        var rng := RandomNumberGenerator.new()
        rng.seed = 42 + i

        var start := Time.get_ticks_usec()
        for player in players:
            ScoutRuntime.score_player(scout, player, positions_cfg, stats_cfg, class_rules, rng)
        var elapsed := Time.get_ticks_usec() - start

        times.append(elapsed)

    return {
        "operation": "scout_evaluation",
        "pool_size": pool_size,
        "avg_us": _avg(times),
        "per_player_us": _avg(times) / pool_size
    }

func benchmark_lifecycle_advancement(player_count: int = 2000, iterations: int = 3) -> Dictionary:
    var players := _generate_test_players(player_count)
    var times: Array = []

    for i in range(iterations):
        var rng := RandomNumberGenerator.new()
        rng.seed = 42 + i
        var players_copy := players.duplicate(true)

        var start := Time.get_ticks_usec()
        PlayerLifecycle.advance_one_year(players_copy, positions_cfg, main_cfg, stats_cfg, rng)
        var elapsed := Time.get_ticks_usec() - start

        times.append(elapsed)

    return {
        "operation": "lifecycle_advancement",
        "player_count": player_count,
        "avg_us": _avg(times),
        "per_player_us": _avg(times) / player_count
    }
```

### 3. Full Bootstrap Benchmark

End-to-end bootstrap timing:

```gdscript
func benchmark_full_bootstrap(years: int = 20, seed: int = 42) -> Dictionary:
    var start := Time.get_ticks_usec()

    var bootstrap := BootstrapGameWorld.new()
    bootstrap.years_to_simulate = years
    var result := bootstrap.run(seed)

    var total_us := Time.get_ticks_usec() - start

    return {
        "years": years,
        "total_us": total_us,
        "total_ms": total_us / 1000.0,
        "total_s": total_us / 1000000.0,
        "per_year_us": total_us / years,
        "per_year_ms": (total_us / years) / 1000.0,
        "summary": result.get("summary", {})
    }
```

### 4. Memory Benchmarks

Track memory usage:

```gdscript
func benchmark_memory_usage(years: int = 10) -> Dictionary:
    # Note: Godot doesn't expose detailed memory stats
    # Use OS-level monitoring or approximate via object counting

    var counts_before := _count_world_objects({})

    var bootstrap := BootstrapGameWorld.new()
    bootstrap.years_to_simulate = years
    var result := bootstrap.run(42)

    var counts_after := _count_world_objects(result.world_state)

    return {
        "years": years,
        "hs_players": counts_after.get("hs_players", 0),
        "college_players": counts_after.get("college_players", 0),
        "nfl_players": counts_after.get("nfl_players", 0),
        "retired_players": counts_after.get("retired_players", 0),
        "estimated_mb": _estimate_memory_mb(counts_after)
    }

func _count_world_objects(world_state: Dictionary) -> Dictionary:
    return {
        "hs_players": (world_state.get("hs_players", []) as Array).size(),
        "college_players": _count_college_players(world_state),
        "nfl_players": _count_nfl_players(world_state),
        "retired_players": (world_state.get("retired_players", []) as Array).size()
    }
```

## Benchmark Runner

### Scene: `benchmark_runner.tscn`

```gdscript
extends Node
class_name BenchmarkRunner

const BENCHMARK_OUTPUT_PATH := "user://benchmarks/"

@export var run_on_ready: bool = true
@export var output_json: bool = true

func _ready() -> void:
    if run_on_ready:
        run_all_benchmarks()

func run_all_benchmarks() -> Dictionary:
    _ensure_output_dir()

    var results := {
        "timestamp": Time.get_datetime_string_from_system(),
        "godot_version": Engine.get_version_info(),
        "benchmarks": {}
    }

    print("=== Starting Benchmark Suite ===")

    # Phase timing
    print("Running: Phase Timing Benchmark")
    results["benchmarks"]["phase_timing"] = _run_phase_benchmark()

    # Operation benchmarks
    print("Running: Player Generation Benchmark")
    results["benchmarks"]["player_generation"] = benchmark_player_generation()

    print("Running: Scout Evaluation Benchmark")
    results["benchmarks"]["scout_evaluation"] = benchmark_scout_evaluation()

    print("Running: Lifecycle Advancement Benchmark")
    results["benchmarks"]["lifecycle_advancement"] = benchmark_lifecycle_advancement()

    # Full bootstrap (optional - takes time)
    print("Running: Full Bootstrap Benchmark (5 years)")
    results["benchmarks"]["bootstrap_5yr"] = benchmark_full_bootstrap(5)

    # Memory
    print("Running: Memory Usage Benchmark")
    results["benchmarks"]["memory_usage"] = benchmark_memory_usage()

    print("=== Benchmark Suite Complete ===")
    _print_summary(results)

    if output_json:
        _save_results(results)

    return results

func _print_summary(results: Dictionary) -> void:
    var benchmarks: Dictionary = results.get("benchmarks", {})

    print("\n--- SUMMARY ---")

    if benchmarks.has("bootstrap_5yr"):
        var b: Dictionary = benchmarks["bootstrap_5yr"]
        print("5-Year Bootstrap: %.2f seconds (%.2f s/year)" % [
            b.get("total_s", 0),
            b.get("per_year_ms", 0) / 1000.0
        ])

    if benchmarks.has("phase_timing"):
        print("\nPhase Timing (avg per year):")
        var pt: Dictionary = benchmarks["phase_timing"]
        for phase_id in pt.keys():
            var p: Dictionary = pt[phase_id]
            print("  %s: %.2f ms" % [phase_id, p.get("avg_us", 0) / 1000.0])

    if benchmarks.has("player_generation"):
        var pg: Dictionary = benchmarks["player_generation"]
        print("\nPlayer Generation: %.2f ms for %d players (%.2f us/player)" % [
            pg.get("avg_us", 0) / 1000.0,
            pg.get("count", 0),
            pg.get("per_player_us", 0)
        ])

func _save_results(results: Dictionary) -> void:
    var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
    var path := BENCHMARK_OUTPUT_PATH + "benchmark_%s.json" % timestamp
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_string(JSON.stringify(results, "\t"))
    print("Results saved to: %s" % path)
```

## CI Integration

### Regression Detection

Compare current results to baseline:

```gdscript
func compare_to_baseline(current: Dictionary, baseline_path: String) -> Dictionary:
    var baseline := _load_baseline(baseline_path)
    if baseline.is_empty():
        return {"status": "no_baseline"}

    var regressions: Array = []
    var improvements: Array = []

    # Compare phase timing
    var current_phases: Dictionary = current.get("phase_timing", {})
    var baseline_phases: Dictionary = baseline.get("phase_timing", {})

    for phase_id in current_phases.keys():
        var curr: float = current_phases[phase_id].get("avg_us", 0)
        var base: float = baseline_phases.get(phase_id, {}).get("avg_us", curr)

        var change_pct := ((curr - base) / base) * 100.0 if base > 0 else 0.0

        if change_pct > 10.0:  # >10% slower
            regressions.append({
                "phase": phase_id,
                "baseline_us": base,
                "current_us": curr,
                "change_pct": change_pct
            })
        elif change_pct < -10.0:  # >10% faster
            improvements.append({
                "phase": phase_id,
                "baseline_us": base,
                "current_us": curr,
                "change_pct": change_pct
            })

    return {
        "status": "regression" if regressions.size() > 0 else "ok",
        "regressions": regressions,
        "improvements": improvements
    }
```

## Benchmark Targets

Based on F1 analysis, set targets for each optimization:

| Benchmark | Baseline | Target | Task |
|-----------|----------|--------|------|
| Per-year simulation | ~36s | <9s | All |
| college_recruiting phase | ~15s | <5s | F2, F3 |
| nfl_draft phase | ~5s | <1s | F3 |
| hs_season phase | ~3s | <1s | F4, F5 |
| college_season phase | ~5s | <2s | F4, F5 |
| nfl_season phase | ~4s | <1.5s | F4, F5 |
| Player generation | ~2s | <1s | F4 |
| Scout evaluation (per player) | ~50us | <10us | F3 |
| Memory (10yr bootstrap) | ~500MB | <200MB | F7 |

## Acceptance Criteria

- [ ] BenchmarkRunner scene created and functional
- [ ] Phase timing benchmarks implemented
- [ ] Operation benchmarks implemented (generation, scouting, lifecycle)
- [ ] Full bootstrap benchmark implemented
- [ ] Memory usage benchmark implemented
- [ ] JSON output for CI comparison
- [ ] Baseline comparison function
- [ ] Summary output for quick review
- [ ] All benchmarks reproducible with fixed seeds

## Files to Create

- `scripts/benchmarks/BenchmarkRunner.gd`
- `scripts/benchmarks/PhaseBenchmark.gd`
- `scripts/benchmarks/OperationBenchmark.gd`
- `scripts/benchmarks/MemoryBenchmark.gd`
- `benchmark_runner.tscn`

## Usage

```bash
# Run benchmarks headless
godot --headless benchmark_runner.tscn

# Results saved to user://benchmarks/benchmark_YYYY-MM-DD_HH-MM-SS.json
```

## Next Steps

After completing F8:
1. Run baseline benchmarks before any optimization
2. Save baseline results
3. Implement F2-F7 optimizations
4. Re-run benchmarks after each task
5. Verify targets met
6. Document final improvements
