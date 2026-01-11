# Phase F: Performance Optimization Roadmap

**Track**: Performance Optimization
**Status**: In progress (baseline refreshed)
**Created**: January 2026
**Target**: Reduce 20-year bootstrap below 150 seconds without reducing simulation realism

---

## Executive Summary

BenchmarkRunner results (2026-01-11) show a 20-year bootstrap of **184.72 seconds** (~9.24 seconds/year) with recruiting and lifecycle advancement still dominant. The primary bottlenecks remain O(N*M) recruiting evaluations, redundant scout scoring, and dictionary deep-copy churn.

---

## Current Performance Baseline

| Metric | Current | Target |
|--------|---------|--------|
| Per-year simulation | ~9.24s | <7.5s |
| 20-year bootstrap | 184.72s | <150s |
| College recruiting (benchmark micro) | ~5.00s | <3s |
| NFL Draft | ~5s/year | <1s/year |
| Memory (10yr) | ~500MB | <200MB |

---

## Task Overview

| Task | Description | Priority | Effort | Impact |
|------|-------------|----------|--------|--------|
| F1 | Profiling Report | Done | - | Foundation |
| F2 | College Recruiting Optimization | Done | 2-3 days | 50-70% reduction |
| F3 | Scout Evaluation Caching | Done | 1-2 days | 20-30% reduction |
| F4 | Deep Copy Reduction | P2 | 1-2 days | 10-20% reduction |
| F5 | Parallel Player Lifecycle | P3 | 1-2 days | 10-15% reduction |
| F6 | Config Access Optimization | P5 | 0.5-1 day | 5-10% reduction |
| F7 | Development Report Deferral | P4 | 0.5 day | Memory focus |
| F8 | Benchmark Suite | Done | 1 day | Validation |

**Total Estimated Effort**: 8-12 days

---

## Task Dependencies

```
F1 (Profiling) - COMPLETE
    |
    v
F8 (Benchmarks) - COMPLETE
    |
    v
F2 (Recruiting) - COMPLETE
    |
    v
F3 (Scout Caching) - COMPLETE
    |
    v
F4 (Deep Copy)
    |
    v
F5 (Parallel Lifecycle)
    |
    +---> F6 (Config)
    |
    +---> F7 (Reports)
    |
    v
F8 (Benchmarks) -----> Verify targets
```

---

## Implementation Order

### Phase F.1: Foundation (Completed)

1. **F8: Benchmark Suite** - Measurement infrastructure in place
   - Baseline captured (BenchmarkRunner)
   - Regression detection enabled

### Phase F.2: Critical Path (Completed)

2. **F2: College Recruiting Optimization** - Completed
   - Pre-computed baseline scores
   - Lightweight scout adjustments
   - Parallel college processing

3. **F3: Scout Evaluation Caching** - Completed
   - ScoreCache class
   - Integration with recruiting
   - Integration with NFL Draft

### Phase F.3: Memory & Efficiency (Next)

4. **F4: Deep Copy Reduction** - Reduce allocations
   - Selective copying
   - In-place modification where safe

5. **F5: Parallel Player Lifecycle** - CPU utilization
   - Seed derivation for parallel RNG
   - Per-team/roster parallelization

### Phase F.4: Polish (After F5)

6. **F6: Config Access Optimization** - Minor speedup
   - Early binding of config values
   - Config helper classes

7. **F7: Development Report Deferral** - Memory optimization
   - Skip reports during bootstrap
   - On-demand generation

### Phase F.5: Validation (After F6/F7)

8. **F8: Final Benchmarks** - Verify all targets met
   - Compare to baseline
   - Document improvements
   - Update targets if needed

---

## Success Criteria

### Performance

- [ ] 20-year bootstrap completes in under 150 seconds
- [ ] Per-year simulation under 7.5 seconds
- [ ] No performance regressions in any phase

### Quality

- [ ] All existing tests pass
- [ ] Determinism preserved (same seeds produce same results)
- [ ] No new bugs introduced

### Documentation

- [ ] All task files completed and moved to COMPLETED.md
- [ ] Benchmark results documented
- [ ] Architectural notes updated

---

## Architectural Constraints

All optimizations must:

1. **Preserve Determinism** - Same inputs produce same outputs
2. **Maintain Thread Safety** - No shared mutable state
3. **Keep Config-Driven Values** - No magic numbers
4. **Support Serialization** - World state remains saveable
5. **Enable Testability** - Optimizations don't break tests

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Breaking determinism | Run determinism tests after each task |
| Thread safety issues | Use seed derivation, avoid shared state |
| Regression in correctness | Full test suite after each task |
| Diminishing returns | Track improvements per task, adjust priorities |

---

## Verification Commands

```bash
# Run baseline benchmarks (allow sufficient time)
timeout 900 godot --headless benchmark_runner.tscn

# Run fast tests (after each task)
godot --headless -s res://scripts/tests/TestRunnerFast.gd

# Run full test suite
timeout 300 godot --headless -s res://scripts/tests/TestRunner.gd

# Run bootstrap and observe timing (20-year bootstrap can take 10+ minutes)
timeout 900 godot --headless bootstrap_preview.tscn

# For shorter testing, use 5-year bootstrap
timeout 300 godot --headless bootstrap_preview.tscn -- --years 5
```

---

## Related Documents

- `docs/tasks/TASK_F1_profiling_report.md` - Detailed profiling analysis
- `docs/tasks/TASK_F2_recruiting_optimization.md` - Critical path optimization
- `docs/tasks/TASK_F3_scout_caching.md` - Caching implementation
- `docs/tasks/TASK_F4_deep_copy_reduction.md` - Memory optimization
- `docs/tasks/TASK_F5_parallel_lifecycle.md` - Parallelization
- `docs/tasks/TASK_F6_config_optimization.md` - Config access
- `docs/tasks/TASK_F7_development_report_deferral.md` - Report deferral
- `docs/tasks/TASK_F8_benchmark_suite.md` - Benchmark infrastructure

---

## Notes for Implementers

### Getting Started

1. Read F1 (profiling report) to understand bottlenecks
2. Implement F8 (benchmarks) to establish baseline
3. Start with F2 (recruiting) for maximum impact
4. Run tests after each task

### Common Pitfalls

- Don't optimize without measuring first
- Ensure determinism tests pass after each change
- Avoid premature optimization of low-impact areas
- Keep parallelization simple (seed derivation pattern)

### When to Stop

If target (3-minute bootstrap) is reached before all tasks complete, remaining tasks become optional polish. Prioritize based on remaining bottlenecks as revealed by benchmarks.

---

Last updated: January 2026
