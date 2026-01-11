# Performance Benchmark Suite

## Quick Start

```bash
# Run full benchmark suite (5-15 minutes)
godot --headless -s res://scripts/tests/BenchmarkRunner.gd
```

## What Gets Benchmarked

The suite measures 4 categories:

1. **Phase Timing** - Individual simulation phases (HS generation, season, recruiting)
2. **Operations** - Atomic operations (player gen, scout eval, lifecycle)
3. **Bootstrap** - End-to-end simulation (5-year and 20-year)
4. **Memory** - Memory usage estimates

## Output

Results are saved to:
- `user://benchmarks/benchmark_TIMESTAMP.json` - Full results with metadata
- `user://benchmarks/benchmark_latest.json` - Latest run (for easy access)

Console output provides human-readable summary.

## Setting Baseline

After first successful run:

```bash
# Copy latest to baseline
cd ~/.local/share/godot/app_userdata/gridiron-dynasty/benchmarks/
cp benchmark_latest.json benchmark_baseline.json
```

Future runs will compare against baseline and detect regressions (>10% slower).

## Reproducibility

All benchmarks use **fixed seed** (`0xBEEF_2026`) ensuring:
- Identical player counts every run
- Same simulation complexity
- Comparable timing data

## Documentation

- **Full specification**: `docs/tasks/TASK_F8_benchmark_suite.md`
- **Usage guide**: `scripts/tests/BENCHMARK_USAGE.md`

## Validation

Before running benchmarks, verify implementation:

```bash
godot --headless -s res://scripts/tests/verify_benchmark.gd
```

This checks that all dependencies load correctly.

## Example Output

```
================================================================================
BENCHMARK SUMMARY
================================================================================

Phase Timing:
  HS Generation:            1250.00 ms
  HS Season:                850.00 ms
  College Recruiting:       2100.00 ms

Operations:
  Player Generation:        1250.00 ms
  Scout Evaluation:         450.00 ms
  Lifecycle Advancement:    320.00 ms

Bootstrap:
  5-Year Bootstrap:         95.50 seconds
  20-Year Bootstrap:        320.50 seconds

Memory:
  Player Memory:            ~4.00 KB/player
  World State (5yr):        ~38.80 MB

Total Benchmark Time: 350.00 seconds
```

## Baseline Comparison

If baseline exists, automatic comparison is performed:

```
BASELINE COMPARISON
================================================================================
  player_generation: 1250.00 ms -> 1150.00 ms (-8.0%) [OK]
  scout_evaluation: 450.00 ms -> 550.00 ms (+22.2%) [REGRESSION]
  bootstrap_5_year: 95.50 seconds -> 92.30 seconds (-3.4%) [OK]
================================================================================
```

- `OK` - Within 10% (acceptable)
- `REGRESSION` - >10% slower (needs attention)
- `IMPROVEMENT` - >10% faster (optimization success)

## Using for Optimization

1. **Establish baseline** before optimization
2. **Make changes** to target system
3. **Run benchmarks** to measure impact
4. **Compare results** to validate improvement
5. **Update baseline** if successful

See `scripts/tests/BENCHMARK_USAGE.md` for detailed workflow.

## Performance Expectations

Expected ranges (varies by hardware):

| Benchmark | Fast | Slow | Units |
|-----------|------|------|-------|
| Player Generation | 500-800 | 1200-1500 | ms |
| 5-Year Bootstrap | 60-90 | 150-180 | seconds |
| 20-Year Bootstrap | 240-360 | 480-600 | seconds |

**Use relative comparison (baseline) rather than absolute times.**

## Implementation Details

- **Timing precision**: Microsecond (`Time.get_ticks_usec()`)
- **Fixed seed**: `0xBEEF_2026`
- **Output format**: JSON with full metadata
- **Regression threshold**: 10%

## Files

- `scripts/tests/BenchmarkRunner.gd` - Main benchmark suite
- `scripts/tests/verify_benchmark.gd` - Validation script
- `benchmark_runner.tscn` - Scene file
- `docs/tasks/TASK_F8_benchmark_suite.md` - Full specification
- `scripts/tests/BENCHMARK_USAGE.md` - Detailed usage guide

## Next Steps

After running benchmarks:
1. Establish baseline (copy latest to baseline)
2. Analyze results to identify bottlenecks
3. Use for optimization validation (Track F9+)

---

**Part of Phase F (Performance Optimization)**
