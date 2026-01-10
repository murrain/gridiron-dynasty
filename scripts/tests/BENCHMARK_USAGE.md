# Benchmark Suite Usage Guide

## Quick Start

### Running Benchmarks

```bash
# Run full benchmark suite (5-15 minutes depending on hardware)
godot --headless -s res://scripts/tests/BenchmarkRunner.gd
```

### Expected Output

The benchmark will run 4 categories:
1. **Phase Timing** - Individual simulation phases (~1-5 minutes)
2. **Operations** - Atomic operations like player generation (~1-2 minutes)
3. **Bootstrap** - Full world bootstrap (5-year and 20-year) (~5-10 minutes)
4. **Memory** - Memory usage estimates (~1-2 minutes)

Total time: **5-15 minutes** (varies by hardware)

## Setting Up Baseline

After your first successful run:

```bash
# Find the output path (printed at end of benchmark run)
# Example output: Results saved to: user://benchmarks/benchmark_2026-01-10_12-00-00.json

# Use the globalized path shown in output, or find it manually:
cd ~/.local/share/godot/app_userdata/gridiron-dynasty/benchmarks/

# Copy latest to baseline
cp benchmark_latest.json benchmark_baseline.json
```

Future runs will automatically compare against this baseline.

## Understanding Results

### Console Output

The benchmark prints human-readable results to console:

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
```

### JSON Output

Results are saved to `user://benchmarks/` with full details:

```json
{
  "metadata": {
    "timestamp": "2026-01-10T12:00:00",
    "seed": 3135062054,
    "platform": "Linux",
    "processor_count": 8
  },
  "phase_timing": { /* ... */ },
  "operations": { /* ... */ },
  "bootstrap": { /* ... */ },
  "memory": { /* ... */ }
}
```

### Baseline Comparison

If a baseline exists, the benchmark automatically compares:

```
BASELINE COMPARISON
================================================================================
  player_generation: 1250.00 ms -> 1150.00 ms (-8.0%) [OK]
  scout_evaluation: 450.00 ms -> 550.00 ms (+22.2%) [REGRESSION]
  lifecycle_advancement: 320.00 ms -> 310.00 ms (-3.1%) [OK]
  bootstrap_5_year: 95.50 seconds -> 92.30 seconds (-3.4%) [OK]
  bootstrap_20_year: 320.50 seconds -> 325.00 seconds (+1.4%) [OK]
================================================================================
```

**Status codes:**
- `OK` - Within 10% of baseline (acceptable variance)
- `REGRESSION` - More than 10% slower (performance degradation)
- `IMPROVEMENT` - More than 10% faster (optimization success)

## Interpreting Benchmark Data

### Phase Timing
Measures complete simulation phases (high-level):
- **HS Generation**: Creating draft class + assigning HS metadata
- **HS Season**: Running high school season (year progression, stats)
- **College Recruiting**: Offers, evaluations, commitments

Use this to identify which phases need optimization.

### Operations
Measures atomic operations (low-level):
- **Player Generation**: DraftClassGenerator creating 2000 players
- **Scout Evaluation**: ScoutRuntime evaluating 100 players
- **Lifecycle Advancement**: PlayerLifecycle advancing 1000 players

Use this to profile specific systems.

### Bootstrap
Measures end-to-end simulation:
- **5-Year Bootstrap**: Quick validation (generates 5 draft classes, ages them)
- **20-Year Bootstrap**: Full simulation (20 classes, realistic player population)

Use this for overall performance tracking.

### Memory
Estimates memory footprint:
- **Player Memory**: Average bytes per player (JSON serialization proxy)
- **World State Memory**: Total memory for 5-year bootstrap

Note: Memory benchmarks are estimates (JSON serialization proxy), not exact measurements.

## Reproducibility

All benchmarks use **fixed seed** (`0xBENCH_2026`) ensuring:
- Identical player counts every run
- Same simulation complexity
- Comparable timing data

### Verifying Reproducibility

Run benchmark twice and compare player counts:

```bash
godot --headless -s res://scripts/tests/BenchmarkRunner.gd > run1.txt
godot --headless -s res://scripts/tests/BenchmarkRunner.gd > run2.txt

# Player counts should be identical
diff <(grep "players_generated" run1.txt) <(grep "players_generated" run2.txt)

# Timing should be similar (within 5-10% due to system load)
```

## Performance Expectations

Expected ranges (varies by hardware):

| Benchmark | Fast Hardware | Slow Hardware | Units |
|-----------|---------------|---------------|-------|
| Player Generation | 500-800 | 1200-1500 | ms |
| Scout Evaluation | 300-400 | 500-600 | ms |
| Lifecycle Advancement | 200-300 | 350-400 | ms |
| 5-Year Bootstrap | 60-90 | 150-180 | seconds |
| 20-Year Bootstrap | 240-360 | 480-600 | seconds |
| Player Memory | 2-4 | 6-8 | KB/player |

**Fast Hardware**: 8+ cores, SSD, 16GB+ RAM
**Slow Hardware**: 4 cores, HDD, 8GB RAM

Use **relative comparison** (baseline) rather than absolute times.

## Using Benchmarks for Optimization

### Before Optimization

1. Run baseline:
   ```bash
   godot --headless -s res://scripts/tests/BenchmarkRunner.gd
   cp ~/.local/share/godot/.../benchmark_latest.json \
      ~/.local/share/godot/.../benchmark_baseline.json
   ```

2. Identify bottlenecks from results

### After Optimization

1. Run benchmark again:
   ```bash
   godot --headless -s res://scripts/tests/BenchmarkRunner.gd
   ```

2. Check baseline comparison for improvement/regression

3. If improved >10%, update baseline

### Example Workflow

```bash
# Establish baseline
godot --headless -s res://scripts/tests/BenchmarkRunner.gd
# ... copy to baseline ...

# Optimize PlayerLifecycle
# ... make code changes ...

# Measure impact
godot --headless -s res://scripts/tests/BenchmarkRunner.gd
# Look for: lifecycle_advancement: 320.00 ms -> 180.00 ms (-43.8%) [IMPROVEMENT]

# If successful, update baseline
cp ~/.local/share/godot/.../benchmark_latest.json \
   ~/.local/share/godot/.../benchmark_baseline.json
```

## Advanced Usage

### Analyzing JSON Results

```bash
# Extract specific metrics with jq
cd ~/.local/share/godot/app_userdata/gridiron-dynasty/benchmarks/

# Player generation time
jq '.operations.player_generation.time_ms' benchmark_latest.json

# Compare two runs
diff <(jq '.operations' run1.json) <(jq '.operations' run2.json)

# Track memory over time
jq '.memory.player_memory.estimated_kb_per_player' benchmark_*.json
```

### Running Specific Categories

The benchmark runner runs all categories. To test specific areas:

1. **Comment out categories** in `BenchmarkRunner.gd`:
   ```gdscript
   # _results["phase_timing"] = _run_phase_timing_benchmarks()
   # _results["operations"] = _run_operation_benchmarks()
   _results["bootstrap"] = _run_bootstrap_benchmarks()  # Only this
   # _results["memory"] = _run_memory_benchmarks()
   ```

2. **Run subset** for faster iteration during optimization work

### CI Integration (Future)

Example GitHub Actions workflow:

```yaml
name: Benchmark

on:
  push:
    branches: [main]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Godot
        uses: chickensoft-games/setup-godot@v1
        with:
          version: 4.2.1

      - name: Run Benchmarks
        run: godot --headless -s res://scripts/tests/BenchmarkRunner.gd

      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: benchmark-results
          path: ~/.local/share/godot/app_userdata/*/benchmarks/benchmark_latest.json

      - name: Check Regression
        run: |
          python scripts/ci/check_benchmark_regression.py \
            ~/.local/share/godot/.../benchmark_latest.json \
            baseline/benchmark_baseline.json
```

## Troubleshooting

### Benchmark Takes Too Long

Expected: 5-15 minutes. If longer:
- Check system resources (CPU, RAM)
- Close other applications
- Run on dedicated hardware (not shared VM)

### Results Vary Too Much

Some variance (5-10%) is normal due to:
- System load
- OS scheduling
- Disk I/O

For consistent results:
- Close background applications
- Run multiple times and average
- Use dedicated benchmark machine

### Baseline Comparison Not Showing

Ensure baseline exists:
```bash
ls -lh ~/.local/share/godot/app_userdata/gridiron-dynasty/benchmarks/benchmark_baseline.json
```

If missing, copy from latest:
```bash
cd ~/.local/share/godot/app_userdata/gridiron-dynasty/benchmarks/
cp benchmark_latest.json benchmark_baseline.json
```

### Memory Estimates Seem Wrong

Memory benchmarks use JSON serialization as proxy. This is an **estimate**, not exact measurement.

For precise memory profiling:
1. Use Godot's built-in profiler (Editor → Debugger → Profiler)
2. Run specific scene in editor
3. Monitor "Memory" tab

JSON estimates are good for **relative comparison**, not absolute values.

## Best Practices

1. **Run on clean system** - Close unnecessary applications
2. **Establish baseline early** - After major features, set new baseline
3. **Compare relatively** - Use baseline comparison, not absolute times
4. **Track over time** - Keep historical benchmark JSONs for trend analysis
5. **Validate optimizations** - Always benchmark before/after code changes
6. **Document hardware** - Note system specs when sharing benchmark results

## Questions?

See full specification: `docs/tasks/TASK_F8_benchmark_suite.md`
