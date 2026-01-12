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
   - Legacy player-only bootstrap (BootstrapWorld)
   - World generation with phase timing capture (BootstrapGameWorld)
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

World Generation:
  5-Year World Gen:         125.00 seconds
  20-Year World Gen:        485.00 seconds
  Phase Breakdown (20-year totals):
    nfl_season:                      85000.00 ms (85.00 s)
    college_season:                  72000.00 ms (72.00 s)
    college_recruiting:              45000.00 ms (45.00 s)
    hs_season:                       28000.00 ms (28.00 s)
    nfl_draft:                       15000.00 ms (15.00 s)
    draft_prep:                      12000.00 ms (12.00 s)
    hs_generation:                   8500.00 ms (8.50 s)
    hs_assignment:                   2500.00 ms (2.50 s)
    college_generation:              450.00 ms (0.45 s)
    nfl_team_generation:             320.00 ms (0.32 s)
    cap_validation:                  180.00 ms (0.18 s)

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

## World Generation Timing Capture

Starting with Task P1, world generation benchmarks include per-phase timing data:

### JSON Structure

```json
{
  "bootstrap": {
    "world_generation_20_year": {
      "time_us": 485000000,
      "time_ms": 485000.0,
      "time_seconds": 485.0,
      "summary": {
        "hs_schools": 500,
        "hs_players": 8000,
        "colleges": 64,
        "college_players": 3200,
        "nfl_teams": 32,
        "nfl_players": 1696,
        "retired_players": 12000
      },
      "phase_timings": {
        "hs_generation": 8500000,
        "hs_assignment": 2500000,
        "hs_season": 28000000,
        "college_generation": 450000,
        "nfl_team_generation": 320000,
        "college_recruiting": 45000000,
        "college_season": 72000000,
        "draft_prep": 12000000,
        "cap_validation": 180000,
        "nfl_draft": 15000000,
        "nfl_season": 85000000
      },
      "phase_timings_ms": {
        "hs_generation": 8500.0,
        "hs_assignment": 2500.0,
        "hs_season": 28000.0,
        "college_generation": 450.0,
        "nfl_team_generation": 320.0,
        "college_recruiting": 45000.0,
        "college_season": 72000.0,
        "draft_prep": 12000.0,
        "cap_validation": 180.0,
        "nfl_draft": 15000.0,
        "nfl_season": 85000.0
      },
      "per_year_phase_timings": [
        {
          "year": 2006,
          "phases": {
            "hs_generation": 425000,
            "hs_assignment": 125000,
            "hs_season": 1400000,
            "college_generation": 450000,
            "nfl_team_generation": 320000,
            "college_recruiting": 2250000,
            "college_season": 3600000,
            "draft_prep": 600000,
            "cap_validation": 9000,
            "nfl_draft": 750000,
            "nfl_season": 4250000
          }
        }
      ]
    }
  }
}
```

### Field Descriptions

- **phase_timings**: Total microseconds per phase across all simulated years
- **phase_timings_ms**: Same data in milliseconds for readability
- **per_year_phase_timings**: Array of per-year breakdowns (useful for identifying year-specific outliers)
- **summary**: Entity counts at end of simulation

### Determinism Guarantee

Timing capture is **opt-in** (default: `false`) and **never alters simulation results**:
- No RNG calls added for timing
- Phase execution order unchanged
- Same seed produces identical `world_state` with or without timing capture
- Timing data excluded from determinism tests

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
