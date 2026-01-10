# Task: Parallel Test Execution (Phase 3)

**Track**: Testing Performance Strategy
**Dependencies**: TASK_TEST_FIXTURES (Phase 2) - Should be completed first for best results
**Status**: Not started
**Estimated Effort**: 5-7 days
**Priority**: Low (nice-to-have optimization)

## Goal

Implement parallel test execution using Godot's threading system to leverage multi-core CPUs, reducing test suite execution time from ~30-45 seconds (with fixtures) to ~15-30 seconds.

## Current Problem

Tests run sequentially on a single core:
```gdscript
for path in TEST_SCRIPTS:
    var script = load(path)
    var test_instance = script.new()
    test_instance.run(helper)  # Blocks until complete
```

**Impact**: Wastes available CPU cores, slower than necessary

## Prerequisites

### Test Isolation Requirements

For parallel execution, tests MUST be:
1. **Stateless**: No shared global state between tests
2. **Config-isolated**: Each test creates its own ConfigService instance
3. **RNG-isolated**: Each test uses its own RNG instance (no global RNG)
4. **File-isolated**: No shared file writes or reads during test execution

**Current status**: ✅ Most tests already follow these patterns (ConfigService architecture)

## Implementation

### Step 1: Test Categorization

**File**: `scripts/tests/TestRunner.gd` (update)

Categorize tests by execution time:

```gdscript
# Fast tests (< 1 second each) - Run sequentially first
const FAST_TESTS := [
    "res://scripts/tests/test_rand.gd",
    "res://scripts/tests/test_config.gd",
    "res://scripts/tests/test_helpers.gd",
    "res://scripts/tests/test_deager.gd",
    "res://scripts/tests/test_stathelpers.gd",
    "res://scripts/tests/test_combine_calculator.gd",
    "res://scripts/tests/test_player_model.gd",
    "res://scripts/tests/test_world_calendar.gd",
    # ... ~20 tests, < 10 seconds total
]

# Slow tests (> 2 seconds each) - Run in parallel
const SLOW_TESTS := [
    "res://scripts/tests/test_player_generator.gd",
    "res://scripts/tests/test_draft_class_generator.gd",
    "res://scripts/tests/test_bootstrap_game_world.gd",
    "res://scripts/tests/test_world_history_preview.gd",
    "res://scripts/tests/test_college_recruiting.gd",
    "res://scripts/tests/test_nfl_draft.gd",
    "res://scripts/tests/test_high_school_season.gd",
    # ... ~10 tests, ~30 seconds total sequential
]
```

### Step 2: Create Parallel Test Runner

**File**: `scripts/tests/TestRunnerParallel.gd` (new)

```gdscript
extends SceneTree
## Parallel test runner using thread pool

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const Threader = preload("res://scripts/support/threading/Threader.gd")

# Fast tests (< 1 second each) - Already defined in TestRunner
const FAST_TESTS := [...]

# Slow tests (> 2 seconds each) - Run these in parallel
const SLOW_TESTS := [...]

func _init() -> void:
    var start_time := Time.get_ticks_msec()

    print("🧪 Running test suite (parallel mode)...")
    print("Fast tests: %d | Slow tests: %d" % [FAST_TESTS.size(), SLOW_TESTS.size()])

    # Step 1: Run fast tests sequentially (no overhead worth parallelizing)
    var fast_results := _run_tests_sequential(FAST_TESTS)

    # Step 2: Run slow tests in parallel (maximize throughput)
    var slow_results := _run_tests_parallel(SLOW_TESTS)

    # Combine results
    var all_results := fast_results + slow_results
    var total_failures := _count_failures(all_results)

    var elapsed := Time.get_ticks_msec() - start_time
    print("\n⏱️  Total time: %.2f seconds" % (elapsed / 1000.0))

    if total_failures == 0:
        print("✅ All tests passed (%d tests)." % all_results.size())
        quit(0)
    else:
        print("❌ Failures (%d):" % total_failures)
        _print_failures(all_results)
        quit(1)

## Run tests sequentially (for fast tests)
func _run_tests_sequential(test_paths: Array) -> Array:
    var results: Array = []

    for path in test_paths:
        var result := _run_single_test(path)
        results.append(result)

    return results

## Run tests in parallel using thread pool
func _run_tests_parallel(test_paths: Array) -> Array:
    var max_threads := _determine_thread_count()
    print("  Using %d threads for parallel execution" % max_threads)

    # Use Threader.map_parallel to run tests concurrently
    var results := Threader.map_parallel(
        test_paths,
        func(path): return _run_single_test(path),
        max_threads
    )

    return results

## Run a single test and capture results
func _run_single_test(path: String) -> Dictionary:
    var script = load(path)
    if script == null:
        return {
            "path": path,
            "failures": ["Failed to load test script"]
        }

    var test_instance = script.new()
    var helper = TestHelpers.new()

    # Run test with isolated helper
    test_instance.run(helper)

    return {
        "path": path,
        "failures": helper.failures.duplicate(),
        "assertions": helper.assertion_count
    }

## Determine optimal thread count
func _determine_thread_count() -> int:
    var cpu_count := OS.get_processor_count()

    # Cap at 4 threads to avoid:
    # - Memory pressure (each thread loads full test context)
    # - Resource contention (disk I/O, config loading)
    # - Diminishing returns (Amdahl's law)
    return mini(4, maxi(2, cpu_count - 1))

## Count total failures across all results
func _count_failures(results: Array) -> int:
    var count := 0
    for result in results:
        count += (result.failures as Array).size()
    return count

## Print failure details
func _print_failures(results: Array) -> void:
    for result in results:
        var failures: Array = result.failures
        if failures.is_empty():
            continue

        print("\n  %s:" % result.path)
        for failure in failures:
            print("    - %s" % failure)
```

### Step 3: Thread Safety Audit

**File**: `docs/architectural_notes/thread_safety_audit.md` (new)

Document thread safety for all tests:

```markdown
# Thread Safety Audit

## Safe for Parallel Execution

✅ **RNG Isolation**: All tests create their own RNG instances
✅ **Config Isolation**: ConfigService uses instance methods, no global state
✅ **No File Writes**: Tests only read files, no shared writes
✅ **No Global State**: All test data stored in local variables

## Potential Risks

⚠️ **Config Loading**: Multiple threads loading same config files
- **Mitigation**: Config files are read-only, safe for concurrent reads

⚠️ **Memory Pressure**: Each thread loads full game context
- **Mitigation**: Limit to 4 threads maximum

⚠️ **Assertion Timing**: print() statements may interleave
- **Mitigation**: Capture failures in thread-local arrays, print after join
```

### Step 4: Integration with CI/CD

**File**: `.github/workflows/test.yml` (update)

```yaml
name: Tests

on: [push, pull_request]

jobs:
  fast-tests:
    name: Fast Tests (< 10s)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run fast tests
        run: godot --headless -s res://scripts/tests/TestRunnerFast.gd

  full-parallel-tests:
    name: Full Test Suite (Parallel)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run parallel test suite
        run: godot --headless -s res://scripts/tests/TestRunnerParallel.gd
```

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Race conditions on config | Low | High | Config files are read-only |
| Memory thrashing with too many threads | Medium | Medium | Cap at 4 threads |
| Flaky tests due to timing | Low | High | Tests already deterministic with fixed seeds |
| print() statement interleaving | High | Low | Capture output per thread, print after join |

## Testing Strategy

### Validation Steps

1. **Run sequential and parallel side-by-side**
   ```bash
   godot --headless -s res://scripts/tests/TestRunner.gd
   godot --headless -s res://scripts/tests/TestRunnerParallel.gd
   ```
   Verify same pass/fail results

2. **Run parallel multiple times**
   ```bash
   for i in {1..10}; do
     godot --headless -s res://scripts/tests/TestRunnerParallel.gd
   done
   ```
   Verify deterministic results (no flakiness)

3. **Profile thread contention**
   - Monitor CPU usage during parallel execution
   - Verify all cores are utilized
   - Check for thread starvation or thrashing

## Performance Targets

| Configuration | Sequential | Parallel (2 threads) | Parallel (4 threads) |
|---------------|-----------|---------------------|---------------------|
| With fixtures | ~30-45s | ~20-30s | ~15-25s |
| Without fixtures | ~141s | ~80-100s | ~50-70s |

**Expected improvement**: 2-3x speedup on 4+ core CPUs

## Acceptance Criteria

- [ ] TestRunnerParallel.gd created and tested
- [ ] Thread safety audit completed
- [ ] Parallel execution produces same results as sequential
- [ ] No flakiness across 10+ runs
- [ ] Test suite completes in < 30 seconds (with fixtures)
- [ ] CPU utilization shows multi-core usage
- [ ] CI/CD updated to use parallel runner

## Files to Create

- `scripts/tests/TestRunnerParallel.gd`
- `docs/architectural_notes/thread_safety_audit.md`

## Files to Modify

- `.github/workflows/test.yml` (if CI/CD exists)

## Optional Enhancements

### Real-Time Progress Reporting

Add progress updates during parallel execution:

```gdscript
# In TestRunnerParallel._init()
var completed := 0
var total := SLOW_TESTS.size()

# Use thread-safe counter
var mutex := Mutex.new()

func _on_test_complete(result: Dictionary) -> void:
    mutex.lock()
    completed += 1
    print("  [%d/%d] %s" % [completed, total, result.path])
    mutex.unlock()
```

### Test Result Caching

Cache test results based on file checksums:

```gdscript
# If test file hasn't changed since last run, skip it
var cache := TestCache.new()
if cache.is_up_to_date(test_path):
    return cache.get_cached_result(test_path)
```

## Known Limitations

1. **Godot Thread Limitations**
   - Maximum recommended threads: 4-8
   - Each thread has separate SceneTree context
   - Some Godot APIs are not thread-safe

2. **Diminishing Returns**
   - Most time is in I/O (loading configs, fixtures)
   - CPU-bound tests benefit most from parallelization
   - Amdahl's Law: speedup limited by sequential portions

## Next Steps

1. Complete Phase 2 (fixtures) first for maximum benefit
2. Implement TestRunnerParallel.gd
3. Conduct thread safety audit
4. Profile and tune thread count
5. Update CI/CD to use parallel runner
6. Document results and lessons learned

## Success Metrics

After Phase 3 completion:
- ✅ Test suite completes in < 30 seconds (full suite)
- ✅ Fast tests complete in < 10 seconds (developer feedback loop)
- ✅ No flakiness (deterministic results across runs)
- ✅ Multi-core CPU utilization visible in profiling

## Final Performance Comparison

| Phase | Test Time | Improvement | Developer Experience |
|-------|-----------|-------------|---------------------|
| Baseline | 141s | - | Very slow |
| Phase 1 (Fast tests only) | 10s | 14x | Great for quick checks |
| Phase 2 (Fixtures) | 30-45s | 3-5x | Good for full validation |
| Phase 3 (Parallel) | 15-30s | 5-9x | Excellent |
