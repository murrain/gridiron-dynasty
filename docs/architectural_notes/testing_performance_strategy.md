# Testing Performance Strategy

**Status**: Phase 1 Complete ✅ | Phases 2-3 Available
**Created**: 2026-01-10
**Phase 1 Completed**: January 2026 (PR #66)
**Priority**: High (Phase 1), Medium (Phases 2-3)

---

## Current Status

### Phase 1: Test Categorization + Fast Test Runner ✅ COMPLETED

**Merged**: January 2026, PR #66
**Achievement**: 141s → 10s (14x faster for fast tests)

**Delivered**:
- ✅ `TestRunnerFast.gd` with ~20 fast unit tests
- ✅ Fast test feedback loop: **< 10 seconds**
- ✅ Developer productivity dramatically improved
- ✅ Clear separation: fast tests vs full suite

**Commands Available**:
```bash
# Fast tests only (< 10 seconds) - Use this for rapid iteration
godot --headless -s res://scripts/tests/TestRunnerFast.gd

# Full suite (~2 minutes) - Use before PR submission
godot --headless -s res://scripts/tests/TestRunner.gd
```

**Files Created**:
- `scripts/tests/TestRunnerFast.gd`

---

## Original Problem (For Reference)

**Baseline**: Test suite execution time was 141 seconds (2 minutes 21 seconds)
**Test count**: 43 tests (39 passing, 4 pre-existing failures)
**Bottleneck**: Sequential execution of expensive multi-year simulations

### Root Causes Identified

1. **Expensive Player Generation**: Tests generating thousands of players (~10+ seconds each)
2. **Sequential Execution**: Single-threaded, no parallelization (~60-90 seconds wasted)
3. **Repeated Setup**: Same data regenerated across tests

---

## Remaining Phases (Optional Quality-of-Life Improvements)

### Phase 2: Test Fixtures ⏳ Available

**Status**: Not started
**Effort**: 3-4 days
**Target**: Reduce full suite from 141s to 30-45s (3-5x improvement)

**Goals**:
- Pre-generate expensive test data (players, teams, world states)
- Reduce generation overhead in integration tests
- Version-controlled fixtures for deterministic testing

**Task File**: `docs/tasks/TASK_TEST_FIXTURES.md`

**Key Deliverables**:
- `FixtureLoader.gd` - Helper for loading pre-generated data
- `GenerateTestFixtures.gd` - One-time fixture generation tool
- Fixture data files in `scripts/tests/fixtures/`
- Migrated top 5 slowest tests to use fixtures

**Expected Improvement**: 141s → 30-45s

---

### Phase 3: Parallel Test Execution ⏳ Available

**Status**: Not started
**Dependencies**: Phase 2 recommended (but not required)
**Effort**: 5-7 days
**Target**: Reduce full suite to 15-30s (5-9x improvement from baseline)

**Goals**:
- Leverage multi-core CPUs (4-8 cores)
- Run slow tests in parallel using thread pool
- 2-3x speedup on top of Phase 2 improvements

**Task File**: `docs/tasks/TASK_TEST_PARALLEL.md`

**Key Deliverables**:
- `TestRunnerParallel.gd` - Thread-pool-based test runner
- Thread safety audit documentation
- Performance profiling and tuning

**Expected Improvement**: 30-45s → 15-30s (with Phase 2 fixtures)

---

## Performance Targets Summary

| Phase | Test Time | vs Baseline | Developer Experience |
|-------|-----------|-------------|---------------------|
| **Baseline** | 141s | - | ❌ Very slow |
| **Phase 1 (Fast tests)** | **10s** | **14x faster** | ✅ **Excellent** |
| Phase 1 (Full suite) | 141s | - | ⚠️ Still slow |
| Phase 2 (Fixtures) | 30-45s | 3-5x | ✅ Good |
| Phase 3 (Parallel) | 15-30s | 5-9x | ✅ Excellent |

---

## Recommendation

### For Daily Development
✅ **Use Phase 1 (TestRunnerFast)** - Already available, 10-second feedback

**Workflow**:
```bash
# Make code changes
# Run fast tests (10s)
godot --headless -s res://scripts/tests/TestRunnerFast.gd

# If passing, continue development
# Before PR: run full suite (141s)
godot --headless -s res://scripts/tests/TestRunner.gd
```

### For CI/CD
- **Fast tests on every push** (<10s) - Quick smoke test
- **Full suite on PR merge** (~2min) - Comprehensive validation

### For Future Optimization

**Phase 2 (Fixtures)** is recommended if:
- Full test suite is run frequently (multiple times per day)
- Integration test speed is a bottleneck
- Team size grows (more developers = more test runs)

**Phase 3 (Parallel)** is optional polish:
- Nice-to-have optimization
- Requires thread safety audit
- Best benefit with Phase 2 fixtures already in place

---

## Detailed Implementation Notes

For detailed implementation plans, see:
- **Phase 2**: `docs/tasks/TASK_TEST_FIXTURES.md`
- **Phase 3**: `docs/tasks/TASK_TEST_PARALLEL.md`

These task files contain:
- Step-by-step implementation guides
- Code examples and API designs
- Test requirements and acceptance criteria
- Risk mitigation strategies
- Performance profiling approaches

---

## Success Metrics

### Phase 1 (Achieved ✅)
- ✅ Fast test feedback loop < 10 seconds
- ✅ Clear documentation of fast vs full suite
- ✅ No impact on existing test reliability

### Future Phases
- Phase 2: Full suite < 45 seconds
- Phase 3: Full suite < 30 seconds with parallel execution
- All phases: Zero flakiness, deterministic results

---

## Historical Context

### Why Phase 1 Was Prioritized

Phase 1 delivered **maximum developer benefit** with **minimal complexity**:
- **14x speedup** for common workflows
- **1-day implementation** (vs 3-4 days for Phase 2, 5-7 days for Phase 3)
- **Zero risk** (no architectural changes, just test categorization)
- **Immediate value** (available to all developers immediately)

### Why Phases 2-3 Are Optional

- **Diminishing returns**: Phase 1 already provides excellent feedback
- **Complexity cost**: Fixtures require maintenance, parallelization requires thread safety
- **Current pain tolerable**: 2-minute full suite acceptable for PR validation
- **Can defer**: Optimize later if needed (no blocking issue)

---

## References

- **Phase 1 PR**: #66 (Testing performance strategy)
- **Fast test runner**: `scripts/tests/TestRunnerFast.gd`
- **Full test suite**: `scripts/tests/TestRunner.gd`
- **Phase 2 task**: `docs/tasks/TASK_TEST_FIXTURES.md`
- **Phase 3 task**: `docs/tasks/TASK_TEST_PARALLEL.md`
- **Completed work**: See `docs/COMPLETED.md`
