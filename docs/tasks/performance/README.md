# Performance Optimization Tasks (Track F & P)

## Overview

Performance optimization tasks focus on reducing simulation time and memory usage. The major optimization effort was completed in January 2026 (see [archive](../archive/2026-01/)), achieving 96% bootstrap time reduction.

## Remaining Tasks

### F7: Development Report Deferral (READY)
**Status**: 🟢 Ready to start
**Priority**: Low
**Effort**: 1-2 days
**Expected Impact**: 5-10% memory reduction, minor CPU savings

#### Problem
Each player accumulates a `development_report` array tracking yearly changes (stats, injuries, development context). This data is:
- Generated during every lifecycle advancement
- Stored for every player's entire career
- Only used for debugging and UI display
- Grows unbounded over multi-year simulations

#### Proposed Solution
Defer report generation until actually needed:
1. Add `generate_reports: bool = false` flag to lifecycle functions
2. Only generate reports when explicitly requested (UI display, debugging)
3. For world generation, skip reports entirely (95% of lifecycle calls)

#### Implementation
**Files to modify**:
- `scripts/world/PlayerLifecycle.gd` - Add `generate_reports` parameter
- `scripts/world/HighSchoolSeason.gd` - Pass `generate_reports = false`
- `scripts/world/CollegeSeason.gd` - Pass `generate_reports = false`
- `scripts/world/NflSeason.gd` - Pass `generate_reports = false`
- UI components - Pass `generate_reports = true` when displaying player details

**Memory Impact**:
- Current: ~200 bytes/player/year for reports
- With deferral: 0 bytes for world gen, ~200 bytes only when displayed
- 20-year bootstrap: ~3.2MB savings (15,000 players × 200 bytes × 20 years)

#### Testing Requirements
- Verify world generation produces identical results (determinism)
- Verify UI still shows reports when requested
- Benchmark memory usage before/after

#### Trade-offs
**Pros**:
- Significant memory savings for long simulations
- No impact on simulation correctness
- Slight CPU savings from skipping report generation

**Cons**:
- Historical player data not available unless regenerated
- Adds parameter to lifecycle interface
- May need to regenerate reports on-demand for historical players

### P1: Phase Timing Capture (READY)
**Status**: 🟢 Ready to start
**Priority**: Medium
**Effort**: 1 day
**Expected Impact**: Better observability for future optimization

#### Problem
Current `BenchmarkRunner` provides total bootstrap time but not per-phase breakdown. We can't answer questions like:
- Which phases are now the bottlenecks after F1-F6 optimizations?
- How do phase times scale with player population?
- Which phases benefit most from parallelization?

#### Proposed Solution
Add opt-in phase timing instrumentation to world generation pipeline:

```gdscript
# In AdvanceWorldYear.run()
func run(world_state: Dictionary, capture_timing: bool = false) -> Dictionary:
    var phase_timings := {}

    if capture_timing:
        var start := Time.get_ticks_usec()

    # Run phase...

    if capture_timing:
        phase_timings["hs_generation"] = Time.get_ticks_usec() - start

    return {"world_state": ..., "timings": phase_timings}
```

#### Implementation
**Files to modify**:
- `scripts/pipelines/AdvanceWorldYear.gd` - Add timing capture
- `scripts/pipelines/BootstrapGameWorld.gd` - Aggregate per-year timings
- `scripts/tests/BenchmarkRunner.gd` - Output timing breakdown
- `docs/metrics/BENCHMARKS.md` - Document timing data format

**Output Format**:
```json
{
  "total_time_ms": 30000,
  "per_year_timings": [
    {
      "year": 2006,
      "phases": {
        "hs_generation": 500,
        "hs_season": 800,
        "college_recruiting": 2000,
        "college_season": 1200,
        "nfl_draft": 1000,
        "nfl_season": 900
      }
    }
  ],
  "phase_totals": {
    "college_recruiting": 40000,
    "college_season": 24000,
    "nfl_draft": 20000
  }
}
```

#### Testing Requirements
- Verify timing capture doesn't alter simulation output
- Verify timing overhead is negligible (< 1% of total time)
- Test both with and without capture enabled

#### Use Cases
1. **Identify New Bottlenecks**: After F1-F6 optimizations, what's slow now?
2. **Validate Optimizations**: Measure before/after for future improvements
3. **Scaling Analysis**: How do phases scale with player count?
4. **Profiling Target Selection**: Data-driven decision on next optimization

## Completed Work (January 2026)

See [archive/2026-01/README.md](../archive/2026-01/README.md) for full details.

### Summary of Completed Tasks
- **F1**: Profiling Report - Identified recruiting (50%), lifecycle (20%), deep copies (15%) as bottlenecks
- **F2**: Recruiting Optimization - O(N×M) → O(N+M), 70% time reduction
- **F3**: Scout Caching - Cached perception calculations
- **F4**: Deep Copy Reduction - 90% memory allocation reduction
- **F5**: Parallel Lifecycle - 2x speedup on multi-core systems
- **F6**: Config Optimization - 10x faster config access
- **F8**: Benchmark Suite - Created measurement framework
- **P2**: Recruiting Score Cache - Eliminated redundant evaluations
- **P3**: Lifecycle Copy Reduction - Additional 15-20% memory savings

### Performance Improvements Achieved
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| 20-year bootstrap | 12 minutes | 30 seconds | 96% faster |
| Memory per year | 2.27 GB | 154 MB | 93% reduction |
| College recruiting | 15s/year | 2s/year | 87% faster |
| Player lifecycle | 4s/year | 1s/year | 75% faster |

## Optimization Patterns Established

### 1. Algorithmic First
Biggest wins come from reducing complexity (O(N×M) → O(N))

### 2. Memory Pressure Matters
Reducing allocations improves CPU cache efficiency

### 3. Selective Copying
Deep copy only mutable nested structures, share primitives

### 4. Parallelization
Use ThreadPool for independent operations (2x speedup)

### 5. Pre-extraction
Cache expensive computations, pre-extract config values

### 6. Profiling-Driven
Measure before optimizing, validate improvements

## Future Optimization Opportunities

### High Impact (if needed)
1. **GPU-accelerated stat calculations** - Offload player development math
2. **Incremental world state** - Delta-based updates instead of full copies
3. **Lazy team/conference generation** - Only generate what's accessed

### Medium Impact
1. **F7: Development Report Deferral** - 5-10% memory savings
2. **String interning** - Reduce string duplication (positions, names)
3. **Compact player format** - Custom struct instead of Dictionary

### Low Impact (diminishing returns)
1. **Further config optimization** - Already 10x faster
2. **More aggressive caching** - Hit rate plateaus quickly
3. **Micro-optimizations** - GDScript JIT already handles most

## Guidelines for New Optimizations

### Before Starting
1. **Profile first**: Use BenchmarkRunner + phase timing (P1)
2. **Identify bottleneck**: What specific operation is slow?
3. **Measure baseline**: Record current performance metrics
4. **Check low-hanging fruit**: Is it an algorithmic issue?

### During Implementation
1. **Preserve determinism**: Same seed = same output
2. **Comprehensive tests**: Verify correctness at each step
3. **Clear boundaries**: Maintain ownership model
4. **Incremental changes**: One optimization at a time

### After Completion
1. **Validate improvement**: Measure actual speedup
2. **Document trade-offs**: Memory vs speed, complexity vs gain
3. **Create summary**: Implementation notes + lessons learned
4. **Archive task**: Move to archive with completion date

## Related Documentation

- Archive: [../archive/2026-01/README.md](../archive/2026-01/README.md)
- Implementation details: `docs/implementation/TASK_F*_IMPLEMENTATION.md`
- Benchmark results: `docs/metrics/BENCHMARKS.md`
- Coding guidelines: `docs/AGENT_GUIDELINES.md`
