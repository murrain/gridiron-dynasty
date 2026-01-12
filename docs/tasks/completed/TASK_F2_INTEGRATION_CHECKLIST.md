# Task F2 Integration Checklist

Use this checklist to validate and integrate the college recruiting optimization.

---

## Pre-Integration Validation

### Step 1: Verify Test Suite

- [ ] Run full test suite
  ```bash
  godot --headless --script scripts/tests/test_recruiting_optimization.gd
  ```

- [ ] Verify all 8 tests pass:
  - [ ] `test_optimized_determinism` ✓
  - [ ] `test_parallel_determinism` ✓
  - [ ] `test_backward_compatibility` ✓
  - [ ] `test_seed_variation` ✓
  - [ ] `test_edge_cases` ✓
  - [ ] `test_recruiting_constraints` ✓
  - [ ] `test_performance_comparison` ✓
  - [ ] `test_rng_consumption_consistency` ✓

- [ ] No failures or warnings in output

### Step 2: Run Performance Benchmark

- [ ] Execute benchmark script
  ```bash
  godot --headless --script scripts/pipelines/RecruitingBenchmark.gd
  ```

- [ ] Verify performance targets:
  - [ ] Small dataset (100×10): 10x+ speedup
  - [ ] Medium dataset (500×30): 15x+ speedup
  - [ ] Large dataset (1000×65): 20x+ speedup
  - [ ] Realistic dataset (2000×130): 18x+ speedup

- [ ] Verify correctness:
  - [ ] Sequential matches original: PASS
  - [ ] Parallel matches sequential: PASS

### Step 3: Code Review

- [ ] Review `CollegeRecruitingOptimized.gd`:
  - [ ] Algorithm logic correct
  - [ ] RNG seeding pattern implemented correctly
  - [ ] No shared mutable state between threads
  - [ ] Comments explain RNG consumption

- [ ] Review test coverage:
  - [ ] Edge cases covered (empty inputs, boundaries)
  - [ ] Determinism verified (5+ runs)
  - [ ] Parallel execution tested
  - [ ] Performance regression prevention

- [ ] Review documentation:
  - [ ] Task specification complete
  - [ ] Design rationale documented
  - [ ] Migration guide clear
  - [ ] Performance impact measured

---

## Integration Steps

### Step 4: Locate Usage Sites

- [ ] Find all imports of original `CollegeRecruiting.gd`:
  ```bash
  grep -r "CollegeRecruiting" scripts/ --include="*.gd"
  ```

- [ ] Identify files to update:
  - [ ] List file: `_______________________________`
  - [ ] List file: `_______________________________`
  - [ ] List file: `_______________________________`

### Step 5: Update Imports (One at a Time)

For each usage site:

- [ ] **File:** `_______________________________`
  - [ ] Change import path:
    ```gdscript
    # Before
    const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")

    # After
    const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruitingOptimized.gd")
    ```
  - [ ] Add `use_parallel` parameter (if not present):
    ```gdscript
    var result = pipeline.run(
        recruits, colleges, config,
        positions_cfg, stats_cfg, class_rules, scouts_cfg,
        seed, year,
        true  # use_parallel = true
    )
    ```
  - [ ] Run existing tests for this module
  - [ ] Verify no regressions

- [ ] **File:** `_______________________________`
  - [ ] (Repeat above steps)

- [ ] **File:** `_______________________________`
  - [ ] (Repeat above steps)

### Step 6: Run Integration Tests

- [ ] Run full project test suite:
  ```bash
  godot --headless --script scripts/tests/TestRunner.gd
  ```

- [ ] Verify all tests pass (no new failures)

- [ ] Check for performance improvements:
  - [ ] Multi-year simulation benchmark
  - [ ] Measure total simulation time
  - [ ] Verify recruiting phase < 5% of total time

### Step 7: Validation Run

- [ ] Execute full 50-year simulation:
  ```bash
  godot --headless --script scripts/pipelines/BootstrapWorld.gd
  ```

- [ ] Monitor performance:
  - [ ] Recruiting phase per year < 150 ms
  - [ ] Total simulation time reduced by 50%+
  - [ ] No crashes or errors

- [ ] Verify determinism:
  - [ ] Run with same seed twice
  - [ ] Compare outputs (should be identical)
  - [ ] Check commitment counts match

---

## Post-Integration Monitoring

### Step 8: Performance Monitoring

Add performance logging (optional but recommended):

```gdscript
# In your main simulation loop
var time_start = Time.get_ticks_usec()
var result = recruiting.run(...)
var time_elapsed = Time.get_ticks_usec() - time_start

# Log performance
print("Year %d recruiting: %.2f ms" % [year, time_elapsed / 1000.0])

# Alert if slow
if time_elapsed > 150_000:  # 150ms threshold
    push_warning("Recruiting phase slow: %.2f ms" % (time_elapsed / 1000.0))
```

- [ ] Add performance logging to main simulation loop
- [ ] Monitor first 10 years of simulation
- [ ] Record typical recruiting times:
  - [ ] Average: `_______ ms` (expect 80-120 ms sequential)
  - [ ] Max: `_______ ms` (should be < 150 ms)
  - [ ] Min: `_______ ms` (should be > 20 ms)

### Step 9: Determinism Monitoring

Add seed verification (optional):

```gdscript
# Store seeds and results for verification
var recruiting_history = []

var result = recruiting.run(..., seed, year, true)
recruiting_history.append({
    "year": year,
    "seed": seed,
    "commitment_count": result.commitments.size(),
    "uncommitted_count": result.uncommitted.size()
})

# Periodically verify determinism
if year % 10 == 0:
    verify_determinism(recruiting_history)
```

- [ ] Add seed logging
- [ ] Run same scenario twice with same seed
- [ ] Verify identical outcomes

---

## Rollback Plan (If Needed)

### Step 10: Rollback Procedure

If issues are discovered after integration:

1. **Immediate rollback:**
   - [ ] Revert imports to original `CollegeRecruiting.gd`
   - [ ] Remove `use_parallel` parameter
   - [ ] Run tests to verify rollback successful

2. **Document issue:**
   - [ ] Record seed that caused problem: `_____________`
   - [ ] Record dataset size: `_____ recruits, _____ colleges`
   - [ ] Record error message or unexpected behavior:
     ```
     ___________________________________________________
     ___________________________________________________
     ```

3. **Debug:**
   - [ ] Run isolated test with problematic seed
   - [ ] Compare original vs optimized outputs
   - [ ] Check RNG consumption pattern
   - [ ] Review parallel execution logs

4. **Fix and re-test:**
   - [ ] Implement fix in `CollegeRecruitingOptimized.gd`
   - [ ] Add regression test for issue
   - [ ] Re-run full test suite
   - [ ] Re-attempt integration

---

## Sign-off

### Development Sign-off

- [ ] All tests passing
- [ ] Performance targets met
- [ ] Code review complete
- [ ] Documentation complete

**Signed:** _________________ **Date:** _________

### QA Sign-off

- [ ] Integration tests passing
- [ ] No regressions detected
- [ ] Performance improvements verified
- [ ] Determinism validated

**Signed:** _________________ **Date:** _________

### Production Deployment

- [ ] All sign-offs complete
- [ ] Rollback plan documented
- [ ] Monitoring in place
- [ ] Team notified of changes

**Signed:** _________________ **Date:** _________

---

## Post-Deployment Checklist

### Week 1: Initial Monitoring

- [ ] Day 1: Check performance logs
  - [ ] Average recruiting time: `_______ ms`
  - [ ] Any warnings/errors: Yes / No

- [ ] Day 3: Verify determinism
  - [ ] Run test simulation with known seed
  - [ ] Compare to baseline results
  - [ ] Identical: Yes / No

- [ ] Day 7: Performance trends
  - [ ] Recruiting time stable: Yes / No
  - [ ] No performance degradation: Yes / No
  - [ ] Memory usage normal: Yes / No

### Week 2-4: Extended Monitoring

- [ ] Week 2: Long-run simulation
  - [ ] 100-year simulation completes: Yes / No
  - [ ] Total time: `_______ seconds` (expect < 100s)
  - [ ] No crashes: Yes / No

- [ ] Week 4: Production stability
  - [ ] No bug reports: Yes / No
  - [ ] Performance consistent: Yes / No
  - [ ] Ready to archive original: Yes / No

---

## Archival (After 30 Days)

Once validated in production:

- [ ] Archive original implementation:
  ```bash
  mv scripts/pipelines/CollegeRecruiting.gd \
     scripts/pipelines/CollegeRecruiting.gd.backup
  ```

- [ ] Update all documentation references

- [ ] Remove backward compatibility tests

- [ ] Mark task as complete:
  ```bash
  # Update COMPLETED.md
  echo "- Task F2: College Recruiting Optimization (2026-01-10)" >> docs/COMPLETED.md
  ```

---

## Success Criteria Summary

| Criterion | Target | Actual | Status |
|-----------|--------|--------|--------|
| Determinism tests pass | 8/8 | ___/8 | ⬜ |
| Performance speedup (seq) | 15x+ | ___x | ⬜ |
| Performance speedup (par) | 40x+ | ___x | ⬜ |
| Recruiting time/year | < 150ms | ___ms | ⬜ |
| No correctness regressions | 0 | ___ | ⬜ |
| Integration smooth | Yes | ___ | ⬜ |
| Production stable (30 days) | Yes | ___ | ⬜ |

**Overall Status:** 🟡 In Progress / 🟢 Complete / 🔴 Issues

---

## Notes

Use this space for any additional notes, issues, or observations during integration:

```
___________________________________________________________

___________________________________________________________

___________________________________________________________

___________________________________________________________

___________________________________________________________
```

---

**Checklist Version:** 1.0
**Last Updated:** 2026-01-10
**Maintained By:** Development Team
